-- +goose Up
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  email text NOT NULL UNIQUE,
  phone text,
  password_hash text NOT NULL,
  facility_id text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE roles (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL UNIQUE,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE permissions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  code text NOT NULL UNIQUE,
  name text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE user_roles (user_id uuid REFERENCES users(id) ON DELETE CASCADE, role_id uuid REFERENCES roles(id) ON DELETE CASCADE, PRIMARY KEY(user_id, role_id));
CREATE TABLE role_permissions (role_id uuid REFERENCES roles(id) ON DELETE CASCADE, permission_id uuid REFERENCES permissions(id) ON DELETE CASCADE, PRIMARY KEY(role_id, permission_id));

CREATE TABLE guideline_documents (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  title text NOT NULL,
  country text,
  source_org text,
  program_area text,
  language text DEFAULT 'en',
  description text,
  current_version_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE guideline_versions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_id uuid NOT NULL REFERENCES guideline_documents(id) ON DELETE CASCADE,
  version text NOT NULL,
  publication_date text,
  review_date text,
  status text NOT NULL DEFAULT 'draft',
  original_file_key text,
  html_file_key text,
  markdown_file_key text,
  checksum text,
  approved_by uuid REFERENCES users(id),
  approved_at text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

ALTER TABLE guideline_documents ADD CONSTRAINT fk_current_version FOREIGN KEY (current_version_id) REFERENCES guideline_versions(id);

CREATE TABLE guideline_sections (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  version_id uuid NOT NULL REFERENCES guideline_versions(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES guideline_sections(id) ON DELETE SET NULL,
  title text,
  slug text,
  level int DEFAULT 1,
  html text,
  text text,
  page_start int,
  page_end int,
  sort_order int DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE guideline_chunks (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  version_id uuid NOT NULL REFERENCES guideline_versions(id) ON DELETE CASCADE,
  section_id uuid REFERENCES guideline_sections(id) ON DELETE SET NULL,
  title text,
  content text NOT NULL,
  html text,
  page_start int,
  page_end int,
  language text DEFAULT 'en',
  program_area text,
  source_name text,
  source_version text,
  review_status text DEFAULT 'draft',
  embedding_text text,
  embedding vector(1536),
  search_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(content,''))) STORED,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX idx_guideline_chunks_search ON guideline_chunks USING GIN(search_vector);
CREATE INDEX idx_guideline_chunks_embedding ON guideline_chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

CREATE TABLE guideline_tables (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  version_id uuid NOT NULL REFERENCES guideline_versions(id) ON DELETE CASCADE,
  section_id uuid REFERENCES guideline_sections(id) ON DELETE SET NULL,
  title text,
  html text,
  data_json jsonb,
  page int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE ingestion_jobs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  version_id uuid NOT NULL REFERENCES guideline_versions(id) ON DELETE CASCADE,
  job_type text DEFAULT 'pdf_ingestion',
  status text DEFAULT 'queued',
  error text,
  payload_json jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE clinical_protocols (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  code text NOT NULL UNIQUE,
  title text NOT NULL,
  program_area text,
  version text,
  language text DEFAULT 'en',
  status text DEFAULT 'draft',
  definition_yaml text,
  definition_json jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE protocol_runs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  protocol_id uuid,
  user_id uuid,
  input_json jsonb,
  output_json jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE chat_sessions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES users(id),
  title text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE chat_messages (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id uuid NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
  role text,
  content text,
  citations_json jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE retrieval_logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES users(id),
  question text,
  query_json jsonb,
  results_json jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE sync_packages (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  version text NOT NULL,
  status text DEFAULT 'draft',
  file_key text,
  manifest_json jsonb,
  checksum text,
  size_bytes bigint DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE device_registrations (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_id text NOT NULL UNIQUE,
  user_id uuid,
  platform text,
  app_version text,
  last_sync_at text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE device_sync_logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_id text,
  package_id uuid,
  status text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE audit_logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  actor_id uuid,
  action text,
  entity_type text,
  entity_id text,
  metadata_json jsonb,
  ip_address text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

-- +goose Down
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS device_sync_logs;
DROP TABLE IF EXISTS device_registrations;
DROP TABLE IF EXISTS sync_packages;
DROP TABLE IF EXISTS retrieval_logs;
DROP TABLE IF EXISTS chat_messages;
DROP TABLE IF EXISTS chat_sessions;
DROP TABLE IF EXISTS protocol_runs;
DROP TABLE IF EXISTS clinical_protocols;
DROP TABLE IF EXISTS ingestion_jobs;
DROP TABLE IF EXISTS guideline_tables;
DROP TABLE IF EXISTS guideline_chunks;
DROP TABLE IF EXISTS guideline_sections;
ALTER TABLE guideline_documents DROP CONSTRAINT IF EXISTS fk_current_version;
DROP TABLE IF EXISTS guideline_versions;
DROP TABLE IF EXISTS guideline_documents;
DROP TABLE IF EXISTS role_permissions;
DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS permissions;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS users;
