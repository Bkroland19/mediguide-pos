#!/usr/bin/env bash

set -euo pipefail

application_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sqlite_version="2.9.4"
sqlite_sha256="922a76b182b6af69b030c8e2fdd3283ecc8e827248b20e4b1f3f3db170b52117"
sqlite_url="https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-${sqlite_version}/sqlite3.wasm"
sqlite_target="${application_root}/web/sqlite3.wasm"
worker_target="${application_root}/web/drift_worker.dart.js"

download="$(mktemp)"
trap 'rm -f "${download}"' EXIT

curl --fail --silent --show-error --location "${sqlite_url}" --output "${download}"
actual_sha256="$(shasum -a 256 "${download}" | awk '{print $1}')"
if [[ "${actual_sha256}" != "${sqlite_sha256}" ]]; then
  echo "sqlite3.wasm checksum mismatch: ${actual_sha256}" >&2
  exit 1
fi
mv "${download}" "${sqlite_target}"

cd "${application_root}"
dart compile js tool/drift_worker.dart -O4 -o "${worker_target}"

echo "Prepared pinned Drift Web database assets."
