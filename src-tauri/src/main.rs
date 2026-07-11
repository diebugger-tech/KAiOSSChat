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

use tauri::{
    image::Image,
    menu::{Menu, MenuItem},
    tray::TrayIconBuilder,
    Manager, PhysicalPosition,
};

// Tray-Frames für die Blinzel-Animation (Augen auf / Augen zu).
const TRAY_OPEN: &[u8] = include_bytes!("../icons/tray-open.png");
const TRAY_BLINK: &[u8] = include_bytes!("../icons/tray-blink.png");
const TRAY_ID: &str = "kai-tray";

// Tray-Icon tauschen — muss auf dem Main-Thread laufen (GTK).
fn set_tray_frame(handle: &tauri::AppHandle, png: &'static [u8]) {
    let h = handle.clone();
    let _ = handle.run_on_main_thread(move || {
        if let (Some(tray), Ok(img)) = (h.tray_by_id(TRAY_ID), Image::from_bytes(png)) {
            let _ = tray.set_icon(Some(img));
        }
    });
}

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

                // Mikrofon für kai-voice (PTT): WebKitGTK beantwortet
                // Permission-Requests per Default mit DENY — getUserMedia
                // scheitert dann still. Da die Webview ausschließlich den
                // eigenen localhost-Stack lädt, erlauben wir die Anfragen
                // hier pauschal. (Phase 3 bekommt echte Permission-Gates
                // für Tool-Calls — das hier betrifft nur Browser-APIs.)
                #[cfg(target_os = "linux")]
                let _ = win.with_webview(|webview| {
                    use webkit2gtk::{PermissionRequestExt, SettingsExt, WebViewExt};
                    let wv = webview.inner();
                    if let Some(settings) = wv.settings() {
                        settings.set_enable_media_stream(true);
                    }
                    wv.connect_permission_request(|_, req| {
                        req.allow();
                        true // Request behandelt — kein Default-DENY
                    });

                    // Externe Links (z.B. 📚 -> ollama.com/library, TODO #58a:
                    // "im Browser oeffnen, dort pullen, KAiOSS erkennt neue
                    // Modelle automatisch") im Standard-Browser oeffnen —
                    // die Webview schluckte target=_blank sonst still.
                    // Lokaler Stack (localhost/127.0.0.1) navigiert normal.
                    use glib::prelude::Cast;
                    use webkit2gtk::{
                        NavigationPolicyDecision, NavigationPolicyDecisionExt,
                        PolicyDecisionExt, PolicyDecisionType, URIRequestExt,
                    };
                    wv.connect_decide_policy(|_, decision, decision_type| {
                        if decision_type != PolicyDecisionType::NavigationAction
                            && decision_type != PolicyDecisionType::NewWindowAction
                        {
                            return false;
                        }
                        if let Some(nav) = decision.dynamic_cast_ref::<NavigationPolicyDecision>() {
                            if let Some(mut action) = nav.navigation_action() {
                                if let Some(req) = action.request() {
                                    if let Some(uri) = req.uri() {
                                        let external = (uri.starts_with("http://")
                                            || uri.starts_with("https://"))
                                            && !uri.starts_with("http://localhost")
                                            && !uri.starts_with("http://127.0.0.1");
                                        if external {
                                            let _ = std::process::Command::new("xdg-open")
                                                .arg(uri.as_str())
                                                .spawn();
                                            decision.ignore();
                                            return true;
                                        }
                                    }
                                }
                            }
                        }
                        false
                    });
                });
            }

            // --- Tray-Icon: KAi in der Leiste, blinzelt periodisch ---
            // Linux/AppIndicator liefert keine Klick-Events, daher Menü.
            let toggle = MenuItem::with_id(app, "toggle", "KAi anzeigen/verstecken", true, None::<&str>)?;
            let quit = MenuItem::with_id(app, "quit", "Beenden", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&toggle, &quit])?;
            TrayIconBuilder::with_id(TRAY_ID)
                .icon(Image::from_bytes(TRAY_OPEN)?)
                .menu(&menu)
                .tooltip("KAi")
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "toggle" => {
                        if let Some(win) = app.get_webview_window("main") {
                            if win.is_visible().unwrap_or(false) {
                                let _ = win.hide();
                            } else {
                                let _ = win.show();
                                let _ = win.set_focus();
                            }
                        }
                    }
                    "quit" => app.exit(0),
                    _ => {}
                })
                .build(app)?;

            // Blinzel-Loop: alle ~4 s Augen kurz zu (Icon-Swap, GTK-safe
            // via run_on_main_thread in set_tray_frame).
            let handle = app.handle().clone();
            std::thread::spawn(move || loop {
                std::thread::sleep(std::time::Duration::from_millis(3800));
                set_tray_frame(&handle, TRAY_BLINK);
                std::thread::sleep(std::time::Duration::from_millis(160));
                set_tray_frame(&handle, TRAY_OPEN);
            });

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("Fehler beim Starten von KAiOSSChat");
}
