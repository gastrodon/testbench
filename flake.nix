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
    # Threads (threading.scad) + gears/racks (gears.scad) for the
    # prime-focus microscope build — real helical threads and a proper
    # rack-and-pinion instead of hand-rolled geometry.
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
          cp -r ${bosl2} $out/BOSL2
        '';

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

        # Mesh analysis for the optics parts: trimesh drives the queries,
        # manifold3d is the boolean engine (trimesh ships no boolean
        # backend of its own — without this, .intersection() has nothing
        # to call). Lets optics/check.py answer "do these two parts
        # interfere" instead of rendering a picture and squinting at it.
        opticsPython = pkgs.python3.withPackages (ps: [
          ps.trimesh
          ps.manifold3d
          ps.numpy
          # trimesh's proximity queries (nearest.on_surface) import rtree
          # and scipy lazily — absent, they fail at call time rather than
          # import time, so they are not optional here.
          ps.rtree
          ps.scipy
        ]);

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

          # STLs for every printable part, each already rotated into its
          # print orientation so the slicer needs no manual fiddling.
          #   nix build .#optics-stl && ls result/
          optics-stl = pkgs.runCommand "testbench-optics-stl"
            {
              nativeBuildInputs = [ pkgs.openscad ];
              # The coupons label themselves with text(), and text() with
              # no font available renders NOTHING — a warning on stderr,
              # exit 0, and a watertight STL with no label on it. The
              # sandbox has no system fontconfig, so the font has to be an
              # explicit input or every label silently disappears in the
              # one build that is supposed to be reproducible.
              FONTCONFIG_FILE = pkgs.makeFontsConf {
                fontDirectories = [ pkgs.dejavu_fonts ];
              };
            }
            ''
              mkdir -p build $out
              cp ${./optics}/*.scad build/
              ln -s ${opticsLib} build/lib

              emit () {  # name, source file, body (already oriented)
                cat > build/_$1.scad <<EOF
              include <params.scad>
              include <lib/BOSL2/std.scad>
              include <lib/BOSL2/gears.scad>
              include <lib/BOSL2/threading.scad>
              \$slop = 0.1;
              use <$2>
              $3
              EOF
                openscad -o $out/$1.stl build/_$1.scad
              }

              # base: floor on the bed, bore up — as modelled
              emit base_mount objective_focus_mount.scad "base_mount();"

              # carrier: PCB face DOWN, telescope tube UP. As modelled the
              # tube hangs in -Z, so flip it.
              emit carrier pcb_carrier.scad "pcb_carrier_printable();"

              # pinion: ONE part now — knob, shaft, gear. Printed knob
              # DOWN (28mm disc = bed adhesion) with the gear on top.
              emit pinion focus_pinion.scad "focus_pinion_printable();"

              # technic adapter: baseplate DOWN, pins UP — as modelled
              openscad -o $out/technic_adapter.stl build/technic_adapter.scad

              # test pieces
              openscad -o $out/slide_coupon.stl build/slide_coupon.scad

              # Coupons for the two open tolerance questions. Both are
              # built from the SAME geometry as the real parts (clip_coupon
              # literally intersects base_mount), so a pass transfers
              # directly instead of only proving the coupon fits.
              openscad -o $out/m12_coupon.stl build/m12_coupon.scad
              openscad -o $out/clip_coupon.stl build/clip_coupon.scad
            '';

          optics-calibration = pkgs.runCommand "testbench-optics-calibration"
            { nativeBuildInputs = [ pkgs.openscad ]; }
            ''
              mkdir -p build $out
              cp ${./optics/calibration.scad} build/calibration.scad
              ln -s ${opticsLib} build/lib
              openscad -o $out/calibration.stl -D '_large_nozzle=false' build/calibration.scad
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
            pkgs.imagemagick   # montage: canonical-view contact sheets
            # Slicing + inspection for the optics parts. prusa-slicer's
            # CLI generates the gcode; prusa-gcodeviewer opens a sliced
            # file to step through layer by layer, which is the only way
            # to actually SEE a toolpath before committing the machine to
            # it. CuraEngine was dropped from nixpkgs, so this is the
            # supported CLI slicer here.
            pkgs.prusa-slicer
          ];
          shellHook = ''
            if [ ! -e optics/lib ]; then
              ln -sfn ${opticsLib} optics/lib
              echo "optics/lib -> Nix store (pinned via flake inputs, see flake.nix)"
            fi
            ln -sfn ${firmwareGoroot} firmware/.gopls-goroot
          '';
        };
      }
    );
}
