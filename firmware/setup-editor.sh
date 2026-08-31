#!/usr/bin/env bash
# Builds a merged GOROOT that gopls (and therefore VSCodium's Go extension)
# can use to resolve "machine" and its transitive imports for editing
# firmware/main.go. Doesn't touch anything used to actually build the
# firmware — that's still `tinygo build`, unaffected by this.
#
# Why this exists: `machine` lives in TinyGo's own TINYGOROOT/src, not in
# any GOROOT or GOPATH gopls already knows about — it's not a fetchable Go
# module (no go.mod, and its own imports like device/avr and
# runtime/volatile are meant to be resolved the same GOROOT-relative way,
# not as a self-contained dependency graph). So `go get`, a go.mod
# `replace`, and GOPATH are all the wrong tool here: nothing to fetch,
# nothing that resolves as a module. The fix is giving gopls a GOROOT that
# has both the real stdlib AND TinyGo's exclusive packages, matching what
# `tinygo build` already does internally (check TINYGOROOT/src first, fall
# back to GOROOT/src) — but tinygo's compiler does that resolution itself
# and gopls has no equivalent, hence needing a real merged directory.
#
# Verified (see git log / PROTOCOL discussion): naive whole-tree merges hit
# two real snags before this shape was right —
#   1. copying (cp -rs) inherited the Nix store's read-only directory
#      permissions onto the destination, breaking the second overlay pass.
#      Fixed by symlinking per-top-level-directory instead of copying.
#   2. merging the whole `runtime` directory (real Go's + TinyGo's) hit a
#      hard Go toolchain error: a cross-platform case-insensitivity guard
#      trips on real Go's `asm_386.s` vs TinyGo's `asm_386.S` coexisting.
#      Fixed by only ADDING TinyGo's runtime-exclusive subdirectories
#      (internal, interrupt, volatile) rather than merging every file.
set -euo pipefail

DEST="${1:-$HOME/.cache/testbench-firmware-goroot}"
TGR=$(tinygo env TINYGOROOT)
GOROOT_REAL=$(tinygo env GOROOT)

rm -rf "$DEST"
mkdir -p "$DEST/src"

for entry in "$GOROOT_REAL"/*; do
  [ "$(basename "$entry")" = "src" ] && continue
  ln -sfn "$entry" "$DEST/$(basename "$entry")"
done

for entry in "$GOROOT_REAL"/src/*; do
  name=$(basename "$entry")
  if [ "$name" = "runtime" ]; then
    # Needs to be a real (writable) directory since TinyGo adds
    # subpackages alongside the real ones rather than replacing the
    # whole thing — a plain directory symlink can't have things added
    # inside it (it'd be adding files under a read-only Nix store path).
    mkdir -p "$DEST/src/runtime"
    for sub in "$entry"/*; do
      ln -sfn "$sub" "$DEST/src/runtime/$(basename "$sub")"
    done
  else
    ln -sfn "$entry" "$DEST/src/$name"
  fi
done

# TinyGo-exclusive packages with no real-stdlib counterpart at all.
for name in device examples machine tinygo; do
  ln -sfn "$TGR/src/$name" "$DEST/src/$name"
done
# TinyGo-exclusive runtime subpackages (real Go's runtime has no
# equivalents at these paths, so no collision).
for name in internal interrupt volatile; do
  ln -sfn "$TGR/src/runtime/$name" "$DEST/src/runtime/$name"
done

echo "Merged GOROOT built at: $DEST"
echo "Verify with: GOROOT=$DEST GOFLAGS=-tags=arduino_uno gopls check main.go"
