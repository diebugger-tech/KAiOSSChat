#!/usr/bin/env bash
# KAiOSSChat als installierte Desktop-App starten (Release-Binary).
# Wird vom .desktop-Starter aufgerufen — kein Terminal, kein cargo.
# Phase 0: laedt den KAiOSS-Stack (localhost:5174) und startet ihn bei Bedarf.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

KAIOSS_DIR="${KAIOSS_DIR:-$HOME/Projekte/aktiv/KAiOSS}"
BIN="./src-tauri/target/release/kaiosschat"

if [ ! -x "$BIN" ]; then
  notify-send "KAiOSSChat" "Binary fehlt — einmalig ./install-desktop.sh ausführen." 2>/dev/null || true
  exit 1
fi

# KAiOSS-Stack sicherstellen (liefert /desktop-bubble)
if ! curl -s -o /dev/null http://127.0.0.1:5174/desktop-bubble; then
  "$KAIOSS_DIR/start.sh" start
  for _ in $(seq 1 30); do
    curl -s -o /dev/null http://127.0.0.1:5174/desktop-bubble && break
    sleep 1
  done
fi

# Webkit-Renderfixes — identisch zu run.sh (llvmpipe, Compositing AN,
# sonst Resize-Blank-Bug; siehe run.sh-Kommentar)
export WEBKIT_DISABLE_DMABUF_RENDERER=1
export LIBGL_ALWAYS_SOFTWARE=1

exec "$BIN"
