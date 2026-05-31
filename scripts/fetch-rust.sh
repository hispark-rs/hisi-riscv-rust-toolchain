#!/usr/bin/env bash
# Shallow-clone the rust-lang/rust source at the pinned stable tag.
# Usage: scripts/fetch-rust.sh [dest-dir]   (default: ./rust)
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
VER="$(tr -d '[:space:]' < "$HERE/rust-version.txt")"
DEST="${1:-$PWD/rust}"

if [ -d "$DEST/.git" ]; then
  echo "rust source already present at $DEST"
else
  echo "Cloning rust-lang/rust @ $VER -> $DEST (shallow)"
  git clone --depth 1 --branch "$VER" https://github.com/rust-lang/rust.git "$DEST"
fi
echo "rust source ready: $DEST ($VER)"
