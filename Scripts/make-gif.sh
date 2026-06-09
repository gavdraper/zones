#!/usr/bin/env bash
#
# make-gif.sh — convert a screen recording into an optimized README GIF.
#
# Pipeline: ffmpeg decodes/crops/scales the recording into PNG frames, then
# gifski encodes them into a high-quality, well-compressed GIF (per-frame
# palettes). Designed for the "Cmd+Shift+5" recordings macOS produces (.mov).
#
# Usage:
#   ./Scripts/make-gif.sh <input.mov> [output.gif]
#
# Environment overrides (all optional):
#   FPS=20            output frame rate
#   WIDTH=1200        output width in px (height auto, aspect preserved)
#   QUALITY=90        gifski quality, 1-100
#   CROP=             ffmpeg crop filter, e.g. "in_w-200:in_h-100:100:50"
#                     (w:h:x:y) — handy to trim menu bars / chrome
#   START=            trim: start offset, e.g. 1.5 (seconds)
#   DURATION=         trim: length to keep, e.g. 10 (seconds)
#
# Examples:
#   ./Scripts/make-gif.sh ~/Desktop/demo.mov
#   WIDTH=900 FPS=24 ./Scripts/make-gif.sh demo.mov docs/demo.gif
#   START=2 DURATION=8 ./Scripts/make-gif.sh demo.mov

set -euo pipefail

readonly INPUT="${1:-}"
readonly OUTPUT="${2:-docs/demo.gif}"

readonly FPS="${FPS:-20}"
readonly WIDTH="${WIDTH:-1200}"
readonly QUALITY="${QUALITY:-90}"
readonly CROP="${CROP:-}"
readonly START="${START:-}"
readonly DURATION="${DURATION:-}"

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

[[ -n "$INPUT" ]]    || die "no input file. Usage: ./Scripts/make-gif.sh <input.mov> [output.gif]"
[[ -f "$INPUT" ]]    || die "input not found: $INPUT"
command -v ffmpeg >/dev/null || die "ffmpeg not installed (brew install ffmpeg)"
command -v gifski >/dev/null || die "gifski not installed (brew install gifski)"

# Resolve repo root so relative output paths land predictably.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
case "$OUTPUT" in
  /*) OUT_PATH="$OUTPUT" ;;
  *)  OUT_PATH="$REPO_ROOT/$OUTPUT" ;;
esac
mkdir -p "$(dirname "$OUT_PATH")"

FRAME_DIR="$(mktemp -d)"
trap 'rm -rf "$FRAME_DIR"' EXIT

# Build the ffmpeg video filter chain: crop (optional) → fps → scale.
filter=""
[[ -n "$CROP" ]] && filter="crop=${CROP},"
filter+="fps=${FPS},scale=${WIDTH}:-2:flags=lanczos"

# Optional trim flags (input-side seeking for speed).
trim=()
[[ -n "$START" ]]    && trim+=(-ss "$START")
[[ -n "$DURATION" ]] && trim+=(-t "$DURATION")

printf '→ Extracting frames (fps=%s width=%s%s)…\n' \
  "$FPS" "$WIDTH" "${CROP:+ crop=$CROP}"
ffmpeg -hide_banner -loglevel error \
  "${trim[@]}" -i "$INPUT" \
  -vf "$filter" \
  "$FRAME_DIR/frame%05d.png"

frame_count=$(find "$FRAME_DIR" -name 'frame*.png' | wc -l | tr -d ' ')
[[ "$frame_count" -gt 0 ]] || die "ffmpeg produced no frames — check the input file"

printf '→ Encoding %s frames with gifski (quality=%s)…\n' "$frame_count" "$QUALITY"
gifski \
  --fps "$FPS" \
  --quality "$QUALITY" \
  -o "$OUT_PATH" \
  "$FRAME_DIR"/frame*.png

size=$(du -h "$OUT_PATH" | cut -f1 | tr -d ' ')
printf '✓ Wrote %s (%s)\n' "$OUTPUT" "$size"
