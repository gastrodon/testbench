export const meta = {
  name: 'cad-preflight',
  description: 'Read-only geometric verification (interference + sustained contact, duplicated-dimension audit) and cold-read visual review of parametric CAD parts, before slicing or printing. Every finding is tagged by how it was checked: measured, rendered, or reasoned.',
  phases: ['Discover', 'Verify geometry', 'Review renders', 'Report'],
}

// Every finding an agent returns must declare HOW it knows, not just WHAT it
// found. This is the structural fix for a real failure mode: a reviewer
// computing something quickly and reporting it as verified when it was only
// reasoned. See .claude/skills/cad-print/SKILL.md, "Tag every finding."
const FINDING_SCHEMA = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['claim', 'method', 'evidence', 'severity'],
        properties: {
          claim: { type: 'string' },
          method: { enum: ['measured', 'rendered', 'reasoned'] },
          evidence: { type: 'string' },
          severity: { enum: ['fail', 'warn', 'info'] },
        },
      },
    },
  },
}

const FILES_SCHEMA = {
  type: 'object',
  required: ['files'],
  properties: {
    files: { type: 'array', items: { type: 'string' } },
  },
}

log('cad-preflight: discovering target parts')
phase('Discover')

const discoverPrompt = args && args.parts
  ? `Confirm these files exist and are real CAD part files, not libraries/includes: ${JSON.stringify(args.parts)}. Return the confirmed list of paths, relative to the repo root.`
  : "Find every top-level parametric CAD part file in this repo (e.g. an OpenSCAD file that renders a real solid at its bottom, not a library or include-only file — grep for files that call a module rather than just define one). List their paths relative to the repo root."

const discovered = await agent(discoverPrompt, { schema: FILES_SCHEMA, label: 'discover' })
const files = (discovered && discovered.files) || []

log(`cad-preflight: ${files.length} part file(s) to check`)
phase('Verify geometry')

const geometryPrompt = (file) => `
You are a READ-ONLY geometry verifier. You never edit files, never touch a
serial device, printer, or camera — only report findings.

Target: ${file}

1. Read the file and any params / shared-dimension file it includes.
2. If a geometry-checking script already exists in this repo (something
   using trimesh/manifold3d, or scripted OpenSCAD --render + measurement),
   run it against this part and report its REAL output. If none exists,
   render the part with OpenSCAD in full --render mode (not preview),
   orthographic, down each axis a mating or moving feature turns on, and
   reason from that instead. State plainly which of these two you did —
   do not blur "I ran a checker" and "I looked at a render" together.
3. Specifically check for:
   - Any dimension also written out BY VALUE in a second file, instead of
     read via an include/shared-params mechanism — a duplication defect
     regardless of whether the two values currently agree.
   - For any pair of features meant to touch (gear mesh, snap-fit, thread,
     slide fit): interference AND sustained contact, both. Absence of
     overlap alone is not proof the parts actually meet — two parts a
     metre apart also never overlap.
   - Anything that could produce a valid, watertight STL with a feature
     silently missing: an include that might not resolve, a variable that
     could evaluate to undef, a font/text() dependency, a boolean that
     could silently no-op.
   - Whether the part's PRINT orientation (if the file sets one) actually
     matches its ASSEMBLED orientation relative to whatever it mates with
     — these have been silently different before.
4. Do not invent a defect you can't point to a specific line, value, or
   measurement for. If something is unverifiable in the time you have,
   report that fact as its own finding (method "reasoned", evidence
   describing what blocked you) rather than omitting it or guessing.

Return every finding, including a single info-severity "nothing found"
finding if the part is genuinely clean. Each finding needs: claim, method
(measured = you ran a checker or the OpenSCAD CLI and read real output;
rendered = you looked at an image; reasoned = you inferred from reading
source without running or rendering anything), evidence (the actual
number, line, or observation), severity.
`.trim()

const geometryFindings = await pipeline(files, (file) =>
  agent(geometryPrompt(file), { schema: FINDING_SCHEMA, label: `verify:${file}` }),
)

phase('Review renders')
log('cad-preflight: rendering canonical views for a cold read')

const renderPrompt = (file) => `
Render ${file} with OpenSCAD in full --render mode (not preview — preview
can hide boolean/manifold errors), orthographic, at minimum top, front,
and one 3/4 iso view, plus any additional axis a moving or mating feature
turns on. Per-part color() on if the file supports it. Save the images
somewhere in the scratchpad and report their exact paths in your reply.

Do not describe or judge the geometry yourself. A separate reviewer with
zero context looks at the images next — your job here is only to produce
them and say where they are.
`.trim()

const renderReports = await pipeline(files, (file) =>
  agent(renderPrompt(file), { label: `render:${file}` }),
)

const coldReadPrompt = (renderReport) => `
You are looking at CAD renders for the first time, with no other context
about this project, this part, or what it is supposed to do.

${renderReport}

Open each image path mentioned above and say, plainly, what you see: how
many distinct bodies; whether anything looks like it is floating, buried
in, or misaligned with anything else; whether a moving mechanism (gears,
a sliding fit, a hinge, a screw) looks like it could actually move once
assembled; and whether the print orientation looks different from how the
parts would sit once assembled together — that mismatch has broken a
build before.

When something looks off, say explicitly which of these it is, because
they call for different responses: (a) wrong regardless of viewing angle,
or (b) could just be this camera angle / an isometric view hiding an
axial offset — ask for an orthographic re-render down the suspect axis
before calling it a defect.
`.trim()

const coldReads = await pipeline(renderReports, (renderReport) =>
  agent(coldReadPrompt(renderReport), { schema: FINDING_SCHEMA, label: 'cold-read' }),
)

phase('Report')
log('cad-preflight: synthesizing preflight report')

const allFindings = []
  .concat(...geometryFindings.filter(Boolean).map((f) => f.findings || []))
  .concat(...coldReads.filter(Boolean).map((f) => f.findings || []))

const report = await agent(`
Synthesize one CAD preflight report from these tagged findings (each
already carries method: measured/rendered/reasoned, and severity
fail/warn/info):

${JSON.stringify(allFindings, null, 2)}

Group by severity, fails first. For every fail or warn, state the file,
the claim, and the method — never let a "reasoned" finding read like a
"measured" one in your summary. End with an explicit go/no-go for
SLICING (not printing): go only if there are zero fail-severity findings
whose method is measured or rendered. A reasoned-only fail is a flag to
verify by measuring or rendering, not an automatic no-go — say so
explicitly.

Do not recommend running the printer, homing an axis, or streaming
g-code. This report ends at slicer-readiness. Driving the physical
machine is a separate, human-attended step, on purpose: a workflow run
can be replayed and would re-issue any physical action it contained.
`.trim(), { label: 'report' })

log('cad-preflight: done')

return {
  files,
  findingCount: allFindings.length,
  failCount: allFindings.filter((f) => f.severity === 'fail').length,
  report,
}
