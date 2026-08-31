#!/usr/bin/env bash
# Vendors the two external OpenSCAD libraries this directory's designs
# depend on, pinned to specific commits for reproducibility. Not checked
# into git (see .gitignore) — third-party MIT/CC-BY-SA code, re-fetch
# instead of vendoring copies.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

fetch() {
  local repo="$1" dir="$2" commit="$3"
  if [ -d "$dir" ]; then
    echo "$dir already present, skipping (rm -rf to re-fetch)"
    return
  fi
  git clone --quiet "$repo" "$dir"
  git -C "$dir" checkout --quiet "$commit"
  echo "fetched $dir @ $commit"
}

# Technic-specific geometry: beams, pins, axles, gears (no studs).
fetch https://github.com/cfinke/Technic.scad lib/Technic.scad 41f17a4696b582850097a2e3779348bc27c87f47

# Parametric Technic-compatible parts tuned for FDM printing (top/bottom/axle
# fit tweaks per-printer, per-material) — this is the one with the
# calibration beam.
fetch https://github.com/paulirotta/PELA-blocks lib/PELA-blocks 0e7dcc9df37e21bbf4e59dcd356259579bb91ba8
