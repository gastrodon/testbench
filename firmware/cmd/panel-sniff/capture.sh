#!/usr/bin/env bash
# capture.sh: log panel-sniff's serial output AND record the overhead bench
# camera at the same time, both wall-clock timestamped, so a button press
# seen on video lines up directly against the data line that moved.
#
# Usage:
#   ./capture.sh [basename]
#
# Writes <basename>.log (serial, one line per event, HH:MM:SS prefix)
# and <basename>.mp4 (video, live HH:MM:SS burned into each frame).
# Defaults to panel-capture-<timestamp> under the current directory.
#
# Ctrl-C stops both and exits cleanly. If you get "Permission denied" on
# the serial device and haven't logged out since being added to the
# dialout group, run instead:
#   sg dialout -c './capture.sh'
set -euo pipefail

if pgrep -f 'cat -u /dev/ttyACM' >/dev/null; then
  echo "a capture already appears to be running (found a 'cat -u /dev/ttyACM*' process) -- stop it first" >&2
  exit 1
fi

device="${1:-/dev/ttyACM0}"
cam="${CAM_DEVICE:-/dev/hw-bench/cam0}"
base="${2:-panel-capture-$(date +%Y%m%d-%H%M%S)}"
logfile="${base}.log"
video="${base}.mp4"

if [ ! -e "$cam" ]; then
  for fallback in /dev/video0 /dev/video1; do
    [ -e "$fallback" ] && cam="$fallback" && break
  done
fi

stty -F "$device" 115200 raw -echo

echo "serial:  $device -> $logfile"
echo "video:   $cam -> $video (timestamp burned into each frame)"
echo "ctrl-c to stop both"
echo "board resets on open -- first serial line may take ~2s to appear"

# -movflags frag_keyframe+empty_moov writes the mp4 index up front instead
# of trailing it at EOF, so the file stays playable even if ffmpeg is ever
# killed without a chance to finalize -- belt-and-suspenders alongside the
# graceful SIGINT below (plain SIGTERM skipped ffmpeg's own finalization
# and left an unplayable "moov atom not found" file the first time).
ffmpeg -hide_banner -loglevel error \
  -f v4l2 -input_format mjpeg -video_size 1920x1080 -framerate 30 -i "$cam" \
  -vf "drawtext=font=monospace:text='%{localtime}':x=10:y=10:fontsize=36:fontcolor=yellow:box=1:boxcolor=black@0.5" \
  -c:v libx264 -preset veryfast -movflags frag_keyframe+empty_moov -y "$video" &
ffmpeg_pid=$!

cleanup() {
  kill -INT "$ffmpeg_pid" 2>/dev/null || true
  wait "$ffmpeg_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# A per-line `date` fork here (bash `while read; do date; done`) is slow
# enough that under CPU load from the concurrent ffmpeg encode, the reader
# fell behind the firmware's output rate and the kernel's serial buffer
# silently dropped/merged bytes -- corrupting lines. gawk timestamps inside
# one long-running process instead of forking per line, avoiding that.
stdbuf -oL cat -u "$device" \
  | gawk '{ sub(/\r$/, ""); print strftime("%H:%M:%S", systime()) " " $0; fflush() }' \
  | tee -a "$logfile"
