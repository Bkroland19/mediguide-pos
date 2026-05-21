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


class RagChatMessage(BaseModel):
    role: str
    content: str


class RagAskRequest(BaseModel):
    question: str = Field(min_length=3)
    language: str = "en"
    program_area: str | None = None
    country: str | None = None
    top_k: int | None = None
    history_summary: str | None = None
    recent_messages: list[RagChatMessage] = Field(default_factory=list)


class Citation(BaseModel):
    chunk_id: str
    title: str | None = None
    country: str | None = None
    source_name: str | None = None
    source_version: str | None = None
    page_start: int | None = None
    page_end: int | None = None
    similarity: float | None = None


class RetrievedChunk(BaseModel):
    """Safe projection of a retrieved guideline chunk for API consumers.
    Intentionally excludes internal fields such as embedding_text."""
    id: str
    title: str | None = None
    content: str | None = None
    page_start: int | None = None
    page_end: int | None = None
    language: str | None = None
    program_area: str | None = None
    country: str | None = None
    source_name: str | None = None
    source_version: str | None = None
    similarity: float | None = None


class ReadinessResponse(BaseModel):
    status: str  # "ok" or "degraded"
    checks: dict[str, str]


class RagAskResponse(BaseModel):
    answer: str
    citations: list[Citation]
    retrieved: list[RetrievedChunk] = Field(default_factory=list)
    safety: dict[str, Any] = Field(default_factory=dict)
