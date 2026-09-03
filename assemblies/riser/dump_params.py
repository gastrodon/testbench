#!/usr/bin/env python3
"""Echo the parameters the viewer needs out of params.scad. Never a copy."""
import json, re, subprocess, sys
from pathlib import Path
HERE = Path(__file__).parent
NAMES = ['az_gear_cd','tilt_axis_z','tilt_gear_cd','tilt_ratio','payload_face_z',
         'stud_len','tilt_max_deg','riser_rise','base_plate_r','knob_force_req',
         'knob_force_limit','tilt_clamp_force','az_gear_teeth','tilt_wheel_teeth',
         'tilt_pinion_teeth','tripod_bolt_r','tripod_plate_d','payload_r',
         'payload_arm_r','tilt_torque_max','tilt_wheel_needed',
         'tilt_pinion_needed','payload_arm_dir','tilt_arm2_y','tilt_saddle_d','stud_thread_d','stud_pitch','tripod_hole_d','tilt_saddle_wrap','nut_d']
src = HERE / "_dump.scad"
src.write_text("include <params.scad>\n" +
               "".join(f'echo("P","{n}",{n});\n' for n in NAMES))
try:
    r = subprocess.run(["openscad", "-o", str(HERE/"build"/"_d.stl"), str(src)],
                       capture_output=True, text=True, cwd=HERE)
finally:
    src.unlink(missing_ok=True)
out = {}
for l in r.stderr.splitlines():
    m = re.match(r'ECHO: "P", "(\w+)", (.*)$', l.strip())
    if m:
        out[m.group(1)] = float(m.group(2))
missing = [n for n in NAMES if n not in out]
if missing:
    sys.exit(f"dump_params: not readable: {missing}")
(HERE / "build" / "viewer_params.json").write_text(json.dumps(out, indent=1))
print(f"{len(out)} params")
