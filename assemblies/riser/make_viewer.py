#!/usr/bin/env python3
"""Assemble the standalone WebGL viewer, data inlined."""
import json
from pathlib import Path

HERE = Path(__file__).parent
data = json.loads((HERE / "build" / "viewer_data.json").read_text())
P = json.loads((HERE / "build" / "viewer_params.json").read_text())

HTML = r"""<title>Riser Gimbal</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&display=swap">
<style>
:root{
  --ground:#E4E7EA; --surface:#F7F9FA; --sunk:#D4D9DE;
  --ink:#161C22; --ink-2:#495661; --ink-3:#78848E;
  --line:#C3CAD1; --accent:#2E6F7E; --accent-soft:#DCE8EA;
  --warn:#8A5A12; --warn-soft:#F2E6CF;
  --sky-a:#EDF1F3; --sky-b:#C9D2D8;
}
@media (prefers-color-scheme:dark){
  :root:not([data-theme="light"]){
    --ground:#12171B; --surface:#1A2127; --sunk:#0C1114;
    --ink:#E6EBEE; --ink-2:#A3B0B9; --ink-3:#6F7D87;
    --line:#2C363E; --accent:#63B4C4; --accent-soft:#1D3138;
    --warn:#D9A441; --warn-soft:#33270F;
    --sky-a:#1B2228; --sky-b:#0B0F12;
  }
}
:root[data-theme="dark"]{
  --ground:#12171B; --surface:#1A2127; --sunk:#0C1114;
  --ink:#E6EBEE; --ink-2:#A3B0B9; --ink-3:#6F7D87;
  --line:#2C363E; --accent:#63B4C4; --accent-soft:#1D3138;
  --warn:#D9A441; --warn-soft:#33270F;
  --sky-a:#1B2228; --sky-b:#0B0F12;
}
*{box-sizing:border-box}
body{
  margin:0; background:var(--ground); color:var(--ink);
  font-family:"IBM Plex Sans",system-ui,-apple-system,"Segoe UI",sans-serif;
  font-size:15px; line-height:1.5;
}
.shell{display:grid; grid-template-columns:minmax(0,1fr) 320px;
  gap:1px; background:var(--line); min-height:100vh}
@media (max-width:900px){ .shell{grid-template-columns:1fr} }

.stage{position:relative; background:var(--surface); min-height:62vh}
canvas{display:block; width:100%; height:100%; touch-action:none; cursor:grab}
canvas:active{cursor:grabbing}
.stamp{position:absolute; left:18px; top:16px; pointer-events:none}
.stamp h1{margin:0; font-size:19px; font-weight:600; letter-spacing:-.01em}
.stamp p{margin:2px 0 0; font-size:12px; color:var(--ink-3);
  font-family:"IBM Plex Mono",ui-monospace,monospace}
.hint{position:absolute; right:18px; bottom:14px; font-size:11.5px;
  color:var(--ink-3); font-family:"IBM Plex Mono",ui-monospace,monospace;
  pointer-events:none}

.rail{background:var(--surface); padding:22px 20px 28px;
  display:flex; flex-direction:column; gap:22px; overflow-y:auto}
.eyebrow{font-family:"IBM Plex Mono",ui-monospace,monospace; font-size:10.5px;
  letter-spacing:.13em; text-transform:uppercase; color:var(--ink-3);
  margin:0 0 10px}

.ctl{display:flex; flex-direction:column; gap:7px}
.ctl .row{display:flex; justify-content:space-between; align-items:baseline}
.ctl .nm{font-size:14px; font-weight:500}
.ctl .val{font-family:"IBM Plex Mono",ui-monospace,monospace; font-size:15px;
  font-variant-numeric:tabular-nums; color:var(--accent)}
.ctl .sub{font-size:11.5px; color:var(--ink-3);
  font-family:"IBM Plex Mono",ui-monospace,monospace;
  font-variant-numeric:tabular-nums}
input[type=range]{-webkit-appearance:none; appearance:none; width:100%;
  height:22px; background:transparent; margin:0}
input[type=range]::-webkit-slider-runnable-track{height:4px;
  background:var(--sunk); border-radius:2px}
input[type=range]::-moz-range-track{height:4px; background:var(--sunk);
  border-radius:2px}
input[type=range]::-webkit-slider-thumb{-webkit-appearance:none;
  width:16px; height:16px; border-radius:50%; background:var(--accent);
  border:2px solid var(--surface); margin-top:-6px}
input[type=range]::-moz-range-thumb{width:16px; height:16px; border:2px solid
  var(--surface); border-radius:50%; background:var(--accent)}
input[type=range]:focus-visible{outline:2px solid var(--accent);
  outline-offset:3px; border-radius:3px}

.lghead{display:flex; justify-content:space-between; align-items:baseline}
.lgbtns{display:flex; gap:5px}
button.mini{font-size:11px; padding:2px 7px; border-radius:3px}
.legend{display:flex; flex-direction:column; gap:3px}
button.lg{display:grid; grid-template-columns:14px 1fr auto; gap:9px;
  align-items:center; font-size:13px; width:100%; text-align:left;
  padding:5px 7px; border:1px solid transparent; background:transparent;
  color:var(--ink); border-radius:4px}
button.lg:hover{background:var(--accent-soft)}
button.lg[aria-pressed="false"]{color:var(--ink-3)}
button.lg[aria-pressed="false"] .sw{opacity:.22}
button.lg[aria-pressed="false"] .nm2{text-decoration:line-through}
.sw{width:12px; height:12px; border-radius:2px; display:inline-block}
.lg .role{font-family:"IBM Plex Mono",ui-monospace,monospace; font-size:10.5px;
  color:var(--ink-3); letter-spacing:.04em}

.facts{display:flex; flex-direction:column; gap:0; border-top:1px solid
  var(--line)}
.fact{display:flex; justify-content:space-between; gap:12px;
  padding:7px 0; border-bottom:1px solid var(--line); font-size:13px}
.fact b{font-weight:500; color:var(--ink-2)}
.fact span{font-family:"IBM Plex Mono",ui-monospace,monospace;
  font-variant-numeric:tabular-nums}

.note{background:var(--warn-soft); border-left:2px solid var(--warn);
  padding:11px 13px; font-size:12.5px; line-height:1.5; color:var(--ink-2)}
.note b{color:var(--warn); font-weight:600; display:block; margin-bottom:3px;
  font-family:"IBM Plex Mono",ui-monospace,monospace; font-size:10.5px;
  letter-spacing:.11em; text-transform:uppercase}

.toggles{display:flex; gap:8px; flex-wrap:wrap}
button{font:inherit; font-size:12.5px; padding:6px 11px; cursor:pointer;
  background:var(--surface); color:var(--ink-2);
  border:1px solid var(--line); border-radius:4px}
button[aria-pressed="true"]{background:var(--accent-soft);
  border-color:var(--accent); color:var(--accent)}
button:focus-visible{outline:2px solid var(--accent); outline-offset:2px}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>

<div class="shell">
  <div class="stage">
    <canvas id="gl"></canvas>
    <div class="stamp">
      <h1>Manual riser gimbal</h1>
      <p>1:1 hand-driven, under the motorised mount</p>
    </div>
    <div class="hint">drag to orbit &middot; scroll to zoom</div>
  </div>

  <aside class="rail">
    <div>
      <p class="eyebrow">Axes</p>
      <div class="ctl">
        <div class="row"><span class="nm">Azimuth</span>
          <span class="val" id="vaz">0&deg;</span></div>
        <input type="range" id="saz" min="0" max="360" step="1" value="0"
               aria-label="Azimuth angle in degrees">
        <div class="sub" id="kaz">knob turns &minus;0&deg;</div>
      </div>
    </div>
    <div class="ctl">
      <div class="row"><span class="nm">Tilt</span>
        <span class="val" id="vtl">0&deg;</span></div>
      <input type="range" id="stl" min="0" max="__TILTMAX__" step="1" value="0"
             aria-label="Tilt angle in degrees">
      <div class="sub" id="ktl">gravity torque 0.00 N&middot;m</div>
    </div>

    <div class="toggles">
      <button id="bsweep" aria-pressed="false">Sweep tilt</button>
      <button id="breset">Reset view</button>
    </div>

    <div>
      <div class="lghead">
        <p class="eyebrow">Bodies &mdash; click to hide</p>
        <span class="lgbtns">
          <button id="ball" class="mini">All</button>
          <button id="bnone" class="mini">None</button>
        </span>
      </div>
      <div class="legend" id="legend"></div>
    </div>

    <div>
      <p class="eyebrow">Dimensions</p>
      <div class="facts" id="facts"></div>
    </div>

    <div class="note">
      <b>Holding, not geometry</b>
      At the assumed payload the tilt knob needs
      <strong>__FORCE__&nbsp;N</strong> at the rim against a
      __LIMIT__&nbsp;N comfortable pinch. The pair&rsquo;s tooth sum is
      fixed, so __WN__/__PN__ teeth would fix it at the same centre
      distance &mdash; two reprinted parts. Reasoned from an unweighed
      payload; weigh the mount before printing.
    </div>
  </aside>
</div>

<script id="meshdata" type="application/json">__DATA__</script>
<script>
const P = __PARAMS__;
const RAW = JSON.parse(document.getElementById('meshdata').textContent);

// ---- decode the packed mesh blob -----------------------------------
function b64(s){
  const bin = atob(s), n = bin.length, out = new Uint8Array(n);
  for (let i=0;i<n;i++) out[i] = bin.charCodeAt(i);
  return out;
}
const BLOB = b64(RAW.blob);
const META = RAW.meta;

// Colour encodes KINEMATIC ROLE, not part identity: grounded bodies are
// neutral, driven bodies take a hue, and the two things a hand touches
// are the only warm, bright objects on screen.
const STYLE = {
  tripod_nut  : {c:[0.42,0.41,0.39], role:'ground',  nm:'Tripod hand nut'},
  pedestal    : {c:[0.60,0.60,0.58], role:'ground',  nm:'Pedestal'},
  az_column   : {c:[0.24,0.43,0.56], role:'azimuth', nm:'Column'},
  yoke        : {c:[0.34,0.56,0.64], role:'azimuth', nm:'Yoke (both tines)'},
  az_pinion   : {c:[0.72,0.45,0.20], role:'az drive',nm:'Azimuth pinion'},
  az_handle   : {c:[0.86,0.58,0.26], role:'az drive',nm:'Azimuth handle'},
  tilt_platter: {c:[0.62,0.29,0.29], role:'tilt',    nm:'Platter'},
  tilt_wheel  : {c:[0.49,0.21,0.21], role:'tilt',    nm:'Tilt gear (wheel)'},
  tilt_pinion : {c:[0.72,0.56,0.20], role:'tilt drive', nm:'Tilt gear (pinion)'},
  tilt_handle : {c:[0.88,0.70,0.28], role:'tilt drive', nm:'Tilt handle'},
  payload     : {c:[0.40,0.55,0.39], role:'payload', nm:'Motorised mount'},
};
// Per-part visibility. The legend rows are the switches, so the colour
// key and the control are the same object rather than two lists to keep
// in step.
const SHOWN = {};
for (const k in STYLE) SHOWN[k] = true;

// ---- 4x4 matrices, column-major ------------------------------------
const M = {
  id:()=>new Float32Array([1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]),
  mul(a,b){ const o=new Float32Array(16);
    for(let c=0;c<4;c++) for(let r=0;r<4;r++){ let s=0;
      for(let k=0;k<4;k++) s+=a[k*4+r]*b[c*4+k]; o[c*4+r]=s; } return o; },
  tr(x,y,z){ const m=M.id(); m[12]=x; m[13]=y; m[14]=z; return m; },
  rz(d){ const a=d*Math.PI/180,s=Math.sin(a),c=Math.cos(a),m=M.id();
    m[0]=c;m[1]=s;m[4]=-s;m[5]=c; return m; },
  ry(d){ const a=d*Math.PI/180,s=Math.sin(a),c=Math.cos(a),m=M.id();
    m[0]=c;m[2]=-s;m[8]=s;m[10]=c; return m; },
  rx(d){ const a=d*Math.PI/180,s=Math.sin(a),c=Math.cos(a),m=M.id();
    m[5]=c;m[6]=s;m[9]=-s;m[10]=c; return m; },
};
// Rotate about a horizontal Y line at height z0.
const aboutY = (deg,z0) => M.mul(M.tr(0,0,z0), M.mul(M.ry(deg), M.tr(0,0,-z0)));

// The same derivation assembly.scad and check.py use. Ground is the
// pedestal; nothing poses itself.
function modelMatrix(name, az, tilt){
  const z0 = P.tilt_axis_z, zk = P.tilt_axis_z - P.tilt_gear_cd;
  switch(name){
    case 'pedestal': case 'tripod_nut': return M.id();
    case 'az_column': case 'yoke': return M.rz(az);
    case 'az_handle': case 'az_pinion':   // spin on a FIXED pin; they do
      return M.mul(M.tr(P.az_gear_cd,0,0),     // not orbit
             M.mul(M.rz(-az), M.tr(-P.az_gear_cd,0,0)));
    case 'tilt_platter': case 'tilt_wheel':
      return M.mul(M.rz(az), aboutY(tilt, z0));
    case 'tilt_handle': case 'tilt_pinion':
      return M.mul(M.rz(az), aboutY(-tilt*P.tilt_ratio, zk));
    case 'payload':
      return M.mul(M.rz(az), M.mul(aboutY(tilt,z0),
             M.mul(M.tr(0,0,P.payload_face_z), M.rz(P.payload_arm_dir))));
  }
  return M.id();
}

// ---- GL -------------------------------------------------------------
const cv = document.getElementById('gl');
const gl = cv.getContext('webgl', {antialias:true, alpha:false});
const VS = `
attribute vec3 a_pos; attribute vec3 a_nrm;
uniform mat4 u_mvp, u_model; uniform float u_qs; uniform vec3 u_qc;
varying vec3 v_n; varying float v_z;
void main(){
  vec3 p = a_pos * u_qs + u_qc;
  vec4 w = u_model * vec4(p,1.0);
  v_n = normalize((u_model * vec4(a_nrm,0.0)).xyz);
  v_z = w.z;
  gl_Position = u_mvp * w;
}`;
const FS = `
precision mediump float;
varying vec3 v_n; varying float v_z;
uniform vec3 u_col; uniform float u_alpha;
void main(){
  vec3 n = normalize(v_n);
  vec3 L = normalize(vec3(0.42,-0.68,0.75));
  float d = max(dot(n,L),0.0);
  float hemi = 0.5 + 0.5*n.z;                 // sky above, ground below
  float rim = pow(1.0 - max(n.z,0.0), 3.0)*0.10;
  vec3 c = u_col * (0.30 + 0.52*hemi) + u_col*0.62*d + vec3(rim);
  c += vec3(0.9,0.94,1.0) * pow(d,26.0) * 0.30;
  gl_FragColor = vec4(pow(c, vec3(0.4545)), u_alpha);
}`;
function sh(t,s){ const o=gl.createShader(t); gl.shaderSource(o,s);
  gl.compileShader(o);
  if(!gl.getShaderParameter(o,gl.COMPILE_STATUS)) throw gl.getShaderInfoLog(o);
  return o; }
const prog = gl.createProgram();
gl.attachShader(prog, sh(gl.VERTEX_SHADER,VS));
gl.attachShader(prog, sh(gl.FRAGMENT_SHADER,FS));
gl.linkProgram(prog); gl.useProgram(prog);

const vbo = gl.createBuffer();
gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
gl.bufferData(gl.ARRAY_BUFFER, BLOB, gl.STATIC_DRAW);
const A_POS = gl.getAttribLocation(prog,'a_pos');
const A_NRM = gl.getAttribLocation(prog,'a_nrm');
gl.enableVertexAttribArray(A_POS); gl.enableVertexAttribArray(A_NRM);
const U = n => gl.getUniformLocation(prog,n);
gl.uniform1f(U('u_qs'), META.scale);
gl.uniform3fv(U('u_qc'), new Float32Array(META.centre));
gl.enable(gl.DEPTH_TEST);

// ---- camera ---------------------------------------------------------
const HOME = {yaw:-42, pitch:20, dist:430, tz:66};
let cam = Object.assign({}, HOME);
function persp(fov,asp,n,f){
  const t=1/Math.tan(fov*Math.PI/360), m=new Float32Array(16);
  m[0]=t/asp; m[5]=t; m[10]=(f+n)/(n-f); m[11]=-1; m[14]=2*f*n/(n-f);
  return m;
}
function viewMatrix(){
  return M.mul(M.tr(0,0,-cam.dist),
         M.mul(M.rx(-(90-cam.pitch)),
         M.mul(M.rz(-cam.yaw), M.tr(0,0,-cam.tz))));
}

let az=0, tilt=0;

function draw(){
  const dpr = Math.min(devicePixelRatio||1, 2);
  const w = cv.clientWidth|0, h = cv.clientHeight|0;
  if (cv.width!==w*dpr || cv.height!==h*dpr){ cv.width=w*dpr; cv.height=h*dpr; }
  gl.viewport(0,0,cv.width,cv.height);
  const css = getComputedStyle(document.documentElement);
  const bg = css.getPropertyValue('--sky-a').trim();
  const rgb = bg.match(/\w\w/g).map(x=>parseInt(x,16)/255);
  gl.clearColor(rgb[0],rgb[1],rgb[2],1);
  gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);

  const vp = M.mul(persp(34, w/h, 10, 2000), viewMatrix());
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
  gl.vertexAttribPointer(A_POS,3,gl.SHORT,false,12,0);
  gl.vertexAttribPointer(A_NRM,3,gl.BYTE,true,12,6);

  const order = META.parts.slice();
  for (const pt of order){
    if (!SHOWN[pt.name]) continue;
    const st = STYLE[pt.name];
    const mm = modelMatrix(pt.name, az, tilt);
    gl.uniformMatrix4fv(U('u_model'), false, mm);
    gl.uniformMatrix4fv(U('u_mvp'), false, vp);
    gl.uniform3fv(U('u_col'), new Float32Array(st.c));
    const trans = pt.name==='payload';
    gl.uniform1f(U('u_alpha'), trans?0.55:1.0);
    if (trans){ gl.enable(gl.BLEND);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA); gl.depthMask(false); }
    gl.drawArrays(gl.TRIANGLES, pt.offset/12, pt.count);
    if (trans){ gl.disable(gl.BLEND); gl.depthMask(true); }
  }
}

// ---- interaction ----------------------------------------------------
// Multi-pointer, because a phone has more than one finger and the first
// version assumed a mouse. One pointer orbits; two pinch to zoom. Tracking
// them in a Map rather than a single `drag` object is what makes the
// second finger a zoom instead of a jump in the orbit -- on a touch screen
// the old code read the midpoint of a pinch as a drag, which is why
// zooming and rotating fought each other.
const PTRS = new Map();
let pinch0 = null;

function pinchDist(){
  const p = [...PTRS.values()];
  return Math.hypot(p[0].x-p[1].x, p[0].y-p[1].y);
}
cv.addEventListener('pointerdown', e=>{
  cv.setPointerCapture(e.pointerId);
  PTRS.set(e.pointerId, {x:e.clientX, y:e.clientY});
  if (PTRS.size===2) pinch0 = {d:pinchDist(), dist:cam.dist};
});
cv.addEventListener('pointermove', e=>{
  const prev = PTRS.get(e.pointerId);
  if (!prev) return;
  e.preventDefault();
  if (PTRS.size===1){
    cam.yaw += (e.clientX-prev.x)*0.45;
    // Dragging DOWN tilts the model's top toward the viewer, the way
    // every 3D viewer people already use does it. The first pass had this
    // inverted.
    cam.pitch = Math.max(-85, Math.min(85,
                  cam.pitch - (e.clientY-prev.y)*0.35));
  }
  PTRS.set(e.pointerId, {x:e.clientX, y:e.clientY});
  if (PTRS.size===2 && pinch0){
    const d = pinchDist();
    if (d > 4) cam.dist = Math.max(150, Math.min(1100,
                            pinch0.dist * pinch0.d / d));
  }
  draw();
}, {passive:false});
function endPtr(e){ PTRS.delete(e.pointerId);
  if (PTRS.size<2) pinch0 = null; }
addEventListener('pointerup', endPtr);
addEventListener('pointercancel', endPtr);
// Wheel is for actual wheels. Some mobile browsers synthesise wheel events
// from touch scrolling, and with a pointer already down that arrives as
// "zoom while the user is rotating" -- which is exactly what it looked
// like. Ignored whenever a finger is on the canvas.
cv.addEventListener('wheel', e=>{ e.preventDefault();
  if (PTRS.size > 0) return;
  cam.dist = Math.max(150, Math.min(1100, cam.dist * (1+e.deltaY*0.0012)));
  draw(); }, {passive:false});

const saz=document.getElementById('saz'), stl=document.getElementById('stl');
function sync(){
  az = +saz.value; tilt = +stl.value;
  document.getElementById('vaz').textContent = az+'°';
  document.getElementById('vtl').textContent = tilt+'°';
  document.getElementById('kaz').textContent =
    'knob turns −'+az.toFixed(0)+'° — 1:1, opposite sense';
  const T = P.tilt_torque_max/Math.sin(P.tilt_max_deg*Math.PI/180)
            * Math.sin(tilt*Math.PI/180);
  document.getElementById('ktl').textContent =
    'gravity torque '+T.toFixed(2)+' N·m';
  draw();
}
saz.addEventListener('input', sync); stl.addEventListener('input', sync);

document.getElementById('breset').addEventListener('click', ()=>{
  cam=Object.assign({},HOME); draw(); });

let sweep=null;
const bs=document.getElementById('bsweep');
bs.addEventListener('click', ()=>{
  if (sweep){ cancelAnimationFrame(sweep); sweep=null;
    bs.setAttribute('aria-pressed','false'); return; }
  bs.setAttribute('aria-pressed','true');
  let t0=null;
  const step = (t)=>{ if(t0===null) t0=t;
    const u=((t-t0)/4200)%1;
    stl.value = Math.round(P.tilt_max_deg*(0.5-0.5*Math.cos(u*2*Math.PI)));
    saz.value = Math.round(((t-t0)/34)%361);
    sync(); sweep=requestAnimationFrame(step); };
  sweep=requestAnimationFrame(step);
});

// ---- rail content ---------------------------------------------------
const lg = document.getElementById('legend');
for (const pt of META.parts){
  const s = STYLE[pt.name];
  const row = document.createElement('button');
  row.className='lg'; row.type='button';
  row.setAttribute('aria-pressed','true');
  row.title = 'Show or hide '+s.nm;
  const sw = document.createElement('span'); sw.className='sw';
  sw.style.background = 'rgb('+s.c.map(v=>Math.round(v*255*1.15)).join(',')+')';
  const nm = document.createElement('span'); nm.className='nm2';
  nm.textContent = s.nm;
  const rl = document.createElement('span'); rl.className='role';
  rl.textContent = s.role;
  row.append(sw,nm,rl); lg.append(row);
  row.addEventListener('click', ()=>{
    SHOWN[pt.name] = !SHOWN[pt.name];
    row.setAttribute('aria-pressed', SHOWN[pt.name]);
    draw();
  });
}
document.getElementById('ball').addEventListener('click', ()=>{
  for (const k in SHOWN) SHOWN[k] = true;
  lg.querySelectorAll('.lg').forEach(b=>b.setAttribute('aria-pressed','true'));
  draw();
});
document.getElementById('bnone').addEventListener('click', ()=>{
  for (const k in SHOWN) SHOWN[k] = false;
  lg.querySelectorAll('.lg').forEach(b=>b.setAttribute('aria-pressed','false'));
  draw();
});
const facts = [
  ['Rise, tripod face to payload', P.riser_rise.toFixed(0)+' mm'],
  ['Tilt range', '0–'+P.tilt_max_deg.toFixed(0)+'°'],
  ['Azimuth', 'unlimited'],
  ['Azimuth pair', P.az_gear_teeth+'T → '+P.az_gear_teeth+'T, mod 2'],
  ['Tilt pair', P.tilt_wheel_teeth+'T → '+P.tilt_pinion_teeth
    +'T, mod 2.5 — one part, twice'],
  ['Base plate', (P.base_plate_r*2).toFixed(0)+' mm across'],
  ['Tripod plate', P.tripod_plate_d.toFixed(0)+' mm, '
    +(P.tripod_bolt_r*2).toFixed(1)+' mm post circle'],
  ['Tripod stud', 'M'+P.stud_thread_d.toFixed(0)+'×'+P.stud_pitch.toFixed(1)],
  ['Saddle seat wrap', P.tilt_saddle_wrap.toFixed(0)+'° on a '
    +P.tilt_saddle_d.toFixed(0)+' mm stub'],
  ['Trunnion preload', P.tilt_clamp_force.toFixed(0)+' N'],
];
const fw = document.getElementById('facts');
for (const [k,v] of facts){
  const d=document.createElement('div'); d.className='fact';
  d.innerHTML='<b></b><span></span>';
  d.querySelector('b').textContent=k; d.querySelector('span').textContent=v;
  fw.append(d);
}

addEventListener('resize', draw);
matchMedia('(prefers-color-scheme:dark)').addEventListener('change', draw);
sync();
</script>
"""

HTML = (HTML
        .replace("__DATA__", json.dumps(data))
        .replace("__PARAMS__", json.dumps(P))
        .replace("__TILTMAX__", str(int(P["tilt_max_deg"])))
        .replace("__FORCE__", f"{P['knob_force_req']:.0f}")
        .replace("__LIMIT__", f"{P['knob_force_limit']:.0f}")
        .replace("__WN__", str(int(P["tilt_wheel_needed"])))
        .replace("__PN__", str(int(P["tilt_pinion_needed"]))))
(HERE / "build" / "riser-viewer.html").write_text(HTML)
print(f"{len(HTML)/1e6:.2f} MB")
