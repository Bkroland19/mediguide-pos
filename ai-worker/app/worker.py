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
    log.info("worker_started", poll_interval=settings.worker_poll_interval_seconds)

    while settings.worker_enabled:
        jobs = repo.claim_queued_jobs(settings.worker_batch_size)
        if not jobs:
            time.sleep(settings.worker_poll_interval_seconds)
            continue
        for job in jobs:
            job_id = str(job["id"])
            try:
                log.info("processing_job", job_id=job_id)
                service.run_job(job_id)
            except Exception as exc:
                log.exception("job_failed", job_id=job_id, error=str(exc))


if __name__ == "__main__":
    main()
