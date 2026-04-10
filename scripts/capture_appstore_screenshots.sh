#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW_DIR="${1:-$ROOT_DIR/artifacts/screenshots/raw}"
OUT_DIR="${2:-$ROOT_DIR/artifacts/screenshots/en-US}"

cd "$ROOT_DIR"

echo "Capturing App Store screenshots into $RAW_DIR"
if command -v bundle >/dev/null 2>&1; then
  bundle exec fastlane take_appstore_screenshots
else
  fastlane take_appstore_screenshots
fi

if [[ ! -d "$OUT_DIR" ]]; then
  echo "Output directory missing: $OUT_DIR"
  exit 1
fi

echo "Available screenshots:"
find "$OUT_DIR" -maxdepth 1 -type f -name "*.png" -exec basename {} \; | sort
