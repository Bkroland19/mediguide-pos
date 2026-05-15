from __future__ import annotations
import json
import httpx
from app.core.config import get_settings
from app.embeddings.factory import get_embedding_provider
from app.repositories.search_repo import SearchRepository


SYSTEM_PROMPT = """You are MediGuide, a clinical guideline assistant for frontline health workers.
Use only the supplied guideline context.
Do not use general medical knowledge.
If the answer is not found in the context, say that the approved guidelines provided do not contain enough information.
Always include practical next steps and cite source numbers like [1], [2].
Prioritize national guidelines when available.
Mention urgent referral when the context indicates danger signs or emergency care.
"""


class RagService:
    def __init__(self):
        self.settings = get_settings()
        self.embedder = get_embedding_provider()
        self.search = SearchRepository()

    def ask(self, question: str, language: str = "en", program_area: str | None = None, top_k: int | None = None) -> dict:
        top_k = top_k or self.settings.rag_top_k
        q_emb = self.embedder.embed([question])[0]
        vector_hits = self.search.vector_search(q_emb, top_k=top_k, program_area=program_area, language=language)
        keyword_hits = self.search.keyword_search(question, top_k=max(3, top_k // 2), program_area=program_area)
        hits = self._merge_hits(vector_hits, keyword_hits, top_k=top_k)

        if not hits:
            return {
                "answer": "I could not find enough information in the approved MediGuide sources to answer this safely. Please consult the current national guideline or refer to a senior clinician.",
                "citations": [],
                "retrieved": [],
                "safety": {"grounded": False, "reason": "no_context"},
            }

        context = self._format_context(hits)
        answer = self._generate_answer(question, context, hits)
        citations = [
            {
                "chunk_id": str(h["id"]),
                "title": h.get("title"),
                "source_name": h.get("source_name"),
                "source_version": h.get("source_version"),
                "page_start": h.get("page_start"),
                "page_end": h.get("page_end"),
                "similarity": float(h.get("similarity") or 0),
            }
            for h in hits
        ]
        return {
            "answer": answer,
            "citations": citations,
            "retrieved": hits,
            "safety": {"grounded": True, "provider": self.settings.llm_provider},
        }

    def _merge_hits(self, vector_hits: list[dict], keyword_hits: list[dict], top_k: int) -> list[dict]:
        seen = set()
        merged = []
        for hit in sorted(vector_hits + keyword_hits, key=lambda h: float(h.get("similarity") or 0), reverse=True):
            key = str(hit["id"])
            if key in seen:
                continue
            seen.add(key)
            merged.append(hit)
            if len(merged) >= top_k:
                break
        return merged

    def _format_context(self, hits: list[dict]) -> str:
        blocks = []
        for idx, h in enumerate(hits, start=1):
            source = h.get("source_name") or "Approved guideline"
            version = h.get("source_version") or ""
            pages = self._pages(h)
            blocks.append(f"[{idx}] {source} {version} {pages}\nTitle: {h.get('title') or ''}\n{h.get('content') or ''}")
        return "\n\n".join(blocks)

    @staticmethod
    def _pages(hit: dict) -> str:
        if hit.get("page_start") and hit.get("page_end"):
            return f"pages {hit['page_start']}-{hit['page_end']}"
        if hit.get("page_start"):
            return f"page {hit['page_start']}"
        return ""

    def _generate_answer(self, question: str, context: str, hits: list[dict]) -> str:
        provider = self.settings.llm_provider.lower()
        if provider == "extractive":
            return self._extractive_answer(question, hits)
        if provider == "ollama":
            return self._ollama_answer(question, context)
        if provider == "openai":
            return self._openai_answer(question, context)
        return self._extractive_answer(question, hits)

    def _extractive_answer(self, question: str, hits: list[dict]) -> str:
        lines = ["Based on the approved guideline sections retrieved, the most relevant guidance is:"]
        for idx, h in enumerate(hits[:3], start=1):
            content = " ".join((h.get("content") or "").split())
            excerpt = content[:650] + ("..." if len(content) > 650 else "")
            lines.append(f"\n[{idx}] {excerpt}")
        lines.append("\nUse this as decision support and follow the current national guideline, facility SOPs, and referral policy.")
        return "\n".join(lines)

    def _ollama_answer(self, question: str, context: str) -> str:
        payload = {
            "model": self.settings.ollama_model,
            "prompt": f"{SYSTEM_PROMPT}\n\nContext:\n{context}\n\nQuestion: {question}\n\nAnswer:",
            "stream": False,
        }
        with httpx.Client(timeout=120) as client:
            response = client.post(f"{self.settings.ollama_base_url}/api/generate", json=payload)
            response.raise_for_status()
            return response.json().get("response", "").strip()

    def _openai_answer(self, question: str, context: str) -> str:
        try:
            from openai import OpenAI
        except ImportError as exc:
            raise RuntimeError("Install openai to use LLM_PROVIDER=openai") from exc
        client = OpenAI(api_key=self.settings.openai_api_key)
        response = client.chat.completions.create(
            model=self.settings.openai_chat_model,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": f"Context:\n{context}\n\nQuestion: {question}"},
            ],
            temperature=0.1,
        )
        return response.choices[0].message.content or ""
