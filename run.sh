#!/usr/bin/env bash
# KAiOSSChat starten (Companion-Shell).
# Stellt sicher, dass der KAiOSS-Stack läuft (die Shell lädt dessen Frontend),
# startet ihn bei Bedarf, dann das Tauri-Fenster.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

KAIOSS_DIR="${KAIOSS_DIR:-$HOME/Projekte/aktiv/KAiOSS}"

if ! curl -s -o /dev/null http://127.0.0.1:5174/desktop-bubble; then
  echo "KAiOSS-Stack läuft nicht — starte ihn ($KAIOSS_DIR)…"
  "$KAIOSS_DIR/start.sh" start
  for i in $(seq 1 30); do
    curl -s -o /dev/null http://127.0.0.1:5174/desktop-bubble && break
    sleep 1
  done
fi

# shellcheck disable=SC1091
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
cd src-tauri
exec cargo tauri dev
