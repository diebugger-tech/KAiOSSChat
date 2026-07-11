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

use tauri::{Manager, PhysicalPosition};

fn main() {
    tauri::Builder::default()
        .setup(|app| {
            // Fenster unten rechts platzieren — über Uhr + Dock. Aus der
            // Monitorgröße berechnet, passt sich jeder Auflösung an.
            if let Some(win) = app.get_webview_window("main") {
                if let Ok(Some(monitor)) = win.current_monitor() {
                    let screen = monitor.size();
                    let w = win.outer_size().unwrap_or(*screen);
                    let margin_right: i32 = 16;
                    let margin_bottom: i32 = 110; // Platz für Dock + Uhr
                    let x = screen.width as i32 - w.width as i32 - margin_right;
                    let y = screen.height as i32 - w.height as i32 - margin_bottom;
                    let _ = win.set_position(PhysicalPosition::new(x.max(0), y.max(0)));
                }
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("Fehler beim Starten von KAiOSSChat");
}
