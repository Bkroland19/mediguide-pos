import pytest

from app.repositories.guideline_repo import GuidelineRepository


def test_replace_extraction_rejects_incomplete_embedding_results():
    repo = GuidelineRepository()

    with pytest.raises(ValueError, match="Embedding count does not match chunk count"):
        repo.replace_extraction(
            version_id="version-id",
            version={"id": "version-id"},
            sections=[],
            tables=[],
            chunks=[object()],
            embeddings=[],
            html_key="extracted.html",
            markdown_key="extracted.md",
        )
