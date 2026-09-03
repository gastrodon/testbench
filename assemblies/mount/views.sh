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

# --viewall --autocenter rather than a hand-picked distance: these parts
# span ~250mm and a fixed camera distance silently crops the thing you
# were trying to look at. A cropped review render is worse than none --
# it looks like a finished picture of a smaller part.
shot() { # name, rotation, extra -D args...
    local name=$1 rot=$2; shift 2
    openscad --projection=o --imgsize=$SZ --camera="0,0,0,$rot,0" \
             --viewall --autocenter \
             "$@" -o "build/views/$name.png" assembly.scad 2>/dev/null
    echo "  build/views/$name.png"
}

part_shot() { # file, name, rotation
    openscad --projection=o --imgsize=$SZ --camera="0,0,0,$3,0" \
             --viewall --autocenter \
             -o "build/views/part-$2.png" "$1.scad" 2>/dev/null
    echo "  build/views/part-$2.png"
}

echo "orthographic views:"
# Down the ALTITUDE axis (+Y). This is the view that shows whether the
# 160T wheel clears the deck and whether the tube fouls the motor.
for a in 0 45 90; do
    shot "alt-axis-a$a" "90,0,0" -D "alt_angle=$a"
done
# Down the AZIMUTH axis (+Z), from above -- shows the belt triangle and
# whether the motors are on the plate.
shot "az-axis-top" "0,0,0" -D "alt_angle=0"
# Front elevation, the stack of datums: plate / thrust / deck / tine.
shot "front" "90,0,90" -D "alt_angle=45"
# Single parts, isolated, down their own axis.
part_shot alt_rotor alt_rotor "0,0,0"        # down the wheel axis
part_shot alt_rotor alt_rotor-side "90,0,0"  # across it: the stepped axle
part_shot yoke      yoke       "90,0,0"
part_shot base      base       "0,0,0"
part_shot az_table  az_table   "90,0,0"
part_shot gt2_coupon coupon    "0,0,0"
