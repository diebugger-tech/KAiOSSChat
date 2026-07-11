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
- **Übernahme ≠ Kopie — UI-Schulden bei der Portierung tilgen:**
  - Buttons durchgängig als kompakte Icon-Buttons mit Tooltips,
    konsistente Höhen (28px-Raster), keine Text-Boxen
  - **Ollama-Anbindung aufräumen:** EINE Statusquelle statt drei —
    der modelAvailability-Store liefert online/installiert/pull überall
    (kein separater OLLAMA_ONLINE-Text + GREEN-Badge + Dropdown-Mix);
    Header-Chip: ● Modellname · Status, mehr nicht
  - Fehler sichtbar machen: Toasts statt console.warn (Ollama down,
    Modell fehlt), Reconnect-Feedback statt stillem Hängen
  - Header entrümpeln: Kontext-Zeile und Statusanzeigen zusammenführen

### 2.2 Chat-Core — ÜBERNAHME aus KAiOSS (der Kern des Ganzen)
**Der Chat wird nicht neu gebaut — er existiert fertig in KAiOSS** und wird
auf Systemebene gehoben. Der komplette KAiPanel-Stack ist Svelte 5 und
spricht ausschließlich localhost-Dienste an — er läuft in der Tauri-Webview
unverändert:
- `KAiPanel` (Chat, Verlauf, Next-Actions, Stop, Streaming mit Rest-Buffer)
- `ollamaService` (chatStream, listInstalledModels, pullModel mit Abort)
- `memoryRepository` (Capture mit Secret-Filter + Phase-3-Retrieval mit
  allen Guards) → **das gemeinsame Gehirn ist damit ab Tag 1 angebunden**
- `voiceClient` (PTT, Gain, Mikrofon-Release, satzweises TTS via kai-voice)
- `ModelDropdown`/`modelAvailability` (Badges, HITL-Pull, 📚-Link)
- `db.svelte.js` (SurrealDB-Singleton mit Reconnect)

**Code-Sharing — ZWEISTUFIG (Anforderung „Standalone" bestätigt 11.07.):**

Ziel ist eine EIGENSTÄNDIGE Desktop-App, die auch bei geschlossenem
KAiOSS-Dashboard läuft (Dienste SurrealDB/Ollama/kai-voice laufen im
Hintergrund; nur das Svelte-Frontend braucht einen Host).

- **Phase 0 (gebaut) = Companion-Shell-SPIKE, nicht Endprodukt:** Tauri lädt
  `http://localhost:5174/desktop-bubble` des laufenden Stacks. Zweck: die
  riskanteste These OHNE Build-Zyklen beweisen — läuft der komplette Chat
  (Voice, Memory, Modell-Dropdown) unverändert in der Webview? Wenn ja,
  trägt das Fundament.
- **Phase 1 = Standalone-Umbau (das echte Produkt):**
  1. Geteilte Komponenten in ein **Workspace-Package** `ui-core`
     (npm workspace, NICHT Symlink — fragil): KAiPanel, ollamaService,
     memoryRepository, voiceClient, ModelDropdown, modelAvailability, db.
  2. **Eigener Desktop-Build mit `adapter-static`** (nur die Desktop-App!
     KAiOSS-Web BLEIBT auf adapter-node — es braucht seine Server-Routen
     `/api/open`, `/api/runner`; die dürfen nicht kaputt-SSG't werden).
  3. **`platformAdapter`** kapselt den Unterschied: Web-Modus → `fetch('/api/…')`,
     Desktop-Modus → Tauri-IPC an Rust. Löst `/api/open` UND die Tool-Calls
     (Lösung C) in EINER Abstraktion — KAiPanel bleibt sonst identisch.
  4. Desktop verbindet direkt: Ollama `:11434`, SurrealDB `ws://:8000`,
     kai-voice `:8770` — kein KAiOSS-Webserver nötig.
- Trade-off: Phase 1 kostet echten Aufwand (Package-Extraktion + zwei
  Build-Configs + Adapter). Deshalb Phase 0 zuerst als billiger Beweis.

### 2.3 Agent-Schicht — Tool-Calling (Phase 3) — ENTSCHIEDEN: Lösung C

**Die „Zwei-Wege-Falle" (Gemini-Review) ist real** — zwei konkurrierende
LLM-Loops (Frontend→Ollama vs. Pi→Ollama) darf es nicht geben. Gelöst wird
sie aber weder mit Intent-Classifier (Lösung A, überkomplex) noch mit
Pi-als-Middleware (Lösung B, KAiPanel-Umbau + opaker Loop), sondern:

**Lösung C — Ollama ist selbst der Router (native Tool-Calls):**
- `ollamaService.chatStream` wird um `tools` + `onToolCall`-Callback
  erweitert (EIN Loop, Web und Desktop identisch).
- Web-Modus: keine Tools registriert → Verhalten exakt wie heute.
- Desktop-Modus: Tool-Definitionen werden mitgesendet. Antwortet das Modell
  mit `tool_calls`, reicht das Frontend sie via **Tauri-IPC an Rust**:
  Permission-Dialog (nativ) → Rust führt den HTTP-Call aus (Egress NUR in
  Rust, hinter Whitelist — schließt Geminis Node.js-Loch by design, es
  gibt keinen Node-Kindprozess mit Netzzugang) → Ergebnis zurück in den Loop.
- **PermissionGate** = nativer Rust-Dialog; **WorkflowRecorder** = Rust
  loggt bestätigte Call-Sequenzen → SKILL.md; **Tool-Definitionen** =
  deklarative JSON-Schemas im Repo (Frontend sendet sie, Rust validiert
  Host gegen Whitelist).
- **Pi = Plan B**, nicht mehr gesetzt: nur falls SKILL.md-Interpretation/
  Kontext-Kompaktierung im Eigenbau zu teuer werden. (Frage 1 damit
  vorentschieden; Spike in Phase 3 bestätigt qwen2.5-coder-Tool-Calling.)

### 2.4 Modell — Ollama (bestehende Instanz)
- Arbeitsmodell: `qwen3:8b` (Q4) — solides Tool-Calling, passt komplett in
  8 GB VRAM. 14B nur teiloffloaded → nicht für v1.
- Modell-Auswahl-UI: Muster aus KAiOSS wiederverwenden
  (`listInstalledModels`, Badges ✓/⬇, HITL-Pull, 📚-Library-Link).
- OFFENE FRAGE (Gemini): qwen3:8b vs. qwen2.5-coder:7b für Tool-Calling —
  im Labor (KAiOSS #45) messen statt raten, sobald Daten da sind.

### 2.5 Lernen — SKILL.md pro App/Workflow
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
  Schema (Gemini-Review eingearbeitet): `app`, `verb`, **`resource_scope`**
  (z.B. nur Kalender X), **`expires_at`** (Dauerfreigaben laufen ab, z.B.
  30 Tage), `erlaubt_seit`, `provenance`, `widerrufen`.
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

## 7. Skill 1: Lokale PC-Steuerung (PIVOT, Gemini-Review 11.07.)

**Statt Cloud-API zuerst den eigenen Rechner** — null Egress, kein
OAuth-Setup, CSP bleibt strikt localhost. Human-in-the-Loop an echten,
lokalen Aktionen.

- Tools v1 (Blast-Radius-gestaffelt):
  1. `app.open(name)` — Programm starten (harmlos, idealer Erstfall)
  2. `fs.read(pfad)` — Datei lesen (read-only, Pfad-Whitelist ~/Projekte)
  3. `shell.run(alias)` — **NUR Alias-Whitelist, NIEMALS Freitext!**
- **Leitplanken (nicht verhandelbar):**
  - Kein freies `shell.execute("...")` — die Charta verbietet KAi freie
    Shell-Befehle, und KAiOSS hat die Lösung schon gebaut: die
    `commands.json`-Whitelist + Risiko-Stufen + `task_queue`/cmd-runner
    mit HITL + Audit-Log werden WIEDERVERWENDET (Desktop enqueued in
    dieselbe Schiene bzw. Rust prüft gegen dieselbe commands.json).
  - **„Immer erlauben" nur pro exaktem Alias / exakter App — nie für
    Aufrufe mit freien Argumenten** (sonst wird eine Dauerfreigabe zur
    Prompt-Injection-Rampe: vergifteter Memory-Inhalt → Tool-Argument →
    Shell). resource_scope + expires_at aus §5 gelten.
  - `fs.write` erst nach Bewährung von `fs.read` (verdiente Autonomie
    gilt auch für den Werkzeugkasten selbst); delete-Verben NIE automatisch.
- Ausführung: Rust-Executor (Lösung C) — Frontend sendet tool_call per IPC,
  nativer Dialog, Rust führt aus, Ergebnis zurück in den Loop, alles in
  kai_log (Provenance inkl. Modell).

## 7b. Skill 2 (später): Google Calendar

Wie ursprünglich spezifiziert (list/create/update, OAuth2 Desktop-Flow,
Refresh-Token lokal, ~30 min Setup) — das **deklarierte Egress-Modell (§6)
bleibt dafür bestehen** und wird erst mit diesem Skill scharf.

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

## 9b. Entwicklung vs. Auslieferung (bewusst getrennt)

- **Entwickeln (du + Mitentwickler): Nix.** `flake.nix`-devShell → `nix develop`
  liefert Rust, cargo-tauri, webkit reproduzierbar; kein apt/rustup, Host bleibt
  schlank, deklarativ (deine Linie). Scheitert NICHT an der schreibgeschützten
  `.zshenv` wie der imperative rustup-Weg. `setup-imperativ.sh` = Fallback für
  Nicht-Nix-Systeme.
- **Ausliefern (Endnutzer): Tauri-Bundle, KEIN Nix nötig.** `cargo tauri build`
  → eine `.AppImage` (Doppelklick, jedes Linux) oder `.deb` (Ubuntu). Der Nutzer
  braucht weder Nix noch Rust noch Compiler — nur die eine Datei.
- **Ehrliche Deployment-Einschränkung:** Die App redet mit localhost-Diensten.
  „Läuft" beim Endnutzer = App-AppImage **+** Ollama (separat installiert) **+**
  SurrealDB (KAiOSS-Container `compose.yaml`, ohne Nix) **+** optional kai-voice.
  Das ist die eigentliche Deployment-Story, getrennt von der App-Datei — in
  einer künftigen `docs/INSTALL.md` dokumentieren.

## 10. Phasen (umgestellt: Chat-Übernahme zuerst — er existiert ja schon)

- **Phase 0 — Spike:** Tauri-2-Minimalfenster, das den bestehenden
  KAiOSS-Chat-Stack lädt und gegen die laufenden localhost-Dienste
  (SurrealDB, Ollama) spricht. Beweist die Kern-These „Chat läuft in der
  Webview unverändert" in einem Tag. (Der Tool-Calling-Spike mit qwen3:8b
  wandert in Phase 3.)
- **Phase 1 — STANDALONE (eigenständige App):** ui-core-Package extrahieren,
  Desktop-Build mit adapter-static, platformAdapter (fetch↔IPC). App läuft
  bei geschlossenem KAiOSS-Dashboard. Dazu rundes Always-on-top-Bubble ↔
  Chat-Expand, Tray, Autostart; `kaichat`-DB-User (Least Privilege) +
  kai_status:chat. Chat inkl. Memory + Voice ist ab hier fest eigenständig.
- **Phase 3 — Agent-Schicht + Calendar:** Tool-Calling-Spike (qwen3:8b vs.
  qwen2.5-coder), PermissionGate, die drei Calendar-Tools, OAuth-Setup,
  kai_permission, Audit-Log.
- **Phase 4 — Recorder:** bestätigte Läufe → SKILL.md → Replay (L0→L1).
- **Phase 5 — Politur:** Sprachsteuerungs-Feinheiten, Energie-/Statusanzeigen
  (Muster aus KAiOSS #59).

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

## 12. Phase-3/4-Leitplanken (Tool-Ausführung) — VERBINDLICH

Gesammelt aus dem Gemini-Ping-Pong 11.07. Diese acht Regeln gelten beim Bau
der Agent-/Tool-Schicht (Lösung C, §2.3). Kein Docker: KAiOSSChat ist eine
native App und operiert nativ am PC — ein Container würde genau das verhindern.

1. **Rust ist der letzte Gatekeeper (Defense in Depth).** Frontend-/Adapter-
   Validierung ist UX-Komfort; die eiserne Mauer liegt in Rust. Bei jedem
   IPC-Tool-Call parst und validiert Rust `commands.json` SELBST und lehnt
   alles ab, was nicht drinsteht. Nie dem Frontend vertrauen (XSS-Vektor über
   gerenderten Modell-Output). Muster: KAiOSS hard-gated DB-Permissions.
2. **Read/Write aus `risiko` ableiten, nicht neu erfinden.** `commands.json`
   klassifiziert jeden Alias (low/medium/high/critical). `low` = darf „Immer
   erlauben" verdienen; `medium`+ = Klickpflicht. Eine Wahrheitsquelle,
   konsistent mit dem cmd-runner.
3. **Argument-Leitplanke (Read UND Write).** „Immer erlauben" NUR bei exakt
   statischem Argument (Alias ohne freie Args / Pfad aus Whitelist wie
   `~/Projekte`). Freie Argumente erfordern IMMER einen Klick — auch bei
   `fs.read`: ein gekaperter Read leakt `.env`/`~/.ssh` (Exfiltration ist
   der Blast-Radius von Read, Schaden der von Write; beide brauchen die Regel).
   delete-Verben nie automatisch.
4. **Dynamische Tool-Discovery.** Rust liest `commands.json` beim Start und
   liefert die Alias-Liste ans Frontend, das daraus das Ollama-Tool-Schema
   generiert. Neuer Alias in KAiOSS → Desktop kennt ihn nach Neustart, mit
   `risiko`-Stufe, ohne Code-Änderung. `commands.json` = EIN Vertrag für
   Schema-Generierung UND Validierung (Regel 1).
5. **Strenge Tool-Descriptions.** Lokale Modelle brauchen explizite Schemas:
   „Argument 'alias' MUSS exakt einem aus [<Liste>] sein. Erfinde nie eigene."
   Liste aus `commands.json` injiziert (nie hart eintippen — Drift).
6. **Rust-Truncation (Context-Schutz).** Tool-Ausgaben kappt der Rust-Executor
   VOR Rückgabe (z.B. 50 erste + 50 letzte Zeilen, `[…truncated…]`) — im Tool,
   nicht im Prompt, damit unumgehbar. Schützt 7B/8B-Kontextfenster.
7. **Panic Button / Prozessgruppen.** Tool-Prozesse via `setsid` in eigener
   Prozessgruppe starten (PID/PGID in Rust-State). STOP-Button killt
   Ollama-Stream UND die Gruppe: erst SIGTERM, nach Timeout SIGKILL
   (`kill -- -PGID`) — sonst überleben Enkelprozesse als Zombies.
8. **Tool-Capability ≠ installiert.** Ein Modell im Dropdown kann chatten,
   aber nicht zwingend Tool-Calling (fehlt das Tool-Template im Modelfile →
   keine `tool_calls` bzw. als Text halluziniert). Desktop erkennt das und
   sagt es ehrlich („Modell X führt keine Aktionen aus — für PC-Steuerung
   qwen2.5-coder wählen") statt still zu scheitern. Genau das macht das
   Modell-Labor (KAiOSS #45) messbar: Tool-Zuverlässigkeit als Dimension.

9. **NIEMALS `sh -c` — immer `Command::new`.** Rust führt Tool-Befehle NIE
   über eine Subshell aus (`sh -c "…"`), sondern via
   `std::process::Command::new(prog).arg(a).arg(b)`. Dann werden Shell-
   Metazeichen (`;`, `$()`, `&&`, Backticks) als harmloser String übergeben,
   nicht ausgewertet — Command-Injection ist auf OS-Ebene neutralisiert,
   selbst wenn ein gekapertes Modell `; rm -rf` als Argument liefert.
   (Dieselbe Lektion wie KAiOSS `/api/open`: `execFile` statt `exec`.)
   Gilt ZUSÄTZLICH zur Argument-Leitplanke (Regel 3) — Defense in Depth.

**Streaming-Pfad (bestätigt):** Im Desktop-Modus spricht Svelte für den
Chat/Stream WEITERHIN direkt mit Ollama (`fetch`/WS zu :11434) — NUR
Tool-Calls gehen per IPC an Rust. Streaming über den IPC-Kanal zu pipen
würde ihn verstopfen und die UI verruckeln. (Ergibt sich aus Lösung C,
hier explizit fixiert, damit's beim Bauen niemand „vereinfacht".)

**Gehirn-Reconnect (Autostart-Rennen):** Startet die App vor dem
SurrealDB-Dienst, darf `db.svelte.js` nicht crashen — der bestehende
Exponential-Backoff (MAX_RETRIES, DB_STATES.RECONNECTING; Muster wie
cmd-runner) greift, Bubble/Tray zeigt „Gehirn fehlt" (grau/blinkend) und
wird aktiv, sobald SurrealDB da ist.

**Globaler Hotkey (UX, Phase 1/5):** OS-Shortcut (z.B. Alt+Space) holt das
Bubble in den Vordergrund + Fokus ins Textfeld (Raycast-Feeling). CAVEAT
Ubuntu: unter **Wayland** sind globale Shortcuts eingeschränkt (Portal nötig),
unter X11 problemlos — Session-Typ vorher prüfen.

**Wake-Word-Falle (Phase 5, falls Hands-free):** Ein Wake-Word („Hey Kai")
darf NIE über den kai-voice-WebSocket erkannt werden — das hieße 24/7-Stream
des Raums und zerstört das Mikrofon-Release-Privacy-Feature. Erkennung lokal
im Frontend (winziges In-Browser-Modell, z.B. Picovoice Porcupine); erst
NACH erkanntem Wake-Word öffnet das bestehende PTT-Muster den kai-voice-Kanal.
