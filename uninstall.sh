#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-${HOME}/.local/bin}"
DEST="$TARGET_DIR/img-to-svg"
# Leave another clone's install and every other command alone.
if [[ -L "$DEST" && "$(readlink "$DEST")" == "$ROOT/img-to-svg" ]]; then
  rm "$DEST"
  echo "Removed $DEST"
fi
