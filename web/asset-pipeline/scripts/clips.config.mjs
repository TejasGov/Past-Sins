// Character + clip table for build-characters.mjs.
//
// Every *.fbx in SOURCE_DIR other than the character itself is treated as an
// animation clip. Its normalized name comes from CLIP_TABLE (keyed by the FBX
// basename); files not listed fall back to snake_case of the basename, so a new
// Mixamo download dropped into the folder is picked up on the next build.

export const SOURCE_DIR = '../../assets/characters/models_mixamo';
export const OUTPUT_DIR = '../public/assets/characters';

export const CHARACTER = {
  source: 'Ch35_nonPBR.fbx',
  output: 'guard.glb',
  rootName: 'guard',
};

// loop:  true when the clip cycles (first frame == last frame).
// root:  how hips X/Z travel is removed (hips Y is always kept):
//        'linear' subtracts the constant drift (start→end) so a walk/run
//                 cycle stays in place but keeps its natural sway; the drift
//                 speed is reported as clipInfo.rootSpeed in the manifest.
//        'pin'    holds hips X/Z at the first frame (deaths, transitions).
//        Default: 'linear' for loops, 'pin' for one-shots.
// note:  copied into manifest.clipInfo for clips whose content doesn't match
//        their name (verified visually in the viewer).
export const CLIP_TABLE = {
  'Idle': { name: 'idle', loop: true },
  'Walking': { name: 'walk', loop: true },
  'Run Forward': { name: 'run_forward', loop: true },
  'Run Backwards': {
    name: 'run_backward',
    loop: false,
    note: 'Not a run cycle: steps back out of an aiming stance into a deep crouch and holds it. Download a real backward run (README) to replace it.',
  },
  'Run Left': { name: 'run_left', loop: true },
  'Run Right': { name: 'run_right', loop: true },
  'Idle Crouching': { name: 'crouch_idle', loop: true },
  'Crouch Walking': { name: 'crouch_walk', loop: true },
  'Gunplay': { name: 'gunplay', loop: true },
  'Reload_standing': {
    name: 'reload_standing',
    loop: false,
    root: 'linear',
    note: 'Reload while walking forward (legs keep stepping), authored at rootSpeed m/s. For a stationary reload use reload_idle.',
  },
  'Reload_crouch': { name: 'reload_crouch', loop: false },
  'Reloading_idle': { name: 'reload_idle', loop: false },
  'Crouch Death': { name: 'death_crouch', loop: false },
  'Death From Right': { name: 'death_from_right', loop: false },
  'Falling Back Death': { name: 'death_fall_back', loop: false },
  'Falling Forward Death': { name: 'death_fall_forward', loop: false },
  'Standing React Death Left': { name: 'death_react_left', loop: false },
};

// Fallback for FBX files not in CLIP_TABLE.
export function defaultClipEntry(basename) {
  const name = basename
    .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
    .replace(/[^A-Za-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .toLowerCase();
  const oneShot = /(^|_)(death|dying|die|reload|hit|react|shove|push|open|knock|stun|throw|alert|surprise|turn)[a-z]*(_|$)|stand_up|sit_down|to_sit|to_stand/;
  const loop = !oneShot.test(name);
  return { name, loop };
}

// Texture budget: longest edge in px. Raise a slot to 2048 only if the
// viewer shows visible blur at gameplay distances.
export const TEXTURES = {
  maxSize: 1024,
  quality: { baseColor: 85, normal: 90, roughness: 80 },
};
