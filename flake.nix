{
  description = "Bench Uno firmware + host client + microscope-coupler optics tooling";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Pinned by commit, same revs fetch-libs.sh used to use — now content-addressed
    # and hash-verified by Nix instead of an imperative git clone script.
    technic-scad = {
      url = "github:cfinke/Technic.scad/41f17a4696b582850097a2e3779348bc27c87f47";
      flake = false;
    };
    pela-blocks = {
      url = "github:paulirotta/PELA-blocks/0e7dcc9df37e21bbf4e59dcd356259579bb91ba8";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, technic-scad, pela-blocks }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Assembles the two vendored libraries into the lib/Technic.scad,
        # lib/PELA-blocks layout optics/*.scad already expects, so no .scad
        # files need to change to consume this.
        opticsLib = pkgs.runCommand "testbench-optics-lib" { } ''
          mkdir -p $out
          cp -r ${technic-scad} $out/Technic.scad
          cp -r ${pela-blocks} $out/PELA-blocks
        '';
      in
      {
        packages = {
          probe = pkgs.buildGoModule {
            pname = "testbench-probe";
            version = "0.1.0";
            src = ./host;
            subPackages = [ "cmd/probe" ];
            vendorHash = null; # host/go.mod has zero external deps (stdlib only)
            meta.mainProgram = "probe"; # binary is named after cmd/probe, not pname
          };

          firmware = pkgs.stdenv.mkDerivation {
            pname = "testbench-uno-firmware";
            version = "0.1.0";
            src = ./firmware;
            nativeBuildInputs = [ pkgs.tinygo ];
            # tinygo shells out to `go` underneath, which wants a writable $HOME
            # for its cache; the build sandbox gives none by default.
            buildPhase = ''
              export HOME=$TMPDIR
              tinygo build -target=arduino-uno -o testbench-uno.hex .
            '';
            installPhase = ''
              mkdir -p $out
              cp testbench-uno.hex $out/
            '';
          };

          optics-calibration = pkgs.runCommand "testbench-optics-calibration"
            { nativeBuildInputs = [ pkgs.openscad ]; }
            ''
              mkdir -p build $out
              cp ${./optics/calibration.scad} build/calibration.scad
              ln -s ${opticsLib} build/lib
              openscad -o $out/calibration.stl -D '_large_nozzle=false' build/calibration.scad
            '';
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.go
            pkgs.tinygo
            pkgs.avrdude
            pkgs.arduino-cli
            pkgs.openscad
            pkgs.esptool
            pkgs.usbutils
          ];
          shellHook = ''
            if [ ! -e optics/lib ]; then
              ln -sfn ${opticsLib} optics/lib
              echo "optics/lib -> Nix store (pinned via flake inputs, see flake.nix)"
            fi
          '';
        };
      }
    );
}
