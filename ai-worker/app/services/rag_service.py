from __future__ import annotations
import httpx
import re
from app.core.config import get_settings
from app.embeddings.factory import get_embedding_provider
from app.models.schemas import RetrievedChunk
from app.repositories.search_repo import SearchRepository


SYSTEM_PROMPT = """You are a conversational RAG assistant for MediGuide.
Use retrieved guideline context as the primary source of truth.
Use conversation history only to resolve follow-up references and user intent.
Do not use unsupported medical knowledge.
If the retrieved context does not support the answer, say that clearly.
Do not invent facts, page numbers, or sources.
Keep answers direct, concise, and clinically practical.
When giving a grounded factual answer, cite the supporting source numbers like [1], [2].
"""

FALLBACK_ANSWER = (
    "I could not find enough support for that in the approved MediGuide documents. "
    "Please rephrase the question, ask about one of the loaded guidelines, or consult a senior clinician."
)

FOLLOW_UP_PATTERN = re.compile(
    r"^\s*(what about|how about|and what about|what if|does that|is that|is it|can it|can they|can we|"
    r"how do i|what are they|what are those|why is that|when should that|when should it)\b",
    re.I,
)
PRONOUN_PATTERN = re.compile(r"\b(it|that|those|they|them|this|these|he|she|there|the other)\b", re.I)
WORD_PATTERN = re.compile(r"[a-zA-Z][a-zA-Z0-9_-]{2,}")
SOURCE_NUMBER_PATTERN = re.compile(r"\[(\d+)\]")


class RagService:
    def __init__(self):
        self.settings = get_settings()
        self.embedder = get_embedding_provider()
        self.search = SearchRepository()

    def ask(
        self,
        question: str,
        language: str = "en",
        program_area: str | None = None,
        top_k: int | None = None,
        history_summary: str | None = None,
        recent_messages: list[dict] | None = None,
    ) -> dict:
        top_k = top_k or self.settings.rag_top_k
        recent_messages = recent_messages or []
        conversation_summary = self._build_conversation_summary(history_summary, recent_messages)
        standalone_question = self._rewrite_question(question, conversation_summary, recent_messages)

        q_emb = self.embedder.embed([standalone_question])[0]
        vector_hits = self.search.vector_search(q_emb, top_k=top_k, program_area=program_area, language=language)
        vector_hits = [dict(hit, retrieval_method="vector") for hit in vector_hits]
        keyword_hits = self.search.keyword_search(standalone_question, top_k=max(3, top_k // 2), program_area=program_area)
        keyword_hits = [dict(hit, retrieval_method="keyword") for hit in keyword_hits]
        hits = self._merge_hits(vector_hits, keyword_hits, top_k=top_k)
        hits = self._filter_hits(hits, standalone_question)

        if not hits:
            return {
                "answer": FALLBACK_ANSWER,
                "citations": [],
                "retrieved": [],
                "safety": {
                    "grounded": False,
                    "reason": "insufficient_context",
                    "standalone_question": standalone_question,
                },
            }

        used_hits = hits[: min(3, len(hits))]
        context = self._format_context(used_hits)
        answer = self._generate_answer(
            question=question,
            standalone_question=standalone_question,
            context=context,
            hits=used_hits,
            history_summary=conversation_summary,
            recent_messages=recent_messages,
        )
        answer, citations = self._finalize_answer(answer, used_hits)
        retrieved = [
            RetrievedChunk(
                id=str(h["id"]),
                title=h.get("title"),
                content=h.get("content"),
                page_start=h.get("page_start"),
                page_end=h.get("page_end"),
                language=h.get("language"),
                program_area=h.get("program_area"),
                source_name=h.get("source_name"),
                source_version=h.get("source_version"),
                similarity=float(h.get("similarity") or 0),
            )
            for h in hits
        ]
        return {
            "answer": answer,
            "citations": citations,
            "retrieved": retrieved,
            "safety": {
                "grounded": True,
                "provider": self.settings.llm_provider,
                "standalone_question": standalone_question,
            },
        }

    def _merge_hits(self, vector_hits: list[dict], keyword_hits: list[dict], top_k: int) -> list[dict]:
        """Reciprocal Rank Fusion (RRF) — merges ranked lists without relying on
        incomparable similarity scores from different retrieval methods."""
        rrf_k = 60  # standard RRF constant
        scores: dict[str, float] = {}
        index: dict[str, dict] = {}

        for rank, hit in enumerate(vector_hits, start=1):
            key = str(hit["id"])
            scores[key] = scores.get(key, 0.0) + 1.0 / (rrf_k + rank)
            index[key] = hit

        for rank, hit in enumerate(keyword_hits, start=1):
            key = str(hit["id"])
            scores[key] = scores.get(key, 0.0) + 1.0 / (rrf_k + rank)
            index[key] = hit

        sorted_keys = sorted(scores, key=lambda k: scores[k], reverse=True)[:top_k]
        merged = []
        for key in sorted_keys:
            hit = dict(index[key])
            hit["rrf_score"] = scores[key]
            merged.append(hit)
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

    def _generate_answer(
        self,
        question: str,
        standalone_question: str,
        context: str,
        hits: list[dict],
        history_summary: str,
        recent_messages: list[dict],
    ) -> str:
        provider = self.settings.llm_provider.lower()
        if provider == "extractive":
            return self._extractive_answer(question, hits)
        if provider == "ollama":
            return self._ollama_answer(question, standalone_question, context, history_summary, recent_messages)
        if provider == "openai":
            return self._openai_answer(question, standalone_question, context, history_summary, recent_messages)
        return self._extractive_answer(question, hits)

    def _extractive_answer(self, question: str, hits: list[dict]) -> str:
        lines = []
        for idx, h in enumerate(hits[:2], start=1):
            content = " ".join((h.get("content") or "").split())
            excerpt = content[:420] + ("..." if len(content) > 420 else "")
            if idx == 1:
                lines.append(excerpt)
            else:
                lines.append(f"Additional relevant guidance: {excerpt}")
        lines.append(f"Sources: {', '.join(f'[{i}]' for i in range(1, len(hits[:2]) + 1))}")
        return "\n".join(lines)

    def _ollama_answer(
        self,
        question: str,
        standalone_question: str,
        context: str,
        history_summary: str,
        recent_messages: list[dict],
    ) -> str:
        payload = {
            "model": self.settings.ollama_model,
            "prompt": self._build_answer_prompt(
                question=question,
                standalone_question=standalone_question,
                context=context,
                history_summary=history_summary,
                recent_messages=recent_messages,
            ),
            "stream": False,
        }
        with httpx.Client(timeout=120) as client:
            response = client.post(f"{self.settings.ollama_base_url}/api/generate", json=payload)
            response.raise_for_status()
            return response.json().get("response", "").strip()

    def _openai_answer(
        self,
        question: str,
        standalone_question: str,
        context: str,
        history_summary: str,
        recent_messages: list[dict],
    ) -> str:
        try:
            from openai import OpenAI
        except ImportError as exc:
            raise RuntimeError("Install openai to use LLM_PROVIDER=openai") from exc
        client = OpenAI(api_key=self.settings.openai_api_key)
        prompt = self._build_answer_prompt(
            question=question,
            standalone_question=standalone_question,
            context=context,
            history_summary=history_summary,
            recent_messages=recent_messages,
        )
        response = client.chat.completions.create(
            model=self.settings.openai_chat_model,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
            temperature=0.1,
        )
        return response.choices[0].message.content or ""

    def _build_conversation_summary(self, history_summary: str | None, recent_messages: list[dict]) -> str:
        summary = (history_summary or "").strip()
        if summary:
            return summary[:1200]

        if not recent_messages:
            return ""

        parts: list[str] = []
        for message in recent_messages[-4:]:
            role = "User" if (message.get("role") or "").lower() == "user" else "Assistant"
            content = " ".join((message.get("content") or "").split())
            if not content:
                continue
            parts.append(f"{role}: {content[:220]}")
        return " | ".join(parts)[:1200]

    def _rewrite_question(self, question: str, history_summary: str, recent_messages: list[dict]) -> str:
        cleaned = " ".join(question.split())
        if not recent_messages or self._looks_standalone(cleaned):
            return cleaned

        recent_user_messages = [
            " ".join((message.get("content") or "").split())
            for message in recent_messages
            if (message.get("role") or "").lower() == "user" and (message.get("content") or "").strip()
        ]
        last_user_context = recent_user_messages[-1] if recent_user_messages else ""
        last_assistant_context = ""
        for message in reversed(recent_messages):
            if (message.get("role") or "").lower() == "assistant" and (message.get("content") or "").strip():
                last_assistant_context = " ".join(message["content"].split())[:240]
                break

        context_parts = []
        if history_summary:
            context_parts.append(f"Conversation summary: {history_summary[:400]}")
        if last_user_context:
            context_parts.append(f"Previous user question: {last_user_context[:220]}")
        if last_assistant_context:
            context_parts.append(f"Previous assistant answer: {last_assistant_context}")
        context_text = " ".join(context_parts).strip()
        if not context_text:
            return cleaned

        return f"{cleaned} Regarding: {context_text}"

    def _looks_standalone(self, question: str) -> bool:
        normalized = question.strip()
        if not normalized:
            return True
        if FOLLOW_UP_PATTERN.search(normalized):
            return False
        return PRONOUN_PATTERN.search(normalized) is None

    def _filter_hits(self, hits: list[dict], question: str) -> list[dict]:
        filtered: list[dict] = []
        for hit in hits:
            if self._is_hit_relevant(hit, question):
                filtered.append(hit)
        return filtered

    def _is_hit_relevant(self, hit: dict, question: str) -> bool:
        content = " ".join(((hit.get("title") or "") + " " + (hit.get("content") or "")).split())
        if not content:
            return False

        similarity = float(hit.get("similarity") or 0)
        retrieval_method = hit.get("retrieval_method") or ""
        overlap = self._term_overlap(question, content)
        if retrieval_method == "vector":
            return similarity >= self.settings.rag_min_similarity or overlap >= 2
        if retrieval_method == "keyword":
            return similarity > 0 or overlap >= 2
        return overlap >= 2 or similarity >= self.settings.rag_min_similarity

    def _term_overlap(self, left: str, right: str) -> int:
        left_terms = set(self._important_terms(left))
        if not left_terms:
            return 0
        right_terms = set(self._important_terms(right))
        return len(left_terms & right_terms)

    def _important_terms(self, text: str) -> list[str]:
        stop_words = {
            "what", "when", "where", "which", "with", "that", "this", "those", "these", "from",
            "into", "about", "they", "them", "then", "than", "have", "has", "should", "would",
            "could", "there", "their", "your", "ours", "does", "doesnt", "under", "over", "after",
            "before", "please", "guideline", "guidelines",
        }
        return [
            token.lower()
            for token in WORD_PATTERN.findall(text)
            if token.lower() not in stop_words
        ]

    def _build_answer_prompt(
        self,
        question: str,
        standalone_question: str,
        context: str,
        history_summary: str,
        recent_messages: list[dict],
    ) -> str:
        recent_turns = []
        for message in recent_messages[-4:]:
            role = "User" if (message.get("role") or "").lower() == "user" else "Assistant"
            content = " ".join((message.get("content") or "").split())
            if content:
                recent_turns.append(f"{role}: {content[:240]}")

        return (
            f"{SYSTEM_PROMPT}\n\n"
            f"Context:\n{context}\n\n"
            f"Conversation summary:\n{history_summary or 'None'}\n\n"
            f"Recent turns:\n{chr(10).join(recent_turns) or 'None'}\n\n"
            f"Standalone retrieval question:\n{standalone_question}\n\n"
            f"Latest user question:\n{question}\n\n"
            "Instructions:\n"
            "- Answer using the context when possible.\n"
            "- If context is insufficient, say you do not know based on the indexed documents.\n"
            "- Resolve follow-up references using the conversation summary and recent turns.\n"
            "- Do not fabricate missing details.\n"
            "- Start with the answer.\n"
            "- Follow with a short explanation.\n"
            "- End with only the source numbers actually used.\n"
        )

    def _finalize_answer(self, answer: str, hits: list[dict]) -> tuple[str, list[dict]]:
        answer = (answer or "").strip()
        if not answer:
            answer = FALLBACK_ANSWER

        indexed_citations = [
            {
                "index": idx,
                "chunk_id": str(hit["id"]),
                "title": hit.get("title"),
                "source_name": hit.get("source_name"),
                "source_version": hit.get("source_version"),
                "page_start": hit.get("page_start"),
                "page_end": hit.get("page_end"),
                "similarity": float(hit.get("similarity") or 0),
            }
            for idx, hit in enumerate(hits, start=1)
        ]

        cited_indexes = {
            int(match)
            for match in SOURCE_NUMBER_PATTERN.findall(answer)
            if match.isdigit()
        }
        cited = [citation for citation in indexed_citations if citation["index"] in cited_indexes]
        if not cited and hits:
            answer = answer.rstrip()
            if "Sources:" not in answer:
                answer = f"{answer}\nSources: [1]"
            cited = indexed_citations[:1]

        normalized_citations = []
        for citation in cited:
            normalized = dict(citation)
            normalized.pop("index", None)
            normalized_citations.append(normalized)
        return answer, self._dedupe_citations(normalized_citations)

    def _dedupe_citations(self, citations: list[dict]) -> list[dict]:
        seen: set[str] = set()
        deduped: list[dict] = []
        for citation in citations:
            chunk_id = str(citation.get("chunk_id") or "")
            if not chunk_id or chunk_id in seen:
                continue
            seen.add(chunk_id)
            deduped.append(citation)
        return deduped
