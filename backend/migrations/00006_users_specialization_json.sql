-- +goose Up
-- Converts legacy users.specialization into a PB-faithful multi-select jsonb field.

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION is_valid_user_specialization_json(value jsonb)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT
    value IS NULL
    OR (
      jsonb_typeof(value) = 'array'
      AND jsonb_array_length(value) <= 5
      AND NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements_text(value) AS elem(item)
        WHERE elem.item NOT IN (
          'General Practice',
          'Pediatrics',
          'Internal Medicine',
          'Surgery',
          'Emergency Medicine',
          'Obstetrics',
          'Psychiatry',
          'Radiology',
          'Anesthesia',
          'Nursing',
          'Pharmacy',
          'Laboratory',
          'Public Health',
          'Other'
        )
      )
    );
$$;
-- +goose StatementEnd

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS specialization_json jsonb;

UPDATE users
SET specialization_json = jsonb_build_array(specialization)
WHERE specialization_json IS NULL
  AND specialization IS NOT NULL
  AND btrim(specialization) <> '';

ALTER TABLE users
  DROP CONSTRAINT IF EXISTS chk_users_specialization_json_pb;

ALTER TABLE users
  ADD CONSTRAINT chk_users_specialization_json_pb
  CHECK (is_valid_user_specialization_json(specialization_json));

-- +goose Down
ALTER TABLE users
  DROP CONSTRAINT IF EXISTS chk_users_specialization_json_pb,
  DROP COLUMN IF EXISTS specialization_json;

-- +goose StatementBegin
DROP FUNCTION IF EXISTS is_valid_user_specialization_json(jsonb);
-- +goose StatementEnd
