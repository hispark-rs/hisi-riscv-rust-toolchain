#!/usr/bin/env bash
# End-to-end: fetch rust source, inject the WS63 target, build, link, (optionally) package.
# Usage: scripts/build-all.sh [rust-checkout] [jobs]
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
RUST="${1:-$PWD/rust}"
JOBS="${2:-$(nproc)}"

"$HERE/scripts/fetch-rust.sh" "$RUST"
"$HERE/scripts/apply-target.sh" "$RUST"
"$HERE/scripts/build.sh" "$RUST" "$JOBS"
"$HERE/scripts/link.sh" "$RUST" ws63
echo
echo "Done. Validate with:"
echo "  cargo +ws63 build --target riscv32imfc-unknown-none-elf  # in a no_std crate"
