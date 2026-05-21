from __future__ import annotations

from concurrent import futures
from functools import lru_cache

import grpc
from grpc import StatusCode

from app.core.config import get_settings
from app.services.ingestion_service import IngestionService
from app.services.rag_service import RagService
from mediguide.aiworker.v1 import aiworker_pb2, aiworker_pb2_grpc


@lru_cache(maxsize=1)
def get_ingestion_service() -> IngestionService:
    return IngestionService()


@lru_cache(maxsize=1)
def get_rag_service() -> RagService:
    return RagService()


class AIWorkerServicer(aiworker_pb2_grpc.AIWorkerServiceServicer):
    def AskRAG(
        self,
        request: aiworker_pb2.AskRAGRequest,
        context: grpc.ServicerContext,
    ) -> aiworker_pb2.AskRAGResponse:
        _authorize(context)
        if len(request.question.strip()) < 3:
            context.abort(StatusCode.INVALID_ARGUMENT, "question must be at least 3 characters")

        response = get_rag_service().ask(
            question=request.question,
            language=request.language or "en",
            program_area=request.program_area or None,
            country=request.country or None,
            top_k=request.top_k or None,
            history_summary=request.history_summary or None,
            recent_messages=[
                {"role": message.role, "content": message.content}
                for message in request.recent_messages
            ],
        )
        return _build_ask_response(response)

    def RunIngestionJob(
        self,
        request: aiworker_pb2.RunIngestionJobRequest,
        context: grpc.ServicerContext,
    ) -> aiworker_pb2.RunIngestionJobResponse:
        _authorize(context)
        job_id = request.job_id.strip()
        if not job_id:
            context.abort(StatusCode.INVALID_ARGUMENT, "job_id is required")
        try:
            get_ingestion_service().run_job(job_id)
        except ValueError as exc:
            context.abort(StatusCode.NOT_FOUND, str(exc))
        except Exception as exc:
            context.abort(StatusCode.INTERNAL, f"Ingestion job failed: {exc}")
        return aiworker_pb2.RunIngestionJobResponse(
            job_id=job_id,
            status="completed",
            message="Ingestion job completed",
        )


def build_grpc_server() -> grpc.Server:
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=8))
    aiworker_pb2_grpc.add_AIWorkerServiceServicer_to_server(AIWorkerServicer(), server)
    settings = get_settings()
    server.add_insecure_port(f"{settings.grpc_host}:{settings.grpc_port}")
    return server


def _authorize(context: grpc.ServicerContext) -> None:
    secret = (get_settings().worker_api_secret or "").strip()
    if not secret:
        return
    provided = ""
    for key, value in context.invocation_metadata():
        if key.lower() == "x-worker-secret":
            provided = value
            break
    if provided != secret:
        context.abort(StatusCode.UNAUTHENTICATED, "invalid or missing x-worker-secret metadata")


def _build_ask_response(payload: dict) -> aiworker_pb2.AskRAGResponse:
    response = aiworker_pb2.AskRAGResponse(answer=str(payload.get("answer") or ""))
    for citation in payload.get("citations") or []:
        item = response.citations.add()
        item.chunk_id = str(_get_field(citation, "chunk_id") or "")
        item.title = str(_get_field(citation, "title") or "")
        item.country = str(_get_field(citation, "country") or "")
        item.source_name = str(_get_field(citation, "source_name") or "")
        item.source_version = str(_get_field(citation, "source_version") or "")
        item.page_start = int(_get_field(citation, "page_start") or 0)
        item.page_end = int(_get_field(citation, "page_end") or 0)
        item.similarity = float(_get_field(citation, "similarity") or 0)
    for chunk in payload.get("retrieved") or []:
        item = response.retrieved.add()
        item.id = str(_get_field(chunk, "id") or "")
        item.title = str(_get_field(chunk, "title") or "")
        item.content = str(_get_field(chunk, "content") or "")
        item.page_start = int(_get_field(chunk, "page_start") or 0)
        item.page_end = int(_get_field(chunk, "page_end") or 0)
        item.language = str(_get_field(chunk, "language") or "")
        item.program_area = str(_get_field(chunk, "program_area") or "")
        item.country = str(_get_field(chunk, "country") or "")
        item.source_name = str(_get_field(chunk, "source_name") or "")
        item.source_version = str(_get_field(chunk, "source_version") or "")
        item.similarity = float(_get_field(chunk, "similarity") or 0)
    safety = payload.get("safety") or {}
    response.safety.CopyFrom(
        aiworker_pb2.Safety(
            grounded=bool(safety.get("grounded")),
            provider=str(safety.get("provider") or ""),
            reason=str(safety.get("reason") or ""),
            standalone_question=str(safety.get("standalone_question") or ""),
            generation_error=str(safety.get("generation_error") or ""),
        )
    )
    return response


def _get_field(item, field: str):
    if isinstance(item, dict):
        return item.get(field)
    return getattr(item, field, None)
