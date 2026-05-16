import time
import structlog
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.repositories.ingestion_repo import IngestionRepository
from app.services.ingestion_service import IngestionService

configure_logging()
log = structlog.get_logger()


def main() -> None:
    settings = get_settings()
    repo = IngestionRepository()
    service = IngestionService()
    log.info(
        "worker_started",
        poll_interval=settings.worker_poll_interval_seconds,
        chunk_size=settings.chunk_size,
        chunk_overlap=settings.chunk_overlap,
        min_chunk_chars=settings.min_chunk_chars,
        embedding_request_batch_size=settings.embedding_request_batch_size,
        ollama_base_url=settings.ollama_base_url,
        ollama_embedding_model=settings.ollama_embedding_model,
    )

    while settings.worker_enabled:
        # 1. Pick up new queued jobs.
        jobs = repo.claim_queued_jobs(settings.worker_batch_size)

        # 2. Re-queue failed jobs that are eligible for retry.
        retryable = repo.claim_retryable_jobs(
            limit=settings.worker_batch_size,
            max_attempts=settings.worker_max_attempts,
            backoff_seconds=settings.worker_retry_backoff_seconds,
        )
        # Immediately claim the re-queued jobs so they are processed this cycle.
        if retryable:
            jobs.extend(repo.claim_queued_jobs(len(retryable)))

        if not jobs:
            time.sleep(settings.worker_poll_interval_seconds)
            continue

        for job in jobs:
            job_id = str(job["id"])
            attempt = job.get("attempt_count") or 0
            try:
                log.info("processing_job", job_id=job_id, attempt=attempt + 1)
                # NOTE: job is already marked 'running' by claim_queued_jobs;
                # do NOT call mark_running here to avoid overwriting started_at.
                service.run_job(job_id)
            except Exception as exc:
                log.exception("job_failed", job_id=job_id, attempt=attempt + 1, error=str(exc))


if __name__ == "__main__":
    main()
