#!/usr/bin/env bash
# Install only this repo's launcher. Re-run after moving the clone.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.local/bin"
SKIP_DEPS=0
for arg in "$@"; do
  case "$arg" in
    --skip-deps) SKIP_DEPS=1 ;;
    -h|--help) echo 'Usage: bash install.sh [target_bin_dir] [--skip-deps]'; exit 0 ;;
    -*) echo "Unknown option: $arg" >&2; exit 1 ;;
    *) TARGET_DIR="$arg" ;;
  esac
done
if [[ "$SKIP_DEPS" -eq 0 ]]; then
  if [[ ! -x "$ROOT/.venv/bin/python3" ]]; then
    python3 -m venv "$ROOT/.venv"
  fi
  "$ROOT/.venv/bin/python3" -m pip install -r "$ROOT/requirements.txt"
fi
mkdir -p "$TARGET_DIR"
if [[ -e "$TARGET_DIR/img-to-svg" && ! -L "$TARGET_DIR/img-to-svg" ]]; then
  echo "Refusing to replace an existing file: $TARGET_DIR/img-to-svg" >&2
  exit 1
fi
chmod +x "$ROOT/img-to-svg"
ln -sfn "$ROOT/img-to-svg" "$TARGET_DIR/img-to-svg"
echo "Installed $TARGET_DIR/img-to-svg -> $ROOT/img-to-svg"
case ":$PATH:" in
  *":$TARGET_DIR:"*) ;;
  *) echo "Add to ~/.zshrc or ~/.bashrc: export PATH=\"$TARGET_DIR:\$PATH\"" ;;
esac
