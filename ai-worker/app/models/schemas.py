from typing import Any
from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str = "ok"
    service: str = "mediguide-ai-worker"


class ExtractionPreviewResponse(BaseModel):
    title: str | None = None
    pages: int
    sections: int
    chunks: int
    tables: int
    markdown_sample: str


class RunJobResponse(BaseModel):
    job_id: str
    status: str
    message: str


class RagAskRequest(BaseModel):
    question: str = Field(min_length=3)
    language: str = "en"
    program_area: str | None = None
    country: str | None = None
    top_k: int | None = None


class Citation(BaseModel):
    chunk_id: str
    title: str | None = None
    source_name: str | None = None
    source_version: str | None = None
    page_start: int | None = None
    page_end: int | None = None
    similarity: float | None = None


class RagAskResponse(BaseModel):
    answer: str
    citations: list[Citation]
    retrieved: list[dict[str, Any]] = []
    safety: dict[str, Any] = {}
