-- +goose Up
-- Consolidates legacy PocketBase schema coverage into the active PostgreSQL schema.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS alternative_phone text,
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS country text,
  ADD COLUMN IF NOT EXISTS postal_code text,
  ADD COLUMN IF NOT EXISTS license_number text,
  ADD COLUMN IF NOT EXISTS organization text,
  ADD COLUMN IF NOT EXISTS department text,
  ADD COLUMN IF NOT EXISTS job_title text,
  ADD COLUMN IF NOT EXISTS preferred_language text,
  ADD COLUMN IF NOT EXISTS timezone text,
  ADD COLUMN IF NOT EXISTS notes text,
  ADD COLUMN IF NOT EXISTS specialization text,
  ADD COLUMN IF NOT EXISTS avatar text,
  ADD COLUMN IF NOT EXISTS verified boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS status text;

ALTER TABLE roles
  ADD COLUMN IF NOT EXISTS role_key text,
  ADD COLUMN IF NOT EXISTS permissions_json jsonb,
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

CREATE UNIQUE INDEX IF NOT EXISTS idx_roles_role_key ON roles(role_key) WHERE role_key IS NOT NULL;

CREATE TABLE settings (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  key text NOT NULL UNIQUE,
  value_json jsonb NOT NULL,
  category text,
  description text,
  is_public boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE languages (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  native_name text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  is_default boolean NOT NULL DEFAULT false,
  translations_url text,
  translations_json jsonb,
  version double precision,
  status text,
  progress double precision,
  enabled_for_users boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE regions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  nhpi_code text NOT NULL UNIQUE,
  hsdt_code text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE health_sub_regions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  region_id uuid NOT NULL REFERENCES regions(id) ON DELETE RESTRICT,
  name text NOT NULL,
  nhpi_code text NOT NULL UNIQUE,
  hsdt_code text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_health_sub_regions_region_id ON health_sub_regions(region_id);

CREATE TABLE districts (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  health_sub_region_id uuid NOT NULL REFERENCES health_sub_regions(id) ON DELETE RESTRICT,
  region_id uuid NOT NULL REFERENCES regions(id) ON DELETE RESTRICT,
  name text NOT NULL,
  nhpi_code text NOT NULL UNIQUE,
  hsdt_code text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_districts_health_sub_region_id ON districts(health_sub_region_id);
CREATE INDEX idx_districts_region_id ON districts(region_id);

CREATE TABLE counties (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  district_id uuid NOT NULL REFERENCES districts(id) ON DELETE RESTRICT,
  name text NOT NULL,
  nhpi_code text NOT NULL UNIQUE,
  hsdt_code text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_counties_district_id ON counties(district_id);

CREATE TABLE health_sub_districts (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  district_id uuid NOT NULL REFERENCES districts(id) ON DELETE RESTRICT,
  name text NOT NULL,
  nhpi_code text NOT NULL UNIQUE,
  hsdt_code text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_health_sub_districts_district_id ON health_sub_districts(district_id);

CREATE TABLE subcounties (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  county_id uuid NOT NULL REFERENCES counties(id) ON DELETE RESTRICT,
  district_id uuid NOT NULL REFERENCES districts(id) ON DELETE RESTRICT,
  name text NOT NULL,
  nhpi_code text NOT NULL UNIQUE,
  hsdt_code text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_subcounties_county_id ON subcounties(county_id);
CREATE INDEX idx_subcounties_district_id ON subcounties(district_id);

CREATE TABLE parishes (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  subcounty_id uuid NOT NULL REFERENCES subcounties(id) ON DELETE RESTRICT,
  name text NOT NULL,
  nhpi_code text NOT NULL UNIQUE,
  hsdt_code text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_parishes_subcounty_id ON parishes(subcounty_id);

CREATE TABLE facility_levels (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  code text NOT NULL UNIQUE,
  name text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE ownership_types (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  code text NOT NULL UNIQUE,
  name text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE authorities (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  code text,
  ownership_type_id uuid NOT NULL REFERENCES ownership_types(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE UNIQUE INDEX idx_authorities_code ON authorities(code) WHERE code IS NOT NULL;
CREATE INDEX idx_authorities_ownership_type_id ON authorities(ownership_type_id);

CREATE TABLE health_facilities (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  nhpi_code text NOT NULL UNIQUE,
  hsdt_code text NOT NULL UNIQUE,
  facility_level_id uuid NOT NULL REFERENCES facility_levels(id) ON DELETE RESTRICT,
  authority_id uuid NOT NULL REFERENCES authorities(id) ON DELETE RESTRICT,
  ownership_type_id uuid NOT NULL REFERENCES ownership_types(id) ON DELETE RESTRICT,
  health_sub_district_id uuid NOT NULL REFERENCES health_sub_districts(id) ON DELETE RESTRICT,
  parish_id uuid NOT NULL REFERENCES parishes(id) ON DELETE RESTRICT,
  subcounty_id uuid NOT NULL REFERENCES subcounties(id) ON DELETE RESTRICT,
  county_id uuid NOT NULL REFERENCES counties(id) ON DELETE RESTRICT,
  district_id uuid NOT NULL REFERENCES districts(id) ON DELETE RESTRICT,
  health_sub_region_id uuid NOT NULL REFERENCES health_sub_regions(id) ON DELETE RESTRICT,
  region_id uuid NOT NULL REFERENCES regions(id) ON DELETE RESTRICT,
  usage_count bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_health_facilities_facility_level_id ON health_facilities(facility_level_id);
CREATE INDEX idx_health_facilities_authority_id ON health_facilities(authority_id);
CREATE INDEX idx_health_facilities_ownership_type_id ON health_facilities(ownership_type_id);
CREATE INDEX idx_health_facilities_health_sub_district_id ON health_facilities(health_sub_district_id);
CREATE INDEX idx_health_facilities_parish_id ON health_facilities(parish_id);
CREATE INDEX idx_health_facilities_subcounty_id ON health_facilities(subcounty_id);
CREATE INDEX idx_health_facilities_county_id ON health_facilities(county_id);
CREATE INDEX idx_health_facilities_district_id ON health_facilities(district_id);
CREATE INDEX idx_health_facilities_health_sub_region_id ON health_facilities(health_sub_region_id);
CREATE INDEX idx_health_facilities_region_id ON health_facilities(region_id);

CREATE TABLE consultants (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  name text NOT NULL,
  email text NOT NULL,
  phone text NOT NULL,
  alternative_phone text,
  profile_picture_json jsonb,
  avatar_json jsonb,
  specialty text NOT NULL,
  license_number text,
  years_of_experience double precision,
  qualifications text,
  certifications text,
  address text,
  city text,
  region text,
  country text NOT NULL,
  postal_code text,
  organization text,
  department text,
  preferred_language text,
  timezone text,
  availability_json jsonb,
  consultation_types text,
  status text NOT NULL,
  is_verified boolean NOT NULL DEFAULT false,
  rating double precision,
  total_consultations integer NOT NULL DEFAULT 0,
  notes text,
  usage_count bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_consultants_user_id ON consultants(user_id);
CREATE INDEX idx_consultants_specialty ON consultants(specialty);

CREATE TABLE ministry_directory (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  district_id uuid NOT NULL REFERENCES districts(id) ON DELETE RESTRICT,
  region_id uuid REFERENCES regions(id) ON DELETE SET NULL,
  name text NOT NULL,
  title text NOT NULL,
  ministry text NOT NULL,
  department text,
  phone text NOT NULL,
  alternative_phone text,
  email text,
  office_address text,
  priority_level integer,
  availability_hours text,
  specialization text,
  status text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_ministry_directory_district_id ON ministry_directory(district_id);
CREATE INDEX idx_ministry_directory_region_id ON ministry_directory(region_id);

CREATE TABLE drug_categories (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  parent_category_id uuid REFERENCES drug_categories(id) ON DELETE SET NULL,
  name text NOT NULL,
  description text,
  color text,
  icon text,
  sort_order integer,
  status text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_drug_categories_parent_category_id ON drug_categories(parent_category_id);

CREATE TABLE drug_tags (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  description text,
  color text,
  tag_category text NOT NULL,
  sort_order integer,
  status text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE drug_classes (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  description text,
  status text NOT NULL,
  sort_order integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE therapeutic_categories (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  description text,
  status text NOT NULL,
  sort_order integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE drugs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  drug_class_id uuid REFERENCES drug_classes(id) ON DELETE SET NULL,
  therapeutic_category_id uuid REFERENCES therapeutic_categories(id) ON DELETE SET NULL,
  name text NOT NULL,
  brand_names text,
  description text,
  mechanism_of_action text,
  adult_dose text,
  pediatric_dose text,
  elderly_dose text,
  max_daily_dose text,
  route_of_administration text,
  frequency text,
  duration text,
  indications text,
  contraindications text,
  side_effects text,
  warnings text,
  monitoring_parameters text,
  pregnancy_category text,
  clinical_notes text,
  categories_json jsonb,
  tags_json jsonb,
  who_eml_status boolean NOT NULL DEFAULT false,
  antimicrobial_status boolean NOT NULL DEFAULT false,
  controlled_substance text,
  status text NOT NULL,
  review_status text NOT NULL,
  search_keywords text,
  reference_text text,
  usage_count bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_drugs_drug_class_id ON drugs(drug_class_id);
CREATE INDEX idx_drugs_therapeutic_category_id ON drugs(therapeutic_category_id);

CREATE TABLE guideline_categories (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  parent_category_id uuid REFERENCES guideline_categories(id) ON DELETE SET NULL,
  name text NOT NULL,
  slug text,
  description text,
  sort_order integer,
  status text NOT NULL,
  color text,
  icon text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE UNIQUE INDEX idx_guideline_categories_slug ON guideline_categories(slug) WHERE slug IS NOT NULL;
CREATE INDEX idx_guideline_categories_parent_category_id ON guideline_categories(parent_category_id);

CREATE TABLE guideline_tags (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE abbreviations (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  abbreviation text NOT NULL,
  meaning text NOT NULL,
  description text,
  common_usage boolean NOT NULL DEFAULT false,
  category_json jsonb,
  tags_json jsonb,
  usage_count bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE UNIQUE INDEX idx_abbreviations_abbreviation ON abbreviations(abbreviation);

CREATE TABLE guideline_index (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  parent_id uuid REFERENCES guideline_index(id) ON DELETE SET NULL,
  title text NOT NULL,
  sort_order integer,
  description text,
  level integer NOT NULL,
  has_children boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_guideline_index_parent_id ON guideline_index(parent_id);

CREATE TABLE calculators (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  added_by_user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  name text NOT NULL,
  description text,
  icon text,
  color text,
  background_color text,
  app_file_json jsonb NOT NULL,
  version text NOT NULL,
  type text NOT NULL,
  status text,
  usage_count bigint NOT NULL DEFAULT 0,
  featured boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_calculators_added_by_user_id ON calculators(added_by_user_id);

CREATE TABLE medical_guidelines (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  index_item_id uuid REFERENCES guideline_index(id) ON DELETE SET NULL,
  condition_name text NOT NULL,
  icd10_code text,
  target_population text,
  definition text,
  causes text,
  clinical_features text,
  differential_diagnosis text,
  classification_mild text,
  classification_moderate text,
  classification_severe text,
  classification_critical text,
  general_management text,
  medication_primary text,
  dosage_adult text,
  dosage_pediatric text,
  medication_secondary text,
  dosage_secondary_adult text,
  dosage_secondary_pediatric text,
  healthcare_level_required text,
  route_administration text,
  monitoring_requirements text,
  contraindications text,
  prevention_measures text,
  special_notes text,
  status text,
  is_published boolean NOT NULL DEFAULT false,
  priority text,
  version text,
  categories_json jsonb,
  tags_json jsonb,
  usage_count bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_medical_guidelines_index_item_id ON medical_guidelines(index_item_id);

CREATE TABLE emergency_protocols (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  title text NOT NULL,
  description text,
  category text NOT NULL,
  priority text NOT NULL,
  timeframe text,
  steps_json jsonb,
  critical_actions_json jsonb,
  medications_json jsonb,
  contact_info_json jsonb,
  transfer_checklist_json jsonb,
  status text NOT NULL,
  access_count bigint NOT NULL DEFAULT 0,
  vital_signs_json jsonb,
  tags_json jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE generic_pages (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  title text NOT NULL,
  description text,
  content_json jsonb NOT NULL,
  key text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE faq_tags (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  color text,
  icon text,
  usage_count bigint NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE faqs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id uuid REFERENCES users(id) ON DELETE SET NULL,
  reviewer_id uuid REFERENCES users(id) ON DELETE SET NULL,
  question text NOT NULL,
  answer text NOT NULL,
  status text,
  priority text,
  sort_order integer,
  is_featured boolean NOT NULL DEFAULT false,
  target_audience text,
  keywords text,
  published_at text,
  review_due text,
  tags_json jsonb,
  related_faqs_json jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_faqs_author_id ON faqs(author_id);
CREATE INDEX idx_faqs_reviewer_id ON faqs(reviewer_id);

CREATE TABLE documentation (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  title text NOT NULL,
  description text,
  content text NOT NULL,
  category text,
  tags text,
  status text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE support_tickets (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  assigned_to uuid REFERENCES users(id) ON DELETE SET NULL,
  subject text NOT NULL,
  description text NOT NULL,
  status text NOT NULL,
  priority text NOT NULL,
  category text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_support_tickets_user_id ON support_tickets(user_id);
CREATE INDEX idx_support_tickets_assigned_to ON support_tickets(assigned_to);

CREATE TABLE support_ticket_replies (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_id uuid NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  message text NOT NULL,
  is_internal boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_support_ticket_replies_ticket_id ON support_ticket_replies(ticket_id);
CREATE INDEX idx_support_ticket_replies_user_id ON support_ticket_replies(user_id);

CREATE TABLE notifications (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  title text NOT NULL,
  message text NOT NULL,
  type text NOT NULL,
  priority text NOT NULL,
  action_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_notifications_user_id ON notifications(user_id);

CREATE TABLE conversations (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  participant1_user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  participant2_user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  last_activity text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_conversations_participant1_user_id ON conversations(participant1_user_id);
CREATE INDEX idx_conversations_participant2_user_id ON conversations(participant2_user_id);

CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  reply_to_id uuid REFERENCES messages(id) ON DELETE SET NULL,
  content text NOT NULL,
  message_type text,
  attachments_json jsonb,
  read_by_json jsonb,
  reactions_json jsonb,
  is_edited boolean NOT NULL DEFAULT false,
  edited_at text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_messages_sender_user_id ON messages(sender_user_id);
CREATE INDEX idx_messages_reply_to_id ON messages(reply_to_id);

CREATE TABLE notification_templates (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  type text NOT NULL,
  category text NOT NULL,
  status text NOT NULL,
  subject text,
  content text NOT NULL,
  audience text,
  variables_json jsonb,
  sent_count bigint NOT NULL DEFAULT 0,
  opened_count bigint NOT NULL DEFAULT 0,
  clicked_count bigint NOT NULL DEFAULT 0,
  last_sent text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE notification_campaigns (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  type text NOT NULL,
  channels_json jsonb NOT NULL,
  status text NOT NULL,
  audience_total bigint,
  audience_countries_json jsonb,
  audience_roles_json jsonb,
  schedule_start text,
  schedule_end text,
  metrics_sent bigint NOT NULL DEFAULT 0,
  metrics_delivered bigint NOT NULL DEFAULT 0,
  metrics_opened bigint NOT NULL DEFAULT 0,
  metrics_clicked bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE reading_progress (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  guideline_document_id uuid NOT NULL REFERENCES guideline_documents(id) ON DELETE CASCADE,
  progress_percentage double precision NOT NULL,
  current_section text,
  last_read_at text,
  is_bookmarked boolean NOT NULL DEFAULT false,
  reading_time_seconds bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_reading_progress_user_id ON reading_progress(user_id);
CREATE INDEX idx_reading_progress_guideline_document_id ON reading_progress(guideline_document_id);

CREATE TABLE calculator_usage_logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  calculator_id uuid NOT NULL REFERENCES calculators(id) ON DELETE CASCADE,
  session_start text NOT NULL,
  session_end text,
  calculator_type text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_calculator_usage_logs_user_id ON calculator_usage_logs(user_id);
CREATE INDEX idx_calculator_usage_logs_calculator_id ON calculator_usage_logs(calculator_id);

CREATE TABLE guideline_usage_logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  guideline_document_id uuid NOT NULL REFERENCES guideline_documents(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_guideline_usage_logs_user_id ON guideline_usage_logs(user_id);
CREATE INDEX idx_guideline_usage_logs_guideline_document_id ON guideline_usage_logs(guideline_document_id);

CREATE TABLE drug_usage_logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  drug_id uuid NOT NULL REFERENCES drugs(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_drug_usage_logs_user_id ON drug_usage_logs(user_id);
CREATE INDEX idx_drug_usage_logs_drug_id ON drug_usage_logs(drug_id);

CREATE TABLE abbreviation_usage_logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  abbreviation_id uuid NOT NULL REFERENCES abbreviations(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_abbreviation_usage_logs_user_id ON abbreviation_usage_logs(user_id);
CREATE INDEX idx_abbreviation_usage_logs_abbreviation_id ON abbreviation_usage_logs(abbreviation_id);

CREATE TABLE consultant_usage_logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consultant_id uuid NOT NULL REFERENCES consultants(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_consultant_usage_logs_user_id ON consultant_usage_logs(user_id);
CREATE INDEX idx_consultant_usage_logs_consultant_id ON consultant_usage_logs(consultant_id);

CREATE TABLE facility_usage_logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  facility_id uuid NOT NULL REFERENCES health_facilities(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_facility_usage_logs_user_id ON facility_usage_logs(user_id);
CREATE INDEX idx_facility_usage_logs_facility_id ON facility_usage_logs(facility_id);

CREATE TABLE ai_usage_logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_ai_usage_logs_user_id ON ai_usage_logs(user_id);

-- +goose Down
DROP TABLE IF EXISTS ai_usage_logs;
DROP TABLE IF EXISTS facility_usage_logs;
DROP TABLE IF EXISTS consultant_usage_logs;
DROP TABLE IF EXISTS abbreviation_usage_logs;
DROP TABLE IF EXISTS drug_usage_logs;
DROP TABLE IF EXISTS guideline_usage_logs;
DROP TABLE IF EXISTS calculator_usage_logs;
DROP TABLE IF EXISTS reading_progress;
DROP TABLE IF EXISTS notification_campaigns;
DROP TABLE IF EXISTS notification_templates;
DROP TABLE IF EXISTS messages;
DROP TABLE IF EXISTS conversations;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS support_ticket_replies;
DROP TABLE IF EXISTS support_tickets;
DROP TABLE IF EXISTS documentation;
DROP TABLE IF EXISTS faqs;
DROP TABLE IF EXISTS faq_tags;
DROP TABLE IF EXISTS generic_pages;
DROP TABLE IF EXISTS emergency_protocols;
DROP TABLE IF EXISTS medical_guidelines;
DROP TABLE IF EXISTS calculators;
DROP TABLE IF EXISTS guideline_index;
DROP TABLE IF EXISTS abbreviations;
DROP TABLE IF EXISTS guideline_tags;
DROP TABLE IF EXISTS guideline_categories;
DROP TABLE IF EXISTS drugs;
DROP TABLE IF EXISTS therapeutic_categories;
DROP TABLE IF EXISTS drug_classes;
DROP TABLE IF EXISTS drug_tags;
DROP TABLE IF EXISTS drug_categories;
DROP TABLE IF EXISTS ministry_directory;
DROP TABLE IF EXISTS consultants;
DROP TABLE IF EXISTS health_facilities;
DROP TABLE IF EXISTS authorities;
DROP TABLE IF EXISTS ownership_types;
DROP TABLE IF EXISTS facility_levels;
DROP TABLE IF EXISTS parishes;
DROP TABLE IF EXISTS subcounties;
DROP TABLE IF EXISTS health_sub_districts;
DROP TABLE IF EXISTS counties;
DROP TABLE IF EXISTS districts;
DROP TABLE IF EXISTS health_sub_regions;
DROP TABLE IF EXISTS regions;
DROP TABLE IF EXISTS languages;
DROP TABLE IF EXISTS settings;

DROP INDEX IF EXISTS idx_roles_role_key;

ALTER TABLE roles
  DROP COLUMN IF EXISTS is_active,
  DROP COLUMN IF EXISTS permissions_json,
  DROP COLUMN IF EXISTS role_key;

ALTER TABLE users
  DROP COLUMN IF EXISTS status,
  DROP COLUMN IF EXISTS verified,
  DROP COLUMN IF EXISTS avatar,
  DROP COLUMN IF EXISTS specialization,
  DROP COLUMN IF EXISTS notes,
  DROP COLUMN IF EXISTS timezone,
  DROP COLUMN IF EXISTS preferred_language,
  DROP COLUMN IF EXISTS job_title,
  DROP COLUMN IF EXISTS department,
  DROP COLUMN IF EXISTS organization,
  DROP COLUMN IF EXISTS license_number,
  DROP COLUMN IF EXISTS postal_code,
  DROP COLUMN IF EXISTS country,
  DROP COLUMN IF EXISTS city,
  DROP COLUMN IF EXISTS address,
  DROP COLUMN IF EXISTS alternative_phone;
