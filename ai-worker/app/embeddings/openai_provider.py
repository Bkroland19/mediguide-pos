from app.core.config import get_settings
from app.embeddings.base import EmbeddingProvider


class OpenAIEmbeddingProvider(EmbeddingProvider):
    def __init__(self):
        try:
            from openai import OpenAI
        except ImportError as exc:
            raise RuntimeError("Install openai to use EMBEDDING_PROVIDER=openai") from exc
        settings = get_settings()
        self.client = OpenAI(api_key=settings.openai_api_key)
        self.model = settings.embedding_model or "text-embedding-3-small"
        self.dim = settings.embedding_dim

    def embed(self, texts: list[str]) -> list[list[float]]:
        response = self.client.embeddings.create(model=self.model, input=texts)
        return [item.embedding for item in response.data]
