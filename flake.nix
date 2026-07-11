{
  description = "KAiOSSChat — Tauri 2 Dev-Shell (Plan C: Rust-Toolchain aus Nix, webkit/GTK vom Ubuntu-System — kein Nix-GL-Konflikt)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = pkgs.mkShell {
          # NUR die Toolchain aus Nix. webkit2gtk/GTK/libsoup kommen vom
          # System (apt), damit die kompilierte App die GPU-/EGL-Treiber des
          # Hosts nativ nutzt — behebt "EGL_BAD_PARAMETER" (Nix-GL-auf-Ubuntu).
          buildInputs = with pkgs; [
            rustc
            cargo
            cargo-tauri
            pkg-config
          ];

          shellHook = ''
            # System-pkg-config-Pfade zuerst, damit cargo das SYSTEM-webkit
            # findet (nicht ein Nix-webkit). Keine Nix-LD_LIBRARY_PATH-
            # Ueberschreibung -> zur Laufzeit laedt der System-Loader die
            # System-webkit + System-Mesa/EGL.
            export PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:''${PKG_CONFIG_PATH:-}"
            echo "🦀 KAiOSSChat Dev-Shell (Plan C: System-webkit)"
            echo "   Rust: $(rustc --version 2>/dev/null || echo n/a) · Tauri: $(cargo tauri --version 2>/dev/null || echo n/a)"
            if ! pkg-config --exists webkit2gtk-4.1 2>/dev/null; then
              echo ""
              echo "⚠️  System-webkit-Dev-Pakete fehlen. EINMALIG installieren:"
              echo "    sudo apt install -y libwebkit2gtk-4.1-dev libgtk-3-dev \\"
              echo "        libsoup-3.0-dev libjavascriptcoregtk-4.1-dev \\"
              echo "        libayatana-appindicator3-dev librsvg2-dev"
            else
              echo "   webkit2gtk-4.1: $(pkg-config --modversion webkit2gtk-4.1) (System) ✅"
            fi
            echo "   Start: ./run.sh"
          '';
        };
      });
}
