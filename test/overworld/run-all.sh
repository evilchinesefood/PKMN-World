#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
ROM="$REPO/pokemonworld.gba"
if [[ $# -gt 0 && "$1" != --* ]]; then ROM="$1"; shift; fi
PROFILE=full
OUT="${PW_OUT:-$REPO/_pwtest}"
ELF="${PW_ELF:-${ROM%.gba}.elf}"
SYMBOLS="${PW_SYMBOLS:-}"
BUNDLE=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --elf) ELF="$2"; shift 2 ;;
    --symbols) SYMBOLS="$2"; shift 2 ;;
    --bundle) BUNDLE="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
RUN="$(mktemp -d "$OUT/sweep-$PROFILE.XXXXXX")"
echo "sweep-dir: $RUN"
python3 "$HERE/NativeRunner.py" inventory --profile "$PROFILE" --out "$RUN" > "$RUN/selected.tsv"
if [[ -z "$BUNDLE" ]]; then
  BUNDLE="$RUN/bundle"
  args=(--rom "$ROM" --elf "$ELF" --out "$BUNDLE")
  [[ -z "$SYMBOLS" ]] || args+=(--symbols "$SYMBOLS")
  python3 "$HERE/NativeRunner.py" bundle "${args[@]}"
fi
failed=0
passed=0
selected=0
while IFS=$'\t' read -r name suite fixture; do
  selected=$((selected + 1))
  args=("$suite" "$ROM")
  [[ "$fixture" == - ]] || args+=("$fixture")
  if "$HERE/mgba-run.sh" "${args[@]}" --bundle "$BUNDLE" --out "$RUN" --case-name "$name" > "$RUN/$name.log" 2>&1; then
    passed=$((passed + 1))
    echo "PASS $name"
  else
    failed=$((failed + 1))
    echo "FAIL $name (see $RUN/$name.log)"
    tail -8 "$RUN/$name.log"
  fi
done < "$RUN/selected.tsv"
excluded="$(python3 "$HERE/NativeRunner.py" inventory --profile "$PROFILE" --out "$RUN" --excluded)"
printf 'selected=%s passed=%s failed=%s excluded=%s,complete-campaigns,natural-team\n' "$selected" "$passed" "$failed" "$excluded" | tee "$RUN/summary.txt"
[[ "$selected" -gt 0 && "$failed" -eq 0 ]]
