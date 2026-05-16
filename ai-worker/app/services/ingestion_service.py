from __future__ import annotations
from pathlib import Path
import tempfile
import uuid
import structlog
from app.core.config import get_settings
from app.core.storage import ObjectStorage
from app.document_processing.pdf_extractor import extract_pdf
from app.document_processing.chunker import chunk_sections
from app.embeddings.factory import get_embedding_provider
from app.repositories.guideline_repo import GuidelineRepository
from app.repositories.ingestion_repo import IngestionRepository

log = structlog.get_logger()


class IngestionService:
    def __init__(self):
        self.settings = get_settings()
        self.jobs = IngestionRepository()
        self.guidelines = GuidelineRepository()
        self.storage = ObjectStorage()
        self.embedder = get_embedding_provider()

    def run_job(self, job_id: str) -> None:
        job = self.jobs.get_job(job_id)
        if not job:
            raise ValueError(f"Ingestion job not found: {job_id}")
        # For API-triggered runs the job may not be in 'running' state yet.
        self.jobs.mark_running(job_id)
        try:
            self._process(job)
            self.jobs.mark_completed(job_id)
        except Exception as exc:
            log.exception("ingestion_job_failed", job_id=job_id, error=str(exc))
            self.jobs.mark_failed(job_id, str(exc))
            raise

    def _process(self, job: dict) -> None:
        version_id = str(job["version_id"])
        version = self.guidelines.get_version_with_document(version_id)
        if not version:
            raise ValueError(f"Guideline version not found: {version_id}")
        original_key = version.get("original_file_key")
        if not original_key:
            raise ValueError("Guideline version has no original_file_key")

        with tempfile.TemporaryDirectory(prefix="mediguide-ingest-") as tmp:
            tmp_path = Path(tmp)
            pdf_path = tmp_path / "source.pdf"
            self.storage.download_file(original_key, pdf_path)
            extracted = extract_pdf(pdf_path)
            chunks = chunk_sections(extracted.sections)

            html_key = f"guidelines/{version_id}/extracted/{uuid.uuid4()}.html"
            markdown_key = f"guidelines/{version_id}/extracted/{uuid.uuid4()}.md"
            self.storage.upload_bytes(extracted.html.encode("utf-8"), html_key, "text/html; charset=utf-8")
            self.storage.upload_bytes(extracted.markdown.encode("utf-8"), markdown_key, "text/markdown; charset=utf-8")

            self.guidelines.clear_existing_extraction(version_id)

            section_id_by_order: dict[int, str] = {}
            for section in extracted.sections:
                section_id_by_order[section.sort_order] = self.guidelines.insert_section(version_id, section)

            for table in extracted.tables:
                self.guidelines.insert_table(version_id, None, table)

            texts = [c.content for c in chunks]
            embeddings = []
            batch_size = max(1, self.settings.embedding_request_batch_size)
            for i in range(0, len(texts), batch_size):
                embeddings.extend(self.embedder.embed(texts[i:i + batch_size]))

            for chunk, embedding in zip(chunks, embeddings):
                section_id = section_id_by_order.get(chunk.section_order)
                self.guidelines.insert_chunk(version=version, section_id=section_id, chunk=chunk, embedding=embedding)

            self.guidelines.update_version_assets(version_id, html_key, markdown_key)
            log.info(
                "ingestion_job_completed",
                job_id=str(job["id"]),
                version_id=version_id,
                sections=len(extracted.sections),
                chunks=len(chunks),
                tables=len(extracted.tables),
            )
