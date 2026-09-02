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
    # Same pin as eva-316's (uncommitted, as of this writing) microscope
    # build — threading.scad for the M12x0.5 boss both builds share. Kept
    # identical on purpose so merging with that branch later is a
    # near-no-op instead of two BOSL2 pins to reconcile.
    bosl2 = {
      url = "github:BelfrySCAD/BOSL2/fcfce7c763863d8e66d5f36a551d11129ec1a607";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, technic-scad, pela-blocks, bosl2 }:
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

        # tele/*.scad only needs BOSL2 (threading), not Technic/PELA — no
        # LEGO interface on this part.
        teleLib = pkgs.runCommand "testbench-tele-lib" { } ''
          mkdir -p $out
          cp -r ${bosl2} $out/BOSL2
        '';

        # Mesh analysis (trimesh + manifold3d boolean backend) so tele's
        # verification can measure the STL — body count, watertightness,
        # bounding box — instead of only rendering a picture and squinting.
        # Mirrors eva-316's own addition (uncommitted as of this writing).
        opticsPython = pkgs.python3.withPackages (ps: [
          ps.trimesh
          ps.manifold3d
          ps.numpy
          ps.scipy   # trimesh's connected-components graph engine
        ]);

        # A GOROOT gopls can use to resolve `machine` and its transitive
        # imports (device/avr, runtime/volatile, ...) when editing
        # firmware/main.go. `machine` lives in TinyGo's own TINYGOROOT/src,
        # not in any fetchable module (no go.mod there, and its imports
        # assume GOROOT-style resolution the same way tinygo's own compiler
        # does internally) — so this merges the real stdlib with exactly the
        # TinyGo-exclusive packages, via symlinks (a few MB, not a stdlib
        # copy).
        #
        # Two real snags fixed here, found by testing rather than designed
        # around: (1) copying instead of symlinking inherits the Nix store's
        # read-only directory permissions onto the destination, breaking a
        # second overlay pass — avoided entirely by symlinking, never
        # copying, real GOROOT content; (2) merging the whole `runtime`
        # directory (real + TinyGo's) trips Go's cross-platform
        # case-insensitivity guard (real `asm_386.s` vs TinyGo's
        # `asm_386.S`) — avoided by only *adding* TinyGo's runtime-exclusive
        # subdirectories rather than merging the whole directory.
        firmwareGoroot = pkgs.runCommand "testbench-firmware-goroot"
          { nativeBuildInputs = [ pkgs.tinygo ]; }
          ''
            TGR=$(tinygo env TINYGOROOT)
            GOROOT_REAL=$(tinygo env GOROOT)

            mkdir -p $out/src

            for entry in "$GOROOT_REAL"/*; do
              [ "$(basename "$entry")" = "src" ] && continue
              ln -sfn "$entry" "$out/$(basename "$entry")"
            done

            for entry in "$GOROOT_REAL"/src/*; do
              name=$(basename "$entry")
              if [ "$name" = "runtime" ]; then
                mkdir -p "$out/src/runtime"
                for sub in "$entry"/*; do
                  ln -sfn "$sub" "$out/src/runtime/$(basename "$sub")"
                done
              else
                ln -sfn "$entry" "$out/src/$name"
              fi
            done

            for name in device examples machine tinygo; do
              ln -sfn "$TGR/src/$name" "$out/src/$name"
            done
            for name in internal interrupt volatile; do
              ln -sfn "$TGR/src/runtime/$name" "$out/src/runtime/$name"
            done
          '';

        # One firmware image per device, mirroring host/cmd/ -- each is a
        # complete, standalone binary for the whole chip (these are never
        # combined; only one runs on the Uno at a time), built from
        # firmware/cmd/<name>.
        mkFirmware = name: pkgs.stdenv.mkDerivation {
          pname = "testbench-uno-firmware-${name}";
          version = "0.1.0";
          src = ./firmware;
          nativeBuildInputs = [ pkgs.tinygo ];
          # tinygo shells out to `go` underneath, which wants a writable $HOME
          # for its cache; the build sandbox gives none by default.
          buildPhase = ''
            export HOME=$TMPDIR
            tinygo build -target=arduino-uno -o ${name}.hex ./cmd/${name}
          '';
          installPhase = ''
            mkdir -p $out
            cp ${name}.hex $out/
          '';
        };
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

          firmware-probe = mkFirmware "probe";
          firmware-light-breathe = mkFirmware "light-breathe";

          optics-calibration = pkgs.runCommand "testbench-optics-calibration"
            { nativeBuildInputs = [ pkgs.openscad ]; }
            ''
              mkdir -p build $out
              cp ${./optics/calibration.scad} build/calibration.scad
              ln -s ${opticsLib} build/lib
              openscad -o $out/calibration.stl -D '_large_nozzle=false' build/calibration.scad
            '';

          # nix build .#tele-stl && ls result/ — the EVA-319 nosepiece,
          # emitted via nosepiece_printable() (boss down — see nosepiece.scad
          # for why that orientation and not the as-modelled one).
          tele-stl = pkgs.runCommand "testbench-tele-stl"
            { nativeBuildInputs = [ pkgs.openscad ]; }
            ''
              mkdir -p build $out
              cp ${./tele}/*.scad build/
              ln -s ${teleLib} build/lib
              cat > build/_nosepiece.scad <<EOF
              use <nosepiece.scad>
              nosepiece_printable();
              EOF
              openscad -o $out/nosepiece.stl build/_nosepiece.scad
            '';

          # Exposed directly for inspection/testing: `nix build .#firmware-goroot`
          # then `GOROOT=./result GOFLAGS=-tags=arduino_uno gopls check firmware/main.go`.
          firmware-goroot = firmwareGoroot;
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
            opticsPython
          ];
          shellHook = ''
            if [ ! -e optics/lib ]; then
              ln -sfn ${opticsLib} optics/lib
              echo "optics/lib -> Nix store (pinned via flake inputs, see flake.nix)"
            fi
            if [ ! -e tele/lib ]; then
              ln -sfn ${teleLib} tele/lib
              echo "tele/lib -> Nix store (pinned via flake inputs, see flake.nix)"
            fi
            ln -sfn ${firmwareGoroot} firmware/.gopls-goroot
          '';
        };
      }
    );
}
