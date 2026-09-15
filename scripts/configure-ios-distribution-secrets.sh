#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: configure-ios-distribution-secrets.sh [--repo OWNER/REPO] [--environment NAME]

Required environment variables:
  APPLE_TEAM_ID
  IOS_DISTRIBUTION_CERTIFICATE_FILE
  IOS_DISTRIBUTION_CERTIFICATE_PASSWORD
  IOS_FIREBASE_PROVISIONING_PROFILE_FILE
  IOS_FIREBASE_EXPORT_OPTIONS_PLIST_FILE
  IOS_TESTFLIGHT_PROVISIONING_PROFILE_FILE
  IOS_TESTFLIGHT_EXPORT_OPTIONS_PLIST_FILE
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_PRIVATE_KEY_FILE

Optional:
  IOS_BUNDLE_IDENTIFIER (defaults to com.omarsoft.mediguide.staging)

The command validates every local asset, uploads it to the selected protected
GitHub Environment, and never writes decoded credentials into the repository.
EOF
}

repo="mohuganda/mediguide-pos"
environment="staging"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:-}"; shift 2 ;;
    --environment) environment="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

required=(
  APPLE_TEAM_ID
  IOS_DISTRIBUTION_CERTIFICATE_FILE
  IOS_DISTRIBUTION_CERTIFICATE_PASSWORD
  IOS_FIREBASE_PROVISIONING_PROFILE_FILE
  IOS_FIREBASE_EXPORT_OPTIONS_PLIST_FILE
  IOS_TESTFLIGHT_PROVISIONING_PROFILE_FILE
  IOS_TESTFLIGHT_EXPORT_OPTIONS_PLIST_FILE
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_PRIVATE_KEY_FILE
)
missing=()
for name in "${required[@]}"; do
  [ -n "${!name:-}" ] || missing+=("$name")
done
if [ "${#missing[@]}" -gt 0 ]; then
  printf 'Missing local configuration: %s\n' "${missing[*]}" >&2
  exit 1
fi

command -v gh >/dev/null || { echo "GitHub CLI (gh) is required." >&2; exit 1; }
command -v openssl >/dev/null || { echo "OpenSSL is required." >&2; exit 1; }
gh auth status >/dev/null

bundle_id="${IOS_BUNDLE_IDENTIFIER:-com.omarsoft.mediguide.staging}"

openssl pkcs12 \
  -in "$IOS_DISTRIBUTION_CERTIFICATE_FILE" \
  -passin env:IOS_DISTRIBUTION_CERTIFICATE_PASSWORD \
  -nokeys -clcerts -out /dev/null
openssl pkey -in "$APP_STORE_CONNECT_PRIVATE_KEY_FILE" -check -noout >/dev/null

script_dir="$(cd "$(dirname "$0")" && pwd)"
"${script_dir}/validate-ios-distribution-assets.sh" \
  --bundle-id "$bundle_id" \
  --team-id "$APPLE_TEAM_ID" \
  --firebase-profile "$IOS_FIREBASE_PROVISIONING_PROFILE_FILE" \
  --firebase-export-options "$IOS_FIREBASE_EXPORT_OPTIONS_PLIST_FILE" \
  --testflight-profile "$IOS_TESTFLIGHT_PROVISIONING_PROFILE_FILE" \
  --testflight-export-options "$IOS_TESTFLIGHT_EXPORT_OPTIONS_PLIST_FILE"

set_text_secret() {
  printf '%s' "$2" | gh secret set "$1" --repo "$repo" --env "$environment"
}

set_file_secret() {
  openssl base64 -A -in "$2" | gh secret set "$1" --repo "$repo" --env "$environment"
}

set_text_secret APPLE_TEAM_ID "$APPLE_TEAM_ID"
set_text_secret IOS_DISTRIBUTION_CERTIFICATE_PASSWORD "$IOS_DISTRIBUTION_CERTIFICATE_PASSWORD"
set_text_secret APP_STORE_CONNECT_KEY_ID "$APP_STORE_CONNECT_KEY_ID"
set_text_secret APP_STORE_CONNECT_ISSUER_ID "$APP_STORE_CONNECT_ISSUER_ID"
set_file_secret IOS_DISTRIBUTION_CERTIFICATE_BASE64 "$IOS_DISTRIBUTION_CERTIFICATE_FILE"
set_file_secret IOS_FIREBASE_PROVISIONING_PROFILE_BASE64 "$IOS_FIREBASE_PROVISIONING_PROFILE_FILE"
set_file_secret IOS_FIREBASE_EXPORT_OPTIONS_PLIST_BASE64 "$IOS_FIREBASE_EXPORT_OPTIONS_PLIST_FILE"
set_file_secret IOS_TESTFLIGHT_PROVISIONING_PROFILE_BASE64 "$IOS_TESTFLIGHT_PROVISIONING_PROFILE_FILE"
set_file_secret IOS_TESTFLIGHT_EXPORT_OPTIONS_PLIST_BASE64 "$IOS_TESTFLIGHT_EXPORT_OPTIONS_PLIST_FILE"
set_file_secret APP_STORE_CONNECT_PRIVATE_KEY_BASE64 "$APP_STORE_CONNECT_PRIVATE_KEY_FILE"

echo "Configured and validated iOS distribution secrets in ${repo}/${environment}."
