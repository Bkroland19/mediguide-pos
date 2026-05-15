import hashlib
import math
from app.core.config import get_settings
from app.embeddings.base import EmbeddingProvider


class HashEmbeddingProvider(EmbeddingProvider):
    """Deterministic dev embedding provider.

    This is useful for local development and tests without downloading models.
    It is not recommended for production retrieval quality.
    """

    def __init__(self, dim: int | None = None):
        self.dim = dim or get_settings().embedding_dim

    def embed(self, texts: list[str]) -> list[list[float]]:
        return [self._embed_one(t) for t in texts]

    def _embed_one(self, text: str) -> list[float]:
        vector = [0.0] * self.dim
        tokens = text.lower().split()
        for token in tokens:
            digest = hashlib.blake2b(token.encode("utf-8"), digest_size=8).digest()
            idx = int.from_bytes(digest[:4], "little") % self.dim
            sign = 1.0 if digest[4] % 2 == 0 else -1.0
            vector[idx] += sign
        norm = math.sqrt(sum(v * v for v in vector)) or 1.0
        return [v / norm for v in vector]
