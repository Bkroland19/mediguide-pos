#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "The mobile-only bump command has been replaced by the monorepo release command." >&2
echo "Synchronizing backend, dashboard, guidelines, AI worker, and user_app together." >&2

exec node "${repository_root}/scripts/prepare-release.js" "$@"
