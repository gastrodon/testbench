#!/usr/bin/env bash
# Render every part. --hardwarnings, so an ignored-unknown-variable warning
# is a build failure rather than a silently missing feature (rule 2).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
# The payload proxy is ../mount's REAL base, so it has to exist.
[ -f ../mount/build/base.stl ] || (cd ../mount && ./build.sh)
for p in pedestal az_column yoke az_pinion az_handle tilt_platter \
         tilt_gear tilt_handle tripod_nut; do
    printf '%-14s ' "$p"
    if openscad -o "build/$p.stl" --hardwarnings "$p.scad" 2>"build/$p.log"; then
        printf 'ok (%sB)\n' "$(stat -c%s "build/$p.stl")"
    else
        printf 'FAILED\n'; sed -n '1,20p' "build/$p.log"; exit 1
    fi
done

# Print-oriented copies. The assembly-frame STLs above are what check.py
# measures; these are what a slicer wants, and they are a DIFFERENT
# transform (rule 5). Kept in a separate directory so the two can never be
# confused for each other.
mkdir -p build/print
for p in pedestal az_column yoke az_pinion az_handle tilt_platter \
         tilt_gear tilt_handle tripod_nut; do
    printf 'print/%-11s ' "$p"
    if openscad -o "build/print/$p.stl" --hardwarnings \
                -D "part=\"$p\"" print.scad 2>"build/print/$p.log"; then
        printf 'ok\n'
    else
        printf 'FAILED\n'; sed -n '1,12p' "build/print/$p.log"; exit 1
    fi
done
# Landing heights are MEASURED off the meshes, never written into
# print.scad. See drop_to_bed.py for why.
python3 drop_to_bed.py
