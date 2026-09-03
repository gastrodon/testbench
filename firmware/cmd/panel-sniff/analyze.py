#!/usr/bin/env python3
"""analyze.py: find discrete button-press events in a panel-sniff capture.log.

Usage: analyze.py <capture.log>

panel-sniff (v2, digital-edge mode) streams one line per logic transition:
    <elapsed_us> <pin> <0|1>
prefixed by capture.sh with a wall-clock HH:MM:SS timestamp:
    <HH:MM:SS> <elapsed_us> <pin> <0|1>

The toy's idle scan is a steady rhythm (A1 pulses roughly every ~40ms, A2 on
a slower cadence) -- a real button press should show up as a deviation from
that rhythm: a burst of unusually dense activity, a silence gap where the
scan pauses, or both. This script finds every such deviation, in order, so
it can be matched 1:1 against an announced press sequence without needing
synchronized timestamps.
"""
import re
import statistics
import sys

LINE_RE = re.compile(r"^(\d\d:\d\d:\d\d) (\d+) (A\d) (\d)$")
BUCKET_US = 200_000  # 200ms
GAP_US = 500_000  # 500ms
BURST_FACTOR = 2.5  # flag buckets denser than this multiple of the idle median


def parse(path):
    """Returns events in receive order (file order), NOT sorted by the
    firmware's elapsed_us. The board is only reset (elapsed_us restarting
    near 0) on a fresh DTR toggle; repeated capture.sh runs against an
    already-running board share one continuous counter, and a burst of
    bytes buffered by the kernel before a reconnect can arrive stamped
    with a wall-clock second that doesn't match when they actually
    happened. File/receive order is always correct; the counter's
    absolute value across a reconnect boundary is not."""
    events = []
    with open(path) as f:
        for line in f:
            m = LINE_RE.match(line.strip())
            if not m:
                continue
            wall, us, pin, level = m.groups()
            events.append((int(us), pin, int(level), wall))
    return events


BOUNDARY_US = 120_000_000  # 120s -- a jump bigger than this is a reconnect
# artifact (see parse docstring), not a real silence; nothing in this
# protocol's idle scan or observed "busy" states runs anywhere near that long.


def segments(events):
    """Split file-order events into runs with no backward or absurdly-large
    forward jump between consecutive elapsed_us values -- each run is one
    span of genuinely continuous, orderable time."""
    if not events:
        return []
    runs = [[events[0]]]
    for i in range(1, len(events)):
        dt = events[i][0] - events[i - 1][0]
        if dt < 0 or dt > BOUNDARY_US:
            runs.append([])
        runs[-1].append(events[i])
    return [r for r in runs if r]


def find_gaps(events):
    gaps = []
    for si, seg in enumerate(segments(events)):
        for i in range(1, len(seg)):
            dt = seg[i][0] - seg[i - 1][0]
            if dt > GAP_US:
                gaps.append(
                    {
                        "kind": "silence",
                        "seg": si,
                        "t0": seg[i - 1][0],
                        "t1": seg[i][0],
                        "dur_s": dt / 1e6,
                        "wall0": seg[i - 1][3],
                        "wall1": seg[i][3],
                    }
                )
    return gaps


def find_bursts(events):
    # Bucket each segment independently (each has its own local start), but
    # pool all nonzero bucket counts to compute one global idle-density
    # threshold, so a burst in segment 2 is judged against the same
    # baseline as segment 1.
    bucketed = []  # list of (seg_index, counts, wall_of, start)
    all_nonzero = []
    for si, seg in enumerate(segments(events)):
        start = seg[0][0]
        end = seg[-1][0]
        nbuckets = int((end - start) / BUCKET_US) + 1
        counts = [0] * nbuckets
        wall_of = [None] * nbuckets
        for us, pin, level, wall in seg:
            b = int((us - start) / BUCKET_US)
            counts[b] += 1
            if wall_of[b] is None:
                wall_of[b] = wall
        bucketed.append((si, counts, wall_of, start))
        all_nonzero.extend(c for c in counts if c > 0)

    if not all_nonzero:
        return [], 0
    med = statistics.median(all_nonzero)
    threshold = med * BURST_FACTOR

    out = []
    for si, counts, wall_of, start in bucketed:
        nbuckets = len(counts)
        in_run = False
        run_start = 0
        runs = []
        for i, c in enumerate(counts):
            busy = c > threshold
            if busy and not in_run:
                run_start = i
                in_run = True
            if not busy and in_run:
                runs.append((run_start, i - 1))
                in_run = False
        if in_run:
            runs.append((run_start, nbuckets - 1))

        for r0, r1 in runs:
            t0 = start + r0 * BUCKET_US
            t1 = start + (r1 + 1) * BUCKET_US
            out.append(
                {
                    "kind": "burst",
                    "seg": si,
                    "t0": t0,
                    "t1": t1,
                    "dur_s": (t1 - t0) / 1e6,
                    "wall0": wall_of[r0],
                    "wall1": wall_of[min(r1 + 1, nbuckets - 1)] or wall_of[r1],
                    "edges": sum(counts[r0 : r1 + 1]),
                }
            )
    return out, med


def merge_overlapping(events_list):
    """Merge silence/burst windows that overlap or touch into single events,
    since a real press often shows as burst-then-silence back to back.
    Never merges across a segment boundary -- t0/t1 in different segments
    aren't on a comparable timeline (see parse/segments docstrings)."""
    ev = sorted(events_list, key=lambda e: (e["seg"], e["t0"]))
    merged = []
    for e in ev:
        if (
            merged
            and merged[-1]["seg"] == e["seg"]
            and e["t0"] <= merged[-1]["t1"] + 200_000
        ):
            prev = merged[-1]
            prev["t1"] = max(prev["t1"], e["t1"])
            prev["wall1"] = e["wall1"]
            prev["kind"] = prev["kind"] + "+" + e["kind"] if prev["kind"] != e["kind"] else prev["kind"]
            prev["dur_s"] = (prev["t1"] - prev["t0"]) / 1e6
        else:
            merged.append(dict(e))
    return merged


def main():
    if len(sys.argv) != 2:
        print("usage: analyze.py <capture.log>", file=sys.stderr)
        sys.exit(2)

    events = parse(sys.argv[1])
    if not events:
        print("no edge events parsed -- wrong file, or firmware not in EDGE mode?", file=sys.stderr)
        sys.exit(1)

    segs = segments(events)
    span_s = sum((s[-1][0] - s[0][0]) for s in segs) / 1e6
    print(f"# {len(events)} edges in {len(segs)} segment(s), ~{span_s:.1f}s total, "
          f"first={events[0][3]} last={events[-1][3]}")
    if len(segs) > 1:
        print(f"# note: {len(segs)} segments found -- board's elapsed_us counter had a "
              f"discontinuity (reconnect artifact, see parse() docstring); each segment "
              f"is analyzed independently.")

    gaps = find_gaps(events)
    bursts, idle_median = find_bursts(events)
    print(f"# idle baseline: {idle_median:.0f} edges/200ms")

    merged = merge_overlapping(gaps + bursts)
    print(f"\n{len(merged)} candidate event(s), in order:\n")
    for i, e in enumerate(merged):
        print(f"[{i:2d}] {e['wall0']} -> {e['wall1']}  "
              f"({e['t0']}us..{e['t1']}us)  dur={e['dur_s']:.2f}s  kind={e['kind']}"
              + (f"  edges={e['edges']}" if "edges" in e else ""))


if __name__ == "__main__":
    main()
