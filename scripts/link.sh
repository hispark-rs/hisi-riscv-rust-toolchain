#!/usr/bin/env bash
# Register the freshly built sysroot as a rustup custom toolchain named "ws63".
# Ensures cargo is present in the sysroot bin. Usage: scripts/link.sh <rust-checkout> [name]
set -euo pipefail
RUST="${1:?usage: link.sh <rust-checkout> [toolchain-name]}"
NAME="${2:-ws63}"
SYSROOT="$RUST/build/x86_64-unknown-linux-gnu/stage2"

[ -x "$SYSROOT/bin/rustc" ] || { echo "ERROR: $SYSROOT/bin/rustc missing — build first"; exit 1; }

# x.py may place cargo under stage2-tools-bin; make sure it's in the sysroot bin.
if [ ! -x "$SYSROOT/bin/cargo" ]; then
  CARGO="$(find "$RUST/build" -path '*stage2-tools-bin/cargo' -type f 2>/dev/null | head -1)"
  [ -n "$CARGO" ] && cp "$CARGO" "$SYSROOT/bin/cargo" && echo "copied cargo into sysroot bin"
fi

rustup toolchain uninstall "$NAME" >/dev/null 2>&1 || true
rustup toolchain link "$NAME" "$SYSROOT"
echo "linked toolchain '$NAME' -> $SYSROOT"
echo "try: cargo +$NAME build --target riscv32imfc-unknown-none-elf   (NO -Z build-std needed)"
