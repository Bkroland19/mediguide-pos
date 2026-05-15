from dataclasses import dataclass, field
from typing import Any


@dataclass
class ExtractedBlock:
    text: str
    page: int
    level: int = 0
    html: str = ""
    kind: str = "paragraph"  # heading, paragraph, table


@dataclass
class ExtractedSection:
    title: str
    level: int
    page_start: int | None = None
    page_end: int | None = None
    html: str = ""
    text: str = ""
    sort_order: int = 0


@dataclass
class ExtractedTable:
    title: str | None
    page: int
    html: str
    data: list[list[Any]] = field(default_factory=list)


@dataclass
class ExtractedDocument:
    title: str | None
    pages: int
    html: str
    markdown: str
    text: str
    sections: list[ExtractedSection]
    tables: list[ExtractedTable]
