from app.embeddings.hash_provider import HashEmbeddingProvider


def test_hash_embedding_dim():
    provider = HashEmbeddingProvider(dim=16)
    emb = provider.embed(["severe malaria treatment"])[0]
    assert len(emb) == 16
    assert abs(sum(x * x for x in emb) - 1.0) < 1e-6
