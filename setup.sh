#!/usr/bin/env bash
# KAiOSSChat — Einmal-Setup (Phase 0): installiert alle Abhängigkeiten.
# Idempotent: bereits Installiertes wird erkannt und übersprungen.
set -euo pipefail

echo "=== KAiOSSChat Setup (Phase 0: Companion-Shell) ==="

# 1. Tauri-Systemabhängigkeiten (Ubuntu/Debian)
echo "--- [1/4] System-Pakete (webkit2gtk & Co.) ---"
NEED=()
for pkg in libwebkit2gtk-4.1-dev build-essential curl wget file libssl-dev \
           libayatana-appindicator3-dev librsvg2-dev; do
  dpkg -s "$pkg" >/dev/null 2>&1 || NEED+=("$pkg")
done
if [ ${#NEED[@]} -gt 0 ]; then
  echo "Installiere: ${NEED[*]} (sudo erforderlich)"
  sudo apt-get update -qq && sudo apt-get install -y "${NEED[@]}"
else
  echo "✅ System-Pakete vorhanden."
fi

# 2. Rust-Toolchain
echo "--- [2/4] Rust ---"
if ! command -v cargo >/dev/null 2>&1; then
  echo "Installiere rustup (stable)…"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  # shellcheck disable=SC1091
  source "$HOME/.cargo/env"
else
  echo "✅ Rust vorhanden: $(rustc --version)"
fi

# 3. Tauri-CLI (v2)
echo "--- [3/4] Tauri-CLI ---"
if ! cargo tauri --version >/dev/null 2>&1; then
  echo "Installiere tauri-cli (dauert ein paar Minuten)…"
  cargo install tauri-cli --version '^2' --locked
else
  echo "✅ Tauri-CLI vorhanden: $(cargo tauri --version)"
fi

# 4. Laufzeit-Voraussetzungen prüfen (nur Hinweise, keine Installation)
echo "--- [4/4] Laufzeit-Checks ---"
curl -s -o /dev/null http://127.0.0.1:11434/api/tags \
  && echo "✅ Ollama erreichbar" \
  || echo "⚠️  Ollama nicht erreichbar — 'ollama serve' bzw. läuft als Dienst?"
curl -s -o /dev/null http://127.0.0.1:8000/health \
  && echo "✅ SurrealDB erreichbar" \
  || echo "⚠️  SurrealDB nicht erreichbar — KAiOSS-Stack starten (../KAiOSS/start.sh start)"
curl -s -o /dev/null http://127.0.0.1:5174/desktop-bubble \
  && echo "✅ KAiOSS-Frontend + /desktop-bubble erreichbar" \
  || echo "⚠️  KAiOSS-Frontend nicht erreichbar — ../KAiOSS/start.sh start"

echo ""
echo "=== Setup fertig. Starten mit: ./run.sh ==="
