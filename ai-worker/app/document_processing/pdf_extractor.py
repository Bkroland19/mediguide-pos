from __future__ import annotations
from pathlib import Path
import html
import re
import fitz
from bs4 import BeautifulSoup
from markdownify import markdownify as md
from slugify import slugify
from app.document_processing.types import ExtractedDocument, ExtractedSection, ExtractedTable


def _clean_text(text: str) -> str:
    text = text.replace("\x00", " ")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _guess_heading(line: str) -> int:
    s = line.strip()
    if not s or len(s) > 140:
        return 0
    if re.match(r"^(chapter|section)\s+\d+", s, re.I):
        return 1
    # Numbered section headings: require ≤ 12 words to avoid misclassifying
    # body text like "1 tablet twice daily" as a heading.
    if re.match(r"^\d{1,3}(\.\d{1,3}){0,3}\s+[A-Za-z]", s) and len(s.split()) <= 12:
        return min(1 + s.split()[0].count("."), 4)
    if s.isupper() and 1 < len(s.split()) <= 10:
        return 2
    return 0


def _split_sections(page_lines: list[tuple[int, str]]) -> list[ExtractedSection]:
    sections: list[ExtractedSection] = []
    current: ExtractedSection | None = None
    fallback_order = 0

    for page, raw in page_lines:
        for line in raw.splitlines():
            line = line.strip()
            if not line:
                continue
            level = _guess_heading(line)
            if level:
                if current:
                    current.text = _clean_text(current.text)
                    current.html = _section_html(current.title, current.level, current.text)
                    current.page_end = page
                    sections.append(current)
                current = ExtractedSection(
                    title=line,
                    level=level,
                    page_start=page,
                    page_end=page,
                    sort_order=len(sections),
                )
            else:
                if current is None:
                    fallback_order += 1
                    current = ExtractedSection(
                        title="Introduction" if fallback_order == 1 else f"Section {fallback_order}",
                        level=1,
                        page_start=page,
                        page_end=page,
                        sort_order=len(sections),
                    )
                current.text += line + "\n"
                current.page_end = page

    if current:
        current.text = _clean_text(current.text)
        current.html = _section_html(current.title, current.level, current.text)
        sections.append(current)

    return [s for s in sections if s.text or s.title]


def _section_html(title: str, level: int, text: str) -> str:
    h_level = max(1, min(level, 4))
    paras = "".join(f"<p>{html.escape(p.strip())}</p>" for p in text.split("\n") if p.strip())
    return f"<h{h_level} id=\"{slugify(title)}\">{html.escape(title)}</h{h_level}>{paras}"


def _extract_tables_pdfplumber(path: Path) -> list[ExtractedTable]:
    tables: list[ExtractedTable] = []
    try:
        import pdfplumber
        with pdfplumber.open(str(path)) as pdf:
            for i, page in enumerate(pdf.pages, start=1):
                for idx, table in enumerate(page.extract_tables() or []):
                    if not table:
                        continue
                    html_rows = []
                    for row in table:
                        cells = "".join(f"<td>{html.escape(str(c or ''))}</td>" for c in row)
                        html_rows.append(f"<tr>{cells}</tr>")
                    tables.append(
                        ExtractedTable(
                            title=f"Table {len(tables)+1}",
                            page=i,
                            html="<table>" + "".join(html_rows) + "</table>",
                            data=table,
                        )
                    )
    except Exception:
        # Table extraction is best-effort. The PDF text extraction should continue.
        return tables
    return tables


def extract_pdf(path: Path) -> ExtractedDocument:
    doc = fitz.open(str(path))
    page_lines: list[tuple[int, str]] = []
    all_text: list[str] = []
    title = None

    for page_number, page in enumerate(doc, start=1):
        text = page.get_text("text") or ""
        text = _clean_text(text)
        if page_number == 1:
            for line in text.splitlines():
                if len(line.strip()) > 8:
                    title = line.strip()[:180]
                    break
        page_lines.append((page_number, text))
        all_text.append(text)

    sections = _split_sections(page_lines)
    tables = _extract_tables_pdfplumber(path)
    body_html = "\n".join(s.html for s in sections)
    if tables:
        body_html += "\n<h2>Extracted Tables</h2>" + "\n".join(t.html for t in tables)

    soup = BeautifulSoup(f"<article>{body_html}</article>", "html.parser")
    clean_html = str(soup)
    markdown = md(clean_html, heading_style="ATX")
    text = _clean_text("\n\n".join(all_text))

    return ExtractedDocument(
        title=title,
        pages=len(doc),
        html=clean_html,
        markdown=markdown,
        text=text,
        sections=sections,
        tables=tables,
    )
