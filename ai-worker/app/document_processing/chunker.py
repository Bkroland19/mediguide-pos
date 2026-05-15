from dataclasses import dataclass
from app.core.config import get_settings
from app.document_processing.types import ExtractedSection


@dataclass
class Chunk:
    title: str | None
    content: str
    html: str
    page_start: int | None
    page_end: int | None
    section_order: int
    chunk_order: int


def _split_words(text: str, chunk_size: int, overlap: int) -> list[str]:
    words = text.split()
    if not words:
        return []
    chunks = []
    start = 0
    while start < len(words):
        end = min(start + chunk_size, len(words))
        chunks.append(" ".join(words[start:end]))
        if end == len(words):
            break
        start = max(0, end - overlap)
    return chunks


def chunk_sections(sections: list[ExtractedSection]) -> list[Chunk]:
    settings = get_settings()
    chunks: list[Chunk] = []
    for section in sections:
        pieces = _split_words(section.text, settings.chunk_size, settings.chunk_overlap)
        if not pieces and section.title:
            pieces = [section.title]
        for idx, piece in enumerate(pieces):
            if len(piece) < settings.min_chunk_chars and len(pieces) > 1:
                continue
            html = f"<h{min(max(section.level, 1), 4)}>{section.title}</h{min(max(section.level, 1), 4)}><p>{piece}</p>"
            chunks.append(
                Chunk(
                    title=section.title,
                    content=piece,
                    html=html,
                    page_start=section.page_start,
                    page_end=section.page_end,
                    section_order=section.sort_order,
                    chunk_order=idx,
                )
            )
    return chunks
