import {
  Color,
  DoubleSide,
  LinearSRGBColorSpace,
  Material,
  MeshBasicMaterial,
  MeshStandardMaterial,
  RepeatWrapping,
  SRGBColorSpace,
  Texture,
  TextureLoader,
  type WebGLProgramParametersWithUniforms,
  type WebGLRenderer,
} from "three";

/** Shared uniforms; mutating `.value` updates every patched material at once. */
export const sharedUniforms = {
  uWetness: { value: 0 },
  uTime: { value: 0 },
  uGrime: { value: 1 },
};

export type MaterialKey =
  | "concrete" | "concrete_ext" | "plaster" | "metal" | "metal_ext" | "dark" | "dark_ext" | "steel" | "iron"
  | "wood" | "tiles" | "tile_shower" | "rubber" | "asphalt" | "gravel" | "grass" | "court"
  | "fabric" | "plastic" | "screen" | "glass" | "emissive_night" | "emissive_always" | "emissive_red"
  | "emissive_green" | "emissive_cyan" | "paper" | "hazard" | "fence" | "gunmetal";

interface TextureSet {
  map?: string;
  normal?: string;
  rough?: string;
  metal?: string;
  alpha?: string;
  tile: number; // metres per texture repeat
}

interface MaterialSpec {
  set?: TextureSet;
  color?: number;
  roughness?: number;
  metalness?: number;
  exterior?: boolean;
  grime?: number;
  normalScale?: number;
  emissive?: number;
  emissiveIntensity?: number;
}

const T = (name: string, tile: number, extra: Partial<TextureSet> = {}): TextureSet => ({
  map: `${name}_albedo`,
  normal: `${name}_normal`,
  rough: `${name}_roughness`,
  tile,
  ...extra,
});

const SPECS: Record<MaterialKey, MaterialSpec> = {
  concrete: { set: T("concrete", 3), roughness: 1, grime: 1.35, normalScale: 0.9 },
  concrete_ext: { set: T("concrete", 3.2), roughness: 1, grime: 1, exterior: true, normalScale: 1 },
  plaster: { set: T("plaster", 2.5), roughness: 1, grime: 0.95, normalScale: 0.5 },
  metal: { set: T("metal", 1.6), roughness: 0.9, metalness: 0.35, grime: 0.5, normalScale: 0.6 },
  metal_ext: { set: T("metal", 1.6), roughness: 0.9, metalness: 0.35, grime: 0.6, exterior: true, normalScale: 0.6 },
  dark: { set: T("metal", 1.6), color: 0x5a605c, roughness: 0.85, metalness: 0.4, grime: 0.4, normalScale: 0.5 },
  dark_ext: { set: T("metal", 1.6), color: 0x5a605c, roughness: 0.85, metalness: 0.4, grime: 0.5, exterior: true },
  steel: { set: T("steel", 1.2), roughness: 0.55, metalness: 0.85, grime: 0.25, normalScale: 0.4 },
  iron: { set: { ...T("iron", 1.0), metal: "iron_metalness" }, roughness: 0.75, metalness: 1, grime: 0.3, normalScale: 0.7 },
  wood: { set: T("wood_furniture", 1.2), roughness: 0.8, grime: 0.2, normalScale: 0.6 },
  tiles: { set: T("tiles", 1.5), roughness: 0.6, grime: 0.6, normalScale: 0.7 },
  tile_shower: { set: T("tile_shower", 1.2), roughness: 0.4, grime: 0.6, normalScale: 0.7 },
  rubber: { set: T("gym_rubber", 2), roughness: 0.95, grime: 0.2 },
  asphalt: { set: T("asphalt", 4), roughness: 0.95, grime: 0.4, exterior: true },
  gravel: { set: T("gravel", 2.5), roughness: 1, grime: 0.2, exterior: true },
  grass: { set: T("grass", 3.5), roughness: 1, grime: 0.15, exterior: true },
  court: { set: T("court_concrete", 4), roughness: 0.9, grime: 0.5, exterior: true },
  fence: { set: { ...T("fence", 2.5), alpha: "fence_opacity" }, roughness: 0.6, metalness: 0.7, exterior: true },
  fabric: { color: 0xffffff, roughness: 0.95, grime: 0.3 },
  gunmetal: { set: { ...T("gunmetal", 0.35), metal: "gunmetal_metalness" }, roughness: 0.6, metalness: 1, normalScale: 0.5 },
  plastic: { color: 0xffffff, roughness: 0.55, grime: 0.2 },
  paper: { color: 0xffffff, roughness: 0.9 },
  hazard: { set: T("metal", 1.2), color: 0xf3c33c, roughness: 0.7, metalness: 0.2, grime: 0.6 },
  screen: { color: 0x0d1416, roughness: 0.2, metalness: 0.1, emissive: 0x2f6d68, emissiveIntensity: 0.6 },
  glass: { color: 0x6d8f92, roughness: 0.05, metalness: 0.2 },
  emissive_night: { emissive: 0xffe2a8, emissiveIntensity: 4 },
  emissive_always: { emissive: 0xfff0d0, emissiveIntensity: 3.5 },
  emissive_red: { emissive: 0xff3b24, emissiveIntensity: 6 },
  emissive_green: { emissive: 0x52ff96, emissiveIntensity: 5 },
  emissive_cyan: { emissive: 0x48e6ff, emissiveIntensity: 6 },
};

export const EMISSIVE_KEYS: MaterialKey[] = ["emissive_night", "emissive_always", "emissive_red", "emissive_green", "emissive_cyan"];

const GRIME_PARS = /* glsl */ `
varying vec3 vGWorldPos;
varying vec3 vGWorldNormal;
uniform float uWetness;
uniform float uGrime;
uniform float uGrimeStrength;
uniform float uExterior;
float gHash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float gNoise(vec3 x) {
  vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(mix(gHash(i), gHash(i + vec3(1,0,0)), f.x), mix(gHash(i + vec3(0,1,0)), gHash(i + vec3(1,1,0)), f.x), f.y),
             mix(mix(gHash(i + vec3(0,0,1)), gHash(i + vec3(1,0,1)), f.x), mix(gHash(i + vec3(0,1,1)), gHash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float gFbm(vec3 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * gNoise(p); p *= 2.07; a *= 0.5; } return v; }
`;

const GRIME_MAP = /* glsl */ `
#include <map_fragment>
float gWall = 1.0 - abs(vGWorldNormal.y);
float gBlotch = gFbm(vGWorldPos * 0.33);
float gStreak = gFbm(vec3((vGWorldPos.x + vGWorldPos.z) * 2.4, vGWorldPos.y * 0.16, 1.7));
float gFine = gFbm(vGWorldPos * 2.7 + 7.0);
float gHeight = mod(vGWorldPos.y + 0.02, 4.0);
float gBase = gWall * (1.0 - smoothstep(0.0, 0.7, gHeight)) * 0.55;
float gStain = smoothstep(0.44, 0.84, gBlotch) * 0.6 + gWall * smoothstep(0.5, 0.9, gStreak) * 0.55 + gBase + (gFine - 0.5) * 0.25;
diffuseColor.rgb *= 1.0 - uGrime * uGrimeStrength * clamp(gStain, 0.0, 0.82);
// Cold, slightly green institutional cast on stained areas (damp concrete).
diffuseColor.rgb = mix(diffuseColor.rgb, diffuseColor.rgb * vec3(0.86, 0.95, 0.92), uGrime * uGrimeStrength * smoothstep(0.3, 0.8, gStain));
float gUp = smoothstep(0.6, 0.95, vGWorldNormal.y);
float gPuddle = smoothstep(0.44, 0.64, gFbm(vGWorldPos * 0.21 + 3.0));
float gWet = uWetness * uExterior * mix(0.5 * gWall, mix(0.55, 1.0, gPuddle), gUp);
diffuseColor.rgb *= 1.0 - 0.42 * gWet;
`;

const GRIME_ROUGH = /* glsl */ `
#include <roughnessmap_fragment>
roughnessFactor = mix(roughnessFactor, mix(0.34, 0.04, gPuddle * gUp), gWet);
roughnessFactor *= 1.0 - 0.18 * uGrime * uGrimeStrength * smoothstep(0.55, 0.9, gBlotch);
`;

function patchShader(shader: WebGLProgramParametersWithUniforms, strength: number, exterior: boolean): void {
  shader.uniforms.uWetness = sharedUniforms.uWetness;
  shader.uniforms.uGrime = sharedUniforms.uGrime;
  shader.uniforms.uGrimeStrength = { value: strength };
  shader.uniforms.uExterior = { value: exterior ? 1 : 0 };
  shader.vertexShader = shader.vertexShader
    .replace("#include <common>", "#include <common>\nvarying vec3 vGWorldPos;\nvarying vec3 vGWorldNormal;")
    .replace(
      "#include <begin_vertex>",
      `#include <begin_vertex>
      vec4 gWorld = vec4(transformed, 1.0);
      #ifdef USE_INSTANCING
        gWorld = instanceMatrix * gWorld;
      #endif
      vGWorldPos = (modelMatrix * gWorld).xyz;
      vec3 gN = objectNormal;
      #ifdef USE_INSTANCING
        gN = mat3(instanceMatrix) * gN;
      #endif
      vGWorldNormal = normalize(mat3(modelMatrix) * gN);`,
    );
  shader.fragmentShader = shader.fragmentShader
    .replace("#include <common>", "#include <common>\n" + GRIME_PARS)
    .replace("#include <map_fragment>", GRIME_MAP)
    .replace("#include <roughnessmap_fragment>", GRIME_ROUGH);
}

/**
 * Hook that lets the lighting system (CSM) prepare a material before our own
 * patch runs. CSM replaces onBeforeCompile, so we chain onto whatever it set.
 */
export type MaterialPreparer = (material: Material) => void;

export class MaterialLibrary {
  private loader = new TextureLoader();
  private textures = new Map<string, Texture>();
  private materials = new Map<MaterialKey, Material>();
  private anisotropy: number;
  readonly ready: Promise<void>;
  private pending: Promise<unknown>[] = [];

  constructor(renderer: WebGLRenderer, private prepare: MaterialPreparer) {
    this.anisotropy = Math.min(8, renderer.capabilities.getMaxAnisotropy());
    for (const key of Object.keys(SPECS) as MaterialKey[]) this.materials.set(key, this.build(key));
    this.ready = Promise.all(this.pending).then(() => undefined);
  }

  get(key: MaterialKey): Material {
    return this.materials.get(key)!;
  }

  all(): Material[] {
    return [...this.materials.values()];
  }

  texture(name: string, tile: number, srgb: boolean): Texture {
    const id = `${name}@${tile}`;
    let tex = this.textures.get(id);
    if (tex) return tex;
    // One Texture per (image, tiling); the browser caches the shared image.
    let done: () => void = () => {};
    this.pending.push(new Promise<void>((resolve) => (done = resolve)));
    tex = this.loader.load(`textures/${name}.webp`, () => done(), undefined, () => done());
    tex.wrapS = tex.wrapT = RepeatWrapping;
    tex.repeat.set(1 / tile, 1 / tile);
    tex.anisotropy = this.anisotropy;
    tex.colorSpace = srgb ? SRGBColorSpace : LinearSRGBColorSpace;
    this.textures.set(id, tex);
    return tex;
  }

  private build(key: MaterialKey): Material {
    const spec = SPECS[key];
    if (key.startsWith("emissive")) {
      // Unlit diffusers: bright enough to feed bloom. Night-only diffusers are
      // dimmed through `setEmissiveLevel` rather than swapping materials.
      const mat = new MeshBasicMaterial({ color: new Color(spec.emissive!).multiplyScalar(spec.emissiveIntensity!) });
      mat.toneMapped = true;
      mat.userData.baseColor = mat.color.clone();
      return mat;
    }
    const mat = new MeshStandardMaterial({
      color: spec.color ?? 0xffffff,
      roughness: spec.roughness ?? 0.9,
      metalness: spec.metalness ?? 0,
      vertexColors: true,
    });
    if (spec.emissive !== undefined) {
      mat.emissive = new Color(spec.emissive);
      mat.emissiveIntensity = spec.emissiveIntensity ?? 1;
    }
    if (spec.set) {
      const s = spec.set;
      if (s.map) mat.map = this.texture(s.map, s.tile, true);
      if (s.normal) {
        mat.normalMap = this.texture(s.normal, s.tile, false);
        const n = spec.normalScale ?? 1;
        mat.normalScale.set(n, n);
      }
      if (s.rough) mat.roughnessMap = this.texture(s.rough, s.tile, false);
      if (s.metal) mat.metalnessMap = this.texture(s.metal, s.tile, false);
      if (s.alpha) {
        mat.alphaMap = this.texture(s.alpha, s.tile, false);
        mat.alphaTest = 0.5;
        mat.side = DoubleSide;
      }
    }
    if (key === "glass") {
      mat.transparent = true;
      mat.opacity = 0.28;
      mat.depthWrite = false;
      mat.side = DoubleSide;
    }
    const strength = spec.grime ?? 0;
    const exterior = spec.exterior ?? false;
    this.prepare(mat);
    applyGrime(mat, strength, exterior);
    return mat;
  }

  /** Night-only diffusers fade between a dim daytime glow and full output. */
  setNightLevel(level: number): void {
    const mat = this.materials.get("emissive_night") as MeshBasicMaterial;
    mat.color.copy(mat.userData.baseColor as Color).multiplyScalar(0.06 + 0.94 * level);
  }
}

/** Chains the grime/wetness patch onto any existing onBeforeCompile (CSM). */
export function applyGrime(mat: Material, strength: number, exterior: boolean): void {
  const previous = mat.onBeforeCompile.bind(mat);
  mat.onBeforeCompile = (shader, renderer) => {
    previous(shader, renderer);
    patchShader(shader, strength, exterior);
  };
  const previousKey = mat.customProgramCacheKey.bind(mat);
  mat.customProgramCacheKey = () => `${previousKey()}|grime${exterior ? "E" : "I"}`;
}

/** Vertex color for a box: a relative tint on textured materials, else albedo. */
export function vertexColorFor(key: MaterialKey, hex: number): Color {
  return SPECS[key].set ? tint(hex) : new Color(hex);
}

/** Converts a Godot-style sRGB greybox color into a texture tint multiplier. */
export function tint(hex: number, gain = 1): Color {
  const c = new Color(hex);
  // Color() stores linear values; work in sRGB space for the relative tint.
  const srgb = c.clone().convertLinearToSRGB();
  const f = (v: number) => Math.min(1.5, Math.max(0.1, (v / 0.52) * gain));
  return new Color(f(srgb.r), f(srgb.g), f(srgb.b));
}
