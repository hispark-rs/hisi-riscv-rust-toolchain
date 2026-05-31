# ws63-rust-toolchain

构建脚本 + CI：从 **stable** 的 rust-lang/rust 源码编译一个 rustc，把 HiSilicon **WS63**
应用核的目标 **`riscv32imfc-unknown-none-elf`** 烤进 **builtin target** 列表，并用
`rustup toolchain link` 挂成自定义工具链。

> 目标 ISA：**RV32IMFC_Zicsr，硬件单精度浮点（`ilp32f`），无原子扩展（A）**。

## 为什么要这个

[ws63-rs](https://github.com/sanchuanhehe/ws63-rs) 默认用 builtin 的 `riscv32imc`（无原子，**软浮点**）。
当需要**硬浮点**（典型场景：链接厂商用 `-mabi=ilp32f` 编的闭源 Wi-Fi/BT blob，软浮点 ABI 不兼容）时，
没有现成的 builtin"无原子 + 硬浮点"目标，常规做法是 `nightly + -Z build-std` 现编 `core`——但它脆弱
（自定义 JSON spec 随 nightly 漂移）且 `build-std` 全局化会破坏 host 测试。

本仓库走另一条路：**把目标编进 rustc 自身**，得到一个 stable 工具链，下游
**无需 `-Z build-std`** 即可 `--target riscv32imfc-unknown-none-elf`（工具链已带预编译的 `core`）。

## 目标定义

`targets/riscv32imfc-unknown-none-elf.rs`：等价于 in-tree 的 `riscv32imafc-unknown-none-elf`
**去掉 `a` 扩展**，并沿用 `riscv32imc` 处理无原子核的方式：

- `features = "+m,+f,+c,+forced-atomics"`、`llvm_abiname = ilp32f`
- `atomic_cas = false`：原子 load/store 降为普通 ld/st（单 hart 安全），RMW/CAS 关闭 →
  下游用 critical-section polyfill（如 `portable-atomic` 的 `critical-section` feature）。
- 不发 `lr.w/sc.w/amo*`，在无 A 扩展的核上不会触发非法指令陷阱。

## 本地构建

需要：x86_64 Linux、`build-essential`、`python3`、`git`、约 20-30G 磁盘、≥8G RAM（建议加 swap）。

```bash
# 一把梭：拉源码 → 注入目标 → 构建 → rustup link 成 "ws63"
./scripts/build-all.sh "$PWD/rust" "$(nproc)"

# 验证（在一个 no_std crate 里，无需 -Z build-std）
cargo +ws63 build --target riscv32imfc-unknown-none-elf
rustc +ws63 --print target-list | grep riscv32imfc   # 确认是 builtin
```

分步脚本：`fetch-rust.sh`（克隆 pinned tag，见 `rust-version.txt`）、`apply-target.sh`（注入目标）、
`build.sh`（`x.py build`）、`link.sh`（`rustup toolchain link`）、`package.sh`（打包 sysroot tar）。

bootstrap 配置见 `config.toml`：`download-ci-llvm = true`（用预编译 LLVM，免 cmake/ninja）、
`target = [host, riscv32imfc]`、`extended + cargo`、`channel = stable`。

## CI / 发布

`.github/workflows/build.yml`：`workflow_dispatch` 或推 `v*` tag 触发，在 ubuntu-latest 上
fetch → 注入 → 构建 → 冒烟测试（确认目标是 builtin）→ 打包 sysroot，并在 tag 时把
`ws63-rust-<ver>-x86_64-unknown-linux-gnu.tar.gz` 作为 Release 资产发布。

下游使用预编译产物：

```bash
curl -LO <release-asset-url>/ws63-rust-1.96.0-x86_64-unknown-linux-gnu.tar.gz
tar xzf ws63-rust-1.96.0-*.tar.gz
rustup toolchain link ws63 "$PWD/stage2"
```

## 在 ws63-rs 中启用（ROADMAP 阶段 3）

切到硬浮点时，在 ws63-rs：`rust-toolchain.toml` 用 `ws63` 工具链、`.cargo/config.toml`
`target = "riscv32imfc-unknown-none-elf"`（builtin，无需 build-std）、`portable-atomic`
保持 `critical-section` feature。详见 ws63-rs 的 `ROADMAP.md` 阶段 3 与
`docs/architecture/overview.md`。

## 版本

`rust-version.txt` pin 了 rust 源码 tag（当前 `1.96.0`，最新 stable）。升级时改它并重新校验目标定义
对该版本的 `rustc_target` API（字段名偶尔变动）。
