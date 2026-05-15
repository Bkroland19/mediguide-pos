# Document Processing Pipeline

```text
PDF
 ↓
PyMuPDF text extraction
 ↓
pdfplumber table extraction
 ↓
section detection
 ↓
clean HTML and Markdown
 ↓
chunk sections with overlap
 ↓
embed chunks
 ↓
insert into guideline_chunks
 ↓
RAG retrieval with citations
```

## Review workflow

For clinical safety, extracted content should be reviewed before publication. The worker currently marks chunks as `approved` to make MVP testing easier. In production, change this to `draft` or `extracted`, then approve after medical review.
