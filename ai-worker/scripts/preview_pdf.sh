#!/usr/bin/env bash
set -euo pipefail
PDF_PATH="${1:?Usage: scripts/preview_pdf.sh /path/to/file.pdf}"
curl -s -X POST http://localhost:8090/api/v1/extract/preview \
  -F "file=@${PDF_PATH}" | python -m json.tool
