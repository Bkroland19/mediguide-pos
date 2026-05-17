from __future__ import annotations
from pathlib import Path
import html
import re
import fitz
from bs4 import BeautifulSoup
from markdownify import markdownify as md
from slugify import slugify
from app.document_processing.types import ExtractedDocument, ExtractedSection, ExtractedTable

_BULLET_RE = re.compile(r"^[~•●○▪■□◦]+\s*")
_LOC_CODE_RE = re.compile(r"^(?:HC ?[1-4IVX]+|RRH?|NRH|H|NA)$", re.I)
_COMMON_SUBHEADINGS = {
    "assessment",
    "care",
    "cause",
    "causes",
    "causes and clinical features",
    "classification",
    "clinical features",
    "comments",
    "complications",
    "definition",
    "diagnosis",
    "differential diagnosis",
    "features",
    "follow up",
    "investigations",
    "management",
    "monitoring",
    "note",
    "notes",
    "prevention",
    "referral",
    "supportive care",
    "treatment",
}
_TABLE_HEAD_BG = "#dbe5f1"
_TABLE_BORDER = "#667085"


def _clean_text(text: str) -> str:
    text = text.replace("\x00", " ").replace("\u00ad", "")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _clean_line(text: str) -> str:
    return _clean_text(text).replace("­", "").strip()


def _is_noise_line(line: str) -> bool:
    if not line:
        return True
    if re.fullmatch(r"Uganda Clinical Guidelines 2023", line, re.I):
        return True
    if re.fullmatch(r"CHAPTER \d+:\s+.+", line, re.I):
        return True
    return False


def _content_lines(text: str) -> list[str]:
    lines: list[str] = []
    for raw in text.splitlines():
        line = _clean_line(raw)
        if not line or _is_noise_line(line):
            continue
        lines.append(line)
    return lines


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
        for line in _content_lines(raw):
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
    body = _render_section_body(_content_lines(text), min(h_level + 1, 6))
    return f"<h{h_level} id=\"{slugify(title)}\">{html.escape(title)}</h{h_level}>{body}"


def _is_subheading(line: str) -> bool:
    candidate = line.strip().rstrip(":")
    if not candidate or len(candidate) > 80 or _LOC_CODE_RE.fullmatch(candidate):
        return False
    if candidate.lower() in _COMMON_SUBHEADINGS:
        return True
    if re.match(r"^\d", candidate):
        return False
    words = candidate.split()
    if len(words) > 6 or candidate.endswith((".", ";", ",")):
        return False
    if candidate.upper() == candidate and 1 <= len(words) <= 5:
        return True
    significant = [w for w in words if re.search(r"[A-Za-z]", w)]
    if not significant:
        return False
    return all(
        w[0].isupper() or w.lower() in {"and", "of", "in", "to", "for", "with"}
        for w in significant
    )


def _strip_bullet(line: str) -> str | None:
    if not _BULLET_RE.match(line):
        return None
    cleaned = _BULLET_RE.sub("", line).strip()
    return cleaned or None


def _is_management_table_header(lines: list[str], index: int) -> bool:
    if index + 1 >= len(lines):
        return False
    return lines[index].upper() == "TREATMENT" and lines[index + 1].upper() == "LOC"


def _render_section_body(lines: list[str], subheading_level: int) -> str:
    parts: list[str] = []
    paragraph: list[str] = []
    items: list[str] = []
    index = 0

    def flush_paragraph() -> None:
        if paragraph:
            parts.append(f"<p>{html.escape(' '.join(paragraph).strip())}</p>")
            paragraph.clear()

    def flush_list() -> None:
        if items:
            rendered = "".join(f"<li>{html.escape(item)}</li>" for item in items if item)
            if rendered:
                parts.append(f"<ul>{rendered}</ul>")
            items.clear()

    while index < len(lines):
        line = lines[index]
        bullet = _strip_bullet(line)

        if _is_management_table_header(lines, index):
            flush_paragraph()
            flush_list()
            table_html, consumed = _parse_management_table(lines, index)
            if table_html:
                parts.append(table_html)
                index = consumed
                continue

        if _is_subheading(line):
            flush_paragraph()
            flush_list()
            parts.append(f"<h{subheading_level}>{html.escape(line.rstrip(':'))}</h{subheading_level}>")
            index += 1
            continue

        if bullet is not None:
            flush_paragraph()
            items.append(bullet)
            index += 1
            while index < len(lines):
                next_line = lines[index]
                if _strip_bullet(next_line) is not None or _is_subheading(next_line) or _is_management_table_header(lines, index):
                    break
                items[-1] = f"{items[-1]} {next_line}".strip()
                index += 1
            continue

        flush_list()
        paragraph.append(line)
        index += 1

    flush_paragraph()
    flush_list()
    return "".join(parts)


def _parse_management_table(lines: list[str], start_index: int) -> tuple[str, int]:
    rows: list[tuple[str, str]] = []
    current_text: list[str] = []
    current_loc = ""
    index = start_index + 2

    while index < len(lines):
        line = lines[index]
        bullet = _strip_bullet(line)

        if _is_subheading(line) and not current_text:
            break
        if _is_management_table_header(lines, index):
            break

        if bullet is not None:
            if current_text:
                rows.append((" ".join(current_text).strip(), current_loc))
            current_text = [bullet]
            current_loc = ""
            index += 1
            continue

        if _LOC_CODE_RE.fullmatch(line):
            if current_text:
                current_loc = line.upper().replace(" ", "")
                rows.append((" ".join(current_text).strip(), current_loc))
                current_text = []
                current_loc = ""
            index += 1
            continue

        if current_text:
            current_text.append(line)
            index += 1
            continue

        break

    if current_text:
        rows.append((" ".join(current_text).strip(), current_loc))

    if not rows:
        return "", start_index + 2

    body_rows = [
        [f"&#x2610; {html.escape(treatment)}", html.escape(loc)]
        for treatment, loc in rows
    ]
    return _render_table_html([["TREATMENT", "LOC"], *body_rows], title=None, already_escaped=True), index


def _clean_table_rows(rows: list[list[object]]) -> list[list[str]]:
    cleaned: list[list[str]] = []
    for row in rows:
        normalized = [_clean_line(str(cell or "")) for cell in row]
        if any(cell for cell in normalized):
            cleaned.append(normalized)
    return cleaned


def _is_management_table_data(rows: list[list[str]]) -> bool:
    if not rows:
        return False
    header = [cell.upper() for cell in rows[0] if cell]
    return "TREATMENT" in header and "LOC" in header


def _render_table_html(rows: list[list[str]], title: str | None, already_escaped: bool = False) -> str:
    if not rows:
        return ""

    def cell(value: str) -> str:
        return value if already_escaped else html.escape(value)

    header = rows[0]
    body = rows[1:] if len(rows) > 1 else []

    caption_html = (
        f"<caption style=\"caption-side:top;text-align:left;font-weight:600;padding:0 0 8px 0;\">{cell(title)}</caption>"
        if title else ""
    )
    thead_cells = "".join(
        f"<th style=\"border:1px solid {_TABLE_BORDER};background:{_TABLE_HEAD_BG};padding:8px 10px;text-align:left;vertical-align:top;font-weight:600;\">{cell(col)}</th>"
        for col in header
    )
    thead = f"<thead><tr>{thead_cells}</tr></thead>"
    tbody_rows = []
    for row in body:
        padded = row + [""] * (len(header) - len(row))
        tds = "".join(
            f"<td style=\"border:1px solid {_TABLE_BORDER};padding:8px 10px;vertical-align:top;\">{cell(col)}</td>"
            for col in padded[:len(header)]
        )
        tbody_rows.append(f"<tr>{tds}</tr>")
    tbody = f"<tbody>{''.join(tbody_rows)}</tbody>" if tbody_rows else ""
    return (
        "<div class=\"guideline-table\" style=\"margin:16px 0;overflow-x:auto;\">"
        f"<table style=\"width:100%;border-collapse:collapse;border:1px solid {_TABLE_BORDER};\">"
        f"{caption_html}{thead}{tbody}</table></div>"
    )


def _extract_tables_pdfplumber(path: Path) -> list[ExtractedTable]:
    tables: list[ExtractedTable] = []
    try:
        import pdfplumber
        with pdfplumber.open(str(path)) as pdf:
            for i, page in enumerate(pdf.pages, start=1):
                for idx, table in enumerate(page.extract_tables() or []):
                    cleaned_rows = _clean_table_rows(table or [])
                    if len(cleaned_rows) < 2:
                        continue
                    title = f"Table {len(tables)+1}"
                    tables.append(
                        ExtractedTable(
                            title=title,
                            page=i,
                            html=_render_table_html(cleaned_rows, title=title),
                            data=cleaned_rows,
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
    section_by_page: dict[int, ExtractedSection] = {}
    for section in sections:
        start = section.page_start or 0
        end = section.page_end or start
        for page in range(start, end + 1):
            section_by_page.setdefault(page, section)

    orphan_table_html: list[str] = []
    for table in tables:
        section = section_by_page.get(table.page)
        if section and not _is_management_table_data(_clean_table_rows(table.data)):
            section.html += table.html
        elif not _is_management_table_data(_clean_table_rows(table.data)):
            orphan_table_html.append(table.html)

    body_html = "\n".join(s.html for s in sections)
    if orphan_table_html:
        body_html += "\n<section><h2>Tables</h2>" + "\n".join(orphan_table_html) + "</section>"

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
