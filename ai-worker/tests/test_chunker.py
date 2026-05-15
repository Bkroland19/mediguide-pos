from app.document_processing.chunker import chunk_sections
from app.document_processing.types import ExtractedSection


def test_chunk_sections_basic():
    section = ExtractedSection(title="Malaria", level=1, text="word " * 1200, sort_order=0)
    chunks = chunk_sections([section])
    assert len(chunks) >= 1
    assert chunks[0].title == "Malaria"
