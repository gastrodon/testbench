---
name: cad-print
description: Parametric CAD, geometric verification, rendering, slicing, and driving a 3D printer — OpenSCAD/BOSL2 (or similar) modeling, mesh/DFM/interference checks, STL export, slicer settings, gcode streaming, print-job monitoring. Load this before writing or reviewing any parametric part, before slicing, or before touching a printer's serial connection.
---

# CAD / print work

This is the general playbook for parametric modeling and physical printing
in this repo, distilled from building the prime-focus microscope in
`optics/` (Linear project "Shop", `optics/model-analysis.md`, the Linear
doc "Printable mechanisms", `optics/check.py`, `optics/AGENTS.md`). Treat
`optics/` as a worked example, not the subject — this skill is for the
next part someone models, in this repo or another one built the same way.

## The core problem this skill exists to solve

**CAD is write-only.** OpenSCAD (and tools like it) render geometry but
cannot be asked whether two parts touch, how far apart they are, or
whether a mechanism actually moves. BOSL2-style anchors don't close this
gap — they're declarative points on a primitive's *nominal* geometry,
computed before any boolean runs, not measurements of the solid that
actually results. You find out by building a query layer beside the
model, or you ship whatever is invisible from the outside.

`optics/model-analysis.md` has the full account, including four real
defects (wrong center distance, mis-facing rack teeth, a gear floating out
of plane, a pinion attached to nothing) that survived rendered review and
were only caught by an orthographic view or a scripted measurement.

## Hardware is the supervisor's alone — subagents never touch it

**The supervisor session owns all hardware. Subagents are code and
knowledge only.** No subagent — not the workflow's agents, not one you
spawn by hand — ever opens a serial port, sends g-code, moves an axis,
captures a camera frame, or touches any `/dev` node. Subagents read
files, run analysis, render, slice, and write code or docs: things with
no physical consequence. The supervisor alone decides when something
physical happens, because the supervisor is the one with a channel to
the person who can see the machine.

This is an architectural constraint, not a style preference, for three
reasons:

1. **It's physically forced.** A serial port has exactly one owner. This
   project has already destroyed a print because a second connection sent
   `M105` and consumed the streamer's `ok` — the nozzle sat on the part at
   210°C. The camera has the same shape of failure: one process holds
   `/dev/video0`, and a frame grab attempted while a timelapse held it
   simply failed. Divided ownership doesn't degrade gracefully here, it
   corrupts the resource.
2. **It's what makes subagents parallelisable at all.** Everything a
   subagent does is reversible — a file, a render, a proposal — which is
   exactly what makes it safe to run several at once and safe to overrule
   any of them. The moment a subagent can start a fire, crash a gantry, or
   waste hours of bed time, none of that is true anymore.
3. **It puts irreversible decisions where the context already is.** The
   supervisor is the one talking to the person who can see the machine.
   Physical actions are exactly the ones that need that channel, not a
   subagent working from a prompt and a file tree.

A build that genuinely needs eyes on a multi-hour print doesn't get a
second agent for it — see "Physical printing," below, for what the
supervisor does instead and what it honestly cannot know.

## Rules that are load-bearing (each earned by a real defect)

1. **Two conditions, always: no interference AND sustained contact.**
   "Nothing intersects" is satisfied by two gears a metre apart. Checking
   only for overlap is a silent false pass on anything designed to touch.
   Classify every pair by intent (must-clear / slip-fit / designed-to-touch)
   and test the designed-to-touch pairs for *shape* (a thin, distributed
   sliver) not just magnitude — a blanket exemption on a touching pair also
   exempts everything rigidly attached to it.

2. **Silent failures are the dominant defect class, and they all share one
   shape: the tool warns and continues where another language would
   abort.** `use<>` imports modules/functions but not the includes or
   variables around them. A missing definition often silently evaluates
   to `undef` rather than erroring. `text()` renders nothing when no font
   is available. Every one of these produces a watertight STL that passes
   geometric checks with a feature simply missing. **If a feature must
   exist, assert on a measurable consequence of it** — a body count, a
   bounding box, geometry probed at a known coordinate — not on "it
   rendered."

3. **Never restate a dimension.** Read it from the shared source of truth
   (a params file, a generator function) at runtime, in both the CAD and
   any verification script. A dimension copied by value into a second
   place is a duplication defect the moment it's written, whether or not
   it currently agrees — it *will* drift, silently, the next time either
   side changes.

4. **Suspect the checker before the design.** A verification tool built
   alongside the thing it verifies inherits the same drift the design has.
   Every false FAIL in this project's history came from the checker
   restating geometry the CAD already owned, not from a real defect.
   Diagnostic tell: an overlap that peaks mid-feature and vanishes at
   symmetric poses is a sign/direction error in the checker; a real
   interference clashes at *every* pose.

5. **Print orientation is not assembly orientation.** A part's rotation
   for bed adhesion and its rotation relative to whatever it mates with
   are two different transforms. Conflating them has broken a build (and
   a 3D viewer) here before. State both explicitly and check that the
   feature meant to mate with something else still faces that something
   else after the print-orientation transform.

6. **Kinematic errors pass every geometric test ever written.** A part
   translated along with the thing it's supposed to drive is
   well-formed, non-interfering, and a complete no-op — because the wrong
   body was held fixed. No interference or contact check can see this; it
   requires literally naming, in the model, which body is grounded, and
   deriving dependent motion from it rather than posing each part
   independently. A good check: describe in words what every part does on
   *every frame* of the intended motion, and require the description to
   be mechanically coherent end to end. A mechanism moving as one rigid
   lump interferes with nothing and reads as fine to every automated test.

7. **Tag every finding by how you know it, and say so out loud:
   measured, rendered, or reasoned.** "Measured" means you ran a checker
   or a scripted query and read real output. "Rendered" means you looked
   at an image. "Reasoned" means you inferred from reading source without
   running or rendering anything. Never let a reasoned claim read like a
   measured one — that conflation, done quickly under time pressure, has
   produced verified-sounding claims that were wrong, more than once.
   Also watch for a **summarized measurement standing in for a real one**
   — concluding "no problem here" from a truncated top-N ranking or a
   sampled distance check is not the same claim as "I checked all of it."

8. **Slicing and the machine are part of the loop, not an afterthought.**
   `brim_width`-style settings usually apply per *object*, so a shared
   plate of small parts (e.g. text labels) can get a brim around every
   glyph that fills counters and bridges gaps — slice small/detailed
   geometry separately or at brim 0. First-layer squish and bed
   temperature decide whether thin features survive contact with the bed
   at all. A bed sitting near a filament's glass-transition temperature
   leaves single-bead strokes soft enough to deform on contact.

## Verification is two distinct, non-overlapping methods

Measuring (running a checker, a scripted geometry query, or the slicer/
printer's own numbers) and looking (a rendered image) catch **different,
non-overlapping classes of defect** — in this project's history, no
method ever caught a defect outside its own class. Do both; don't
substitute one for the other.

- **Measuring** needs a query layer beside the CAD (trimesh + a boolean
  engine such as manifold3d worked well here; anything that can report
  interference volume and minimum surface distance, not just "renders
  fine," will do) and a checker that reads dimensions from the same
  source of truth as the model, per rule 3.
- **Looking** needs orthographic views down the axis of interest (a
  perspective isometric hides axial offsets and makes tangency
  ambiguous — three separate real defects were simultaneously visible in
  one orthographic pinion-axis view and invisible in every isometric
  rendered before it) and a full `--render` pass rather than preview mode
  when checking manifold validity, since preview can hide boolean errors
  preview mode would otherwise surface.
- **Cold-reading**: hand a rendered image to a reviewer with *zero* other
  context and ask what they see, rather than asking a primed reviewer to
  confirm a specific concern. This catches things a primed reviewer
  won't, and — done right — correctly distinguishes "this looks odd
  because of the camera angle" from "this is actually wrong," which
  matters because those two need opposite responses (re-render vs. fix).

## Physical printing — the supervisor's own discipline

Hardware operation is not a role to delegate (see above) — it's a
practice the supervisor session follows itself.

### Pre-print checklist — ask the human, every time, before sending the job

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
happened. None of these four are software faults, and none are
detectable from the g-code stream. That's the reason the checklist is a
question asked of a person rather than a script run against a log.

Be precise about which of these hardware could fix, though. Items 1, 2
and 4 are irreducibly human — no instrument tells you a surface is
*correct* or a nozzle is *clear*. Item 3 is different: a filament motion
sensor genuinely does close the jam-detection gap, turning an invisible
failure into a pause. If a machine keeps losing long prints to jams, buy
the sensor; don't keep asking the question. The checklist is for what
cannot be instrumented, and pretending item 3 belongs in that category
would be an excuse not to fix it.

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
  for**, read out of the command stream itself. **It cannot detect a jam.**
  A printer with no filament sensor and no camera watching the part is
  genuinely unobservable mid-print: the firmware reports no error on a
  jam because, without a sensor, it has nothing to detect and nothing to
  report. Don't let a healthy-looking progress number stand in for "the
  print is fine" — it only ever meant "the print is proceeding as
  commanded." If real jam detection matters for a given build, that means
  physically checking on it (a camera pointed at the part, or eyes on it
  periodically), not a better number pulled from the g-code.
- **Physical actions do not belong in a replayable script.** See the
  workflow section below — `cad-preflight.js` stops at slicer-readiness
  on purpose, because a resumed/replayed run can re-run any agent whose
  prompt or upstream result changed, including ones that already
  completed. A workflow agent that streamed g-code or homed an axis would
  do it again on replay — one more reason hardware access belongs to the
  supervisor alone and never to a script's agents.
- Coupon/test-print small, cheap probes of a genuinely untested tolerance
  (a thread pitch, a snap-fit throat, a slip fit) before committing to
  the full part. Build the coupon from the *real* part's geometry where
  possible (e.g. literally slicing the relevant region out of the real
  model) — a simplified stand-in only tests the stand-in, not the part.

## The workflow: `.claude/workflows/cad-preflight.js`

Runs the two verification methods above as parallelizable agent fan-outs,
ending at a single go/no-go report for slicing. It does **not** drive a
printer or touch a serial device — see "physical actions do not belong in
a replayable script," above.

Phases: **Discover** (find or confirm the target part files) → **Verify
geometry** (one read-only agent per file: runs this repo's checker if one
exists, else renders and reasons from that, and explicitly audits for
duplicated dimensions and missing-feature silent failures) → **Review
renders** (one agent renders canonical views per file; a second,
*context-free* agent cold-reads each set of images, per the cold-reading
rule above) → **Report** (synthesizes every tagged finding into one
severity-grouped go/no-go for slicing, refusing to upgrade a reasoned
finding into a measured-sounding one).

Every finding either verification stage returns is schema-constrained to
`{claim, method, evidence, severity}` — the workflow's structural
enforcement of rule 7. An agent cannot report "verified" without
declaring how.

Run it as `ultracode: run the cad-preflight workflow on <part(s)>`, or
just describe the part(s) and ask for a workflow — Claude can also invoke
it as `/cad-preflight` once you've saved it (`/workflows`, select the run,
press `s`), from either `.claude/workflows/` (project) or
`~/.claude/workflows/` (personal). Pass a specific file list via `args`
(`Run /cad-preflight on optics/focus_pinion.scad, optics/pcb_carrier.scad`)
or omit it to let the Discover phase find every top-level part file
itself.

## Agent division — and why it's not the four we used building the microscope

Building the microscope, four roles emerged by accident, in this order:
a docs-source-of-truth keeper (Linear/Obsidian sync), a read-only
mesh/DFM analyst, an artifact-publisher that also did cold-read visual
review, and a one-shot codebase-structure reviewer. That split had real
successes and real gaps; this skill does not re-enshrine it as-is.

**What's kept, and why:**

- **A read-only geometry verifier that only proposes, never edits.**
  This was the single strongest pattern from today. It produced
  falsifiable, numbered claims, and twice reported "I cannot find the
  feature you describe" instead of inventing a change to match a
  request — which is how two supposedly-separate queued items turned out
  to be the same one, and a third turned out not to exist at all. An
  agent that can refuse to find something is worth more than one that
  always finds *something*. **The former "structure review" role — a
  one-shot pass that found the same dimension written out under three
  different names in three files — is folded into this same role rather
  than kept separate.** Both are "read the source of truth and report
  where it's been restated or where a claim can't be substantiated";
  splitting them by *what prompted the check that day* (DFM concerns vs.
  a general codebase pass) isn't a real boundary, it's an accident of
  what was needed on the day each was invented.

- **A visual, cold-read reviewer, kept as a genuinely separate role from
  the geometry verifier** — not merged in, despite doing the same
  "read-only, proposes findings" job. The justification is structural,
  not just historical: measuring and looking catch non-overlapping
  defect classes (see above), and the cold-read technique specifically
  *requires* a reviewer with no priming context, which the geometry
  verifier's job — reading source, running checkers — cannot have while
  also being unprimed about the part. The workflow tool is a genuinely
  better mechanism for this than what we improvised: every `agent()` call
  spawns a fresh, context-free subagent by default, so "hand a render to
  someone with zero context" falls out of the primitive instead of
  requiring the operator to remember to withhold context by hand.

**What's dropped, and why:**

- **The docs/source-of-truth-keeper role is dropped from this skill.**
  Keeping Linear and Obsidian in sync with what's physically true is real
  and valuable work, but it is not a CAD or print concern — it applies to
  any project with an external doc trail, and folding it in here would
  make the skill about project hygiene instead of about modeling and
  printing. If a build has produced new physical findings worth recording
  externally, that's a downstream step after this skill's work is done,
  not a role this skill owns.

- **The artifact-publisher role is dropped as its own persistent role.**
  Publishing a 3D viewer or a web artifact is a nice-to-have presentation
  layer, not a verification step, and conflating "publish something
  shareable" with "verify the geometry" was part of why a print-vs-assembly
  orientation mismatch reached a viewer before anyone caught it. The one
  genuinely load-bearing technique that role discovered — cold-reading a
  render with no context — is kept, above, decoupled from publishing.

- **There is no "print-operator" agent, and there never will be one in
  this skill.** A stalled print went unnoticed for two hours today, and
  my first framing of that gap — in an earlier draft of this task —
  was "nobody owned physical machine health," as if the fix were a
  missing role. That diagnosis was wrong and I'm not carrying it
  forward: the supervisor owned it the whole time, the session simply
  didn't monitor it well, and the progress signal in use (filament
  extruded) couldn't have caught a jam regardless of who was watching
  it — it measures the command stream, not the physical result (see
  "Physical printing," above). Creating a hardware-owning subagent would
  have papered over a supervisor lapse *and* put a second claimant on a
  resource — the serial port — that is physically forced to have exactly
  one owner. Hardware access is excluded from subagents categorically
  (see "Hardware is the supervisor's alone," above), not as a judgment
  call weighed against convenience.

Net effect: **two** persistent read-only reviewer roles (geometry,
visual) instead of four, both invoked as workflow-spawned subagents
rather than long-lived named agents, and zero hardware-facing roles —
that responsibility stays with the supervisor by architectural
constraint, not because no better division was found.
