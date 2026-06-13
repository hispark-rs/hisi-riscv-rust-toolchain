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
# Chip-neutral artifact prefix `hisi-riscv-rust` (matches the repo + the rustup
# channel `hisi-riscv` that downstream `rust-toolchain.toml` link against). One
# tarball per host triple.
TAR="$OUT/hisi-riscv-rust-${VER}-${HOST}.tar.gz"
# On Windows/git-bash, GNU tar reads the `D:/...` drive-letter path as a remote
# host ("Cannot connect to D:") — --force-local makes it treat `:` as a local
# filename. (Not a valid flag on macOS bsdtar, so gate it to Windows.)
TARFLAGS=""; case "$HOST" in *windows*) TARFLAGS="--force-local";; esac
tar $TARFLAGS -C "$(dirname "$SYSROOT")" -czf "$TAR" "$(basename "$SYSROOT")"
( cd "$OUT" && sha256 "$(basename "$TAR")" )
echo "packaged: $TAR"
ls -la "$OUT"
