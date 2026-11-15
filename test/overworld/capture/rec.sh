#!/usr/bin/env bash
# rec.sh <name> <scene.lua> [every]: record a scene's frames into $CAPTURE_OUT/runs/<name>/frames.
# The first run freezes pokemonworld.gba into $CAPTURE_OUT/bundle; delete it to capture a new build.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; REPO="$(cd "$HERE/../../.." && pwd)"
OUT="${CAPTURE_OUT:-$REPO/build/capture}"; RTC="${REC_RTC:-1704121200}"
name=$1; scene=$(cd "$(dirname "$2")" && pwd)/$(basename "$2"); every=${3:-2}
if [ ! -d "$OUT/bundle" ]; then
  mkdir -p "$OUT"
  python3 "$REPO/test/overworld/NativeRunner.py" bundle --rom "$REPO/pokemonworld.gba" --elf "$REPO/pokemonworld.elf" --out "$OUT/bundle" >/dev/null
fi
rm -rf "$OUT/runs/$name"; mkdir -p "$OUT/runs/$name/frames"
REC_TOOLS="$HERE" REC_SUITE="$scene" REC_DIR="$OUT/runs/$name/frames" REC_EVERY="$every" \
  python3 "$REPO/test/overworld/NativeRunner.py" run --bundle "$OUT/bundle" --out "$OUT/runs/$name/out" \
  --timeout 3000 --rtc "$RTC" "$HERE/Record.lua" "$OUT/bundle/pokemonworld.gba" 2>&1 | tail -4 || true
echo "frames: $(ls "$OUT/runs/$name/frames" | grep -c png)"
