import httpx

from app.core.config import get_settings
from app.embeddings.base import EmbeddingProvider


class OllamaEmbeddingProvider(EmbeddingProvider):
    def __init__(self):
        settings = get_settings()
        self.base_url = settings.ollama_base_url.rstrip("/")
        self.model = settings.ollama_embedding_model
        self.dim = settings.embedding_dim

    def embed(self, texts: list[str]) -> list[list[float]]:
        if not texts:
            return []
        payload = {
            "model": self.model,
            "input": texts,
            "truncate": True,
        }
        with httpx.Client(timeout=120) as client:
            response = client.post(f"{self.base_url}/api/embed", json=payload)
            response.raise_for_status()
        embeddings = response.json().get("embeddings") or []
        if len(embeddings) != len(texts):
            raise RuntimeError(
                "Ollama returned an unexpected embedding count "
                f"for model={self.model}: expected={len(texts)}, returned={len(embeddings)}"
            )
        for embedding in embeddings:
            if len(embedding) != self.dim:
                raise RuntimeError(
                    "Configured EMBEDDING_DIM does not match the Ollama embedding output "
                    f"dimension: EMBEDDING_DIM={self.dim}, model={self.model}, "
                    f"returned_dim={len(embedding)}"
                )
        return embeddings
