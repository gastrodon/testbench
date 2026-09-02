---
name: print-job
description: Slicing and driving a physical 3D printer — sending gcode, monitoring a print, the pre-print human checklist, serial connection discipline, what progress metrics genuinely prove. Load this when a design is ready to slice and print, or when operating a printer directly. Runs single-model with no subagents — for the CAD modeling and geometric-verification work that normally precedes this, use the separate `cad-design` skill instead.
---

# Print job

This skill covers one physical print run: slicing a verified design and
sending it to the machine, watching that one job, and nothing else at the
same time.

## This skill does not spawn agents. That's a rule, not an omission.

No subagent is used anywhere in this skill — not for slicing, not for
monitoring, not for anything. One model runs the whole print job,
start to finish. This isn't a style choice or a resource-saving measure:

**The supervisor session owns all hardware, and hardware is the entire
subject of this skill.** Nothing in here — not a slice, not a serial
connection, not a monitoring loop — gets delegated to a subagent, because
delegating any part of a print run does one of two bad things:

- **Hands hardware to something that must not have it.** A serial port
  has exactly one possible owner. This project has already destroyed a
  print because a second connection sent `M105` and consumed the
  streamer's `ok` — the nozzle sat on the part at 210°C. The camera has
  the same failure shape: one process holds `/dev/video0`, and a frame
  grab attempted while a timelapse held it simply failed. A subagent
  reaching for the serial port or the camera is not a smaller version of
  this problem, it's the same one.
- **Splits attention on the one task that most needs it undivided.** A
  print run needs sustained attention on a single, irreversible,
  in-progress action. That's the opposite of what makes a swarm valuable
  — parallel agents are good because each one's work is small, reversible,
  and safe to abandon. None of that is true of filament already laid
  down. A print job is a single-model task by nature, not by preference.

This is the same architectural boundary as `cad-design`'s "hardware is
the supervisor's alone" — it just has its natural home here instead of
being a caveat inside a design-focused document. If a job genuinely needs
eyes on it for hours, that's solved by the checklist and the honesty
about observability below, never by spinning up a second watcher.

## Handoff in: what this skill expects to receive

Input here is a **verified design** and, where relevant, correctly
oriented STLs — the output of the `cad-design` skill's loop (model →
verify → look → iterate) and its `design-verify` workflow. If the
geometry hasn't been through that yet — the mechanism's soundness is
unconfirmed, the interference/contact checks haven't run, nobody's looked
at a render — load `cad-design` and do that first. This skill assumes the
design question is already answered and only the print question remains.

## Before slicing

- **Print orientation is not assembly orientation** — decided during
  design, not here, but re-check it: the orientation a part slices in for
  bed adhesion should already have been verified (in `cad-design`) to
  still face whatever it mates with once printed. If that hasn't been
  checked, that's a `cad-design` gap to close before proceeding, not
  something to catch by eye on the plate.
- **Brim settings usually apply per object, not per plate.** A shared
  plate of small or detailed parts (e.g. text labels) can get a brim
  around every feature that fills small counters/gaps and merges things
  that were meant to stay separate. Slice small/detailed geometry
  separately, or at brim 0, rather than accepting the plate-wide default.
- **Overhang angle decides whether a feature needs support at all.** A
  taper that stays inside the material's self-supporting angle (roughly
  45° from vertical as a starting floor, tighter is safer) can trade
  axial room for no support material — worth checking before accepting a
  slicer's default support settings, especially on a part `cad-design`
  built with a specific self-supporting taper in mind.
- **First-layer squish and bed temperature decide whether thin features
  survive contact with the bed at all.** A bed sitting near a filament's
  glass-transition temperature leaves single-bead strokes soft enough to
  deform on contact — check both, not just nozzle temperature, when a
  print has fine first-layer detail.
- **Coupon/test-print a genuinely untested tolerance** (a thread pitch, a
  snap-fit throat, a slip fit) before committing to the full part. Build
  the coupon from the *real* part's geometry where possible (e.g.
  literally slicing the relevant region out of the real model) — a
  simplified stand-in only tests the stand-in, not the part.

## Pre-print checklist — ask the human, every time, before sending the job

Four things, and every one of them is a state the machine does not
report and the supervisor cannot check by any means available to it.
This isn't a paragraph of advice — it's a gate: ask all four, wait for
real answers, and don't send the job until you have them. Don't run it
from memory of last time; state changes between prints in ways nothing
reports.

1. **Is the position zeroed?** Firmware happily reports coordinates that
   are wrong. After a manual move, an LCD reset, or a power cycle, a
   position query returns a number with no idea whether it matches
   reality.
2. **Is the print surface clean, correct, and secure?** A print in this
   project already died because the bed surface had physically slipped —
   nothing in the g-code stream could have detected that, and a lifted
   edge or the wrong surface entirely is just as invisible.
3. **Is the printer observable in the ways this print needs — camera,
   filament sensor, whatever's on this machine?** This one is about what
   the supervisor can honestly promise, not a pass/fail on the print
   itself. Without a camera, the supervisor is blind to the bed; without
   a filament sensor, it's blind to whether anything is actually being
   deposited — a jam can run for hours and raise zero firmware errors,
   because without a sensor there's nothing to detect and nothing to
   report. **If the answer is "no," proceed anyway if that's the human's
   call — printing without a camera is a legitimate choice — but say
   plainly that the print will be unsupervised in whatever way is
   missing.** The failure to avoid is implying the supervisor can see
   something it can't, not declining to print.
4. **Is the extruder nozzle clear of debris?** Entirely invisible to the
   machine and to the agent — the fix for this one is a human physically
   looking at and touching the nozzle, and there is no substitute check.

This list exists because of one exchange in this project's history: the
human cleared a nozzle, and the supervisor had no way to know it had
happened. Be precise about which of these hardware could actually fix,
though: items 1, 2, and 4 are irreducibly human — no instrument tells you
a surface is *correct* or a nozzle is *clear*. Item 3 is different: a
filament motion sensor genuinely does close the jam-detection gap,
turning an invisible failure into a pause. If a machine keeps losing long
prints to jams, buy the sensor; don't keep asking the question. The
checklist is for what cannot be instrumented, and pretending item 3
belongs in that category would be an excuse not to fix it.

## Running the job

- **One serial connection, always.** Before opening it, be sure nothing
  else — another session, another tool, a leftover process — already
  holds it. Use real flow control (send a line, wait for the
  acknowledgment, send the next) rather than blasting the buffer; the
  planner queue and serial input buffer are both small and overflow
  silently.
- **Be honest about what a progress metric proves.** Cumulative filament
  extruded (`E` at the current line vs. the file's final `E`) is the
  least-bad progress signal available — it's far better than line count,
  which is actively misleading (infill segments are long single lines, so
  lines-per-second *falls* as a print speeds up into infill, making a
  line-count estimate drift *worse* over the course of a print, not
  better) — and better than the slicer's own time estimate, which runs
  optimistic. But filament-extruded still only measures what was **asked
  for**, read out of the command stream itself. **It cannot detect a jam**
  on a machine with no filament sensor: the firmware reports no error
  because, without a sensor, it has nothing to detect and nothing to
  report. Don't let a healthy-looking progress number stand in for "the
  print is fine" — it only ever meant "the print is proceeding as
  commanded." A printer with no filament sensor and no camera on the part
  is honestly unobservable mid-print — say so, rather than implying the
  job is being watched when it isn't (this is the same gap the checklist's
  item 3 names, and the same fix: a filament sensor closes it; a better
  reading of the command stream cannot).
- **Physical actions belong only to this session, never to a replayable
  script.** `cad-design`'s `design-verify.js` workflow stops before
  touching a printer for exactly this reason — a resumed/replayed
  workflow run can re-run any agent whose prompt or upstream result
  changed, including ones that already completed, and an agent that
  streamed g-code or homed an axis would do it again on replay. Sending a
  job, watching it, and reacting to it all happen here, in this single,
  non-replayed, human-attended session.
