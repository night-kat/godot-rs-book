{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    fenix,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      version = "4.6";
      godot-stable = pkgs.fetchurl {
        url = "https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_linux.x86_64.zip";
        hash = "sha256-a8xZ39HWcOkYx36uBugrncVpneE9NT3DpLO2swe23AY=";
      };

      fenixLib = fenix.packages."x86_64-linux";
      rustToolchain = fenixLib.stable.toolchain;

      buildInputs = with pkgs; [
        alsa-lib
        dbus
        fontconfig
        libGL
        libpulseaudio
        libxkbcommon
        makeWrapper
        mesa
        patchelf
        speechd
        udev
        vulkan-loader
        libX11
        libXcursor
        libXext
        libXfixes
        libXi
        libXinerama
        libXrandr
        libXrender
      ];

      godot-unwrapped = pkgs.stdenv.mkDerivation {
        pname = "godot";
        version = "4.6";

        src = godot-stable;
        nativeBuildInputs = with pkgs; [unzip autoPatchelfHook];
        inherit buildInputs;

        dontAutoPatchelf = false;

        unpackPhase = ''
          mkdir source
          unzip $src -d source
        '';

        installPhase = ''
          mkdir -p $out/bin
          cp source/Godot_v${version}-stable_linux.x86_64 $out/bin/godot
        '';
      };

      godot-bin = pkgs.buildFHSEnv {
        name = "godot";
        targetPkgs = pkgs: buildInputs ++ [godot-unwrapped];
        runScript = "godot";
      };
    in {
      devShell = pkgs.mkShell {
        buildInputs = [godot-bin];
        packages = [rustToolchain pkgs.bacon pkgs.pkg-config];
        env = {
          RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
        };

        # Commands that run when entering the shell
        shellHook = ''
          export CARGO_CLIPPY_FLAGS='-- -W clippy::pedantic -W clippy::nursery -W clippy::unwrap_used'
          neovide&
          godot&
        '';
      };
    });
}
