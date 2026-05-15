from datetime import datetime, timezone
from typing import Any
from app.core.db import db_conn


class IngestionRepository:
    def claim_queued_jobs(self, limit: int = 1) -> list[dict[str, Any]]:
        with db_conn() as conn, conn.cursor() as cur:
            cur.execute(
                """
                WITH picked AS (
                    SELECT id
                    FROM ingestion_jobs
                    WHERE status = 'queued' AND job_type = 'pdf_ingestion' AND deleted_at IS NULL
                    ORDER BY created_at ASC
                    LIMIT %s
                    FOR UPDATE SKIP LOCKED
                )
                UPDATE ingestion_jobs j
                SET status = 'running', started_at = now(), updated_at = now()
                FROM picked
                WHERE j.id = picked.id
                RETURNING j.*
                """,
                (limit,),
            )
            rows = cur.fetchall()
            conn.commit()
            return rows

    def get_job(self, job_id: str) -> dict[str, Any] | None:
        with db_conn() as conn, conn.cursor() as cur:
            cur.execute("SELECT * FROM ingestion_jobs WHERE id = %s", (job_id,))
            return cur.fetchone()

    def mark_running(self, job_id: str) -> None:
        with db_conn() as conn, conn.cursor() as cur:
            cur.execute(
                "UPDATE ingestion_jobs SET status='running', started_at=coalesce(started_at, now()), updated_at=now() WHERE id=%s",
                (job_id,),
            )
            conn.commit()

    def mark_completed(self, job_id: str) -> None:
        with db_conn() as conn, conn.cursor() as cur:
            cur.execute(
                "UPDATE ingestion_jobs SET status='completed', completed_at=now(), updated_at=now(), error=NULL WHERE id=%s",
                (job_id,),
            )
            conn.commit()

    def mark_failed(self, job_id: str, error: str) -> None:
        with db_conn() as conn, conn.cursor() as cur:
            cur.execute(
                "UPDATE ingestion_jobs SET status='failed', error=%s, completed_at=now(), updated_at=now() WHERE id=%s",
                (error[:4000], job_id),
            )
            conn.commit()
