#!/usr/bin/env bash
# Canonical review renders.
#
# ORTHOGRAPHIC, down the axis of interest -- not isometric. A perspective
# isometric hides axial offsets and makes tangency ambiguous; in this
# project's history three separate real defects were simultaneously
# visible in one orthographic axis view and invisible in every isometric
# rendered before it (cad-design: "Looking").
#
# PREVIEW mode, not --render: a full CGAL render discards color(), and
# these images exist to be looked at. Geometry validity is check.py's job,
# not this script's -- the two methods catch different, non-overlapping
# defect classes and neither substitutes for the other.
set -eu
cd "$(dirname "$0")"
mkdir -p build/views
SZ=1400,1000

shot() { # name, camera, extra -D args...
    local name=$1 cam=$2; shift 2
    openscad --projection=o --imgsize=$SZ --camera="$cam" \
             "$@" -o "build/views/$name.png" assembly.scad 2>/dev/null
    echo "  build/views/$name.png"
}

echo "orthographic views:"
# Down the ALTITUDE axis (+Y). This is the view that shows whether the
# 160T wheel clears the deck and whether the tube fouls the motor.
for a in 0 45 90; do
    shot "alt-axis-a$a" "0,0,60,90,0,0,320" -D "alt_angle=$a"
done
# Down the AZIMUTH axis (+Z), from above -- shows the belt triangle and
# whether the motors are on the plate.
shot "az-axis-top" "0,0,60,0,0,0,340" -D "alt_angle=0"
# Front elevation, the stack of datums: plate / thrust / deck / tine.
shot "front" "0,0,60,90,0,90,320" -D "alt_angle=45"
# Single parts, isolated, down their own axis.
openscad --projection=o --imgsize=$SZ --camera=0,0,0,90,0,0,160 \
         -o build/views/part-alt_rotor.png alt_rotor.scad 2>/dev/null
echo "  build/views/part-alt_rotor.png"
openscad --projection=o --imgsize=$SZ --camera=0,0,0,90,0,0,200 \
         -o build/views/part-yoke.png yoke.scad 2>/dev/null
echo "  build/views/part-yoke.png"
openscad --projection=o --imgsize=$SZ --camera=0,0,0,0,0,0,200 \
         -o build/views/part-base.png base.scad 2>/dev/null
echo "  build/views/part-base.png"
