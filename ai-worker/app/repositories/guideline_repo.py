import json
import uuid
from typing import Any
from app.core.db import db_conn
from app.embeddings.factory import to_pgvector


class GuidelineRepository:
    def get_version_with_document(self, version_id: str) -> dict[str, Any] | None:
        with db_conn() as conn, conn.cursor() as cur:
            cur.execute(
                """
                SELECT gv.*, gd.title AS document_title, gd.country, gd.source_org, gd.program_area, gd.language AS document_language
                FROM guideline_versions gv
                JOIN guideline_documents gd ON gd.id = gv.document_id
                WHERE gv.id = %s AND gv.deleted_at IS NULL
                """,
                (version_id,),
            )
            return cur.fetchone()

    def clear_existing_extraction(self, version_id: str) -> None:
        with db_conn() as conn, conn.cursor() as cur:
            cur.execute("DELETE FROM guideline_chunks WHERE version_id = %s", (version_id,))
            cur.execute("DELETE FROM guideline_tables WHERE version_id = %s", (version_id,))
            cur.execute("DELETE FROM guideline_sections WHERE version_id = %s", (version_id,))
            conn.commit()

    def insert_section(self, version_id: str, section, parent_id: str | None = None) -> str:
        with db_conn() as conn, conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO guideline_sections(version_id, parent_id, title, slug, level, html, text, page_start, page_end, sort_order)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                RETURNING id
                """,
                (
                    version_id,
                    parent_id,
                    section.title,
                    self._slug(section.breadcrumb or section.title),
                    section.level,
                    section.html,
                    section.text,
                    section.page_start,
                    section.page_end,
                    section.sort_order,
                ),
            )
            section_id = str(cur.fetchone()["id"])
            conn.commit()
            return section_id

    def insert_chunk(self, *, version: dict[str, Any], section_id: str | None, chunk, embedding: list[float]) -> str:
        review_status = self._chunk_review_status(version.get("status"))
        with db_conn() as conn, conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO guideline_chunks(
                  version_id, section_id, title, content, html, page_start, page_end,
                  language, program_area, source_name, source_version, review_status,
                  embedding_text, embedding
                )
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s::vector)
                RETURNING id
                """,
                (
                    version["id"],
                    section_id,
                    chunk.title,
                    chunk.content,
                    chunk.html,
                    chunk.page_start,
                    chunk.page_end,
                    version.get("document_language") or "en",
                    version.get("program_area"),
                    version.get("source_org") or version.get("document_title"),
                    version.get("version"),
                    review_status,
                    chunk.content,
                    to_pgvector(embedding),
                ),
            )
            chunk_id = str(cur.fetchone()["id"])
            conn.commit()
            return chunk_id

    def insert_table(self, version_id: str, section_id: str | None, table) -> str:
        with db_conn() as conn, conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO guideline_tables(version_id, section_id, title, html, data_json, page)
                VALUES (%s,%s,%s,%s,%s::jsonb,%s)
                RETURNING id
                """,
                (version_id, section_id, table.title, table.html, json.dumps(table.data), table.page),
            )
            table_id = str(cur.fetchone()["id"])
            conn.commit()
            return table_id

    def update_version_assets(self, version_id: str, html_key: str, markdown_key: str, status: str = "extracted") -> None:
        with db_conn() as conn, conn.cursor() as cur:
            cur.execute(
                """
                UPDATE guideline_versions
                SET html_file_key=%s, markdown_file_key=%s, status=%s, updated_at=now()
                WHERE id=%s
                """,
                (html_key, markdown_key, status, version_id),
            )
            conn.commit()

    def replace_extraction(
        self,
        *,
        version_id: str,
        version: dict[str, Any],
        sections: list[Any],
        tables: list[Any],
        chunks: list[Any],
        embeddings: list[list[float]],
        html_key: str,
        markdown_key: str,
        status: str = "extracted",
    ) -> None:
        review_status = self._chunk_review_status(version.get("status"))
        with db_conn() as conn, conn.cursor() as cur:
            cur.execute("DELETE FROM guideline_chunks WHERE version_id = %s", (version_id,))
            cur.execute("DELETE FROM guideline_tables WHERE version_id = %s", (version_id,))
            cur.execute("DELETE FROM guideline_sections WHERE version_id = %s", (version_id,))

            section_id_by_order: dict[int, str] = {}
            section_rows: list[tuple[Any, ...]] = []
            for section in sections:
                section_id = str(uuid.uuid4())
                section_id_by_order[section.sort_order] = section_id
                parent_id = (
                    section_id_by_order.get(section.parent_sort_order)
                    if section.parent_sort_order is not None
                    else None
                )
                section_rows.append(
                    (
                        section_id,
                        version_id,
                        parent_id,
                        section.title,
                        self._slug(section.breadcrumb or section.title),
                        section.level,
                        section.html,
                        section.text,
                        section.page_start,
                        section.page_end,
                        section.sort_order,
                    )
                )
            if section_rows:
                cur.executemany(
                    """
                    INSERT INTO guideline_sections(
                      id, version_id, parent_id, title, slug, level, html, text, page_start, page_end, sort_order
                    )
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                    """,
                    section_rows,
                )

            table_rows: list[tuple[Any, ...]] = []
            for table in tables:
                table_rows.append(
                    (
                        str(uuid.uuid4()),
                        version_id,
                        None,
                        table.title,
                        table.html,
                        json.dumps(table.data),
                        table.page,
                    )
                )
            if table_rows:
                cur.executemany(
                    """
                    INSERT INTO guideline_tables(id, version_id, section_id, title, html, data_json, page)
                    VALUES (%s,%s,%s,%s,%s,%s::jsonb,%s)
                    """,
                    table_rows,
                )

            chunk_rows: list[tuple[Any, ...]] = []
            for chunk, embedding in zip(chunks, embeddings):
                section_id = section_id_by_order.get(chunk.section_order)
                chunk_rows.append(
                    (
                        str(uuid.uuid4()),
                        version["id"],
                        section_id,
                        chunk.title,
                        chunk.content,
                        chunk.html,
                        chunk.page_start,
                        chunk.page_end,
                        version.get("document_language") or "en",
                        version.get("program_area"),
                        version.get("source_org") or version.get("document_title"),
                        version.get("version"),
                        review_status,
                        chunk.content,
                        to_pgvector(embedding),
                    )
                )
            if chunk_rows:
                cur.executemany(
                    """
                    INSERT INTO guideline_chunks(
                      id, version_id, section_id, title, content, html, page_start, page_end,
                      language, program_area, source_name, source_version, review_status,
                      embedding_text, embedding
                    )
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s::vector)
                    """,
                    chunk_rows,
                )

            cur.execute(
                """
                UPDATE guideline_versions
                SET html_file_key=%s, markdown_file_key=%s, status=%s, updated_at=now()
                WHERE id=%s
                """,
                (html_key, markdown_key, status, version_id),
            )
            conn.commit()

    @staticmethod
    def _slug(value: str) -> str:
        from slugify import slugify
        return slugify(value or "section")

    @staticmethod
    def _chunk_review_status(version_status: str | None) -> str:
        if (version_status or "").lower() in {"approved", "published"}:
            return "approved"
        return "draft"
