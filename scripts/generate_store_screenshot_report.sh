#!/usr/bin/env bash
set -euo pipefail

RAW_DIR="$1"
OUT_DIR="$2"
FAMILY="${3:-mac}"
mkdir -p "$OUT_DIR"

declare -a required=(
  "01-overview.png"
  "02-rules.png"
  "03-risk-yellow.png"
  "04-risk-red.png"
  "05-permissions.png"
)

log_info() {
  echo "[report] $1"
}

dimension_for() {
  local path="$1"
  local what="$2"
  sips -g "${what}" "$path" 2>/dev/null | awk -F': ' '/'"${what}"'/ {print $2; exit}'
}

validate_minimum() {
  local name="$1"
  local width="$2"
  local height="$3"
  local family="$4"

  case "$family" in
    mac)
      if (( width < 1024 || height < 768 )); then
        echo "Screenshot too small for mac preview: $name (${width}x${height})"
        return 1
      fi
      ;;
    *)
      if (( width < 700 || height < 420 )); then
        echo "Screenshot too small for $family preview: $name (${width}x${height})"
        return 1
      fi
      ;;
  esac
  return 0
}

validate_ratio() {
  local name="$1"
  local width="$2"
  local height="$3"
  python3 - "$width" "$height" "$name" <<'PY'
import sys

width = int(sys.argv[1])
height = int(sys.argv[2])
name = sys.argv[3]
ratio = width / height
if not (1.2 <= ratio <= 1.9):
    raise SystemExit(f"Screenshot aspect ratio outside expected bounds for {name}: {ratio:.3f} ({width}x{height})")
PY
}

missing=0
for name in "${required[@]}"; do
  src="$RAW_DIR/$name"
  if [[ ! -f "$src" ]]; then
    echo "Missing required screenshot: $name"
    missing=1
    continue
  fi

  if [[ ! -s "$src" ]]; then
    echo "Empty screenshot file: $name"
    missing=1
    continue
  fi

  width=$(dimension_for "$src" pixelWidth)
  height=$(dimension_for "$src" pixelHeight)
  if [[ -z "$width" || -z "$height" ]]; then
    echo "Unable to read dimensions for: $name"
    missing=1
    continue
  fi

  if ! validate_minimum "$name" "$width" "$height" "$FAMILY"; then
    missing=1
    continue
  fi

  validate_ratio "$name" "$width" "$height"

  cp "$src" "$OUT_DIR/$name"
  log_info "accepted $name (${width}x${height})"
done

if (( missing != 0 )); then
    echo "Screenshot capture incomplete."
    exit 1
  fi

echo "Screenshot report complete."
