#!/usr/bin/env bash
set -euo pipefail
uvicorn app.main:app --host "${API_HOST:-0.0.0.0}" --port "${API_PORT:-8090}" --reload
