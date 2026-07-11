#!/usr/bin/env bash
# KAiOSSChat starten (Companion-Shell, Phase 0).
# Nutzt die reproduzierbare Nix-Dev-Shell (flake.nix) — kein apt/rustup.
# Stellt sicher, dass der KAiOSS-Stack läuft (die Shell lädt dessen Frontend).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

KAIOSS_DIR="${KAIOSS_DIR:-$HOME/Projekte/aktiv/KAiOSS}"

# 1. KAiOSS-Stack sicherstellen (liefert /desktop-bubble)
if ! curl -s -o /dev/null http://127.0.0.1:5174/desktop-bubble; then
  echo "KAiOSS-Stack läuft nicht — starte ihn ($KAIOSS_DIR)…"
  "$KAIOSS_DIR/start.sh" start
  for _ in $(seq 1 30); do
    curl -s -o /dev/null http://127.0.0.1:5174/desktop-bubble && break
    sleep 1
  done
fi

# 2. Tauri in der Nix-Dev-Shell starten (alle Deps aus flake.nix).
#    Webkit-Renderfixes HIER gesetzt (nicht nur im shellHook), damit sie
#    unabhängig vom Shell-Zustand greifen:
#    - DMABUF-Renderer aus  -> behebt "EGL_BAD_PARAMETER"
#    - Compositing aus       -> gegen schwarzes/leeres Fenster
#    - Software-GL erzwingen -> harte Fallback-Garantie (etwas langsamer,
#                               für eine Chat-UI völlig unkritisch)
if command -v nix >/dev/null 2>&1; then
  exec nix develop --command bash -c '
    # Plan C: System-webkit, keine Nix-Lib-Pollution zur Laufzeit.
    unset LD_LIBRARY_PATH
    # Wayland-EGL ist auf diesem Setup kaputt -> ueber XWayland (X11) laufen.
    # Jetzt FAIRER Test: die Binary ist frisch gegen System (gdkx11) gebaut.
    export GDK_BACKEND=x11
    export WEBKIT_DISABLE_DMABUF_RENDERER=1
    export WEBKIT_DISABLE_COMPOSITING_MODE=1
    export RUST_BACKTRACE=1
    cd src-tauri && cargo tauri dev'
else
  echo "⚠️  'nix' nicht gefunden. Entweder Nix installieren, oder den"
  echo "   imperativen Fallback nutzen: ./setup-imperativ.sh (apt/rustup)."
  exit 1
fi
