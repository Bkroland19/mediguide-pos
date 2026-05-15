from pathlib import Path
import tempfile
from fastapi import APIRouter, UploadFile, File, HTTPException
from app.models.schemas import HealthResponse, ExtractionPreviewResponse, RunJobResponse, RagAskRequest, RagAskResponse
from app.document_processing.pdf_extractor import extract_pdf
from app.document_processing.chunker import chunk_sections
from app.services.ingestion_service import IngestionService
from app.services.rag_service import RagService

router = APIRouter()


@router.get("/healthz", response_model=HealthResponse)
def healthz():
    return HealthResponse()


@router.post("/api/v1/extract/preview", response_model=ExtractionPreviewResponse)
async def preview_pdf(file: UploadFile = File(...)):
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are supported")
    with tempfile.TemporaryDirectory(prefix="mediguide-preview-") as tmp:
        path = Path(tmp) / file.filename
        path.write_bytes(await file.read())
        extracted = extract_pdf(path)
        chunks = chunk_sections(extracted.sections)
        return ExtractionPreviewResponse(
            title=extracted.title,
            pages=extracted.pages,
            sections=len(extracted.sections),
            chunks=len(chunks),
            tables=len(extracted.tables),
            markdown_sample=extracted.markdown[:3000],
        )


@router.post("/api/v1/ingestion/jobs/{job_id}/run", response_model=RunJobResponse)
def run_job(job_id: str):
    service = IngestionService()
    try:
        service.run_job(job_id)
        return RunJobResponse(job_id=job_id, status="completed", message="Ingestion job completed")
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post("/api/v1/rag/ask", response_model=RagAskResponse)
def ask(request: RagAskRequest):
    service = RagService()
    return service.ask(
        question=request.question,
        language=request.language,
        program_area=request.program_area,
        top_k=request.top_k,
    )
