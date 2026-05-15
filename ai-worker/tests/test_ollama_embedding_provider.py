import pytest

from app.core.config import get_settings
from app.embeddings.ollama_provider import OllamaEmbeddingProvider


class FakeResponse:
    def __init__(self, embeddings: list[list[float]]):
        self._embeddings = embeddings

    def raise_for_status(self) -> None:
        return None

    def json(self) -> dict:
        return {"embeddings": self._embeddings}


class FakeClient:
    def __init__(self, embeddings: list[list[float]], calls: list[tuple[str, dict]], **_: object):
        self._embeddings = embeddings
        self._calls = calls

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def post(self, url: str, json: dict):
        self._calls.append((url, json))
        return FakeResponse(self._embeddings)


def clear_settings_cache() -> None:
    get_settings.cache_clear()


def test_ollama_embedding_provider_calls_embed_api(monkeypatch: pytest.MonkeyPatch):
    calls: list[tuple[str, dict]] = []
    monkeypatch.setenv("OLLAMA_BASE_URL", "http://ollama:11434")
    monkeypatch.setenv("OLLAMA_EMBEDDING_MODEL", "mxbai-embed-large:latest")
    monkeypatch.setenv("EMBEDDING_DIM", "4")
    monkeypatch.setattr(
        "app.embeddings.ollama_provider.httpx.Client",
        lambda **kwargs: FakeClient([[0.1, 0.2, 0.3, 0.4]], calls, **kwargs),
    )
    clear_settings_cache()

    try:
        provider = OllamaEmbeddingProvider()
        embeddings = provider.embed(["severe malaria treatment"])
    finally:
        clear_settings_cache()

    assert embeddings == [[0.1, 0.2, 0.3, 0.4]]
    assert calls == [
        (
            "http://ollama:11434/api/embed",
            {
                "model": "mxbai-embed-large:latest",
                "input": ["severe malaria treatment"],
                "truncate": True,
            },
        )
    ]


def test_ollama_embedding_provider_rejects_dimension_mismatch(monkeypatch: pytest.MonkeyPatch):
    calls: list[tuple[str, dict]] = []
    monkeypatch.setenv("OLLAMA_BASE_URL", "http://ollama:11434")
    monkeypatch.setenv("OLLAMA_EMBEDDING_MODEL", "mxbai-embed-large:latest")
    monkeypatch.setenv("EMBEDDING_DIM", "4")
    monkeypatch.setattr(
        "app.embeddings.ollama_provider.httpx.Client",
        lambda **kwargs: FakeClient([[0.1, 0.2, 0.3]], calls, **kwargs),
    )
    clear_settings_cache()

    try:
        provider = OllamaEmbeddingProvider()
        with pytest.raises(RuntimeError, match="EMBEDDING_DIM"):
            provider.embed(["severe malaria treatment"])
    finally:
        clear_settings_cache()
