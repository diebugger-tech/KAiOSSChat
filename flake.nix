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

        buildTools = with pkgs; [
          rustc
          cargo
          cargo-tauri
          pkg-config
          nodejs_20        # nur für den KAiOSS-Frontend-Build, nicht die Shell selbst
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
            # Bekannter Nix+Webkit-Renderfix (schwarzes Fenster vermeiden):
            export WEBKIT_DISABLE_COMPOSITING_MODE=1
            echo "🦀 KAiOSSChat Dev-Shell — reproduzierbar, kein apt/rustup."
            echo "   Rust: $(rustc --version 2>/dev/null || echo 'n/a')"
            echo "   Tauri: $(cargo tauri --version 2>/dev/null || echo 'n/a')"
            echo "   Start: ./run.sh   (oder: cd src-tauri && cargo tauri dev)"
          '';
        };
      });
}
