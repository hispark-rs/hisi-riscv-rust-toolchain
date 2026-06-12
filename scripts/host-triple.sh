#!/usr/bin/env bash
# Echo the host target triple to build for. Honors $HOST if set (the CI matrix
# sets it explicitly per runner); otherwise auto-detects from uname so the
# scripts work standalone on a dev machine.
detect_host_triple() {
  if [ -n "${HOST:-}" ]; then echo "$HOST"; return; fi
  local s m
  s="$(uname -s)"; m="$(uname -m)"
  case "$s" in
    Linux)
      case "$m" in
        x86_64)         echo "x86_64-unknown-linux-gnu" ;;
        aarch64|arm64)  echo "aarch64-unknown-linux-gnu" ;;
        *) echo "x86_64-unknown-linux-gnu" ;;
      esac ;;
    Darwin)
      case "$m" in
        arm64|aarch64)  echo "aarch64-apple-darwin" ;;
        x86_64)         echo "x86_64-apple-darwin" ;;
        *) echo "aarch64-apple-darwin" ;;
      esac ;;
    MINGW*|MSYS*|CYGWIN*) echo "x86_64-pc-windows-msvc" ;;
    *) echo "x86_64-unknown-linux-gnu" ;;
  esac
}
