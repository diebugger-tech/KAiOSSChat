#!/usr/bin/env bash
# KAiOSSChat NUR als Chatfenster (Standalone) — OHNE KAiOSS-Stack.
# Für VM-Tests (z.B. Linux Mint) und schnelle Shell-Tests.
# Plan D: alles vom System (rustup + apt). Einmal-Setup: ./setup-imperativ.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
if ! command -v cargo >/dev/null 2>&1 || ! cargo tauri --version >/dev/null 2>&1; then
  echo "⚠️  Rust bzw. tauri-cli fehlt. Einmalig ausführen: ./setup-imperativ.sh"
  exit 1
fi

# Webkit-Renderfixes (Software-Rendering — wichtig auch in VMs ohne 3D):
export GDK_GL=disable
export WEBKIT_DISABLE_COMPOSITING_MODE=1
export WEBKIT_DISABLE_DMABUF_RENDERER=1
export LIBGL_ALWAYS_SOFTWARE=1
export RUST_BACKTRACE=1

cd src-tauri && exec cargo tauri dev --config tauri.standalone.conf.json
