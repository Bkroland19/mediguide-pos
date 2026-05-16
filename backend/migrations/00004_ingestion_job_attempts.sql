-- +goose Up
ALTER TABLE ingestion_jobs
  ADD COLUMN IF NOT EXISTS attempt_count integer NOT NULL DEFAULT 0;

-- +goose Down
ALTER TABLE ingestion_jobs
  DROP COLUMN IF EXISTS attempt_count;
