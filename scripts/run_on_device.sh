#!/usr/bin/env bash
# Build and install a debug APK on a physical Android device for testing
# against the real backend over LAN, including Google Sign-In.
#
# GOOGLE_WEB_CLIENT_ID must be baked in at build time -- lib/core/constants/
# google_config.dart defaults it to '' otherwise, which makes Google Sign-In
# silently fail the token exchange after the account picker (see the SHA-1
# fingerprint note in CLAUDE.md for the other half of Google Sign-In setup).
#
# Usage: ./scripts/run_on_device.sh <your-machine-LAN-IP> [device-id]
#   e.g. ./scripts/run_on_device.sh 192.168.1.6

set -euo pipefail

LAN_IP="${1:?Usage: run_on_device.sh <your-machine-LAN-IP> [device-id]}"
DEVICE_ID="${2:-}"

GOOGLE_WEB_CLIENT_ID="1096554919306-ruvmrqabi8ergq2tado24fh37dscfd81.apps.googleusercontent.com"

flutter build apk --debug \
  --dart-define=API_BASE_URL="http://${LAN_IP}:8000/v1" \
  --dart-define=GOOGLE_WEB_CLIENT_ID="${GOOGLE_WEB_CLIENT_ID}"

if [ -n "$DEVICE_ID" ]; then
  flutter install --debug -d "$DEVICE_ID"
else
  flutter install --debug
fi
