# hisi-riscv-rust-toolchain

Official Rust nightly radar for the HiSilicon RISC-V application target
`riscv32imfc-unknown-none-elf` (RV32IMFC_Zicsr, hard-float `ilp32f`, no A
extension).

This repository no longer defines the default downstream toolchain. The
`hisi-riscv-rs` ecosystem now builds with an official upstream Rust nightly where
`rustc --print target-list` includes `riscv32imfc-unknown-none-elf`. Because
rustup does not yet ship a prebuilt `rust-std` component for that target,
downstream firmware builds use `rust-src` plus `-Zbuild-std=core,alloc`.

## Current role

This repo is the external CI / radar that watches the upstream path:

- latest nightly still contains `riscv32imfc-unknown-none-elf`;
- rustup target components start shipping, or remain absent as expected;
- `hisi-riscv-rs` can build representative firmware with
  `-Zbuild-std=core,alloc`;
- optional QEMU/HIL canaries keep target regressions visible;
- reports accumulate evidence for future Tier-2 readiness work.

Older custom rustc tarball releases are retained as historical artifacts only.
They are not the happy path for new projects, CI, or documentation.

## Local smoke

```bash
rustup update nightly
rustc +nightly --print target-list | grep -x riscv32imfc-unknown-none-elf

rustup target list --toolchain nightly | grep -x riscv32imfc-unknown-none-elf || \
  echo "rustup has no prebuilt rust-std yet; use -Zbuild-std=core,alloc"
```

To test the ecosystem canary locally:

```bash
git clone --recurse-submodules https://github.com/hispark-rs/hisi-riscv-rs
cd hisi-riscv-rs
rustup toolchain install nightly --profile minimal --component rust-src --component clippy --component rustfmt
cargo +nightly build -Zbuild-std=core,alloc -p blinky --release
cargo +nightly check -Zbuild-std=core,alloc -p hisi-riscv-rt --target riscv32imfc-unknown-none-elf
```

## CI

`.github/workflows/build.yml` is now an upstream radar workflow. It runs on a
schedule and manually, installs latest nightly, checks the target list and rustup
component state, then builds a small hisi-riscv-rs canary.

The old custom toolchain scripts under `scripts/`, `targets/`, `config.toml`, and
`rust-version.txt` remain only as legacy reference material for old releases. Do
not use them for new ecosystem setup.

## Tier-2 readiness signal

The radar is intentionally boring and repeatable. A future Tier-2 push needs
evidence that the target is not just present once, but remains usable across
nightlies and downstream firmware builds:

1. target present in latest nightly;
2. build-std canary green;
3. rustup std component status tracked;
4. QEMU/HIL canaries available for runtime sanity;
5. downstream template and core crates build without private toolchain patches.
