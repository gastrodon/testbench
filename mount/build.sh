#!/usr/bin/env bash
# Render every top-level part to STL. STL export always takes the full CGAL
# path, never preview -- preview can hide boolean errors a full render
# surfaces (cad-design: "Looking"), and check.py needs real meshes anyway.
#
# --hardwarnings is deliberate: OpenSCAD's default is to warn on an undef
# value and carry on, producing a watertight model with a feature quietly
# missing. That is the single dominant defect class here (rule 2), so
# warnings are promoted to failures.
#
# Exits non-zero if any part fails, so this is usable as a gate.
set -u
cd "$(dirname "$0")"
mkdir -p build
rc=0
parts=(gt2_coupon alt_rotor yoke az_table base)
for p in "${parts[@]}"; do
    printf '%-12s ' "$p"
    if err=$(openscad --hardwarnings -o "build/$p.stl" "$p.scad" 2>&1); then
        # A part that renders to an EMPTY stl is the silent failure rule 2
        # is about: valid, watertight, and missing. Size-check it.
        sz=$(stat -c%s "build/$p.stl")
        if [ "$sz" -lt 1000 ]; then
            echo "EMPTY (${sz}B) -- rendered without error but produced no geometry"
            rc=1
        else
            echo "ok (${sz}B)"
        fi
    else
        echo "FAIL"
        echo "$err" | sed 's/^/    /'
        rc=1
    fi
done

printf '%-12s ' "assembly"
if err=$(openscad --hardwarnings -o build/assembly.stl assembly.scad 2>&1); then
    echo "ok ($(stat -c%s build/assembly.stl)B)"
else
    echo "FAIL"; echo "$err" | sed 's/^/    /'; rc=1
fi

exit $rc
