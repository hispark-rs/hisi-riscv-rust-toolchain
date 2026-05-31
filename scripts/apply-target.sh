#!/usr/bin/env bash
# Inject the WS63 builtin target into a rust-lang/rust checkout:
#   1. copy targets/riscv32imfc-unknown-none-elf.rs into the spec targets dir
#   2. register it in the supported_targets! macro in spec/mod.rs
# Idempotent. Usage: scripts/apply-target.sh <rust-checkout>
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
RUST="${1:?usage: apply-target.sh <rust-checkout>}"

SPEC_DIR="$RUST/compiler/rustc_target/src/spec"
TARGETS_DIR="$SPEC_DIR/targets"
MODRS="$SPEC_DIR/mod.rs"
NAME="riscv32imfc-unknown-none-elf"
MOD="riscv32imfc_unknown_none_elf"

[ -d "$TARGETS_DIR" ] || { echo "ERROR: $TARGETS_DIR not found (rust layout changed?)"; exit 1; }
grep -q 'supported_targets!' "$MODRS" || { echo "ERROR: supported_targets! not in $MODRS"; exit 1; }

# 1. target module
cp "$HERE/targets/$NAME.rs" "$TARGETS_DIR/$MOD.rs"
echo "copied $MOD.rs"

# 2. register in supported_targets! (insert next to the riscv32imc line, once)
if grep -q "\"$NAME\"" "$MODRS"; then
  echo "already registered in mod.rs"
else
  python3 - "$MODRS" "$NAME" "$MOD" <<'PY'
import sys, re
modrs, name, mod = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(modrs).read()
anchor = '("riscv32imc-unknown-none-elf", riscv32imc_unknown_none_elf),'
line = f'    ("{name}", {mod}),\n'
assert anchor in s, "anchor riscv32imc entry not found in supported_targets!"
# insert our entry right after the riscv32imc entry, preserving its indentation
idx = s.index(anchor) + len(anchor)
# move to end of that line
nl = s.index("\n", idx) + 1
s = s[:nl] + line + s[nl:]
open(modrs, "w").write(s)
print("registered", name, "in supported_targets!")
PY
fi

echo "verifying registration:"; grep -n "$NAME" "$MODRS" || true
