---
name: cad-design
description: Parametric CAD modeling, geometric design verification, and stress/load analysis — OpenSCAD/BOSL2 (or similar) part design, iterating on a bracket/mechanism/part, checking interference and whether a mechanism actually works, mesh/DFM review, catching silent modeling failures that pass every geometric test, and FEA against declared load cases (fea/) for weak spots, load capacity, material choice, and lightweighting — including multi-part assemblies under load, where it answers how force crosses a joint: bearing area, contact pressure, whether a joint separates or slips. Load this whenever writing, reviewing, or iterating on a parametric CAD part, or when asked what a part or assembly can hold, where it will fail, or how load passes through it. Uses a swarm of read-only subagents (a workflow) for verification and rendering. For slicing and driving a physical printer, use the separate `print-job` skill instead — that one runs single-model, on purpose.
---

# CAD design

Model parametrically, verify geometrically, look at it, iterate. That loop
is the whole skill — everything here is either part of the loop or the
tooling that runs it.

This is distilled from building the prime-focus microscope in `optics/`
(Linear project "Shop", `optics/model-analysis.md`, the Linear doc
"Printable mechanisms", `optics/check.py`, `optics/AGENTS.md`). Treat
`optics/` as a worked example, not the subject — this skill is for the
next part someone models, in this repo or another one built the same way.

## Design work is a swarm; printing is not — and that's why they're two skills

This skill runs a parallel agent swarm (read-only reviewers, a verification
workflow, cold-readers) because the work is safe to parallelize: a render,
a measurement, a proposal are all reversible, cheap to throw away, and safe
to run four at once. **When the same session is ready to slice and print,
switch to the separate `print-job` skill**, which is a single model with
no subagents at all — the opposite execution shape, because a print run is
the opposite on every axis that matters: one serial port with exactly one
possible owner, an action that is irreversible once filament is down, and
a job that needs sustained attention on one thing rather than divided
attention across many. A swarm is the wrong shape for a print run in the
same way a single serial connection is the wrong shape for reviewing six
parts at once. See `print-job`'s own SKILL.md for why it refuses to spawn
agents, stated as its own rule.

**Handoff**: this skill's output is a verified design and, if the part is
headed to a printer, correctly oriented STLs. That's `print-job`'s input.
Don't duplicate `print-job`'s slicing/machine content here for convenience
— load that skill when you get there, rather than working from a summary
that will drift out of sync with it.

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
were only caught by an orthographic view or a scripted measurement. None
of the four had anything to do with a printer — they were wrong before
any part reached a bed.

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
   is available. Every one of these produces a watertight, geometrically
   valid model that passes every check with a feature simply missing.
   **If a feature must exist, assert on a measurable consequence of it**
   — a body count, a bounding box, geometry probed at a known coordinate
   — not on "it rendered."

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

5. **Print orientation is not assembly orientation.** This is a modelling
   trap, not a printer one — it's about two transforms living in the same
   file, and it broke a web viewer here with no printer anywhere in the
   loop. A part's rotation for bed adhesion and its rotation relative to
   whatever it mates with are two different transforms; conflating them
   is easy because both are "just a rotation" on the same object. State
   both explicitly and check that the feature meant to mate with
   something else still faces that something else after the
   print-orientation transform is applied.

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

## Verification is two distinct, non-overlapping methods

Measuring (running a checker or a scripted geometry query) and looking (a
rendered image) catch **different, non-overlapping classes of defect** —
in this project's history, no method ever caught a defect outside its own
class. Do both; don't substitute one for the other.

- **Measuring** needs a query layer beside the CAD (trimesh + a boolean
  engine such as manifold3d worked well here; anything that can report
  interference volume and minimum surface distance, not just "renders
  fine," will do) and a checker that reads dimensions from the same
  source of truth as the model, per rule 3. For a part that carries
  load, measuring extends to solving it (`fea/`, below): whether the
  shape is right and whether it holds are different questions, and no
  amount of geometric querying answers the second.
- **Looking** needs orthographic views down the axis of interest (a
  perspective isometric hides axial offsets and makes tangency
  ambiguous — three separate real defects were simultaneously visible in
  one orthographic pinion-axis view and invisible in every isometric
  rendered before it) and a full `--render` pass rather than preview mode
  when checking manifold validity, since preview can hide boolean errors
  a full render would otherwise surface.
- **Cold-reading**: hand a rendered image to a reviewer with *zero* other
  context and ask what they see, rather than asking a primed reviewer to
  confirm a specific concern. This catches things a primed reviewer
  won't, and — done right — correctly distinguishes "this looks odd
  because of the camera angle" from "this is actually wrong," which
  matters because those two need opposite responses (re-render vs. fix).

## Stress is checkable — but only against declared intent (`fea/`)

Geometric verification answers "is this shape what the model claims."
`fea/` (gmsh → CalculiX → numpy, all in the devshell, validated against an
analytic cantilever — `fea/README.md`) answers a different question: "does
this shape carry the load it exists to carry." A stress result is a
*measured* finding under rule 7 — you ran a solver and read real output —
but it is measured **conditional on a declared load case**, and the
evidence must say so: where the part is held, where load enters, how much,
which material. State the load case in the finding or the number is
decoration.

The load case encodes design intent the same way contact-pair
classification does (must-clear / slip-fit / designed-to-touch), and it
gets the same treatment: **declared as data, not invented by the
verifier.** A part's author writes it in a `loadcases.py` beside the
`.scad` source (format and a worked example in `fea/README.md`;
predicates derive from the mesh or params — rule 3 applies to load cases
too). A part that plainly carries something but declares no load case is
**unverified for stress, and that absence is itself a reportable
finding** — a verifier inventing plausible-looking boundary conditions on
the spot produces a number that reads as measured while anchored to
nothing.

Reading the numbers, the short version (long version in `fea/README.md`):
capacity comes from the **converged peak** von Mises — solve at two mesh
sizes, and a peak still climbing between them is a sharp-corner
singularity to fillet, not a number to quote; field percentiles are never
a capacity metric (they dilute as the mesh refines). Absolute capacity is
order-of-magnitude — the trustworthy product is *relative*: this variant
vs. that one, this corner vs. the rest of the part. And a material swap
never moves the weak spots (single-material linear elasticity: the stress
field is essentially independent of stiffness) — it moves the allowable
and the deflection, so one solve per geometry answers the material
question for every candidate material.

**Assemblies are the common case, and joints are declared intent too.**
`fea/assembly.py` solves several parts at once, joined by `Tie` (bonded)
or `Contact` (bearing, sliding, separating) interfaces declared in an
`assemblies.py` beside the sources. Which one a joint gets is a statement
about the design, not a solver setting: a joint the model itself calls
rigid gets `Tie`; a joint that bears, slides, or can lift gets `Contact`.
**Tie every joint except the one under investigation** — a full-contact
assembly is slower, more fragile, and answers no question better than a
hybrid one. Escalate a joint to `Contact` on evidence, when you need that
joint's pressure distribution, bearing area, separation or slip; a bonded
solve already tells you *whether* an interface region is marginal.
Every part must be grounded (a fixture, a `Tie` chain, or explicit
`stabilize=True`), and that is checked before the solver runs, because
ccx's answer to a floating part is a diverging solve that names nothing.

What stress analysis buys the iterate loop: the von Mises map is a
**simplification oracle**. Regions sitting far below the allowable are
structurally idle — shell them, pocket them, thin them in the `.scad`
(staying parametric), re-solve, and assert the peak didn't cross the
allowable. That turns "can I lighten this?" into a regression test
instead of a guess.

## The workflow: `.claude/workflows/design-verify.js`

Runs the two verification methods above as agent fan-outs and ends in a
**verdict on the design**: is the geometry sound, does the mechanism
actually work, what's still unverified. "Ready to slice" is one possible
consequence of a clean verdict, not the goal the workflow is aimed at —
most runs of this on most parts never touch a printer at all, and the ones
that do hand off to `print-job` rather than doing anything printer-facing
themselves.

Phases: **Discover** (find or confirm the target part files) → **Verify
geometry** (one read-only agent per file: runs this repo's checker if one
exists, else renders and reasons from that, explicitly audits for
duplicated dimensions and missing-feature silent failures, and — when the
part's project declares a load case in `loadcases.py` — runs the `fea/`
stress check against it, or reports undeclared intent on a load-bearing
part as its own finding) → **Review renders** (one agent renders
canonical views per file; a second, *context-free* agent cold-reads each
set of images, per the cold-reading rule above) → **Report** (synthesizes
every tagged finding into one severity-grouped design verdict, refusing
to upgrade a reasoned finding into a measured-sounding one, and keeping
every stress number explicitly conditional on its declared load case).

Every finding either verification stage returns is schema-constrained to
`{claim, method, evidence, severity}` — the workflow's structural
enforcement of rule 7. An agent cannot report "verified" without
declaring how.

Run it as `ultracode: run the design-verify workflow on <part(s)>`, or
just describe the part(s) and ask for a workflow — Claude can also invoke
it as `/design-verify` once you've saved it (`/workflows`, select the run,
press `s`), from either `.claude/workflows/` (project) or
`~/.claude/workflows/` (personal). Pass a specific file list via `args`
(`Run /design-verify on optics/focus_pinion.scad, optics/pcb_carrier.scad`)
or omit it to let the Discover phase find every top-level part file
itself.

`design-verify.js` stops at the design verdict and never touches a
printer, on purpose — a resumed/replayed workflow run can re-run any
agent whose prompt or upstream result changed, including ones that
already completed, and a workflow agent that streamed g-code or homed an
axis would do it again on replay. That's not a gap in this skill; it's
the reason `print-job` exists as a separate, single-model skill instead
of a phase tacked onto this workflow.

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
  and valuable work, but it is not a CAD concern — it applies to any
  project with an external doc trail, and folding it in here would make
  the skill about project hygiene instead of about modeling. If a build
  has produced new physical findings worth recording externally, that's
  a downstream step after this skill's (and `print-job`'s) work is done,
  not a role either skill owns.

- **The artifact-publisher role is dropped as its own persistent role.**
  Publishing a 3D viewer or a web artifact is a nice-to-have presentation
  layer, not a verification step, and conflating "publish something
  shareable" with "verify the geometry" was part of why a print-vs-assembly
  orientation mismatch reached a viewer before anyone caught it. The one
  genuinely load-bearing technique that role discovered — cold-reading a
  render with no context — is kept, above, decoupled from publishing.

- **There is no "print-operator" agent, in this skill or in `print-job`,
  and there never will be.** A stalled print went unnoticed for two hours
  during this project, and an earlier framing of that gap treated it as
  "nobody owned physical machine health," as if the fix were a missing
  role. That diagnosis is wrong: the supervisor owned it the whole time,
  the session simply didn't monitor it well, and the progress signal in
  use (filament extruded) couldn't have caught a jam regardless of who
  was watching it — it measures the command stream, not the physical
  result (see `print-job`'s SKILL.md). Creating a hardware-owning
  subagent would have papered over a supervisor lapse *and* put a second
  claimant on a resource — the serial port — that is physically forced to
  have exactly one owner. This is also, from the other direction, why
  `print-job` is a single-model skill rather than a swarm: hardware
  ownership is categorically excluded from subagents, so a job that is
  mostly hardware ownership has no swarm left to run.

Net effect: **two** persistent read-only reviewer roles (geometry,
visual) in this skill, both invoked as workflow-spawned subagents rather
than long-lived named agents, and zero hardware-facing roles anywhere —
that responsibility lives entirely in `print-job`, run by the supervisor
alone, by architectural constraint rather than because no better division
was found.
