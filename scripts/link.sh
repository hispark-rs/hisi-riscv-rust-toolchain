#!/usr/bin/env bash
# Register the freshly built sysroot as a rustup custom toolchain named "hisi-riscv".
# Ensures cargo is present in the sysroot bin. Usage: scripts/link.sh <rust-checkout> [name]
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
RUST="${1:?usage: link.sh <rust-checkout> [toolchain-name]}"
NAME="${2:-hisi-riscv}"
. "$HERE/scripts/host-triple.sh"
HOST="$(detect_host_triple)"
SYSROOT="$RUST/build/$HOST/stage2"

[ -x "$SYSROOT/bin/rustc" ] || { echo "ERROR: $SYSROOT/bin/rustc missing — build first"; exit 1; }

# x.py places the extended tools under stage2-tools-bin; make sure each is in the
# sysroot bin so the linked toolchain has cargo/rustfmt/clippy.
for tool in cargo rustfmt cargo-clippy clippy-driver cargo-fmt rustdoc; do
  if [ ! -x "$SYSROOT/bin/$tool" ]; then
    SRC="$(find "$RUST/build" -path "*stage2-tools-bin/$tool" -type f 2>/dev/null | head -1)"
    [ -n "$SRC" ] && cp "$SRC" "$SYSROOT/bin/$tool" && echo "copied $tool into sysroot bin"
  fi
done

rustup toolchain uninstall "$NAME" >/dev/null 2>&1 || true
rustup toolchain link "$NAME" "$SYSROOT"
echo "linked toolchain '$NAME' -> $SYSROOT"
echo "try: cargo +$NAME build --target riscv32imfc-unknown-none-elf   (NO -Z build-std needed)"
