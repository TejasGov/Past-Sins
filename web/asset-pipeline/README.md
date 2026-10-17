# Character asset pipeline

Turns the Mixamo FBX files in `assets/characters/models_mixamo/` into **one** web-ready
`web/public/assets/characters/guard.glb` (+ `manifest.json`) for the Three.js port,
and gives you a viewer to check every clip by eye.

```bash
cd web/asset-pipeline
npm install
npm run build:characters   # regenerates guard.glb + manifest.json from scratch (~12 s)
npm run viewer             # http://localhost:5180 (the "char-viewer" launch config)
```

The build is deterministic: deleting the outputs and rebuilding gives byte-identical files.

## Current output

| | |
|---|---|
| File | `web/public/assets/characters/guard.glb`, **2.25 MB** (2,362,772 bytes) |
| Mesh | 1 skinned mesh (`Ch35`), 3 primitives / 3 materials, 24,649 verts, 41,171 tris |
| Skeleton | 65 joints, `mixamorig:` prefix, root joint `mixamorig:Hips` |
| Size | 1.794 m tall, feet at y = −0.001, faces **+Z**, **Y-up**, metres |
| Clips | 17, all on the one skeleton, root motion removed (hips X/Z), hips Y kept |
| Textures | 9 × 1024² WebP (`EXT_texture_webp`): base colour, normal, roughness per material |
| Compression | `EXT_meshopt_compression` + `KHR_mesh_quantization` (UV/joints/weights/normals only) |
| Validation | Khronos glTF validator: 0 errors (3 warnings: tangents are generated at runtime, which three.js does) |

## Contract (what the game codes against)

`manifest.json`:

```jsonc
{
  "model": "guard.glb",
  "heightMeters": 1.794,
  "forward": "+Z",
  "up": "+Y",
  "compression": "meshopt",
  "clips": { "idle": "idle", "walk": "walk", /* … normalized name → clip name in the GLB */ },
  // Extra, optional (not part of the original contract):
  "clipInfo": {
    "walk": { "loop": true, "duration": 1.0333, "rootSpeed": 1.758, "rootTravel": [0, 1.817] },
    "run_backward": { "loop": false, …, "note": "Not a run cycle: …" }
  }
}
```

- `clips` keys are always the normalized names below; values are the GLB clip names (currently identical).
- `clipInfo.rootSpeed` (m/s) is the speed the clip was authored at before its root motion was
  removed. Move the guard at that speed, or scale `action.timeScale = speed / rootSpeed`, to avoid foot sliding.
- `clipInfo.rootTravel` is the hips X/Z offset that was removed over the whole clip (useful if
  you want a corpse to end up where the mocap fell).

Loading it in three.js:

```js
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { MeshoptDecoder } from 'three/addons/libs/meshopt_decoder.module.js'; // no wasm files needed
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';

const base = import.meta.env.BASE_URL + 'assets/characters/';
const manifest = await (await fetch(base + 'manifest.json')).json();
const gltf = await new GLTFLoader().setMeshoptDecoder(MeshoptDecoder).loadAsync(base + manifest.model);

const guard = SkeletonUtils.clone(gltf.scene);        // one clone per guard; textures/geometry are shared
guard.traverse((o) => { if (o.isSkinnedMesh) o.frustumCulled = false; }); // bind-pose bounds miss death poses
const mixer = new THREE.AnimationMixer(guard);
const clip = (name) => THREE.AnimationClip.findByName(gltf.animations, manifest.clips[name]);
mixer.clipAction(clip('walk')).play();
// one-shots: action.setLoop(THREE.LoopOnce, 1); action.clampWhenFinished = true;
```

## Clips (each one checked visually, see `out/<clip>.png`)

| Normalized | Source FBX | Length | Loop | Authored speed | What it actually is |
|---|---|---|---|---|---|
| `idle` | Idle | 16.63 s | yes | in place | Relaxed standing idle, weight shifts |
| `walk` | Walking | 1.03 s | yes | 1.76 m/s | Unarmed walk (arms swing, no rifle pose) |
| `run_forward` | Run Forward | 0.50 s | yes | 4.77 m/s | Rifle-held run, torso bladed |
| `run_backward` | Run Backwards | 1.50 s | **no** | in place | **Not a run.** Steps back from an aiming stance into a deep crouch and holds it |
| `run_left` | Run Left | 0.50 s | yes | 4.77 m/s | Rifle strafe run toward +X (the guard's left) |
| `run_right` | Run Right | 0.50 s | yes | 4.77 m/s | Rifle strafe run toward −X |
| `crouch_idle` | Idle Crouching | 2.10 s | yes | in place | Kneeling on one knee, rifle ready |
| `crouch_walk` | Crouch Walking | 1.17 s | yes | 1.21 m/s | Crouched rifle walk |
| `gunplay` | Gunplay | 0.27 s | yes | in place | Bladed shooting stance, recoil loop |
| `reload_standing` | Reload_standing | 4.10 s | no | 0.98 m/s | **Reload while walking forward** (legs keep stepping). Use `reload_idle` for a stationary reload |
| `reload_crouch` | Reload_crouch | 6.87 s | no | in place | Crouched reload, ends in the start pose |
| `reload_idle` | Reloading_idle | 3.30 s | no | in place | Standing stationary reload, ends in the start pose |
| `death_crouch` | Crouch Death | 2.37 s | no | pinned | From the kneel, falls onto the back |
| `death_from_right` | Death From Right | 3.30 s | no | pinned | Spins from a right-side hit, falls on the side |
| `death_fall_back` | Falling Back Death | 2.20 s | no | pinned | Falls backwards (big leg kick mid-fall) |
| `death_fall_forward` | Falling Forward Death | 2.57 s | no | pinned | Turns and falls face down |
| `death_react_left` | Standing React Death Left | 3.60 s | no | pinned | Staggers, falls onto the back |

All loop clips close (first frame = last frame). The rifle-posed clips have empty hands: **there is
no weapon mesh**. Parent a rifle to `mixamorig:RightHand` in the game. Death clips dip limbs up to
6 cm below y = 0 at some frames (that's in the source mocap, since hips Y is untouched).

## How the build works (`scripts/build-characters.mjs`)

1. **FBX → glTF.** Every `*.fbx` in `models_mixamo/` goes through FBX2glTF 0.9.7 (the binary inside the
   `fbx2gltf` npm package; on Apple Silicon it runs under Rosetta) at 30 fps. FBX2glTF already converts
   Mixamo centimetres to metres and keeps Y-up. Embedded textures are extracted to `.cache/` (never next
   to the sources).
2. **Character.** `Ch35_nonPBR.fbx` provides the mesh + skin; its own bind-pose take is dropped and the
   identity `RootNode` wrapper is flattened so the skinned mesh is a root node.
3. **Clips.** Every other FBX is merged onto the Ch35 skeleton **by bone name** (`mixamorig:`,
   `mixamorig1:` … prefixes ignored). Only rotations plus hips translation are copied, so the guard keeps
   its own bone lengths even if a clip was downloaded for another Mixamo character (hips height is rescaled
   if it differs by more than 2%). Bones FBX2glTF left unkeyed get a constant key when the clip file's rest
   pose differs from Ch35's. All 17 current clips matched all 65 bones.
4. **Root motion.** `root: 'linear'` (default for loops) subtracts the start→end hips X/Z drift, keeping
   the natural sway and a seamless loop. `root: 'pin'` (default for one-shots) holds hips X/Z at the first
   frame. Hips Y is always kept.
5. **Materials.** Mixamo "nonPBR" is diffuse/specular/glossiness. The specular maps are a flat ~4%
   dielectric value, so materials become metal/rough with metallic 0 and roughness = 1 − glossiness, built
   from the original gloss PNGs (not FBX2glTF's JPEG guess). Textures are resized to 1024² WebP.
6. **Optimise.** dedup → prune → resample (lossless keyframe reduction) → reorder → quantize →
   meshopt (FILTER mode: octahedral normals, 16-bit quaternion / exponential translation filters on
   animation data).
7. **Validate + write.** Runs the Khronos glTF validator (the build fails on errors), then writes
   `guard.glb`, `manifest.json` and `out/build-report.json` (per-clip bone matching, removed travel,
   hips height range, texture sizes, validator messages).

### Things that bit during development

- **Don't quantize skinned POSITION.** gltf-transform's `meshopt()` preset quantizes positions and
  folds the dequantization transform into the inverse bind matrices. Playback still looks fine, but
  `Skeleton.pose()` (and anything else that trusts the IBMs) collapses the body through the floor. The
  build therefore leaves POSITION as float32 (costs ~150 KB).
- **Declare `KHR_mesh_quantization`.** The meshopt octahedral filter stores normals as int8. three.js
  loads it either way, but the file is only valid glTF with the extension declared.
- `SkinnedMesh.computeBoundingBox()` reads `skeleton.boneMatrices`, which only refresh at render time.
  Call `skeleton.update()` first or you measure a stale pose.

## Adding or replacing clips

1. On mixamo.com select the same character (**Ch35**) so bone lengths match, pick the animation and
   download **FBX Binary, Without Skin, 30 fps, keyframe reduction none**. Leave "In Place" unchecked:
   the build removes the travel itself and reports the authored speed.
2. Save it into `assets/characters/models_mixamo/`. Any new FBX is picked up automatically: its
   normalized name is the snake_case filename (`Sneak Walk.fbx` → `sneak_walk`), loop = true unless the
   name looks like a one-shot (death, reload, hit, react, shove, push, open, knock, turn, stand-to-sit, …).
3. To pick the name/loop/root mode yourself, add a row to `CLIP_TABLE` in `scripts/clips.config.mjs`.
   Two files can't map to the same normalized name (the build stops). To replace `run_backward`, save the
   new download over `Run Backwards.fbx`, then set that row to `loop: true` and delete its `note`.
4. `npm run build:characters`, then check it in the viewer (below).

## Verifying (do this for every new clip)

`npm run viewer` (or the `char-viewer` preview) opens `viewer/`. It loads the GLB exactly like the game
(manifest → GLTFLoader + MeshoptDecoder), with a clip dropdown, play/pause/scrub, a SkeletonHelper, a
yellow 1.8 m reference box, a blue +Z arrow and a green line tracing the hips path over the whole clip.
The panel shows hips X/Z excursion and the mesh's lowest/highest point over the clip.

**save contact sheet** writes `out/<clip>.png`: 5 frames × (3/4 front, side, top). **save all** does
every clip. From the browser console or an automation tool:

```js
await viewer.contactSheet('walk');                   // one clip
await viewer.saveAll();                              // all clips
await viewer.bindPoseSheet();                        // out/_bind_pose.png: T-pose + texture close-ups
await viewer.contactSheet('walk', { views: ['side'], frames: 10, file: 'walk_side.png' });
```

Look at the images: no T-pose or exploded limbs, feet on the grid, the guard stays inside the box
(no drift), faces the blue arrow, textures on the right parts ("POLICE" on the chest, "SWAT" reading
correctly on the back in `_bind_pose.png`).

## Missing clips a stealth game will want

None of these are in `models_mixamo/` yet. Search mixamo.com with the term in the first column,
pick the closest match and download it as described above. Exact result names on Mixamo vary, so
check the preview before downloading.

| Need | Mixamo search term | Suggested file name → clip |
|---|---|---|
| Real backward run / backpedal (replaces the current `run_backward`) | `running backward`, `walking backward` | overwrite `Run Backwards.fbx` → `run_backward` |
| Armed patrol walk (current `walk` is unarmed, runs/crouches are rifle-posed) | `rifle walk` | `Rifle Walk.fbx` → `rifle_walk` |
| Sneaking walk | `sneak walk`, `sneaking` | `Sneak Walk.fbx` → `sneak_walk` |
| Searching / look-around idle | `looking around`, `searching` | `Looking Around.fbx` → `looking_around` |
| Alert / heard-something reaction | `alert`, `surprised`, `look over shoulder` | `Alert.fbx` → `alert` |
| Turn in place | `turn 90`, `left turn`, `right turn` | `Left Turn.fbx` → `left_turn` |
| Sitting (guard post, desk) | `sitting idle`, `stand to sit`, `sit to stand` | `Sitting Idle.fbx` → `sitting_idle` |
| Walking cuffed / hands behind back | `hands behind back`, `arrested`, `prisoner` | `Walking Cuffed.fbx` → `walking_cuffed` |
| Pushing / opening a door | `opening door`, `push door`, `pushing` | `Open Door.fbx` → `open_door` |
| Being shoved / stumble | `shoved`, `stumble backwards`, `hit reaction` | `Shoved.fbx` → `shoved` |
| Knocked out / takedown victim | `knocked out`, `stunned`, `choke` | `Knocked Out.fbx` → `knocked_out` |
| Talking / radio idle | `talking`, `phone call` | `Talking.fbx` → `talking` |

## Layout

```
web/asset-pipeline/
  scripts/build-characters.mjs   the pipeline
  scripts/clips.config.mjs       source/output paths, clip table, texture budget
  scripts/inspect-glb.mjs        prints structure of a built GLB (node scripts/inspect-glb.mjs [file])
  viewer/                        Vite app on port 5180 (index.html, main.js, vite.config.mjs)
  out/                           contact sheets + build-report.json
  .cache/                        FBX2glTF intermediates (deleted and rebuilt each run)
web/public/assets/characters/    guard.glb, manifest.json (build output, don't edit by hand)
```

`.gdignore` files in `web/asset-pipeline/` and `web/public/assets/characters/` stop the Godot editor
(which scans the whole repo) from importing the GLB and screenshots.
