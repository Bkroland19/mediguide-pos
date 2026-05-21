from types import SimpleNamespace

import pytest

import app.services.rag_service as rag_module


class FakeEmbedder:
    def __init__(self):
        self.calls: list[list[str]] = []

    def embed(self, texts: list[str]) -> list[list[float]]:
        self.calls.append(texts)
        return [[0.1, 0.2, 0.3, 0.4] for _ in texts]


class FakeSearchRepository:
    def __init__(self, *, vector_hits: list[dict], keyword_hits: list[dict]):
        self.vector_hits = vector_hits
        self.keyword_hits = keyword_hits
        self.vector_calls: list[dict] = []
        self.keyword_calls: list[dict] = []

    def vector_search(
        self,
        query_embedding: list[float],
        top_k: int,
        program_area: str | None = None,
        language: str | None = None,
        country: str | None = None,
        national_first: bool = True,
    ) -> list[dict]:
        self.vector_calls.append(
            {
                "query_embedding": query_embedding,
                "top_k": top_k,
                "program_area": program_area,
                "language": language,
                "country": country,
                "national_first": national_first,
            }
        )
        return list(self.vector_hits)

    def keyword_search(
        self,
        query: str,
        top_k: int,
        program_area: str | None = None,
        language: str | None = None,
        country: str | None = None,
        national_first: bool = True,
    ) -> list[dict]:
        self.keyword_calls.append(
            {
                "query": query,
                "top_k": top_k,
                "program_area": program_area,
                "language": language,
                "country": country,
                "national_first": national_first,
            }
        )
        return list(self.keyword_hits)


def make_settings(**overrides: object) -> SimpleNamespace:
    settings = {
        "rag_top_k": 6,
        "rag_min_similarity": 0.15,
        "rag_national_first": True,
        "llm_provider": "extractive",
        "ollama_model": "qwen2.5:7b-instruct",
        "ollama_base_url": "http://ollama:11434",
        "openai_chat_model": "gpt-4o-mini",
        "openai_api_key": None,
    }
    settings.update(overrides)
    return SimpleNamespace(**settings)


def build_service(
    monkeypatch: pytest.MonkeyPatch,
    *,
    settings: SimpleNamespace | None = None,
    vector_hits: list[dict] | None = None,
    keyword_hits: list[dict] | None = None,
) -> tuple[rag_module.RagService, FakeEmbedder, FakeSearchRepository]:
    embedder = FakeEmbedder()
    search = FakeSearchRepository(
        vector_hits=vector_hits or [],
        keyword_hits=keyword_hits or [],
    )
    monkeypatch.setattr(rag_module, "get_settings", lambda: settings or make_settings())
    monkeypatch.setattr(rag_module, "get_embedding_provider", lambda: embedder)
    monkeypatch.setattr(rag_module, "SearchRepository", lambda: search)
    return rag_module.RagService(), embedder, search


def test_ask_propagates_language_country_and_returns_country_metadata(monkeypatch: pytest.MonkeyPatch):
    hit = {
        "id": "chunk-1",
        "title": "Dehydration treatment",
        "content": "Use ORS for dehydration. Reassess hydration after treatment.",
        "page_start": 12,
        "page_end": 12,
        "language": "en",
        "program_area": "Child Health",
        "country": "Uganda",
        "source_name": "Uganda Clinical Guidelines",
        "source_version": "2025",
        "similarity": 0.44,
    }
    service, _, search = build_service(
        monkeypatch,
        vector_hits=[hit],
        keyword_hits=[dict(hit, similarity=0.9)],
    )

    response = service.ask(
        question="What is recommended for dehydration?",
        language="en",
        country="Uganda",
        program_area="Child Health",
    )

    assert search.vector_calls == [
        {
            "query_embedding": [0.1, 0.2, 0.3, 0.4],
            "top_k": 6,
            "program_area": "Child Health",
            "language": "en",
            "country": "Uganda",
            "national_first": True,
        }
    ]
    assert search.keyword_calls == [
        {
            "query": "What is recommended for dehydration?",
            "top_k": 3,
            "program_area": "Child Health",
            "language": "en",
            "country": "Uganda",
            "national_first": True,
        }
    ]
    assert response["retrieved"][0].country == "Uganda"
    assert response["citations"][0]["country"] == "Uganda"


def test_merge_hits_preserves_vector_similarity_for_duplicate_chunks(monkeypatch: pytest.MonkeyPatch):
    service, _, _ = build_service(monkeypatch)
    vector_hit = {
        "id": "chunk-1",
        "title": "Malaria",
        "content": "Artemether-lumefantrine is first line for uncomplicated malaria.",
        "similarity": 0.41,
        "retrieval_method": "vector",
    }
    keyword_hit = {
        "id": "chunk-1",
        "title": "Malaria",
        "content": "Artemether-lumefantrine is first line for uncomplicated malaria.",
        "similarity": 0.92,
        "retrieval_method": "keyword",
    }

    merged = service._merge_hits([vector_hit], [keyword_hit], top_k=3)

    assert merged[0]["retrieval_method"] == "hybrid"
    assert merged[0]["retrieval_methods"] == ["vector", "keyword"]
    assert merged[0]["vector_similarity"] == pytest.approx(0.41)
    assert merged[0]["keyword_similarity"] == pytest.approx(0.92)
    assert merged[0]["similarity"] == pytest.approx(0.41)


def test_ask_falls_back_to_extractive_when_llm_generation_fails(monkeypatch: pytest.MonkeyPatch):
    hit = {
        "id": "chunk-1",
        "title": "Pneumonia treatment",
        "content": (
            "Give oral amoxicillin for non-severe pneumonia when the guideline criteria are met. "
            "Review the child again in 48 hours."
        ),
        "language": "en",
        "program_area": "Child Health",
        "country": "Uganda",
        "source_name": "Uganda Clinical Guidelines",
        "source_version": "2025",
        "similarity": 0.36,
    }
    service, _, _ = build_service(
        monkeypatch,
        settings=make_settings(llm_provider="ollama"),
        vector_hits=[hit],
        keyword_hits=[],
    )
    monkeypatch.setattr(
        service,
        "_ollama_answer",
        lambda *args, **kwargs: (_ for _ in ()).throw(RuntimeError("ollama unavailable")),
    )

    response = service.ask(question="How do I treat non-severe pneumonia?")

    assert response["safety"]["provider"] == "extractive"
    assert "RuntimeError: ollama unavailable" == response["safety"]["generation_error"]
    assert "Give oral amoxicillin" in response["answer"]
    assert "Sources: [1]" in response["answer"]


def test_ask_rewrites_follow_up_questions_with_recent_context(monkeypatch: pytest.MonkeyPatch):
    hit = {
        "id": "chunk-1",
        "title": "Malaria treatment",
        "content": "Adults with uncomplicated malaria should receive artemether-lumefantrine.",
        "language": "en",
        "program_area": "Malaria",
        "country": "Uganda",
        "source_name": "Uganda Clinical Guidelines",
        "source_version": "2025",
        "similarity": 0.55,
    }
    service, embedder, _ = build_service(
        monkeypatch,
        vector_hits=[hit],
        keyword_hits=[],
    )

    response = service.ask(
        question="What about adults?",
        recent_messages=[
            {
                "role": "user",
                "content": "What is the first-line treatment for uncomplicated malaria in children?",
            },
            {
                "role": "assistant",
                "content": "Use artemether-lumefantrine when there are no danger signs.",
            },
        ],
    )

    standalone_question = response["safety"]["standalone_question"]
    assert "Previous user question:" in standalone_question
    assert "uncomplicated malaria in children" in standalone_question
    assert "Previous assistant answer:" in standalone_question
    assert embedder.calls[0][0] == standalone_question
