// Contact sheet for the Poly Haven props.
//   props.html            every built GLB from /assets/props/manifest.json, labelled
//   props.html?src=<id>   that prop's source glTF, one tile per root node (variant picking)
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { MeshoptDecoder } from 'three/addons/libs/meshopt_decoder.module.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

// eslint-disable-next-line no-undef
const SOURCE_ROOT = `/@fs${__PROPS_SOURCE__}/`;
const params = new URLSearchParams(location.search);
const srcId = params.get('src');
const status = document.getElementById('status');

const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.setSize(innerWidth, innerHeight);
renderer.toneMapping = THREE.AgXToneMapping;
document.getElementById('app').appendChild(renderer.domElement);

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x2a2f36);
scene.environment = new THREE.PMREMGenerator(renderer).fromScene(new RoomEnvironment(), 0.04).texture;
const sun = new THREE.DirectionalLight(0xffffff, 1.6);
sun.position.set(3, 6, 4);
scene.add(sun, new THREE.GridHelper(40, 40, 0x555c66, 0x3a4048));

const camera = new THREE.PerspectiveCamera(40, innerWidth / innerHeight, 0.01, 200);
const controls = new OrbitControls(camera, renderer.domElement);
const labels = [];

const loader = new GLTFLoader().setMeshoptDecoder(MeshoptDecoder);
const load = (url) => new Promise((ok, fail) => loader.load(url, ok, undefined, fail));

function tile(object, name, x, z) {
  const box = new THREE.Box3().setFromObject(object);
  const size = box.getSize(new THREE.Vector3());
  const centre = box.getCenter(new THREE.Vector3());
  object.position.x += x - centre.x;
  object.position.z += z - centre.z;
  object.position.y -= box.min.y;
  scene.add(object);
  const el = document.createElement('div');
  el.className = 'label';
  el.textContent = name;
  document.body.appendChild(el);
  labels.push({ el, at: new THREE.Vector3(x, size.y + 0.05, z) });
  return size;
}

async function main() {
  const items = [];
  if (srcId) {
    const gltf = await load(`${SOURCE_ROOT}${srcId}/${srcId}.gltf`);
    for (const child of [...gltf.scene.children]) items.push({ name: child.name, object: child });
  } else {
    const manifest = await (await fetch('/assets/props/manifest.json')).json();
    const entries = Object.entries(manifest.props);
    const gltfs = await Promise.all(entries.map(([, p]) => load(`/assets/props/${p.file}`)));
    entries.forEach(([id, p], i) => items.push({ name: `${id} · ${p.tris}`, object: gltfs[i].scene }));
  }
  const cols = Math.ceil(Math.sqrt(items.length));
  const pitch = srcId ? 0.8 : 1.6;
  let maxDim = 0;
  items.forEach(({ name, object }, i) => {
    const size = tile(object, name, (i % cols) * pitch, Math.floor(i / cols) * pitch * 1.2);
    maxDim = Math.max(maxDim, size.x, size.z);
  });
  const w = (cols - 1) * pitch;
  const d = (Math.ceil(items.length / cols) - 1) * pitch * 1.2;
  controls.target.set(w / 2, 0.3, d / 2);
  camera.position.set(w / 2, Math.max(w, d) * 0.75 + 1, d / 2 + Math.max(w, d) * 0.9 + 1.2);
  if (params.has('top')) camera.position.set(w / 2, Math.max(w, d) * 1.3 + 1, d / 2 + 0.01);
  status.textContent = `${items.length} ${srcId ? `root nodes in ${srcId}` : 'props'}`;
}

function frame() {
  controls.update();
  renderer.render(scene, camera);
  for (const { el, at } of labels) {
    const p = at.clone().project(camera);
    el.style.left = `${(p.x * 0.5 + 0.5) * innerWidth}px`;
    el.style.top = `${(-p.y * 0.5 + 0.5) * innerHeight}px`;
    el.style.display = p.z < 1 ? '' : 'none';
  }
  requestAnimationFrame(frame);
}

addEventListener('resize', () => {
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
});
main().catch((e) => (status.textContent = String(e)));
frame();
