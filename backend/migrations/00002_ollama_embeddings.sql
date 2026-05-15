-- +goose Up
DROP INDEX IF EXISTS idx_guideline_chunks_embedding;

ALTER TABLE guideline_chunks DROP COLUMN IF EXISTS embedding;
ALTER TABLE guideline_chunks ADD COLUMN embedding vector(1024);

CREATE INDEX idx_guideline_chunks_embedding
  ON guideline_chunks
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

-- +goose Down
DROP INDEX IF EXISTS idx_guideline_chunks_embedding;

ALTER TABLE guideline_chunks DROP COLUMN IF EXISTS embedding;
ALTER TABLE guideline_chunks ADD COLUMN embedding vector(1536);

CREATE INDEX idx_guideline_chunks_embedding
  ON guideline_chunks
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);
