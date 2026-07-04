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
# Ensure extended tools are present in the packaged sysroot. CI packages the
# stage2 sysroot directly and does not run scripts/link.sh, so anything x.py left
# in stage2-tools-bin must be copied here before tarball creation.
for tool in cargo rust-analyzer; do
  if [ ! -x "$SYSROOT/bin/$tool$EXE" ]; then
    SRC="$(find "$RUST/build" -path "*stage2-tools-bin/$tool$EXE" -type f 2>/dev/null | head -1)"
    [ -n "$SRC" ] && cp "$SRC" "$SYSROOT/bin/$tool$EXE" && echo "copied $tool$EXE into sysroot bin"
  fi
done

# Portable sha256 (sha256sum on Linux/Git-bash, shasum -a 256 on macOS).
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" > "$1.sha256"
  else shasum -a 256 "$1" > "$1.sha256"; fi
}

# Materialize rust-src before packaging. x.py leaves the stage2 sysroot's
# `lib/rustlib/src/rust` as a SYMLINK to the build machine's rust checkout ($RUST,
# an absolute path like /home/runner/work/.../rust). tar stores that symlink
# verbatim, so it DANGLES on every downstream machine — rust-analyzer can then not
# load the core/std sources and floods the editor with false-positive diagnostics
# (unresolved `println!`, no `len` on `[u8; N]`, etc). Replace the symlink with the
# real, version-matched `library/` workspace + lockfile so the tarball is
# self-contained (mirrors what `rustup component add rust-src` ships).
SRC_DIR="$SYSROOT/lib/rustlib/src/rust"
if [ -L "$SRC_DIR" ] || [ ! -e "$SRC_DIR/library/std/src/lib.rs" ]; then
  echo "Materializing self-contained rust-src into $SRC_DIR"
  rm -rf "$SRC_DIR"
  mkdir -p "$SRC_DIR"
  cp -a "$RUST/library" "$SRC_DIR/library"
  [ -f "$RUST/Cargo.lock" ] && cp -a "$RUST/Cargo.lock" "$SRC_DIR/Cargo.lock"
fi

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
