# KAiOSSChat — Architektur (v0.1, Entwurf für Gegencheck)

> Desktop-Begleiter für KAi: rundes Always-on-top-Bubble-Fenster, per Klick zum
> Chat expandierend. Steuert Alltags-Apps über deren APIs (Voice/Chat), mit
> Bestätigung pro Schritt — und lernt bestätigte Workflows als SKILL.md.
> Teilt sich das Gehirn mit KAiOSS (dieselbe SurrealDB). 100 % lokal, Egress
> nur zu explizit deklarierten Ziel-APIs, jeder Call sichtbar + bestätigt.
>
> Status: Architektur-Entwurf. Review durch Gemini ausstehend. KEIN Code bisher.

## 1. Identität & Abgrenzung

- KAiOSS (Web) = Projekt-Hub, Read-Only-Labor, Gedächtnis-Verwaltung.
- **KAiOSSChat (Desktop) = die Hand mit Leine:** führt API-Aktionen aus
  (Kalender-Termin verschieben), aber JEDER Schritt läuft durch ein
  Permission-Gate. Autonomie wird verdient (Charta-Eskalationspfad), nie
  per Default gewährt.
- Kein GUI-/Pixel-Agent (kein OpenAdapt/Screenshot-Ansatz): reine
  **API-Orchestrierung**. OpenAdapt dient nur als Referenzarchitektur
  (Abstraction Ladder, Safety Gate, Policy/Grounding-Trennung).

## 2. Vier Schichten

### 2.1 Shell — Tauri 2 (Rust) + Svelte 5
- Frameless, rundes, always-on-top Bubble-Fenster (Kai-Avatar wie in KAiOSS);
  Klick expandiert zum Chatfenster. Tray, Autostart, Mikrofon-Zugriff,
  **Permission-Dialoge** (native, nicht wegklickbar durch Webinhalt).
- Rust bleibt reine App-Shell: Fenster, IPC, Prozess-Spawning, Dialoge.
  KEINE Agent-Logik in Rust.
- UI-Stil: KAiOSS-Terminal-Ästhetik (Screenshots als Referenz), aber
  Buttons/Header kompakter (Feedback: ESC_CLOSE u.a. zu groß — von Anfang
  an Icon-Buttons statt Text-Boxen).

### 2.2 Agent-Core — Pi im RPC-Modus
- Shell spawnt Pi als Kindprozess, JSON über stdin/stdout (OpenClaw-Muster).
- Pi liefert gratis: Agent-Loop, Tool-Calling, Ollama-Anbindung,
  Kontext-Kompaktierung, natives SKILL.md-Laden.
- Drei eigene Extensions (TypeScript):
  1. **PermissionGate** — jeder Tool-Call → Event an Tauri → wartet auf OK
  2. **WorkflowRecorder** — bestätigte Schritte mitschreiben → SKILL.md
  3. **Tool-Definitionen** — dünne Beschreibungen der Ziel-APIs
     (Endpoint, Auth, Parameter-Schema); Retry/Fehlerbehandlung im Tool,
     nicht im Modell
- OFFENE ENTSCHEIDUNG (Gemini): Pi/TypeScript akzeptieren vs. Python-Eigenbau
  (litellm + eigener Loop). Pi = weniger Arbeit, TS; Eigenbau = mehr Arbeit,
  Wunschsprache.

### 2.3 Modell — Ollama (bestehende Instanz)
- Arbeitsmodell: `qwen3:8b` (Q4) — solides Tool-Calling, passt komplett in
  8 GB VRAM. 14B nur teiloffloaded → nicht für v1.
- Modell-Auswahl-UI: Muster aus KAiOSS wiederverwenden
  (`listInstalledModels`, Badges ✓/⬇, HITL-Pull, 📚-Library-Link).
- OFFENE FRAGE (Gemini): qwen3:8b vs. qwen2.5-coder:7b für Tool-Calling —
  im Labor (KAiOSS #45) messen statt raten, sobald Daten da sind.

### 2.4 Lernen — SKILL.md pro App/Workflow
- Erste Ausführung: Modell exploriert, JEDER Schritt bestätigt.
  Recorder destilliert daraus eine SKILL.md nach `~/skills/kai/<app>/`
  (git-versionierbar, menschenlesbar, Pi lädt sie nativ; kompatibel zum
  Open Agent Skills Standard — Codex R&R erzeugt dasselbe Artefakt).
- **Abstraction Ladder** (gestuft, aus OpenAdapt übertragen auf API-Ebene):
  - L0 wörtliches Replay (exakte Calls, nur bestätigen)
  - L1 parametrisiert (gleiche Schritte, Modell füllt Parameter: Datum, Titel)
  - L2 Ziel-Ebene („räum meinen Freitag frei" → Modell plant mit gelernten Verben)
  - Aufstieg pro Skill nur nach Erfolgsbilanz (verdiente Autonomie, messbar).
- SurrealDB hält nur Metadaten/Ausführungshistorie; die SKILL.md ist die
  Wahrheit (SSoT-Muster wie `~/skills/user/`).

## 3. Anbindung ans PC-Gehirn (SurrealDB — dieselbe wie KAiOSS)

**EIN Gedächtnis für Web-KAi und Desktop-KAi.** Eine Konvention, einmal
gelernt, gilt überall.

- Verbindung: bestehende Instanz `ws://localhost:8000`, Namespace/DB `kaioss`.
- **Schreiben:** `memory_capture` — Chat-/Voice-Turns aus KAiOSSChat fließen
  in dieselbe Lern-Pipeline (Secret-Filter identisch übernehmen!); `kai_log`
  (Provenance: quelle 'desktop'); `kai_status:chat` (Live-Sichtbarkeit im
  KAiOSS-Insights-Panel: „Desktop-Kai verschiebt gerade Termin…").
- **Lesen:** `memory_node`-Retrieval als `<retrieved_memory>`-Block im
  System-Prompt (Phase-3-Guards 1:1 übernehmen: Poisoning-Kapselung,
  Präzedenzregel, Top-K, fail-safe, KNN `<|20|>`).
- **Least Privilege:** eigener scoped DB-User `kaichat` — create auf
  memory_capture/kai_log/kai_status, select auf memory_node/kai_config,
  KEIN delete, keine Kernfelder. (Muster: kai-User ROLES EDITOR +
  Table-Permissions.)
- Bekannte Fallen aus KAiOSS übernehmen (AGENTS.md-Guidelines): NULL ≠ NONE
  bei option<>-Feldern, ORDER BY-Feld mitselektieren, time::now() serverseitig.

## 4. Voice — kai-voice wiederverwenden (NICHT neu bauen)

- Bestehender Microservice `github.com/diebugger-tech/kai-voice`:
  faster-whisper (de) STT + Piper TTS, dummer zustandsloser WebSocket-Server
  (:8770). KAiOSS nutzt ihn bereits — KAiOSSChat wird **zweiter Client**.
- Wiederverwendbare Client-Muster aus KAiOSS `voiceClient.svelte.js`:
  Push-to-Talk, GainNode (AGC aus), satzweises TTS, Mute-Semantik,
  **Mikrofon-Release nach jeder Aufnahme** (Privacy, rotes Icon erlischt).
- ZU PRÜFEN (Gemini/Spike): verträgt der WS-Server zwei parallele Clients
  (KAiOSS-Tab + Desktop-App)? Backend ist zustandslos — vermutlich ja,
  sonst Queue/zweite Instanz mit anderem Port.
- v1 darf Text-only starten; Voice ist Phase 5.
- **Sichere Sprachsteuerung (Grundsatz):** Voice ist Ein-/Ausgabekanal —
  das Permission-Gate bleibt ein **Klick im nativen Dialog**. Ein gesprochenes
  „Ja" zählt NICHT als Freigabe für schreibende Aktionen (STT kann sich
  verhören; ein Nuscheln darf keinen Termin verschieben). Erst spätere Stufe,
  und nur nach Gegencheck: Sprach-Bestätigung höchstens für LESENDE Aktionen
  (calendar.list), niemals für create/update — und mit expliziter
  Bestätigungs-Phrase, nicht freiem „Ja".

## 5. Permission-Gate (das Kernstück)

- Jeder Tool-Call erzeugt einen nativen Tauri-Dialog:
  „Kai will: Termin ‚Badminton' Do 19:00 → Fr 15:00 verschieben. [OK] [Nein]
  [Immer erlauben für: calendar.update]"
- „Immer erlauben" = **verdiente Autonomie pro (App × Verb)**, gespeichert
  als `kai_permission`-Record (SurrealDB, mit Provenance + Widerrufs-UI).
  Lesend (calendar.list) kann früher freigegeben werden als schreibend
  (calendar.update); delete-Verben NIE auto (Charta).
- Jede Ausführung (auch abgelehnte) → `kai_log` (Audit, Modell in Provenance
  → Datenbasis fürs Labor/Scoring wie KAiOSS #45).

## 6. Egress-Modell (WICHTIG — Charta-Erweiterung)

KAiOSSChat ist der erste KAi-Baustein mit **echtem Cloud-Egress**
(Google-API). Regel:
- Ziel-APIs sind **deklarierte Egress-Punkte** (Liste im Repo, pro Tool
  dokumentiert: Host, Zweck, Datenumfang).
- Kein Call ohne Permission-Gate; jeder Call geloggt (kai_log).
- Alles andere bleibt localhost-only (CSP `connect-src` localhost +
  deklarierte Hosts — die Whitelist IST die Egress-Doku, browserseitig
  erzwungen).
- Secrets: OAuth-Refresh-Tokens lokal (agenix bzw. chmod 600), NIE in der DB
  (KAiOSS-Invariante „Keys nie in DB/Backup/Export").

## 7. Skill 1: Google Calendar

- Drei Tools: `calendar.list`, `calendar.create`, `calendar.update`
  (delete bewusst NICHT in v1).
- Auth: OAuth2 Desktop-Flow — Google-Cloud-Projekt, Calendar API aktivieren,
  OAuth-Client „Desktop", einmaliger Browser-Consent, Refresh-Token lokal.
  (~30 min Einmal-Setup, dokumentieren in docs/SETUP-GOOGLE.md.)
- Idealer Erstfall: klare Verben, harmloser Blast-Radius
  (Kalender kaputt ≠ System kaputt), perfekte Permission-Gate-Demo.
- Alternative CalDAV (Nextcloud etc.) notiert, aber v1 = native Google-API.

## 8. Repo-Struktur (Vorschlag)

```
KAiOSSChat/
├── src-tauri/          # Rust-Shell (Fenster, Tray, Dialoge, Pi-Spawn)
├── src/                # Svelte 5 UI (Bubble, Chat, Permission-Historie)
├── agent/              # Pi-Extensions (TS): gate.ts, recorder.ts, tools/
│   └── tools/calendar.ts
├── skills/             # gelernte SKILL.md (git-versioniert)
├── db/                 # Migration: kaichat-User, kai_permission (läuft
│                       #   gegen die KAiOSS-Instanz, non-destruktiv)
├── docs/               # ARCHITEKTUR.md (dieses Doc), SETUP-GOOGLE.md, ADRs
└── AGENT.md            # Projektgedächtnis (Konventionen, Stand)
```

## 9. Installationsliste (Ubuntu, Home Manager wo möglich)

1. Rust-Toolchain (rustup) + `cargo install tauri-cli`
2. Tauri-Systemdeps: libwebkit2gtk-4.1-dev, build-essential, libssl-dev,
   libayatana-appindicator3-dev, librsvg2-dev
3. Node ≥ 20 → Pi: `npm i -g @earendil-works/pi-coding-agent`
4. Ollama (vorhanden) → `ollama pull qwen3:8b`
5. kai-voice (vorhanden, Repo diebugger-tech/kai-voice) — nur starten
6. SurrealDB (vorhanden, KAiOSS-Instanz) — Migration kaichat-User
7. Google-Cloud-Projekt + OAuth-Client (einmalig, Phase 3)

## 10. Phasen

- **Phase 0 — Spike (kritischste Annahme zuerst):** Pi headless im RPC-Modus,
  ein Tool-Call mit qwen3:8b durch. Beweist Pi+Ollama+Tool-Calling, BEVOR
  UI-Arbeit anfällt. Abbruchkriterium definiert: klappt Tool-Calling mit
  8B lokal nicht zuverlässig → Python-Eigenbau-Entscheidung neu bewerten.
- **Phase 1 — Shell:** Tauri-Bubble + Chat gegen Pi-RPC (Text-only).
- **Phase 2 — Gehirn:** memory_capture schreiben + memory_node-Retrieval
  (Muster aus KAiOSS 1:1), kaichat-DB-User, kai_status-Sichtbarkeit.
- **Phase 3 — Permission-Gate + Calendar:** die drei Tools, OAuth-Setup,
  kai_permission, Audit-Log.
- **Phase 4 — Recorder:** bestätigte Läufe → SKILL.md → Replay (L0→L1).
- **Phase 5 — Voice:** kai-voice als zweiter Client (PTT, TTS-Toggle).

## 11. Offene Fragen für den Gegencheck (Gemini)

1. **Pi/TS vs. Python-Eigenbau** — Trade-off-Einschätzung? (Pi spart Loop/
   Skills/Kompaktierung; TS statt Python; RPC-Stabilität als Kindprozess?)
2. **Gleiche DB `kaioss` vs. eigene DB** — ein Gehirn (Empfehlung hier) vs.
   Isolation. Risiken bei gleichzeitigen Writern (Web + Desktop + Batches)?
3. **kai-voice mit zwei parallelen WS-Clients** — Backend zustandslos, aber
   getestet ist es nicht. Queue nötig?
4. **qwen3:8b Tool-Calling-Zuverlässigkeit** auf 8 GB — bessere Alternative
   in der Klasse?
5. **Tauri-2-Security-Setup** — Capabilities/Permissions minimal schneiden
   (nur Mic, Tray, Dialog, Prozess-Spawn für Pi); was übersehen wir?
6. **kai_permission-Schema** — reicht (app, verb, erlaubt_seit, provenance,
   widerrufen)? Ablauf/TTL für erteilte Dauerfreigaben?
7. **Sprach-Bestätigung** — trägt die Regel „Voice bestätigt nie schreibende
   Aktionen" (§4)? Oder gibt es ein sicheres Muster (Bestätigungs-Phrase +
   Confidence-Schwelle der STT), das wir unterschätzen?
