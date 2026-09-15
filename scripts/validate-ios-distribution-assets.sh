#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: validate-ios-distribution-assets.sh \
  --bundle-id BUNDLE_ID \
  --team-id TEAM_ID \
  [--firebase-profile FILE --firebase-export-options FILE] \
  [--testflight-profile FILE --testflight-export-options FILE]

Validates Apple provisioning profiles and Export Options plists without printing
their contents. Run this on macOS because decoding .mobileprovision files uses
the Apple `security` command.
EOF
}

bundle_id=""
team_id=""
firebase_profile=""
firebase_export=""
testflight_profile=""
testflight_export=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --bundle-id) bundle_id="${2:-}"; shift 2 ;;
    --team-id) team_id="${2:-}"; shift 2 ;;
    --firebase-profile) firebase_profile="${2:-}"; shift 2 ;;
    --firebase-export-options) firebase_export="${2:-}"; shift 2 ;;
    --testflight-profile) testflight_profile="${2:-}"; shift 2 ;;
    --testflight-export-options) testflight_export="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "iOS signing asset validation must run on macOS." >&2
  exit 1
fi
if [ -z "$bundle_id" ] || [ -z "$team_id" ]; then
  echo "--bundle-id and --team-id are required." >&2
  exit 2
fi
if { [ -n "$firebase_profile" ] && [ -z "$firebase_export" ]; } ||
   { [ -z "$firebase_profile" ] && [ -n "$firebase_export" ]; }; then
  echo "Firebase profile and export options must be supplied together." >&2
  exit 2
fi
if { [ -n "$testflight_profile" ] && [ -z "$testflight_export" ]; } ||
   { [ -z "$testflight_profile" ] && [ -n "$testflight_export" ]; }; then
  echo "TestFlight profile and export options must be supplied together." >&2
  exit 2
fi
if [ -z "$firebase_profile" ] && [ -z "$testflight_profile" ]; then
  echo "At least one distribution destination must be supplied." >&2
  exit 2
fi

task_dir="$(mktemp -d)"
trap 'rm -rf "$task_dir"' EXIT

plist_value() {
  /usr/libexec/PlistBuddy -c "Print $2" "$1" 2>/dev/null
}

validate_profile() {
  local channel="$1"
  local profile="$2"
  local expected_kind="$3"
  local decoded="$task_dir/${channel}.plist"

  test -s "$profile" || { echo "$channel provisioning profile is missing or empty: $profile" >&2; exit 1; }
  security cms -D -i "$profile" > "$decoded"

  local name application_identifier profile_team expiration get_task_allow aps_environment
  name="$(plist_value "$decoded" ':Name')"
  application_identifier="$(plist_value "$decoded" ':Entitlements:application-identifier')"
  profile_team="$(plist_value "$decoded" ':TeamIdentifier:0')"
  expiration="$(plist_value "$decoded" ':ExpirationDate')"
  get_task_allow="$(plist_value "$decoded" ':Entitlements:get-task-allow' || true)"
  aps_environment="$(plist_value "$decoded" ':Entitlements:aps-environment' || true)"

  [ "$application_identifier" = "${team_id}.${bundle_id}" ] || {
    echo "$channel profile targets '$application_identifier'; expected '${team_id}.${bundle_id}'." >&2
    exit 1
  }
  [ "$profile_team" = "$team_id" ] || {
    echo "$channel profile belongs to team '$profile_team'; expected '$team_id'." >&2
    exit 1
  }
  ruby -r time -e 'abort "Provisioning profile has expired" unless Time.parse(ARGV.fetch(0)) > Time.now' "$expiration"
  [ "$get_task_allow" != "true" ] || {
    echo "$channel profile is a development profile; a distribution profile is required." >&2
    exit 1
  }
  [ "$aps_environment" = "production" ] || {
    echo "$channel profile must contain the production APNs entitlement." >&2
    exit 1
  }

  if [ "$expected_kind" = "ad-hoc" ]; then
    plist_value "$decoded" ':ProvisionedDevices:0' >/dev/null || {
      echo "$channel profile is not Ad Hoc or contains no registered tester devices." >&2
      exit 1
    }
  elif plist_value "$decoded" ':ProvisionedDevices:0' >/dev/null; then
    echo "$channel profile contains device UDIDs; an App Store Connect profile is required." >&2
    exit 1
  fi

  printf '%s' "$name"
}

validate_export_options() {
  local channel="$1"
  local plist="$2"
  local expected_method="$3"
  local profile_name="$4"

  test -s "$plist" || { echo "$channel Export Options plist is missing or empty: $plist" >&2; exit 1; }
  plutil -lint "$plist" >/dev/null

  local method export_team signing_style mapped_profile
  method="$(plist_value "$plist" ':method')"
  export_team="$(plist_value "$plist" ':teamID')"
  signing_style="$(plist_value "$plist" ':signingStyle')"
  mapped_profile="$(plist_value "$plist" ":provisioningProfiles:${bundle_id}")"

  if [ "$expected_method" = "app-store-connect" ]; then
    [ "$method" = "app-store-connect" ] || [ "$method" = "app-store" ] || {
      echo "$channel export method is '$method'; expected 'app-store-connect'." >&2
      exit 1
    }
  elif [ "$method" != "$expected_method" ]; then
    echo "$channel export method is '$method'; expected '$expected_method'." >&2
    exit 1
  fi
  [ "$export_team" = "$team_id" ] || {
    echo "$channel Export Options uses team '$export_team'; expected '$team_id'." >&2
    exit 1
  }
  [ "$signing_style" = "manual" ] || {
    echo "$channel Export Options must use manual signing." >&2
    exit 1
  }
  [ "$mapped_profile" = "$profile_name" ] || {
    echo "$channel Export Options maps '$bundle_id' to '$mapped_profile'; expected '$profile_name'." >&2
    exit 1
  }
}

if [ -n "$firebase_profile" ]; then
  firebase_name="$(validate_profile Firebase "$firebase_profile" ad-hoc)"
  validate_export_options Firebase "$firebase_export" ad-hoc "$firebase_name"
  echo "Firebase iOS signing assets are valid for ${bundle_id}."
fi

if [ -n "$testflight_profile" ]; then
  testflight_name="$(validate_profile TestFlight "$testflight_profile" app-store-connect)"
  validate_export_options TestFlight "$testflight_export" app-store-connect "$testflight_name"
  echo "TestFlight signing assets are valid for ${bundle_id}."
fi
