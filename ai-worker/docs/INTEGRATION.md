# Integration Guide

## 1. Start backend infrastructure

```bash
cd backend
cp .env.example .env
docker compose up -d postgres minio redis
make migrate-up
make seed
```

## 2. Start AI worker API

```bash
cd ../ai-worker
cp .env.example .env
ollama pull mxbai-embed-large:latest
uvicorn app.main:app --reload --port 8090
```

## 3. Start worker loop

```bash
python -m app.worker
```

## 4. Upload a guideline PDF through the Go backend

The Go backend creates a `guideline_versions` row and an `ingestion_jobs` row.

## 5. AI worker processes the job

The worker downloads the PDF from MinIO, extracts HTML/Markdown, chunks it, embeds chunks, and stores them in PostgreSQL.

## 6. Ask the RAG service

```bash
curl -X POST http://localhost:8090/api/v1/rag/ask \
  -H 'Content-Type: application/json' \
  -d '{"question":"How is severe malaria managed?","program_area":"Malaria","language":"en"}'
```

## Production note

The backend and AI worker now default to Ollama `mxbai-embed-large:latest` with `EMBEDDING_DIM=1024`. If you change embedding models, migrate the `guideline_chunks.embedding` column to the new vector size before ingesting documents.
