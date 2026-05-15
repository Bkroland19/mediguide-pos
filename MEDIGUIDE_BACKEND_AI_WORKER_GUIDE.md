# MediGuide Backend + AI Worker Developer Guide

## 1. Purpose

MediGuide is an offline-first clinical guideline and decision-support system for frontline health workers. The platform has two main backend components:

1. **Go Backend Service**
   - Handles authentication, users, roles, permissions, guideline metadata, document upload, review workflow, clinical protocols, sync packages, search APIs, and chatbot orchestration.

2. **Python AI Worker Service**
   - Handles PDF extraction, PDF-to-HTML conversion, table extraction, section detection, chunking, embeddings, vector storage, and retrieval-augmented generation support.

The backend owns the application workflow and database records. The AI worker performs heavy document-processing and AI-related tasks.

---

## 2. High-Level Architecture

```text
Admin Web / Mobile App
        |
        v
Go Backend API
        |
        |-- PostgreSQL + pgvector
        |-- MinIO / S3 object storage
        |-- Redis / job queue
        |
        v
Python AI Worker
        |
        |-- PDF extraction
        |-- HTML / Markdown generation
        |-- Chunking
        |-- Embeddings
        |-- Vector storage
        |-- RAG answer generation
```

Recommended deployment model:

```text
backend/       → Go Gin API service
ai-worker/     → Python FastAPI + worker service
postgres/      → PostgreSQL with pgvector
minio/         → Object storage for PDFs, HTML, markdown, images
redis/         → Queue/cache
admin-web/     → Optional React admin portal
mobile-app/    → Optional Flutter offline app
```

---

## 3. Responsibilities by Service

### 3.1 Go Backend Service

The Go backend is responsible for:

- User authentication and JWT generation
- Role-based access control
- Guideline document upload
- Guideline versioning
- Document approval workflow
- Creating ingestion jobs
- Managing clinical protocols
- Search endpoint orchestration
- Chat endpoint orchestration
- Offline sync package generation
- Audit logging
- Serving APIs to web and mobile clients

The Go backend should be the source of truth for:

- users
- roles
- permissions
- documents
- versions
- review status
- published content
- clinical protocols
- sync package metadata
- audit logs

### 3.2 Python AI Worker Service

The AI worker is responsible for:

- Reading pending ingestion jobs
- Downloading source PDFs from MinIO
- Extracting text, tables, pages, and metadata
- Generating clean HTML
- Generating Markdown
- Detecting document sections
- Creating RAG chunks
- Creating embeddings
- Saving vectors into PostgreSQL/pgvector
- Supporting RAG retrieval and generation

The AI worker should not own user permissions, review approvals, or publication state. It should write extracted and processed content back to the backend database or storage, then mark ingestion jobs as complete or failed.

---

## 4. Recommended Repository Layout

```text
mediguide/
  backend/
    cmd/
      api/
      worker/
      seed/
    internal/
      auth/
      users/
      roles/
      guidelines/
      ingestion/
      protocols/
      search/
      rag/
      sync/
      audit/
      storage/
      database/
      config/
    migrations/
    docs/
    Dockerfile
    docker-compose.yml
    Makefile
    go.mod

  ai-worker/
    app/
      api/
      core/
      db/
      embeddings/
      extraction/
      html/
      chunking/
      rag/
      storage/
      worker/
    notebooks/
    tests/
    Dockerfile
    docker-compose.override.yml
    requirements.txt
    pyproject.toml
    .env.example

  docs/
    MEDIGUIDE_BACKEND_AI_WORKER_GUIDE.md
```

---

## 5. Environment Variables

### 5.1 Go Backend `.env`

```env
APP_NAME=mediguide-backend
APP_ENV=development
HTTP_PORT=8080

DATABASE_URL=postgres://mediguide:mediguide@postgres:5432/mediguide?sslmode=disable

JWT_SECRET=change-this-secret
JWT_ACCESS_TTL_MINUTES=60
JWT_REFRESH_TTL_HOURS=720

REDIS_URL=redis://redis:6379

S3_ENDPOINT=minio:9000
S3_ACCESS_KEY=mediguide
S3_SECRET_KEY=mediguide123
S3_BUCKET=mediguide
S3_USE_SSL=false

AI_WORKER_URL=http://ai-worker:8090

DEFAULT_ADMIN_EMAIL=admin@mediguide.local
DEFAULT_ADMIN_PASSWORD=Admin123!
```

### 5.2 AI Worker `.env`

```env
APP_NAME=mediguide-ai-worker
APP_ENV=development
HTTP_PORT=8090

DATABASE_URL=postgresql://mediguide:mediguide@postgres:5432/mediguide
REDIS_URL=redis://redis:6379

S3_ENDPOINT=minio:9000
S3_ACCESS_KEY=mediguide
S3_SECRET_KEY=mediguide123
S3_BUCKET=mediguide
S3_USE_SSL=false

EMBEDDING_PROVIDER=hash
EMBEDDING_MODEL=local-hash-1536
EMBEDDING_DIM=1536

LLM_PROVIDER=extractive
OLLAMA_BASE_URL=http://ollama:11434
OLLAMA_MODEL=qwen2.5:7b-instruct

OPENAI_API_KEY=
OPENAI_EMBEDDING_MODEL=text-embedding-3-small
OPENAI_CHAT_MODEL=gpt-4o-mini
```

For production, replace development secrets and use a secure secrets manager.

---

## 6. Database Requirements

Use PostgreSQL with the `pgvector` extension.

Example Docker image:

```yaml
postgres:
  image: pgvector/pgvector:pg16
```

Required extension:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

Core schema groups:

```text
Authentication:
  users
  roles
  permissions
  user_roles
  role_permissions

Guidelines:
  guideline_documents
  guideline_versions
  guideline_sections
  guideline_tables
  guideline_chunks
  guideline_assets

Ingestion:
  ingestion_jobs
  ingestion_job_logs

Protocols:
  clinical_protocols
  protocol_versions
  protocol_steps
  protocol_test_cases

Chat/RAG:
  chat_sessions
  chat_messages
  retrieval_logs
  answer_citations

Offline Sync:
  sync_packages
  device_registrations
  device_sync_logs

Governance:
  content_reviews
  audit_logs
```

Important: vector column size must match the embedding model dimension.

Example:

```sql
embedding vector(384)
```

If using OpenAI `text-embedding-3-small`, adjust dimension based on the configured output dimension. If using `bge-m3`, `multilingual-e5`, or SentenceTransformers, confirm the model dimension before migrating production data.

---

## 7. Go Backend Setup

### 7.1 Local Setup

```bash
cd backend
cp .env.example .env
go mod tidy
go run ./cmd/api
```

### 7.2 Run Migrations

Using Goose:

```bash
goose -dir migrations postgres "$DATABASE_URL" up
```

Or through Makefile:

```bash
make migrate-up
```

### 7.3 Seed Admin User

```bash
make seed
```

Default development credentials:

```text
email: admin@mediguide.local
password: Admin123!
```

Change these before production deployment.

### 7.4 Run with Docker Compose

```bash
docker compose -f infra/docker-compose.yml up --build
```

Expected services:

```text
Go API:       http://localhost:8080
PostgreSQL:  localhost:5432
MinIO:       http://localhost:9001
Redis:       localhost:6379
AI Worker:   http://localhost:8090
```

---

## 8. AI Worker Setup

### 8.1 Local Setup

```bash
cd ai-worker
cp .env.example .env
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8090
```

### 8.2 Run Worker Loop

```bash
python -m app.worker
```

### 8.3 Run with Backend Compose

From the parent directory:

```bash
docker compose \
  -f backend/docker-compose.yml \
  -f ai-worker/docker-compose.override.yml \
  up --build
```

Expected AI worker service:

```text
AI Worker API: http://localhost:8090
```

---

## 9. Guideline Ingestion Workflow

### 9.1 Upload Guideline PDF

The admin uploads a PDF through the Go backend:

```http
POST /api/v1/guidelines
Content-Type: multipart/form-data
Authorization: Bearer <token>
```

Example fields:

```text
file: malaria_guideline.pdf
title: Uganda National Malaria Guidelines
source_name: Ministry of Health Uganda
program_area: Malaria
language: en
version: 2026
publication_date: 2026-01-01
```

### 9.2 Backend Saves Document

The Go backend should:

1. Validate user permissions.
2. Upload the original PDF to MinIO.
3. Create a `guideline_documents` record.
4. Create a `guideline_versions` record.
5. Create an `ingestion_jobs` record with status `pending`.
6. Return document and job metadata to the client.

### 9.3 AI Worker Processes Job

The AI worker should:

1. Poll for pending jobs or receive a webhook/message.
2. Mark job as `running`.
3. Download PDF from MinIO.
4. Extract pages, text, headings, and tables.
5. Generate clean HTML and Markdown.
6. Upload HTML/Markdown artifacts to MinIO.
7. Detect sections.
8. Generate chunks.
9. Create embeddings.
10. Insert sections, tables, chunks, and embeddings into PostgreSQL.
11. Mark job as `completed`.

If processing fails:

1. Mark job as `failed`.
2. Store error message.
3. Write logs to `ingestion_job_logs`.

---

## 10. PDF Processing Pipeline

Recommended pipeline inside AI worker:

```text
PDF file
  ↓
PyMuPDF extraction
  ↓
pdfplumber table extraction
  ↓
page-level text normalization
  ↓
heading and section detection
  ↓
HTML generation
  ↓
Markdown generation
  ↓
chunking with overlap
  ↓
embedding generation
  ↓
pgvector storage
```

Recommended libraries:

```text
PyMuPDF       → page text and layout extraction
pdfplumber    → table extraction
BeautifulSoup → HTML cleanup
pandas        → table normalization
markdownify   → HTML/Markdown conversions
sentence-transformers → local embeddings
openai        → optional hosted embeddings/LLM
psycopg       → PostgreSQL access
boto3/minio   → object storage
```

For scanned PDFs, add OCR later:

```text
Tesseract OCR
PaddleOCR
Google Document AI
Azure Document Intelligence
```

Do not rely on OCR unless the PDF has no machine-readable text.

---

## 11. Chunking Strategy

Clinical documents should be chunked carefully to avoid unsafe answers.

Recommended default:

```text
chunk_size: 800-1200 tokens
chunk_overlap: 100-200 tokens
split_by: headings, subheadings, paragraphs, tables
preserve: document title, section title, page numbers, source, version
```

Each chunk should include metadata:

```json
{
  "document_id": "uuid",
  "version_id": "uuid",
  "section_id": "uuid",
  "title": "Treatment of severe malaria",
  "content": "...",
  "page_start": 45,
  "page_end": 46,
  "source_name": "Ministry of Health Uganda",
  "source_version": "2026",
  "program_area": "Malaria",
  "language": "en",
  "review_status": "draft"
}
```

Important: only approved/published chunks should be used in production RAG answers.

---

## 12. Embedding Strategy

### 12.1 Development

Use local hash embeddings for development only:

```env
EMBEDDING_PROVIDER=hash
EMBEDDING_DIM=1536
```

This allows the pipeline to run without external APIs, but it is not clinically useful for semantic search quality.

### 12.2 Production Options

Recommended multilingual embedding models:

```text
BAAI/bge-m3
intfloat/multilingual-e5-large
sentence-transformers/paraphrase-multilingual-mpnet-base-v2
```

Recommended production configuration:

```env
EMBEDDING_PROVIDER=sentence_transformers
EMBEDDING_MODEL=BAAI/bge-m3
```

For hosted embeddings:

```env
EMBEDDING_PROVIDER=openai
OPENAI_EMBEDDING_MODEL=text-embedding-3-small
```

Keep one embedding dimension per vector table or create separate vector columns/tables per model.

---

## 13. Search API Design

The search endpoint should combine:

1. PostgreSQL full-text search
2. pgvector similarity search
3. Metadata filtering
4. Optional reranking

Example endpoint:

```http
GET /api/v1/search?q=severe malaria pregnancy&program_area=Malaria&language=en
```

Expected response:

```json
{
  "query": "severe malaria pregnancy",
  "results": [
    {
      "chunk_id": "uuid",
      "title": "Severe malaria in pregnancy",
      "snippet": "...",
      "document_title": "Uganda National Malaria Guidelines",
      "source_name": "Ministry of Health Uganda",
      "version": "2026",
      "page_start": 45,
      "page_end": 46,
      "score": 0.91
    }
  ]
}
```

Search should filter out:

```text
review_status != approved
publication_status != published
expired/superseded versions, unless explicitly requested
```

---

## 14. RAG Chatbot Design

The RAG chatbot must answer from approved guideline context only.

Recommended request:

```http
POST /api/v1/chat/ask
Authorization: Bearer <token>
Content-Type: application/json
```

```json
{
  "question": "How do I manage severe malaria in pregnancy?",
  "language": "en",
  "program_area": "Malaria",
  "facility_level": "HC III",
  "national_first": true
}
```

Recommended response:

```json
{
  "answer": "Based on the approved national guideline, severe malaria requires urgent treatment and referral according to the severe malaria protocol...",
  "citations": [
    {
      "document_title": "Uganda National Malaria Guidelines",
      "section_title": "Severe malaria",
      "page_start": 45,
      "page_end": 47,
      "source_name": "Ministry of Health Uganda",
      "version": "2026"
    }
  ],
  "safety_flags": ["urgent_referral"],
  "retrieval_count": 5
}
```

### 14.1 RAG Safety Rules

The chatbot must:

- Use only retrieved approved guideline chunks.
- Cite every clinical recommendation.
- Prefer national guidelines over international guidelines.
- Refuse to answer when the answer is not found in approved sources.
- Avoid unsupported dosing, diagnosis, or treatment suggestions.
- Trigger referral warnings when danger signs are present.
- Log retrieval and answer citations.

Safe fallback response:

```text
I could not find this in the approved MediGuide sources currently available on this device/system. Please consult the latest national guideline or refer according to facility protocol.
```

---

## 15. Clinical Protocol Engine

Clinical protocols should be deterministic and auditable. Do not rely on the LLM for protocol logic.

Recommended format: YAML or JSON.

Example:

```yaml
id: malaria_fever_assessment_v1
title: Fever and Malaria Assessment
program_area: Malaria
version: "1.0.0"
source:
  document: Uganda National Malaria Guidelines
  section: Malaria case management
steps:
  - id: danger_signs
    type: checklist
    question: Does the patient have any danger signs?
    options:
      - convulsions
      - unable_to_drink
      - persistent_vomiting
      - altered_consciousness
      - severe_anemia
    next:
      if_any_selected: severe_malaria_referral
      else: malaria_test

  - id: malaria_test
    type: choice
    question: What is the malaria test result?
    options:
      - positive
      - negative
      - not_available
    next:
      positive: uncomplicated_malaria_treatment
      negative: assess_other_causes
      not_available: follow_testing_policy

  - id: severe_malaria_referral
    type: recommendation
    message: Treat as severe malaria and refer urgently according to national guidance.
    citation:
      document: Uganda National Malaria Guidelines
      section: Severe malaria
```

The Go backend should expose:

```http
GET  /api/v1/protocols
GET  /api/v1/protocols/{id}
POST /api/v1/protocols/{id}/run
POST /api/v1/protocols
PUT  /api/v1/protocols/{id}
POST /api/v1/protocols/{id}/publish
```

Protocol test cases should be required before publishing a protocol.

---

## 16. Offline Sync Design

The backend should generate sync packages for mobile devices.

Package example:

```text
guidelines_package_2026_05_15.zip
  manifest.json
  documents/
    malaria_guideline.html
    tb_guideline.html
  chunks/
    chunks.jsonl
  protocols/
    malaria_protocol.yaml
    tb_screening.yaml
  search/
    fts_index.sqlite
  metadata/
    versions.json
```

Manifest example:

```json
{
  "package_id": "uuid",
  "created_at": "2026-05-15T08:00:00Z",
  "content_version": "2026.05.15",
  "language": "en",
  "country": "UG",
  "documents": [
    {
      "id": "uuid",
      "title": "Uganda National Malaria Guidelines",
      "version": "2026",
      "file": "documents/malaria_guideline.html"
    }
  ],
  "protocols": [
    {
      "id": "malaria_fever_assessment_v1",
      "file": "protocols/malaria_protocol.yaml"
    }
  ]
}
```

Sync endpoints:

```http
GET  /api/v1/sync/packages/latest
GET  /api/v1/sync/packages/{id}/download
POST /api/v1/sync/devices/register
POST /api/v1/sync/devices/{device_id}/report
```

---

## 17. Object Storage Structure

Use MinIO/S3 for source and generated files.

Recommended object keys:

```text
guidelines/original/{document_id}/{filename}.pdf
guidelines/html/{version_id}/index.html
guidelines/markdown/{version_id}/content.md
guidelines/tables/{version_id}/tables.json
guidelines/images/{version_id}/{page}_{image}.png
sync/packages/{package_id}.zip
```

The database should store object keys, not public URLs.

Generate presigned URLs only when needed.

---

## 18. API Security

Minimum security requirements:

- JWT authentication
- Password hashing with bcrypt or argon2id
- Role-based permissions
- Audit logs for all content changes
- Upload file type validation
- File size limits
- Malware scanning in production
- Rate limiting for chat/search endpoints
- CORS restrictions
- TLS in production

Recommended permission codes:

```text
user.create
user.read
user.update
user.delete

role.manage
permission.manage

guideline.create
guideline.read
guideline.update
guideline.delete
guideline.review
guideline.publish

protocol.create
protocol.read
protocol.update
protocol.delete
protocol.publish

chat.use
search.use
sync.manage
audit.read
```

---

## 19. Development Milestones

### Milestone 1: Backend Foundation

- [ ] Create Go project structure
- [ ] Add config loader
- [ ] Add database connection
- [ ] Add migrations
- [ ] Add JWT auth
- [ ] Add users, roles, permissions
- [ ] Add seed command
- [ ] Add health endpoint
- [ ] Add Docker Compose

### Milestone 2: Guideline Management

- [ ] Add guideline document model
- [ ] Add guideline version model
- [ ] Add file upload to MinIO
- [ ] Add ingestion job creation
- [ ] Add review and approval workflow
- [ ] Add guideline listing and filtering

### Milestone 3: AI Worker

- [ ] Add FastAPI app
- [ ] Add DB connection
- [ ] Add MinIO client
- [ ] Add PDF extraction
- [ ] Add HTML generation
- [ ] Add section detection
- [ ] Add chunking
- [ ] Add embeddings
- [ ] Add vector insertion
- [ ] Add job polling

### Milestone 4: Search and RAG

- [ ] Add keyword search
- [ ] Add vector search
- [ ] Add hybrid search
- [ ] Add RAG endpoint
- [ ] Add citations
- [ ] Add retrieval logs
- [ ] Add safety fallback

### Milestone 5: Clinical Protocols

- [ ] Add YAML protocol schema
- [ ] Add protocol CRUD
- [ ] Add protocol runner
- [ ] Add test cases
- [ ] Add publish workflow

### Milestone 6: Offline Sync

- [ ] Add sync package generation
- [ ] Add manifest generation
- [ ] Add device registration
- [ ] Add package download endpoint
- [ ] Add mobile sync reporting

### Milestone 7: Production Readiness

- [ ] Add structured logging
- [ ] Add metrics
- [ ] Add tracing
- [ ] Add rate limiting
- [ ] Add file scanning
- [ ] Add backup strategy
- [ ] Add CI/CD
- [ ] Add Kubernetes manifests

---

## 20. Testing Strategy

### 20.1 Go Backend Tests

Test:

- Auth login
- JWT middleware
- RBAC middleware
- Guideline upload
- Ingestion job creation
- Review workflow
- Search endpoint
- Protocol runner
- Sync package metadata

Run:

```bash
go test ./...
```

### 20.2 AI Worker Tests

Test:

- PDF extraction
- HTML cleanup
- Section detection
- Chunking
- Embedding dimension consistency
- Vector insert
- RAG retrieval
- Job status update

Run:

```bash
pytest
```

### 20.3 Integration Tests

Recommended flow:

1. Start Docker Compose.
2. Run migrations.
3. Seed admin.
4. Login.
5. Upload sample PDF.
6. Confirm ingestion job exists.
7. Run AI worker.
8. Confirm chunks and embeddings are created.
9. Search for a known phrase.
10. Ask chatbot a question.
11. Confirm citations are returned.
12. Publish guideline.
13. Generate sync package.

---

## 21. Production Deployment Notes

Recommended production services:

```text
API service replicas: 2+
AI worker replicas: 1-3 depending on ingestion volume
PostgreSQL: managed or HA cluster
Object storage: S3/MinIO
Redis: managed or HA Redis
Reverse proxy: Nginx/Traefik
TLS: required
Backups: daily database + object storage backup
```

Important production controls:

- Clinical review workflow must be enforced.
- Draft chunks must not be used in production answers.
- Expired guidelines should be hidden or clearly flagged.
- Every AI answer must include citations.
- RAG prompts and retrieval results should be logged for audit.
- Medical content changes should require approval.

---

## 22. Recommended First Build Order

Build in this order:

```text
1. Go backend foundation
2. Auth/RBAC
3. Guideline upload
4. MinIO storage
5. Ingestion job table
6. AI worker PDF extraction
7. Chunk and embedding creation
8. Search endpoint
9. Review and publish workflow
10. RAG chatbot
11. Clinical protocols
12. Offline sync packages
```

Do not start with the chatbot alone. First ensure the guideline content is clean, reviewed, approved, and searchable.

---

## 23. Definition of Done for MVP

The MVP is complete when:

- Admin can log in.
- Admin can upload a guideline PDF.
- Backend stores the PDF in object storage.
- Backend creates an ingestion job.
- AI worker processes the PDF.
- Extracted HTML is available.
- Chunks and embeddings are stored.
- Admin can review and approve the guideline.
- Users can search approved guidelines.
- Chatbot can answer from approved chunks with citations.
- A sync package can be generated for offline use.

---

## 24. Notes for Developers

- Keep clinical decision logic separate from LLM generation.
- Use deterministic protocol YAML/JSON for decision support.
- Treat the LLM as a guideline explanation assistant, not the clinical authority.
- Always show citations for clinical recommendations.
- Prioritize national guidelines over international ones.
- Keep all ingestion outputs traceable to document version and page number.
- Design for offline use from the beginning.

---

## 25. Suggested Next Tasks

After generating the backend and AI worker projects, the next development tasks are:

1. Run both services locally with Docker Compose.
2. Apply migrations.
3. Seed the admin user.
4. Upload one sample national guideline PDF.
5. Run the AI worker ingestion process.
6. Validate extracted HTML manually.
7. Confirm chunks and embeddings are stored.
8. Implement the admin review screen.
9. Publish approved content.
10. Build the mobile offline sync client.
