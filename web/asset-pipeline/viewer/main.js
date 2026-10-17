// Clip viewer for guard.glb: loads the model exactly the way the game does
// (manifest.json + GLTFLoader + MeshoptDecoder), plays any clip, and renders
// contact sheets (several frames x several camera views) into ../out/.
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { MeshoptDecoder } from 'three/addons/libs/meshopt_decoder.module.js';

const ASSET_BASE = '/assets/characters/';
const $ = (id) => document.getElementById(id);
const status = (msg) => ($('status').textContent = msg);

// ------------------------------------------------------------------ scene

const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFShadowMap;
$('app').appendChild(renderer.domElement);

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x2a2f36);

const camera = new THREE.PerspectiveCamera(35, 1, 0.05, 100);
const controls = new OrbitControls(camera, renderer.domElement);
controls.target.set(0, 0.9, 0);

scene.add(new THREE.HemisphereLight(0xe4ecff, 0x4a443c, 1.4));
const key = new THREE.DirectionalLight(0xffffff, 2.4);
key.position.set(2.5, 4.5, 3.5);
key.castShadow = true;
key.shadow.mapSize.set(2048, 2048);
Object.assign(key.shadow.camera, { left: -2.5, right: 2.5, top: 2.5, bottom: -2.5, near: 0.5, far: 15 });
scene.add(key);
const rim = new THREE.DirectionalLight(0xbfd4ff, 0.9);
rim.position.set(-3, 3, -3);
scene.add(rim);

const ground = new THREE.Mesh(new THREE.PlaneGeometry(14, 14), new THREE.MeshStandardMaterial({ color: 0x5a5f66, roughness: 0.95 }));
ground.rotation.x = -Math.PI / 2;
ground.receiveShadow = true;
scene.add(ground);
const grid = new THREE.GridHelper(14, 28, 0x9aa3ad, 0x70777f);
grid.position.y = 0.002;
scene.add(grid);

// 1.8 m reference box (0.6 x 1.8 x 0.6), bottom on the ground at the origin.
const refBox = new THREE.LineSegments(
  new THREE.EdgesGeometry(new THREE.BoxGeometry(0.6, 1.8, 0.6)),
  new THREE.LineBasicMaterial({ color: 0xf0c674 }),
);
refBox.position.y = 0.9;
scene.add(refBox);

function label(text, color = '#ffffff', scale = 0.35) {
  const c = document.createElement('canvas');
  c.width = 256;
  c.height = 64;
  const g = c.getContext('2d');
  g.font = 'bold 34px ui-monospace, Menlo, monospace';
  g.fillStyle = color;
  g.textBaseline = 'middle';
  g.fillText(text, 6, 32);
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: new THREE.CanvasTexture(c), depthTest: false }));
  s.scale.set(scale * 4, scale, 1);
  return s;
}

// Axes on the ground: +Z (blue) is the model's forward, +X (red).
const axisZ = new THREE.ArrowHelper(new THREE.Vector3(0, 0, 1), new THREE.Vector3(0, 0.01, 0), 1.0, 0x4a90ff, 0.15, 0.08);
const axisX = new THREE.ArrowHelper(new THREE.Vector3(1, 0, 0), new THREE.Vector3(0, 0.01, 0), 0.6, 0xff5a5a, 0.12, 0.06);
scene.add(axisZ, axisX);
const zLabel = label('+Z fwd', '#7fb2ff', 0.18);
zLabel.position.set(0.3, 0.05, 1.15);
const boxLabel = label('1.8 m', '#f0c674', 0.16);
boxLabel.position.set(0.55, 1.82, 0.3);
scene.add(zLabel, boxLabel);

// Hips path over the whole clip, projected onto the ground.
const trail = new THREE.Line(new THREE.BufferGeometry(), new THREE.LineBasicMaterial({ color: 0x5cff8a }));
trail.renderOrder = 2;
scene.add(trail);

// ------------------------------------------------------------------ model

const manifest = await (await fetch(ASSET_BASE + 'manifest.json')).json();
const loader = new GLTFLoader().setMeshoptDecoder(MeshoptDecoder);
const gltf = await loader.loadAsync(ASSET_BASE + manifest.model);
const model = gltf.scene;
const skinned = [];
model.traverse((o) => {
  if (o.isSkinnedMesh) {
    o.castShadow = true;
    o.frustumCulled = false;
    skinned.push(o);
  }
});
scene.add(model);

const skeleton = new THREE.SkeletonHelper(model);
skeleton.material.depthTest = false;
skeleton.material.transparent = true;
skeleton.material.opacity = 0.85;
skeleton.renderOrder = 3;
scene.add(skeleton);

const bone = (n) => model.getObjectByName(`mixamorig:${n}`) ?? model.getObjectByName(`mixamorig${n}`);
const hips = bone('Hips');

const mixer = new THREE.AnimationMixer(model);
const clipNames = Object.keys(manifest.clips);
const clipFor = (name) => gltf.animations.find((a) => a.name === manifest.clips[name]);
for (const name of clipNames) {
  if (!clipFor(name)) console.error(`manifest clip ${name} -> ${manifest.clips[name]} missing from GLB`);
  $('clip').append(new Option(name, name));
}

let current = null;
let action = null;
let playing = true;
let speed = 1;
const statsCache = new Map();

function poseAt(t) {
  action.time = Math.min(t, action.getClip().duration);
  mixer.update(0);
  model.updateMatrixWorld(true);
}

const _v = new THREE.Vector3();
const _box = new THREE.Box3();
function meshBox() {
  _box.makeEmpty();
  for (const m of skinned) {
    m.skeleton.update(); // boneMatrices are otherwise only refreshed at render time
    m.computeBoundingBox();
    _box.union(m.boundingBox.clone().applyMatrix4(m.matrixWorld));
  }
  return _box.clone();
}

function computeStats(name) {
  if (statsCache.has(name)) return statsCache.get(name);
  const clip = action.getClip();
  const steps = 40;
  const path = [];
  let minY = Infinity, maxMinY = -Infinity, maxY = -Infinity, maxXZ = 0;
  for (let i = 0; i <= steps; i++) {
    poseAt((clip.duration * i) / steps * 0.9999);
    hips.getWorldPosition(_v);
    path.push(new THREE.Vector3(_v.x, 0.006, _v.z));
    maxXZ = Math.max(maxXZ, Math.hypot(_v.x, _v.z));
    const b = meshBox();
    minY = Math.min(minY, b.min.y);
    maxMinY = Math.max(maxMinY, b.min.y);
    maxY = Math.max(maxY, b.max.y);
  }
  const s = { duration: clip.duration, path, minY, maxMinY, maxY, maxXZ };
  statsCache.set(name, s);
  return s;
}

function showStats(name) {
  const s = computeStats(name);
  const info = manifest.clipInfo?.[name] ?? {};
  trail.geometry.setFromPoints(s.path);
  $('stats').textContent = [
    `clip      ${manifest.clips[name]}  ${s.duration.toFixed(2)}s ${info.loop ? 'loop' : 'once'}`,
    `hips xz   max ${(s.maxXZ * 100).toFixed(1)} cm from origin`,
    `mesh minY ${s.minY.toFixed(3)} .. ${s.maxMinY.toFixed(3)} m (ground contact)`,
    `mesh maxY ${s.maxY.toFixed(3)} m`,
    `authored  ${info.rootSpeed ? info.rootSpeed + ' m/s' : 'in place'}`,
  ].join('\n');
}

function setClip(name) {
  if (!clipFor(name)) throw new Error(`no clip ${name}`);
  current = name;
  $('clip').value = name;
  mixer.stopAllAction();
  action = mixer.clipAction(clipFor(name));
  action.setLoop(THREE.LoopRepeat, Infinity).reset().play();
  $('time').max = clipFor(name).duration;
  showStats(name);
  poseAt(0);
  return name;
}

// ------------------------------------------------------------------ cameras

const VIEWS = {
  front3q: { dir: [0.55, 0.22, 1], target: [0, 0.85, 0], dist: 4.6 },
  front: { dir: [0, 0.12, 1], target: [0, 0.85, 0], dist: 4.6 },
  back: { dir: [0, 0.12, -1], target: [0, 0.85, 0], dist: 4.6 },
  side: { dir: [1, 0.1, 0], target: [0, 0.75, 0], dist: 4.8 },
  top: { dir: [0.0001, 1, 0.35], target: [0, 0, 0], dist: 5.2 },
  faceFront: { dir: [0.25, 0.08, 1], target: [0, 1.45, 0], dist: 1.6 },
  torsoBack: { dir: [-0.25, 0.08, -1], target: [0, 1.25, 0], dist: 2.0 },
};

function applyView(cam, name, ctl) {
  const v = VIEWS[name];
  const dir = new THREE.Vector3(...v.dir).normalize();
  const target = new THREE.Vector3(...v.target);
  cam.position.copy(target).addScaledVector(dir, v.dist);
  cam.lookAt(target);
  if (ctl) {
    ctl.target.copy(target);
    ctl.update();
  }
}

for (const name of Object.keys(VIEWS)) {
  const b = document.createElement('button');
  b.textContent = name;
  b.onclick = () => applyView(camera, name, controls);
  $('views').append(b);
}

// ------------------------------------------------------------------ contact sheets

let sheetRenderer = null;
async function contactSheet(name = current, opts = {}) {
  const { views = ['front3q', 'side', 'top'], frames = 5, tileW = 300, tileH = 360, skeletonOverlay = false, times = null, file = `${name}.png` } = opts;
  setClip(name);
  const s = computeStats(name);
  trail.geometry.setFromPoints(s.path);
  sheetRenderer ??= new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
  sheetRenderer.shadowMap.enabled = true;
  sheetRenderer.setPixelRatio(1);
  sheetRenderer.setSize(tileW, tileH, false);
  const cam = new THREE.PerspectiveCamera(35, tileW / tileH, 0.05, 100);

  const ts = times ?? Array.from({ length: frames }, (_, i) => (s.duration * i) / (frames - 1) * (i === frames - 1 ? 0.999 : 1));
  const header = 46;
  const canvas = document.createElement('canvas');
  canvas.width = tileW * ts.length;
  canvas.height = header + tileH * views.length;
  const g = canvas.getContext('2d');
  g.fillStyle = '#111418';
  g.fillRect(0, 0, canvas.width, canvas.height);
  g.fillStyle = '#ffffff';
  g.font = 'bold 18px ui-monospace, Menlo, monospace';
  const info = manifest.clipInfo?.[name] ?? {};
  g.fillText(`${name}  (${s.duration.toFixed(2)}s, ${info.loop ? 'loop' : 'once'})`, 10, 20);
  g.font = '13px ui-monospace, Menlo, monospace';
  g.fillStyle = '#aab3bd';
  g.fillText(`hips xz max ${(s.maxXZ * 100).toFixed(1)} cm | mesh minY ${s.minY.toFixed(3)}..${s.maxMinY.toFixed(3)} | maxY ${s.maxY.toFixed(3)} | yellow box 1.8 m, blue arrow +Z, green = hips path`, 10, 38);

  const skelWas = skeleton.visible;
  skeleton.visible = skeletonOverlay;
  views.forEach((view, row) => {
    applyView(cam, view);
    ts.forEach((t, col) => {
      poseAt(t);
      sheetRenderer.render(scene, cam);
      const x = col * tileW;
      const y = header + row * tileH;
      g.drawImage(sheetRenderer.domElement, x, y, tileW, tileH);
      g.strokeStyle = '#000';
      g.strokeRect(x + 0.5, y + 0.5, tileW - 1, tileH - 1);
      g.fillStyle = 'rgba(0,0,0,0.55)';
      g.fillRect(x, y, 150, 20);
      g.fillStyle = '#fff';
      g.font = '12px ui-monospace, Menlo, monospace';
      g.fillText(`${view} t=${t.toFixed(2)}s`, x + 5, y + 14);
    });
  });
  skeleton.visible = skelWas;

  const blob = await new Promise((r) => canvas.toBlob(r, 'image/png'));
  const res = await fetch(`/__save/${encodeURIComponent(file)}`, { method: 'POST', body: blob });
  const out = await res.json();
  status(`saved ${out.saved}`);
  return { ...out, stats: { duration: s.duration, maxXZ: s.maxXZ, minY: s.minY, maxMinY: s.maxMinY, maxY: s.maxY } };
}

async function saveAll() {
  const results = {};
  for (const name of clipNames) {
    status(`rendering ${name}…`);
    results[name] = await contactSheet(name);
  }
  return results;
}

// Bind pose (no clip applied) and texture close-ups.
async function bindPoseSheet() {
  mixer.stopAllAction();
  for (const m of skinned) m.skeleton.pose();
  model.updateMatrixWorld(true);
  sheetRenderer ??= new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
  const views = ['front', 'side', 'back', 'faceFront', 'torsoBack'];
  const tileW = 360, tileH = 420;
  sheetRenderer.setPixelRatio(1);
  sheetRenderer.setSize(tileW, tileH, false);
  const cam = new THREE.PerspectiveCamera(35, tileW / tileH, 0.05, 100);
  const canvas = document.createElement('canvas');
  canvas.width = tileW * views.length;
  canvas.height = tileH;
  const g = canvas.getContext('2d');
  const b = meshBox();
  trail.geometry.setFromPoints([]);
  views.forEach((view, i) => {
    applyView(cam, view);
    sheetRenderer.render(scene, cam);
    g.drawImage(sheetRenderer.domElement, i * tileW, 0);
    g.fillStyle = 'rgba(0,0,0,0.6)';
    g.fillRect(i * tileW, 0, 360, 20);
    g.fillStyle = '#fff';
    g.font = '12px ui-monospace, Menlo, monospace';
    g.fillText(`bind pose ${view}  h=${b.max.y.toFixed(3)} minY=${b.min.y.toFixed(3)}`, i * tileW + 5, 14);
  });
  const blob = await new Promise((r) => canvas.toBlob(r, 'image/png'));
  const res = await fetch('/__save/_bind_pose.png', { method: 'POST', body: blob });
  if (current) setClip(current);
  return { ...(await res.json()), box: { min: b.min.toArray(), max: b.max.toArray() } };
}

// ------------------------------------------------------------------ UI + loop

$('clip').onchange = (e) => setClip(e.target.value);
$('play').onclick = () => {
  playing = !playing;
  $('play').textContent = playing ? 'pause' : 'play';
};
$('speed').onchange = (e) => (speed = +e.target.value);
$('time').oninput = (e) => {
  playing = false;
  $('play').textContent = 'play';
  poseAt(+e.target.value);
};
$('skeleton').onchange = (e) => (skeleton.visible = e.target.checked);
$('mesh').onchange = (e) => skinned.forEach((m) => (m.visible = e.target.checked));
$('trail').onchange = (e) => (trail.visible = e.target.checked);
$('sheet').onclick = () => contactSheet(current).catch((e) => status(String(e)));
$('sheetAll').onclick = () => saveAll().catch((e) => status(String(e)));

function resize() {
  renderer.setSize(innerWidth, innerHeight);
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
}
addEventListener('resize', resize);
resize();

const params = new URLSearchParams(location.search);
applyView(camera, params.get('view') ?? 'front3q', controls);
setClip(params.get('clip') ?? (clipNames.includes('idle') ? 'idle' : clipNames[0]));

const timer = new THREE.Timer();
renderer.setAnimationLoop(() => {
  timer.update();
  const dt = timer.getDelta();
  if (playing && action) {
    mixer.update(dt * speed);
    $('time').value = action.time;
  }
  controls.update();
  renderer.render(scene, camera);
});

window.viewer = { manifest, gltf, clipNames, setClip, poseAt, contactSheet, saveAll, bindPoseSheet, computeStats, applyView: (v) => applyView(camera, v, controls), mixer };
status(`loaded ${manifest.model}: ${gltf.animations.length} clips`);
