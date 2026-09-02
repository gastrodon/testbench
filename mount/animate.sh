#!/usr/bin/env bash
# Render the range-of-motion animation.
#
# PREVIEW mode, not --render: a full CGAL render discards color() and the
# result is an unreadable monochrome blob. This animation exists to be
# looked at; geometry validity is check.py's job (AGENTS.md).
#
# The camera is FIXED across every frame -- no --viewall. Auto-fitting per
# frame rescales the picture as the telescope swings, which reads as the
# mount growing and shrinking rather than the scope moving, and makes it
# impossible to judge whether anything actually collides.
set -eu
cd "$(dirname "$0")"
FRAMES=${1:-72}
OUT=build/anim
rm -rf "$OUT"; mkdir -p "$OUT"

# Framed wide enough to hold the telescope through the whole swing,
# centred back along the tube rather than on the mount -- at 90 degrees the
# tail drops ~320mm and it belongs in shot, because that collision is the
# design's one open question and cropping it out would be flattering.
CAM="-40,0,10,70,0,22,1150"

echo "rendering $FRAMES frames..."
openscad --projection=p --imgsize=1000,750 --camera="$CAM" \
         --animate "$FRAMES" -o "$OUT/frame.png" animate.scad 2>/dev/null

n=$(ls "$OUT"/frame*.png 2>/dev/null | wc -l)
echo "  $n frames"
[ "$n" -gt 0 ] || { echo "no frames produced"; exit 1; }

ffmpeg -y -loglevel error -framerate 20 -pattern_type glob \
       -i "$OUT/frame*.png" \
       -vf "scale=1000:-2:flags=lanczos" \
       -c:v libx264 -pix_fmt yuv420p -crf 20 build/range-of-motion.mp4

# GIF too -- it embeds in Linear and GitHub where an mp4 will not.
ffmpeg -y -loglevel error -framerate 20 -pattern_type glob \
       -i "$OUT/frame*.png" \
       -vf "fps=20,scale=760:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" \
       -loop 0 build/range-of-motion.gif

ls -la build/range-of-motion.mp4 build/range-of-motion.gif
