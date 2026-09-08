-- +goose Up
ALTER TABLE guideline_version_manifests
  ADD COLUMN reviewed_section_count integer NOT NULL DEFAULT 0 CHECK (reviewed_section_count >= 0),
  ADD COLUMN leaf_section_count integer NOT NULL DEFAULT 0 CHECK (leaf_section_count >= 0),
  ADD COLUMN reviewed_leaf_section_count integer NOT NULL DEFAULT 0 CHECK (reviewed_leaf_section_count >= 0),
  ADD COLUMN empty_leaf_section_count integer NOT NULL DEFAULT 0 CHECK (empty_leaf_section_count >= 0),
  ADD COLUMN reviewed_paragraph_count integer NOT NULL DEFAULT 0 CHECK (reviewed_paragraph_count >= 0);

-- Existing rows remain schema version 1. The protected regeneration endpoint
-- upgrades them and recalculates their checksums without publishing content.

-- +goose Down
ALTER TABLE guideline_version_manifests
  DROP COLUMN IF EXISTS reviewed_paragraph_count,
  DROP COLUMN IF EXISTS empty_leaf_section_count,
  DROP COLUMN IF EXISTS reviewed_leaf_section_count,
  DROP COLUMN IF EXISTS leaf_section_count,
  DROP COLUMN IF EXISTS reviewed_section_count;
