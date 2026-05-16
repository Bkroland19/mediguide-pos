from typing import Any
from app.core.db import db_conn
from app.embeddings.factory import to_pgvector


class SearchRepository:
    def vector_search(
        self,
        query_embedding: list[float],
        top_k: int,
        program_area: str | None = None,
        language: str | None = None,
    ) -> list[dict[str, Any]]:
        vector = to_pgvector(query_embedding)
        filters = ["gc.deleted_at IS NULL", "gc.review_status = 'approved'", "gc.embedding IS NOT NULL"]
        params: list[Any] = [vector]
        if program_area:
            filters.append("lower(gc.program_area) = lower(%s)")
            params.append(program_area)
        if language:
            filters.append("gc.language = %s")
            params.append(language)
        params.extend([vector, top_k])
        sql = f"""
            SELECT
              gc.id, gc.title, gc.content, gc.page_start, gc.page_end, gc.language,
              gc.program_area, gc.source_name, gc.source_version,
              1 - (gc.embedding <=> %s::vector) AS similarity
            FROM guideline_chunks gc
            WHERE {' AND '.join(filters)}
            ORDER BY gc.embedding <=> %s::vector
            LIMIT %s
        """
        with db_conn() as conn, conn.cursor() as cur:
            cur.execute(sql, tuple(params))
            return cur.fetchall()

    def keyword_search(self, query: str, top_k: int, program_area: str | None = None) -> list[dict[str, Any]]:
        # Base filter params: first %s in plainto_tsquery (WHERE clause)
        filter_params: list[Any] = [query]
        filters = [
            "deleted_at IS NULL",
            "review_status = 'approved'",
            "search_vector @@ plainto_tsquery('simple', %s)",
        ]
        if program_area:
            filters.append("lower(program_area) = lower(%s)")
            filter_params.append(program_area)

        sql = f"""
            SELECT id, title, content, page_start, page_end, language, program_area, source_name, source_version,
                   ts_rank(search_vector, plainto_tsquery('simple', %s)) AS similarity
            FROM guideline_chunks
            WHERE {' AND '.join(filters)}
            ORDER BY similarity DESC
            LIMIT %s
        """
        # ts_rank needs query again (%s before WHERE), then filter_params, then top_k
        exec_params = [query] + filter_params + [top_k]
        with db_conn() as conn, conn.cursor() as cur:
            cur.execute(sql, tuple(exec_params))
            return cur.fetchall()

