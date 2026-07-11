// KAiOSSChat — Companion-Shell (Phase 0)
//
// Ein dünnes Tauri-2-Fenster, das die /desktop-bubble-Route des laufenden
// KAiOSS-Stacks lädt (http://localhost:5174). Bewusst KEINE Agent-Logik in
// Rust — die kommt in Phase 3 als Tool-Executor mit Permission-Gate und
// Egress-Whitelist (Lösung C, siehe ARCHITEKTUR.md §2.3).
//
// Phase-0-Ziel: beweisen, dass der komplette KAiOSS-Chat (Memory, Voice,
// Modell-Dropdown) unverändert in der Desktop-Webview läuft.

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("Fehler beim Starten von KAiOSSChat");
}
