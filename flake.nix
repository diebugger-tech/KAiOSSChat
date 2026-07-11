{
  description = "KAiOSSChat — DEPRECATED (Plan C gescheitert: Nix-rustc + System-GTK/glibc = ABI-Konflikt, 'stack smashing'). Hauptweg ist jetzt Plan D: ./setup-imperativ.sh + ./run.sh (rustup + apt)";

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
            # Nix' gewrappter pkg-config filtert /usr-Pfade (Purity-Filter)
            # und findet System-cairo/pango/gdk-pixbuf NICHT, obwohl die
            # .pc-Dateien da sind. Deshalb: sys-Crates hart aufs SYSTEM-
            # pkg-config zeigen (die Rust-pkg-config-Crate respektiert $PKG_CONFIG).
            if [ -x /usr/bin/pkg-config ]; then
              export PKG_CONFIG=/usr/bin/pkg-config
            else
              echo "⚠️  /usr/bin/pkg-config fehlt: sudo apt install -y pkg-config"
            fi
            echo "🦀 KAiOSSChat Dev-Shell (Plan C: System-webkit)"
            echo "   Rust: $(rustc --version 2>/dev/null || echo n/a) · Tauri: $(cargo tauri --version 2>/dev/null || echo n/a)"
            if ! "''${PKG_CONFIG:-pkg-config}" --exists webkit2gtk-4.1 2>/dev/null; then
              echo ""
              echo "⚠️  System-webkit-Dev-Pakete fehlen. EINMALIG installieren:"
              echo "    sudo apt install -y libwebkit2gtk-4.1-dev libgtk-3-dev \\"
              echo "        libsoup-3.0-dev libjavascriptcoregtk-4.1-dev \\"
              echo "        libayatana-appindicator3-dev librsvg2-dev"
            else
              echo "   webkit2gtk-4.1: $("''${PKG_CONFIG:-pkg-config}" --modversion webkit2gtk-4.1) (System) ✅"
            fi
            echo "   Start: ./run.sh"
          '';
        };
      });
}
