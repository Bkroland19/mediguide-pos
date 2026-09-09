#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' \
    'Prepare a replacement guideline draft without reviewing, accepting, or publishing it.' \
    '' \
    'Required environment:' \
    '  MEDIGUIDE_API_URL       API origin, for example https://api.example.org' \
    '  MEDIGUIDE_ACCESS_TOKEN  reviewer bearer token (never printed)' \
    '' \
    'Usage:' \
    '  prepare-guideline-recovery.sh --source-version-id UUID --new-version VERSION [--execute]' \
    '' \
    'The default is a read-only dry run. --execute duplicates the exact published Markdown' \
    'revision, starts regeneration, waits for completion, and downloads a completeness report.'
}

source_version_id=''
new_version=''
execute=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-version-id) source_version_id="${2:-}"; shift 2 ;;
    --new-version) new_version="${2:-}"; shift 2 ;;
    --execute) execute=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$source_version_id" || -z "$new_version" ]]; then usage >&2; exit 2; fi
if [[ -z "${MEDIGUIDE_API_URL:-}" || -z "${MEDIGUIDE_ACCESS_TOKEN:-}" ]]; then
  printf 'MEDIGUIDE_API_URL and MEDIGUIDE_ACCESS_TOKEN are required.\n' >&2
  exit 2
fi
for command_name in curl jq; do
  if ! command -v "$command_name" >/dev/null 2>&1; then printf '%s is required.\n' "$command_name" >&2; exit 2; fi
done

api_url="${MEDIGUIDE_API_URL%/}"
authorization="Authorization: Bearer ${MEDIGUIDE_ACCESS_TOKEN}"
source_report="$(curl --fail-with-body --silent --show-error -H "$authorization" "$api_url/api/v2/guideline-versions/$source_version_id/completeness-report")"
source_data="$(jq -c '.data // .' <<<"$source_report")"
source_status="$(jq -r '.version_status' <<<"$source_data")"
source_version="$(jq -r '.version' <<<"$source_data")"
published_revision="$(jq -r '.regeneration.published_markdown_revision_id // empty' <<<"$source_data")"
if [[ "$source_status" != 'published' || -z "$published_revision" ]]; then
  printf 'Refusing recovery: the source must be published and have an immutable published Markdown revision.\n' >&2
  exit 1
fi
if [[ "$new_version" == "$source_version" ]]; then
  printf 'Refusing recovery: the replacement must use a new version label.\n' >&2
  exit 1
fi

printf 'Source: %s version %s (%s)\n' "$(jq -r '.guideline_title' <<<"$source_data")" "$source_version" "$source_version_id"
printf 'Published revision: %s\n' "$published_revision"
printf 'Replacement version: %s\n' "$new_version"
if [[ "$execute" != true ]]; then
  printf 'Dry run only. Re-run with --execute to create and regenerate the replacement draft.\n'
  exit 0
fi

duplicate_payload="$(jq -cn --arg version "$new_version" '{version:$version}')"
duplicate_response="$(curl --fail-with-body --silent --show-error -X POST -H "$authorization" -H 'Content-Type: application/json' --data "$duplicate_payload" "$api_url/api/v2/guideline-versions/$source_version_id/duplicate")"
duplicate_data="$(jq -c '.data // .' <<<"$duplicate_response")"
candidate_version_id="$(jq -r '.version.id' <<<"$duplicate_data")"
candidate_revision_id="$(jq -r '.draft.revision.id' <<<"$duplicate_data")"
if [[ -z "$candidate_version_id" || "$candidate_version_id" == null || -z "$candidate_revision_id" || "$candidate_revision_id" == null ]]; then
  printf 'The duplicate response did not contain the replacement version and revision IDs.\n' >&2
  exit 1
fi
printf 'Created draft %s at exact revision %s.\n' "$candidate_version_id" "$candidate_revision_id"

regenerate_payload="$(jq -cn --arg revision_id "$candidate_revision_id" --arg key "recovery-$candidate_revision_id" '{revision_id:$revision_id,idempotency_key:$key}')"
regenerate_response="$(curl --fail-with-body --silent --show-error -X POST -H "$authorization" -H 'Content-Type: application/json' --data "$regenerate_payload" "$api_url/api/v2/guideline-versions/$candidate_version_id/regenerate")"
job_id="$(jq -r '(.data // .).job.id' <<<"$regenerate_response")"
if [[ -z "$job_id" || "$job_id" == null ]]; then printf 'Regeneration did not return a job ID.\n' >&2; exit 1; fi
printf 'Regeneration queued as job %s.\n' "$job_id"

deadline=$((SECONDS + 900))
while (( SECONDS < deadline )); do
  job_response="$(curl --fail-with-body --silent --show-error -H "$authorization" "$api_url/api/v2/guideline-versions/$candidate_version_id/regeneration-jobs/$job_id")"
  job_data="$(jq -c '(.data // .) | (.job // .)' <<<"$job_response")"
  job_status="$(jq -r '.status' <<<"$job_data")"
  job_progress="$(jq -r '.progress_percent' <<<"$job_data")"
  printf 'Regeneration: %s (%s%%)\n' "$job_status" "$job_progress"
  case "$job_status" in
    completed) break ;;
    failed|canceled|superseded) printf 'Regeneration stopped with status %s. No review, acceptance, or publication was attempted.\n' "$job_status" >&2; exit 1 ;;
  esac
  sleep 5
done
if [[ "${job_status:-}" != 'completed' ]]; then printf 'Timed out waiting for regeneration. The draft remains unpublished.\n' >&2; exit 1; fi

report_path="guideline-completeness-$candidate_version_id.json"
curl --fail-with-body --silent --show-error -H "$authorization" "$api_url/api/v2/guideline-versions/$candidate_version_id/completeness-report/export?format=json" -o "$report_path"
printf 'Recovery draft prepared. Completeness report: %s\n' "$report_path"
printf 'STOP: clinical reviewers must now approve verified low-risk blocks, review every high-risk block individually, accept this exact revision/job, validate, and explicitly publish.\n'
