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

# Under GITHUB_ACTIONS, rust bootstrap walks git history (`git rev-parse HEAD^1`,
# path-modification checks) which fails on our shallow (--depth 1) clone. Neutralize
# the CI detection so it uses the local-build path (proven to work shallow). This only
# affects how bootstrap perceives itself; download-ci-llvm still works.
unset GITHUB_ACTIONS TF_BUILD CI
# Stage-2 compiler + std/core for the listed targets, plus cargo.
# Build EVERYTHING in a single invocation. Separate `x.py build` calls each wipe and
# repopulate the stage2 sysroot ("Removing sysroot to avoid caching bugs"), so a later
# tools-only call would drop the riscv32imfc std. One invocation keeps host+riscv std
# AND the tools in the final sysroot.
# `rust-analyzer-proc-macro-srv` is built in this SAME invocation (it lands in
# <sysroot>/libexec/) so rust-analyzer can expand proc-macros (ws63-rt's `#[entry]`)
# against this rustc — a separate call would wipe the sysroot and drop the std.
python3 x.py build --stage 2 -j "$JOBS" \
  compiler/rustc library/std cargo rustfmt clippy rustdoc \
  src/tools/rust-analyzer/crates/proc-macro-srv-cli \
  --target x86_64-unknown-linux-gnu,riscv32imfc-unknown-none-elf

SYS="$RUST/build/x86_64-unknown-linux-gnu/stage2"

# Install cargo into the linked toolchain's bin/. x.py builds cargo into
# stage2-tools-bin but only hard-links it into the stage2 sysroot bin/ on a clean
# build — incremental runs skip that step, leaving the rustup-linked `ws63`
# toolchain without `cargo` (so `cargo +ws63` silently falls back to the default).
# Copy it explicitly. (rustc/rustfmt/clippy/rustdoc are placed in bin/ by x.py.)
CARGO_SRC="$RUST/build/x86_64-unknown-linux-gnu/stage2-tools-bin/cargo"
[ -f "$CARGO_SRC" ] && cp -f "$CARGO_SRC" "$SYS/bin/cargo" && echo "installed cargo into $SYS/bin"

# Bundle llvm-tools (rust-objcopy/objdump/size/nm/strip) into the sysroot's rustlib
# bin so `rust-objcopy` etc. work with this toolchain (used by ws63-rs release packaging).
RLBIN="$SYS/lib/rustlib/x86_64-unknown-linux-gnu/bin"
mkdir -p "$RLBIN"
for t in objcopy objdump size nm strip; do
  src="$RUST/build/x86_64-unknown-linux-gnu/ci-llvm/bin/llvm-$t"
  [ -f "$src" ] && cp -f "$src" "$RLBIN/rust-$t" && echo "bundled rust-$t"
done
echo "build complete; sysroot: $SYS"
