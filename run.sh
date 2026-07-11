#!/usr/bin/env bash
# KAiOSSChat starten (Companion-Shell, Phase 0).
# Plan D: ALLES vom System (rustup + apt-GTK/webkit) — KEIN Nix-Mix mehr.
# Begruendung: Nix-rustc + System-GTK/glibc = ABI-Konflikt. Symptome waren:
#   - "libgdk-3.so.0: cannot open shared object file" (Nix-Loader kennt /usr nicht)
#   - "*** stack smashing detected ***" (System-Loader + Nix-glibc-Objekte)
# Einmal-Setup: ./setup-imperativ.sh  (rustup mit --no-modify-path, apt-Pakete)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

KAIOSS_DIR="${KAIOSS_DIR:-$HOME/Projekte/aktiv/KAiOSS}"

# 0. Rustup-Toolchain laden (kein PATH-Eintrag noetig dank --no-modify-path)
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
if ! command -v cargo >/dev/null 2>&1 || ! cargo tauri --version >/dev/null 2>&1; then
  echo "⚠️  Rust bzw. tauri-cli fehlt. Einmalig ausführen: ./setup-imperativ.sh"
  exit 1
fi

# 1. KAiOSS-Stack sicherstellen (liefert /desktop-bubble)
if ! curl -s -o /dev/null http://127.0.0.1:5174/desktop-bubble; then
  echo "KAiOSS-Stack läuft nicht — starte ihn ($KAIOSS_DIR)…"
  "$KAIOSS_DIR/start.sh" start
  for _ in $(seq 1 30); do
    curl -s -o /dev/null http://127.0.0.1:5174/desktop-bubble && break
    sleep 1
  done
fi

# 2. Webkit-Renderfixes: EGL ist auf diesem Wayland/AMD-Setup unrettbar.
#    LIBGL_ALWAYS_SOFTWARE=1 (llvmpipe) statt echter GPU, DMABUF aus.
#    WICHTIG: COMPOSITING NICHT deaktivieren — WEBKIT_DISABLE_COMPOSITING_MODE=1
#    hat einen bekannten Bug: die Webview zeichnet beim Fenster-Resize nicht
#    neu (Inhalt verschwindet). Mit llvmpipe laeuft Compositing in Software
#    und Resize funktioniert. Falls das Fenster damit KOMPLETT schwarz
#    startet: die zwei auskommentierten Zeilen wieder aktivieren und melden.
# export GDK_GL=disable
# export WEBKIT_DISABLE_COMPOSITING_MODE=1
export WEBKIT_DISABLE_DMABUF_RENDERER=1
export LIBGL_ALWAYS_SOFTWARE=1
export RUST_BACKTRACE=1

cd src-tauri && exec cargo tauri dev
