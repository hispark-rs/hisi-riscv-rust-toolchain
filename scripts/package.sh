#!/usr/bin/env bash
# Package the built sysroot into a relocatable tarball for distribution
# (download + `rustup toolchain link`). Usage: scripts/package.sh <rust-checkout> [out-dir]
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
RUST="${1:?usage: package.sh <rust-checkout> [out-dir]}"
OUT="${2:-$PWD/dist}"
VER="$(tr -d '[:space:]' < "$HERE/rust-version.txt")"
SYSROOT="$RUST/build/x86_64-unknown-linux-gnu/stage2"

[ -x "$SYSROOT/bin/rustc" ] || { echo "ERROR: $SYSROOT/bin/rustc missing — build first"; exit 1; }
# ensure cargo present
if [ ! -x "$SYSROOT/bin/cargo" ]; then
  CARGO="$(find "$RUST/build" -path '*stage2-tools-bin/cargo' -type f 2>/dev/null | head -1)"
  [ -n "$CARGO" ] && cp "$CARGO" "$SYSROOT/bin/cargo"
fi

mkdir -p "$OUT"
TAR="$OUT/ws63-rust-${VER}-x86_64-unknown-linux-gnu.tar.gz"
tar -C "$(dirname "$SYSROOT")" -czf "$TAR" "$(basename "$SYSROOT")"
( cd "$OUT" && sha256sum "$(basename "$TAR")" > "$(basename "$TAR").sha256" )
echo "packaged: $TAR"
ls -la "$OUT"
