-- +goose Up
-- Aligns the consolidated legacy schema with the PocketBase export by
-- adding the missing users.state field and enforcing single-select values.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS state text;

ALTER TABLE users
  DROP CONSTRAINT IF EXISTS chk_users_status_pb,
  DROP CONSTRAINT IF EXISTS chk_users_preferred_language_pb;

ALTER TABLE drug_categories
  DROP CONSTRAINT IF EXISTS chk_drug_categories_status_pb;

ALTER TABLE drug_tags
  DROP CONSTRAINT IF EXISTS chk_drug_tags_tag_category_pb,
  DROP CONSTRAINT IF EXISTS chk_drug_tags_status_pb;

ALTER TABLE drugs
  DROP CONSTRAINT IF EXISTS chk_drugs_route_of_administration_pb,
  DROP CONSTRAINT IF EXISTS chk_drugs_pregnancy_category_pb,
  DROP CONSTRAINT IF EXISTS chk_drugs_controlled_substance_pb,
  DROP CONSTRAINT IF EXISTS chk_drugs_status_pb,
  DROP CONSTRAINT IF EXISTS chk_drugs_review_status_pb;

ALTER TABLE drug_classes
  DROP CONSTRAINT IF EXISTS chk_drug_classes_status_pb;

ALTER TABLE therapeutic_categories
  DROP CONSTRAINT IF EXISTS chk_therapeutic_categories_status_pb;

ALTER TABLE consultants
  DROP CONSTRAINT IF EXISTS chk_consultants_specialty_pb,
  DROP CONSTRAINT IF EXISTS chk_consultants_qualifications_pb,
  DROP CONSTRAINT IF EXISTS chk_consultants_preferred_language_pb,
  DROP CONSTRAINT IF EXISTS chk_consultants_consultation_types_pb,
  DROP CONSTRAINT IF EXISTS chk_consultants_status_pb;

ALTER TABLE users
  ADD CONSTRAINT chk_users_status_pb CHECK (
    status IS NULL OR status IN ('active', 'inactive', 'suspended', 'pending_activation')
  ),
  ADD CONSTRAINT chk_users_preferred_language_pb CHECK (
    preferred_language IS NULL OR preferred_language IN (
      'English', 'French', 'Spanish', 'Portuguese', 'Arabic', 'Swahili', 'Amharic'
    )
  );

ALTER TABLE drug_categories
  ADD CONSTRAINT chk_drug_categories_status_pb CHECK (
    status IS NULL OR status IN ('active', 'inactive')
  );

ALTER TABLE drug_tags
  ADD CONSTRAINT chk_drug_tags_tag_category_pb CHECK (
    tag_category IS NULL OR tag_category IN ('clinical', 'administrative', 'regulatory', 'safety')
  ),
  ADD CONSTRAINT chk_drug_tags_status_pb CHECK (
    status IS NULL OR status IN ('active', 'inactive')
  );

ALTER TABLE drugs
  ADD CONSTRAINT chk_drugs_route_of_administration_pb CHECK (
    route_of_administration IS NULL OR route_of_administration IN (
      'oral', 'IV', 'IM', 'topical', 'inhaled', 'sublingual',
      'rectal', 'transdermal', 'intranasal', 'subcutaneous'
    )
  ),
  ADD CONSTRAINT chk_drugs_pregnancy_category_pb CHECK (
    pregnancy_category IS NULL OR pregnancy_category IN ('A', 'B', 'C', 'D', 'X', 'Unknown')
  ),
  ADD CONSTRAINT chk_drugs_controlled_substance_pb CHECK (
    controlled_substance IS NULL OR controlled_substance IN (
      'None', 'Schedule I', 'Schedule II', 'Schedule III', 'Schedule IV', 'Schedule V'
    )
  ),
  ADD CONSTRAINT chk_drugs_status_pb CHECK (
    status IS NULL OR status IN ('active', 'inactive', 'under_review', 'archived')
  ),
  ADD CONSTRAINT chk_drugs_review_status_pb CHECK (
    review_status IS NULL OR review_status IN ('approved', 'pending', 'needs_update')
  );

ALTER TABLE drug_classes
  ADD CONSTRAINT chk_drug_classes_status_pb CHECK (
    status IS NULL OR status IN ('active', 'inactive')
  );

ALTER TABLE therapeutic_categories
  ADD CONSTRAINT chk_therapeutic_categories_status_pb CHECK (
    status IS NULL OR status IN ('active', 'inactive')
  );

ALTER TABLE consultants
  ADD CONSTRAINT chk_consultants_specialty_pb CHECK (
    specialty IS NULL OR specialty IN (
      'General Practice', 'Internal Medicine', 'Pediatrics', 'Surgery',
      'Cardiology', 'Neurology', 'Psychiatry', 'Orthopedics', 'Dermatology',
      'Obstetrics & Gynecology', 'Ophthalmology', 'Emergency Medicine',
      'Radiology', 'Anesthesiology', 'Pathology', 'Oncology', 'Endocrinology',
      'Gastroenterology', 'Pulmonology', 'Nephrology', 'Infectious Diseases',
      'Rheumatology', 'Public Health', 'Nursing', 'Pharmacy',
      'Laboratory Medicine', 'Other'
    )
  ),
  ADD CONSTRAINT chk_consultants_qualifications_pb CHECK (
    qualifications IS NULL OR qualifications IN (
      'MD', 'MBBS', 'DO', 'DDS', 'PharmD', 'RN', 'BSN', 'MSN', 'DNP',
      'PhD', 'MPH', 'MS', 'MA', 'Diploma', 'Certificate', 'Fellowship',
      'Residency', 'Other'
    )
  ),
  ADD CONSTRAINT chk_consultants_preferred_language_pb CHECK (
    preferred_language IS NULL OR preferred_language IN (
      'English', 'French', 'Spanish', 'Portuguese', 'Arabic', 'Swahili', 'Amharic', 'Other'
    )
  ),
  ADD CONSTRAINT chk_consultants_consultation_types_pb CHECK (
    consultation_types IS NULL OR consultation_types IN (
      'In-Person', 'Telemedicine', 'Phone Consultation', 'Emergency Consultation',
      'Second Opinion', 'Follow-up', 'Diagnostic Review', 'Treatment Planning',
      'Medication Review', 'Health Education'
    )
  ),
  ADD CONSTRAINT chk_consultants_status_pb CHECK (
    status IS NULL OR status IN ('active', 'inactive', 'pending_approval', 'suspended')
  );

-- +goose Down
ALTER TABLE consultants
  DROP CONSTRAINT IF EXISTS chk_consultants_specialty_pb,
  DROP CONSTRAINT IF EXISTS chk_consultants_qualifications_pb,
  DROP CONSTRAINT IF EXISTS chk_consultants_preferred_language_pb,
  DROP CONSTRAINT IF EXISTS chk_consultants_consultation_types_pb,
  DROP CONSTRAINT IF EXISTS chk_consultants_status_pb;

ALTER TABLE therapeutic_categories
  DROP CONSTRAINT IF EXISTS chk_therapeutic_categories_status_pb;

ALTER TABLE drug_classes
  DROP CONSTRAINT IF EXISTS chk_drug_classes_status_pb;

ALTER TABLE drugs
  DROP CONSTRAINT IF EXISTS chk_drugs_route_of_administration_pb,
  DROP CONSTRAINT IF EXISTS chk_drugs_pregnancy_category_pb,
  DROP CONSTRAINT IF EXISTS chk_drugs_controlled_substance_pb,
  DROP CONSTRAINT IF EXISTS chk_drugs_status_pb,
  DROP CONSTRAINT IF EXISTS chk_drugs_review_status_pb;

ALTER TABLE drug_tags
  DROP CONSTRAINT IF EXISTS chk_drug_tags_tag_category_pb,
  DROP CONSTRAINT IF EXISTS chk_drug_tags_status_pb;

ALTER TABLE drug_categories
  DROP CONSTRAINT IF EXISTS chk_drug_categories_status_pb;

ALTER TABLE users
  DROP CONSTRAINT IF EXISTS chk_users_status_pb,
  DROP CONSTRAINT IF EXISTS chk_users_preferred_language_pb,
  DROP COLUMN IF EXISTS state;
