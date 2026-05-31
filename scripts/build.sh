#!/usr/bin/env bash
# Build the patched rustc + cargo + core/alloc for the WS63 target.
# Usage: scripts/build.sh <rust-checkout> [jobs]
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
RUST="${1:?usage: build.sh <rust-checkout> [jobs]}"
JOBS="${2:-$(nproc)}"

cp "$HERE/config.toml" "$RUST/config.toml"
echo "Building rustc (stage 2) + cargo + library for host + riscv32imfc, jobs=$JOBS"
cd "$RUST"
# The stage0 (beta) bootstrap compiler doesn't know our newly-added target yet, so its
# pre-build target sanity check fails. Our patched in-tree compiler WILL know it once
# built, so skipping the check is correct here.
export BOOTSTRAP_SKIP_TARGET_SANITY=1
# Stage-2 compiler + std/core for the listed targets, plus cargo.
python3 x.py build --stage 2 -j "$JOBS" \
  compiler/rustc library/std \
  --target x86_64-unknown-linux-gnu,riscv32imfc-unknown-none-elf
python3 x.py build --stage 2 -j "$JOBS" cargo rustfmt clippy

# Bundle llvm-tools (rust-objcopy/objdump/size/nm/strip) into the sysroot's rustlib
# bin so `rust-objcopy` etc. work with this toolchain (used by ws63-rs release packaging).
SYS="$RUST/build/x86_64-unknown-linux-gnu/stage2"
RLBIN="$SYS/lib/rustlib/x86_64-unknown-linux-gnu/bin"
mkdir -p "$RLBIN"
for t in objcopy objdump size nm strip; do
  src="$RUST/build/x86_64-unknown-linux-gnu/ci-llvm/bin/llvm-$t"
  [ -f "$src" ] && cp -f "$src" "$RLBIN/rust-$t" && echo "bundled rust-$t"
done
echo "build complete; sysroot: $SYS"
