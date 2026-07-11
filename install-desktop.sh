#!/usr/bin/env bash
# KAiOSSChat als Desktop-App installieren:
#   1. Release-Binary bauen (cargo tauri build --no-bundle)
#   2. Icon + .desktop-Starter nach ~/.local installieren
#   3. Starter zusätzlich auf den Desktop kopieren
# Danach erscheint "KAi" im Anwendungsmenü und auf dem Desktop.
# Dateiname des Starters = Tauri-Identifier (tech.diebugger.kaiosschat),
# damit GNOME/Wayland das Dock-Icon korrekt zuordnet (app_id-Matching).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
APP_DIR="$(pwd)"
ID="tech.diebugger.kaiosschat"

# 0. Toolchain (wie run.sh — Plan D: alles vom System)
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
if ! command -v cargo >/dev/null 2>&1 || ! cargo tauri --version >/dev/null 2>&1; then
  echo "⚠️  Rust bzw. tauri-cli fehlt. Einmalig ausführen: ./setup-imperativ.sh"
  exit 1
fi

# 1. Release-Binary bauen
echo "==> Baue Release-Binary…"
(cd src-tauri && cargo tauri build --no-bundle)

# 2. Icons installieren
echo "==> Installiere Icons…"
for size in 32 128 256; do
  src="src-tauri/icons/${size}x${size}.png"
  [ "$size" = 256 ] || src="src-tauri/icons/${size}x${size}.png"
  dst="$HOME/.local/share/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$dst"
  cp "$src" "$dst/$ID.png"
done
gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

# 3. .desktop-Starter schreiben
echo "==> Installiere Starter…"
mkdir -p "$HOME/.local/share/applications"
DESKTOP_FILE="$HOME/.local/share/applications/$ID.desktop"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=KAi
Comment=KAi Desktop-Companion (KAiOSSChat)
Exec=$APP_DIR/start-app.sh
Icon=$APP_DIR/src-tauri/icons/icon.png
Terminal=false
Categories=Utility;Chat;
StartupWMClass=kaiosschat
EOF
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

# 4. Auf den Desktop kopieren (falls Desktop-Ordner existiert)
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
if [ -d "$DESKTOP_DIR" ]; then
  cp "$DESKTOP_FILE" "$DESKTOP_DIR/"
  chmod +x "$DESKTOP_DIR/$ID.desktop"
  # GNOME: Starter als vertrauenswürdig markieren (sonst "nicht vertrauenswürdig"-Dialog)
  gio set "$DESKTOP_DIR/$ID.desktop" metadata::trusted true 2>/dev/null || true
fi

echo ""
echo "✅ Fertig. 'KAi' ist im Anwendungsmenü und auf dem Desktop."
echo "   Start prüft/startet den KAiOSS-Stack automatisch."
