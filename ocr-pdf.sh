#!/usr/bin/env bash
# OCR a PDF via ocrmypdf so pgpdf can read its (now-embedded) text layer.
# Bootstraps uv into ./bin/uv on first run and invokes ocrmypdf through it,
# so no system Python / pip / venv to manage.
#
# Usage:   ./ocr-pdf.sh INPUT.pdf [OUTPUT.pdf]
# Env:     OCR_LANG=eng                 # tesseract language(s), e.g. dan+eng
#          OCR_EXTRA_ARGS=""            # extra flags passed to ocrmypdf
#
# Default output is INPUT.ocr.pdf next to INPUT. Default behavior is
# --force-ocr (rasterize + OCR every page); override via OCR_EXTRA_ARGS if
# you want --skip-text or --redo-ocr instead.
set -euo pipefail
cd "$(dirname "$0")"

PDF="${1:-}"
if [[ -z "$PDF" || ! -f "$PDF" ]]; then
  echo "usage: $0 INPUT.pdf [OUTPUT.pdf]" >&2
  exit 2
fi
PDF=$(readlink -f "$PDF")
OUT="${2:-${PDF%.pdf}.ocr.pdf}"

# --- Bootstrap a local ./bin/uv if not present ---------------------------
BIN_DIR="$PWD/bin"
UV="$BIN_DIR/uv"
if [[ ! -x "$UV" ]]; then
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)  ARCH=x86_64-unknown-linux-gnu ;;
    Linux-aarch64|Linux-arm64) ARCH=aarch64-unknown-linux-gnu ;;
    *) echo "Unsupported host $(uname -s)-$(uname -m); install uv manually" >&2
       exit 1 ;;
  esac
  mkdir -p "$BIN_DIR"
  echo "Downloading uv..." >&2
  curl -fsSL "https://github.com/astral-sh/uv/releases/latest/download/uv-${ARCH}.tar.gz" \
    | tar -xz --strip-components=1 -C "$BIN_DIR" "uv-${ARCH}/uv"
  chmod +x "$UV"
fi

# --- Run ocrmypdf via uv (caches the env after first invocation) ---------
LANG_ARG="${OCR_LANG:-eng}"
DEFAULT_FLAGS=(--force-ocr)
EXTRA=()
# shellcheck disable=SC2206
[[ -n "${OCR_EXTRA_ARGS:-}" ]] && EXTRA=( ${OCR_EXTRA_ARGS} )

echo "OCR'ing $PDF -> $OUT  (lang=$LANG_ARG)"
"$UV" tool run --from ocrmypdf ocrmypdf \
  "${DEFAULT_FLAGS[@]}" --language "$LANG_ARG" \
  "${EXTRA[@]}" \
  "$PDF" "$OUT"

echo "Wrote: $OUT"
echo
echo "Next: ./run-pdf.sh ${OUT/#$PWD\//}"
