#!/usr/bin/env bash
# Package the built sysroot into a relocatable tarball for distribution
# (download + `rustup toolchain link`). Host-aware: names the tarball after the
# build host triple (auto-detected, or $HOST from the CI matrix).
# Usage: scripts/package.sh <rust-checkout> [out-dir]
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
RUST="${1:?usage: package.sh <rust-checkout> [out-dir]}"
OUT="${2:-$PWD/dist}"
VER="$(tr -d '[:space:]' < "$HERE/rust-version.txt")"
. "$HERE/scripts/host-triple.sh"
HOST="$(detect_host_triple)"
EXE=""; case "$HOST" in *windows*) EXE=".exe";; esac
SYSROOT="$RUST/build/$HOST/stage2"

[ -x "$SYSROOT/bin/rustc$EXE" ] || { echo "ERROR: $SYSROOT/bin/rustc$EXE missing — build first"; exit 1; }
# ensure cargo present
if [ ! -x "$SYSROOT/bin/cargo$EXE" ]; then
  CARGO="$(find "$RUST/build" -path "*stage2-tools-bin/cargo$EXE" -type f 2>/dev/null | head -1)"
  [ -n "$CARGO" ] && cp "$CARGO" "$SYSROOT/bin/cargo$EXE"
fi

# Portable sha256 (sha256sum on Linux/Git-bash, shasum -a 256 on macOS).
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" > "$1.sha256"
  else shasum -a 256 "$1" > "$1.sha256"; fi
}

mkdir -p "$OUT"
# Keep the `ws63-rust` artifact prefix: the rustup channel/identity stays `ws63`
# (downstream `rustup toolchain link ws63` + every rust-toolchain.toml), even though
# the repo is now chip-neutral (hisi-riscv-rust-toolchain).
TAR="$OUT/ws63-rust-${VER}-${HOST}.tar.gz"
tar -C "$(dirname "$SYSROOT")" -czf "$TAR" "$(basename "$SYSROOT")"
( cd "$OUT" && sha256 "$(basename "$TAR")" )
echo "packaged: $TAR"
ls -la "$OUT"
