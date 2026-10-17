import {
  AnimationAction, AnimationClip, AnimationMixer, CapsuleGeometry, Group, LoopOnce, LoopRepeat, Material, Mesh, MeshStandardMaterial, Object3D, SkinnedMesh,
} from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { MeshoptDecoder } from "three/addons/libs/meshopt_decoder.module.js";
import { DRACOLoader } from "three/addons/loaders/DRACOLoader.js";
import * as SkeletonUtils from "three/addons/utils/SkeletonUtils.js";

/** web/public/assets/characters/manifest.json (character-pipeline contract). */
export interface CharacterManifest {
  model: string;
  heightMeters: number;
  forward: "+Z" | "-Z";
  up: "+Y";
  compression: "meshopt" | "draco" | "none";
  clips: Record<string, string>;
  clipInfo?: Record<string, { loop: boolean; duration: number; rootSpeed: number }>;
}

export interface CharacterAsset {
  manifest: CharacterManifest;
  scene: Object3D;
  clips: Map<string, AnimationClip>;
}

const BASE = "assets/characters/";

/** Loads the guard GLB once; returns null (→ capsule fallback) if missing. */
export async function loadCharacter(prepare: (m: Material) => void): Promise<CharacterAsset | null> {
  try {
    const res = await fetch(`${BASE}manifest.json`);
    if (!res.ok) return null;
    const manifest = (await res.json()) as CharacterManifest;
    const loader = new GLTFLoader();
    if (manifest.compression === "meshopt") loader.setMeshoptDecoder(MeshoptDecoder);
    if (manifest.compression === "draco") loader.setDRACOLoader(new DRACOLoader().setDecoderPath("draco/"));
    const gltf = await loader.loadAsync(BASE + manifest.model);
    const clips = new Map<string, AnimationClip>();
    for (const [normalized, name] of Object.entries(manifest.clips)) {
      const clip = gltf.animations.find((a) => a.name === name);
      if (clip) clips.set(normalized, clip);
    }
    gltf.scene.traverse((o) => {
      const mesh = o as Mesh;
      if (!mesh.isMesh) return;
      const mats = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
      for (const m of mats) {
        if ((m as MeshStandardMaterial).isMeshStandardMaterial) {
          const sm = m as MeshStandardMaterial;
          sm.roughness = Math.max(sm.roughness, 0.7);
          sm.envMapIntensity = 0.6;
          if (!sm.userData.prepared) {
            prepare(sm);
            sm.userData.prepared = true;
          }
        }
      }
    });
    return { manifest, scene: gltf.scene, clips };
  } catch (err) {
    console.warn("Guard model unavailable, using capsules:", err);
    return null;
  }
}

export type GuardAnim = "idle" | "walk" | "run_forward" | "gunplay" | "crouch_idle" | "crouch_walk" | "death_fall_back" | "run_left" | "run_right";

/**
 * Skinned guard (SkeletonUtils clone per guard) or a capsule stand-in. The AI
 * sets `state` + `speed`; crossfades pick the clip and timeScale = speed /
 * authored root speed so feet don't slide.
 */
export class GuardVisual {
  readonly root = new Group();
  private mixer: AnimationMixer | null = null;
  private actions = new Map<string, AnimationAction>();
  private current: AnimationAction | null = null;
  private currentName = "";
  private rootSpeeds = new Map<string, number>();

  constructor(asset: CharacterAsset | null, prepare: (m: Material) => void) {
    if (asset) {
      const model = SkeletonUtils.clone(asset.scene);
      if (asset.manifest.forward === "-Z") model.rotation.y = Math.PI;
      model.traverse((o) => {
        if ((o as SkinnedMesh).isSkinnedMesh) {
          o.frustumCulled = false;
          o.castShadow = true;
          o.receiveShadow = true;
        }
      });
      this.root.add(model);
      this.mixer = new AnimationMixer(model);
      for (const [name, clip] of asset.clips) {
        const action = this.mixer.clipAction(clip);
        const info = asset.manifest.clipInfo?.[name];
        const loop = info ? info.loop : !name.startsWith("death") && !name.startsWith("reload") && name !== "run_backward";
        action.setLoop(loop ? LoopRepeat : LoopOnce, Infinity);
        action.clampWhenFinished = !loop;
        this.actions.set(name, action);
        this.rootSpeeds.set(name, info?.rootSpeed ?? 0);
      }
      this.play("idle", 0);
    } else {
      const mat = new MeshStandardMaterial({ color: 0x2c3a44, roughness: 0.8 });
      prepare(mat);
      const body = new Mesh(new CapsuleGeometry(0.3, 1.2, 6, 12), mat);
      body.position.y = 0.9;
      body.castShadow = true;
      const visorMat = new MeshStandardMaterial({ color: 0x0b0d0e, roughness: 0.3 });
      prepare(visorMat);
      const visor = new Mesh(new CapsuleGeometry(0.12, 0.18, 4, 8), visorMat);
      visor.rotation.z = Math.PI / 2;
      visor.position.set(0, 1.55, 0.24);
      this.root.add(body, visor);
    }
  }

  get animated(): boolean {
    return this.mixer !== null;
  }

  play(name: GuardAnim | string, fade = 0.25): void {
    if (name === this.currentName) return;
    const next = this.actions.get(name);
    if (!next) return;
    next.reset();
    next.enabled = true;
    next.setEffectiveWeight(1);
    next.play();
    if (this.current && fade > 0) this.current.crossFadeTo(next, fade, false);
    else if (this.current) this.current.stop();
    this.current = next;
    this.currentName = name;
  }

  /** Drives clip choice from locomotion; `speed` in m/s. */
  locomote(speed: number, running: boolean, aiming: boolean): void {
    if (!this.mixer) return;
    if (aiming && speed < 0.3) this.play("gunplay", 0.2);
    else if (speed < 0.15) this.play("idle", 0.35);
    else if (running) this.play("run_forward", 0.2);
    else this.play("walk", 0.3);
    if (this.current) {
      const root = this.rootSpeeds.get(this.currentName) ?? 0;
      this.current.timeScale = root > 0 ? Math.min(1.6, Math.max(0.5, speed / root)) : 1;
    }
  }

  update(dt: number): void {
    this.mixer?.update(dt);
  }
}
