#!/usr/bin/env bash
# Symlink the tracked hooks into .git/hooks. Idempotent; re-run after a fresh clone.
#
# A symlink rather than a copy, so edits to the tracked script take effect without reinstalling
# and the hook cannot silently drift from what is in the repo.
set -euo pipefail

REPO="$(git rev-parse --show-toplevel)"
SRC="$REPO/Testing/hooks"
DST="$REPO/.git/hooks"

mkdir -p "$DST"
for hook in pre-push; do
  [[ -f "$SRC/$hook" ]] || continue
  if [[ -e "$DST/$hook" && ! -L "$DST/$hook" ]]; then
    echo "install.sh: $DST/$hook exists and is not a symlink -- leaving it alone" >&2
    continue
  fi
  chmod +x "$SRC/$hook"
  ln -sfn "../../Testing/hooks/$hook" "$DST/$hook"
  echo "installed: .git/hooks/$hook -> Testing/hooks/$hook"
done
