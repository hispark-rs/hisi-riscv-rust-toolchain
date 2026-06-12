#!/usr/bin/env bash
# Build the patched rustc + cargo + core/alloc for the riscv32imfc target, for the
# current host (auto-detected, or $HOST from the CI matrix).
# Usage: scripts/build.sh <rust-checkout> [jobs]
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
RUST="${1:?usage: build.sh <rust-checkout> [jobs]}"
JOBS="${2:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
. "$HERE/scripts/host-triple.sh"
HOST="$(detect_host_triple)"
EXE=""; case "$HOST" in *windows*) EXE=".exe";; esac

cp "$HERE/config.toml" "$RUST/config.toml"
echo "Building rustc (stage 2) + cargo + library for $HOST + riscv32imfc, jobs=$JOBS"
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
# Stage-2 compiler + std/core for host + riscv32imfc, plus cargo, in ONE invocation
# (separate `x.py build` calls each wipe + repopulate the stage2 sysroot, dropping the
# riscv32imfc std). `rust-analyzer-proc-macro-srv` is built here too (lands in
# <sysroot>/libexec/) so rust-analyzer can expand proc-macros against this rustc.
python3 x.py build --stage 2 -j "$JOBS" \
  compiler/rustc library/std cargo rustfmt clippy rustdoc \
  src/tools/rust-analyzer/crates/proc-macro-srv-cli \
  --target "$HOST,riscv32imfc-unknown-none-elf"

SYS="$RUST/build/$HOST/stage2"

# Install cargo into the linked toolchain's bin/. x.py hard-links cargo into the
# stage2 sysroot bin/ only on a clean build — incremental runs skip it, leaving the
# linked toolchain without `cargo`. Copy it explicitly.
CARGO_SRC="$RUST/build/$HOST/stage2-tools-bin/cargo$EXE"
[ -f "$CARGO_SRC" ] && cp -f "$CARGO_SRC" "$SYS/bin/cargo$EXE" && echo "installed cargo into $SYS/bin"

# Install the rust-gdb / rust-lldb debug wrappers + the GDB/LLDB pretty-printer
# scripts (x.py copies these only on install/dist). Unix-only: they are POSIX shell
# wrappers; on Windows the printers ship but the wrappers are skipped.
case "$HOST" in
  *windows*) : ;;  # no rust-gdb/lldb wrappers on Windows
  *)
    for w in rust-gdb rust-gdbgui rust-lldb; do
      if [ -f "$RUST/src/etc/$w" ]; then
        cp -f "$RUST/src/etc/$w" "$SYS/bin/$w" && chmod 0755 "$SYS/bin/$w"
      fi
    done
    echo "installed rust-gdb/rust-lldb wrappers"
    ;;
esac
mkdir -p "$SYS/lib/rustlib/etc"
for f in gdb_load_rust_pretty_printers.py gdb_lookup.py gdb_providers.py \
         lldb_commands lldb_lookup.py lldb_providers.py rust_types.py; do
  [ -f "$RUST/src/etc/$f" ] && cp -f "$RUST/src/etc/$f" "$SYS/lib/rustlib/etc/"
done

# Bundle llvm-tools (rust-objcopy/objdump/size/nm/strip) into the sysroot's rustlib
# bin so `rust-objcopy` etc. work with this toolchain (used by ws63-rs release packaging).
RLBIN="$SYS/lib/rustlib/$HOST/bin"
mkdir -p "$RLBIN"
for t in objcopy objdump size nm strip; do
  src="$RUST/build/$HOST/ci-llvm/bin/llvm-$t$EXE"
  [ -f "$src" ] && cp -f "$src" "$RLBIN/rust-$t$EXE" && echo "bundled rust-$t$EXE"
done
echo "build complete; sysroot: $SYS"
