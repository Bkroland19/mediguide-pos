-- +goose Up
ALTER TABLE health_facilities
  ALTER COLUMN parish_id DROP NOT NULL;

-- +goose Down
DELETE FROM health_facilities
WHERE parish_id IS NULL;

ALTER TABLE health_facilities
  ALTER COLUMN parish_id SET NOT NULL;
