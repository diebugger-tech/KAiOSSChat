{
  description = "KAiOSSChat — Tauri 2 Desktop-Companion (reproduzierbare Dev-Shell, kein apt/rustup)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Tauri-2 Systembibliotheken (Linux). Tauri v2 nutzt webkit2gtk 4.1
        # + libsoup3 — NICHT die 4.0/2er-Varianten.
        tauriDeps = with pkgs; [
          webkitgtk_4_1
          gtk3
          libsoup_3
          openssl
          librsvg
          libayatana-appindicator   # Tray-Icon
          glib-networking           # TLS im Webview (fetch zu localhost:11434 etc.)
        ];

        # Kein nodejs hier: die Tauri-Shell braucht es nicht. Der KAiOSS-Stack
        # (Vite/Frontend) läuft über sein eigenes start.sh mit dem Node aus
        # Home Manager. `cargo tauri dev` lädt nur die bereits laufende devUrl.
        buildTools = with pkgs; [
          rustc
          cargo
          cargo-tauri
          pkg-config
        ];
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = tauriDeps ++ buildTools;

          # Ohne diese Env findet der Rust-Linker webkit/gtk nicht und
          # der Webview bekommt kein TLS (glib-networking-Module).
          shellHook = ''
            export PKG_CONFIG_PATH="${pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" tauriDeps}"
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath tauriDeps}:$LD_LIBRARY_PATH"
            export GIO_EXTRA_MODULES="${pkgs.glib-networking}/lib/gio/modules"
            # Webkit-Renderfixes (Nix/Wayland/AMD):
            # DMABUF-Renderer AUS behebt "Could not create default EGL display:
            # EGL_BAD_PARAMETER" — der HW-Pfad scheitert unter Nix-webkit.
            export WEBKIT_DISABLE_DMABUF_RENDERER=1
            export WEBKIT_DISABLE_COMPOSITING_MODE=1
            echo "🦀 KAiOSSChat Dev-Shell — reproduzierbar, kein apt/rustup."
            echo "   Rust: $(rustc --version 2>/dev/null || echo 'n/a')"
            echo "   Tauri: $(cargo tauri --version 2>/dev/null || echo 'n/a')"
            echo "   Start: ./run.sh   (oder: cd src-tauri && cargo tauri dev)"
          '';
        };
      });
}
