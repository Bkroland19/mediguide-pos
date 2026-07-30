# MediGuide dashboard

## Guideline Markdown editor

After a guideline version PDF has been processed, open **Medical Guidelines**, use the row
actions menu, and choose **Edit Markdown** or **Preview Markdown**. The editor route is:

```text
/guidelines/{guideline-document-id}/versions/{version-id}/markdown
```

Users with dashboard content read access can preview extracted Markdown. Users with content update
access can edit draft versions and save with the button or `Command+S`/`Ctrl+S`. Published versions
are read-only; create a new version before revising published content.

The preview uses `react-markdown` and GFM support. Raw embedded HTML is disabled. Saving uses the
permission-protected v2 guideline API rather than the legacy collection API.

The API currently returns no revision or ETag for extracted Markdown, so the editor cannot detect
another user saving the same version concurrently. Autosave is intentionally disabled until the
backend supports optimistic concurrency.

## Quality commands

```bash
bun run lint
bun run typecheck
bun run test
bun run build
```
