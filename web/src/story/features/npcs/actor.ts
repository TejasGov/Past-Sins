import {
  AnimationAction, AnimationMixer, BoxGeometry, Color, Euler, Group, LoopRepeat, Mesh, MeshBasicMaterial, MeshStandardMaterial, Object3D,
  Quaternion, TextureSource, Vector3, type Material, type SkinnedMesh, type Texture,
} from "three";
import * as SkeletonUtils from "three/addons/utils/SkeletonUtils.js";
import type { CharacterAsset } from "../../../ai/guardVisual";
import type { NavGraph, NavWaypoint } from "../../../ai/nav";
import type { Door } from "../../../interact/door";
import { markInteractable, type Interactable } from "../../../interact/interactable";
import { POSES } from "./pose";
import { attachProps, buildFace } from "./props";
import type { LookDef } from "./types";

/**
 * The guard textures are dark navy: keep their luminance as shading detail
 * (folds, seams, pockets) and recolour it, so khaki reads as khaki.
 */
function recolored(src: Texture, hex: string, contrast: number): Texture {
  const img = src.image as CanvasImageSource & { width: number; height: number };
  const canvas = document.createElement("canvas");
  canvas.width = img.width;
  canvas.height = img.height;
  const ctx = canvas.getContext("2d", { willReadFrequently: true })!;
  ctx.drawImage(img, 0, 0);
  const data = ctx.getImageData(0, 0, canvas.width, canvas.height);
  const px = data.data;
  let sum = 0;
  let n = 0;
  for (let i = 0; i < px.length; i += 16) {
    sum += 0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2];
    n++;
  }
  const mean = Math.max(8, sum / Math.max(1, n));
  const c = new Color(hex);
  const tr = c.r * 255;
  const tg = c.g * 255;
  const tb = c.b * 255;
  for (let i = 0; i < px.length; i += 4) {
    const l = (0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2]) / mean;
    const v = Math.min(1.25, 1 - contrast + contrast * l);
    px[i] = Math.min(255, tr * v);
    px[i + 1] = Math.min(255, tg * v);
    px[i + 2] = Math.min(255, tb * v);
  }
  ctx.putImageData(data, 0, 0);
  // clone() shares the Source (setting .image would repaint every guard): give it its own.
  const tex = src.clone();
  tex.source = new TextureSource(canvas);
  tex.needsUpdate = true;
  return tex;
}

const UP = new Vector3(0, 1, 0);
const proxyMaterial = new MeshBasicMaterial({ visible: false });
const DEG = Math.PI / 180;

interface Layer {
  w: number;
  target: number;
  rate: number;
}

interface Walk {
  path: NavWaypoint[];
  i: number;
  from: Vector3;
  speed: number;
  opensDoors: boolean;
  resolve: (arrived: boolean) => void;
  waited: number;
}

export interface ActorWorld {
  nav: () => NavGraph | null;
  prepare: (m: Material) => void;
  /** Eye position the head turns towards (Parth). */
  lookTarget: () => Vector3;
}

/**
 * A story NPC built from guard.glb: its own skeleton clone and tinted
 * materials, bone-attached props, pose layers over the idle/walk clips, a
 * procedural "talking" gesture and head turn, nav-graph walking (doors opened
 * like staff, or waited for), and an E-prompt hit volume. Not a guard: it
 * never sees, hears or detains anyone.
 */
export class NpcActor implements Interactable {
  readonly root = new Group();
  readonly model: Object3D;
  readonly bones = new Map<string, Object3D>();
  readonly props: Map<string, Object3D>;
  yaw = 0;
  targetYaw = 0;
  /** True while one of this actor's lines is on screen. */
  talking = false;
  /** 0..1 head turn towards `world.lookTarget()`. */
  lookWeight = 0;
  lookTargetWeight = 0;
  prompt: () => string = () => "";
  onInteract: () => void = () => undefined;
  /** Hidden actors are skipped entirely. */
  present = false;
  private mixer: AnimationMixer;
  private actions = new Map<string, AnimationAction>();
  private current: AnimationAction | null = null;
  private currentName = "";
  private rootSpeeds = new Map<string, number>();
  private layers = new Map<string, Layer>();
  private rest = new Map<string, Quaternion>();
  private hipsRest = new Vector3();
  private walk: Walk | null = null;
  private opened: { door: Door; t: number }[] = [];
  private talkTime = 0;
  private speed = 0;
  private culled = false;
  private headProxy: Object3D | null = null;
  private collapseHead = false;

  constructor(
    readonly id: string,
    asset: CharacterAsset,
    look: LookDef,
    private world: ActorWorld,
    hit?: { size: [number, number, number]; offset: [number, number, number] },
  ) {
    this.root.name = `Npc:${id}`;
    this.model = SkeletonUtils.clone(asset.scene);
    if (asset.manifest.forward === "-Z") this.model.rotation.y = Math.PI;
    const s = look.scale ?? 1;
    this.model.scale.setScalar(s);
    this.dress(look);
    this.model.traverse((o) => {
      if ((o as { isBone?: boolean }).isBone) {
        this.bones.set(o.name, o);
        this.rest.set(o.name, o.quaternion.clone());
      }
    });
    this.hipsRest.copy(this.bones.get("mixamorigHips")?.position ?? new Vector3());
    // The guard's head is a gas mask: collapse it and carry a plain face on a proxy that
    // follows the head bone (props meant for the head hang there too).
    const head = this.bones.get("mixamorigHead");
    const neck = this.bones.get("mixamorigNeck");
    const propBones = new Map(this.bones);
    if (head && neck && (look.face || look.ink)) {
      this.headProxy = new Object3D();
      this.headProxy.position.copy(head.position);
      this.headProxy.quaternion.copy(head.quaternion);
      neck.add(this.headProxy);
      propBones.set("mixamorigHead", this.headProxy);
      this.collapseHead = true;
      this.headProxy.add(buildFace(look.face?.skin ?? "#000000", look.face?.brows ?? "#1a1410", world.prepare, !!look.ink));
    }
    this.props = attachProps(look.props ?? [], propBones, world.prepare, !!look.ink);
    this.root.add(this.model);
    this.mixer = new AnimationMixer(this.model);
    for (const [name, clip] of asset.clips) {
      const action = this.mixer.clipAction(clip);
      action.setLoop(LoopRepeat, Infinity);
      this.actions.set(name, action);
      this.rootSpeeds.set(name, asset.manifest.clipInfo?.[name]?.rootSpeed ?? 0);
    }
    this.play("idle", 0);
    // Start somewhere random in the 16 s idle so neighbours don't breathe in sync.
    if (this.current) this.current.time = Math.random() * this.current.getClip().duration;
    const [w, h, d] = hit?.size ?? [0.7, 1.1, 0.7];
    const [x, y, z] = hit?.offset ?? [0, 1.15, 0];
    const proxy = new Mesh(new BoxGeometry(w, h, d), proxyMaterial);
    proxy.position.set(x, y, z);
    this.root.add(proxy);
    markInteractable(this.root, this);
    this.root.visible = false;
  }

  private dress(look: LookDef): void {
    const ink = look.ink ? new MeshBasicMaterial({ color: 0x030405, fog: false }) : null;
    this.model.traverse((o) => {
      const m = o as SkinnedMesh;
      if (!m.isMesh) return;
      m.frustumCulled = false;
      if (look.hide?.includes((m.material as Material).name)) {
        m.visible = false;
        return;
      }
      m.castShadow = !ink;
      m.receiveShadow = !ink;
      if (ink) {
        m.material = ink;
        return;
      }
      const src = m.material as MeshStandardMaterial;
      const mat = src.clone();
      const tint = look.tint?.[src.name] ?? look.tint?.["*"];
      const flat = look.flat?.[src.name] ?? look.flat?.["*"];
      const recolor = look.recolor?.[src.name] ?? look.recolor?.["*"];
      if (flat) {
        mat.map = null;
        mat.color = new Color(flat);
      } else if (recolor && src.map) {
        mat.map = recolored(src.map, recolor, look.contrast ?? 0.75);
        mat.color = new Color(0xffffff);
      } else if (tint) mat.color = new Color(tint);
      this.world.prepare(mat);
      m.material = mat;
    });
  }

  // ── Interactable ──────────────────────────────────────────────────────────
  getInteractionPrompt(): string {
    return this.present ? this.prompt() : "";
  }

  interact(): void {
    if (this.present && this.prompt()) this.onInteract();
  }

  // ── Placement ─────────────────────────────────────────────────────────────
  get position(): Vector3 {
    return this.root.position;
  }

  place(p: Vector3, yaw: number): void {
    this.stop();
    this.root.position.copy(p);
    this.yaw = this.targetYaw = yaw;
    this.root.rotation.y = yaw;
  }

  show(on: boolean): void {
    this.present = on;
    if (!on) this.stop();
  }

  /** World point of a bone (e.g. the head, for focus and look-at). */
  bonePoint(name: string, out = new Vector3()): Vector3 {
    const b = this.bones.get(name);
    if (!b) return out.copy(this.root.position).add(new Vector3(0, 1.6, 0));
    this.root.updateMatrixWorld(true);
    return b.getWorldPosition(out);
  }

  faceTo(p: Vector3): void {
    this.targetYaw = Math.atan2(p.x - this.root.position.x, p.z - this.root.position.z);
  }

  // ── Poses ─────────────────────────────────────────────────────────────────
  /** Blend a pose layer towards `weight` (0 removes it) over ~`seconds`. */
  pose(name: string, weight = 1, seconds = 0.6): void {
    if (!POSES[name]) {
      console.warn(`[npcs] unknown pose "${name}"`);
      return;
    }
    let l = this.layers.get(name);
    if (!l) this.layers.set(name, (l = { w: 0, target: 0, rate: 1 }));
    l.target = weight;
    l.rate = seconds <= 0 ? 1e3 : 3 / seconds;
    if (seconds <= 0) l.w = weight;
  }

  clearPoses(seconds = 0.6): void {
    for (const name of this.layers.keys()) this.pose(name, 0, seconds);
  }

  hasPose(name: string): boolean {
    return (this.layers.get(name)?.target ?? 0) > 0;
  }

  // ── Walking ───────────────────────────────────────────────────────────────
  get walking(): boolean {
    return this.walk !== null;
  }

  /**
   * Walks to `to` along the guard nav graph (straight line if off-graph).
   * Staff (`opensDoors`) open closed doors on the way and close them behind;
   * others wait at a closed door. Resolves true on arrival, false if stopped.
   */
  walkTo(to: Vector3, speed: number, opensDoors: boolean): Promise<boolean> {
    this.stop();
    const nav = this.world.nav();
    const path = nav?.findPath(this.root.position, to) ?? [{ p: to.clone(), door: null }];
    return new Promise((resolve) => {
      this.walk = { path, i: 0, from: this.root.position.clone(), speed, opensDoors, resolve, waited: 0 };
    });
  }

  stop(): void {
    const w = this.walk;
    this.walk = null;
    w?.resolve(false);
  }

  /** Seconds spent waiting at a closed door on the current walk. */
  get blockedFor(): number {
    return this.walk?.waited ?? 0;
  }

  private stepWalk(dt: number): void {
    const w = this.walk;
    if (!w) {
      this.speed = 0;
      return;
    }
    const p = this.root.position;
    const wp = w.path[w.i];
    // A door between the previous waypoint and this one: open it (staff) or wait.
    const door = wp.door;
    if (door && !door.isOpen && Math.hypot(door.position.x - p.x, door.position.z - p.z) < 1.7) {
      if (w.opensDoors && !door.isMoving) {
        door.openForAI();
        this.opened.push({ door, t: 0 });
      }
      w.waited += dt;
      this.speed = 0;
      return;
    }
    w.waited = 0;
    const to = wp.p;
    const dx = to.x - p.x;
    const dz = to.z - p.z;
    const d = Math.hypot(dx, dz);
    const stepLen = w.speed * dt;
    if (d <= Math.max(0.05, stepLen)) {
      p.copy(to);
      w.from.copy(to);
      w.i++;
      if (w.i >= w.path.length) {
        this.walk = null;
        this.speed = 0;
        w.resolve(true);
      }
      return;
    }
    const total = Math.max(1e-3, Math.hypot(to.x - w.from.x, to.z - w.from.z));
    p.x += (dx / d) * stepLen;
    p.z += (dz / d) * stepLen;
    // Height follows the segment (stair flights are waypoints along their centre line).
    const t = 1 - Math.min(1, Math.hypot(to.x - p.x, to.z - p.z) / total);
    p.y = w.from.y + (to.y - w.from.y) * t;
    this.targetYaw = Math.atan2(dx, dz);
    this.speed = w.speed;
  }

  private closeDoors(dt: number): void {
    for (let i = this.opened.length - 1; i >= 0; i--) {
      const o = this.opened[i];
      o.t += dt;
      const far = o.door.position.distanceTo(this.root.position) > 2.2;
      if (o.t > 2.5 && far) {
        o.door.closeForAI();
        this.opened.splice(i, 1);
      } else if (o.t > 30) this.opened.splice(i, 1);
    }
  }

  // ── Animation ─────────────────────────────────────────────────────────────
  private play(name: string, fade = 0.3): void {
    if (name === this.currentName) return;
    const next = this.actions.get(name);
    if (!next) return;
    next.reset().play();
    if (this.current && fade > 0) this.current.crossFadeTo(next, fade, false);
    else this.current?.stop();
    this.current = next;
    this.currentName = name;
  }

  update(dt: number, camera: Vector3, drawDistance: number): void {
    this.closeDoors(dt);
    if (!this.present) {
      this.root.visible = false;
      return;
    }
    this.stepWalk(dt);
    let dy = this.targetYaw - this.yaw;
    dy = Math.atan2(Math.sin(dy), Math.cos(dy));
    this.yaw += dy * (1 - Math.exp(-dt * 7));
    this.root.rotation.y = this.yaw;
    this.culled = this.root.position.distanceToSquared(camera) > drawDistance * drawDistance;
    this.root.visible = !this.culled;
    if (this.culled) return;
    if (this.speed > 2.6) this.play("run_forward", 0.25);
    else if (this.speed > 0.1) this.play("walk", 0.3);
    else this.play("idle", 0.4);
    if (this.current) {
      const rs = this.rootSpeeds.get(this.currentName) ?? 0;
      this.current.timeScale = rs > 0 && this.speed > 0 ? Math.min(1.6, Math.max(0.5, this.speed / rs)) : 1;
    }
    this.mixer.update(dt);
    this.applyLayers(dt);
    this.applyTalk(dt);
    this.applyLook(dt);
    const head = this.bones.get("mixamorigHead");
    if (this.headProxy && head) {
      this.headProxy.quaternion.copy(head.quaternion);
      if (this.collapseHead) head.scale.setScalar(0.001);
    }
  }

  private applyLayers(dt: number): void {
    const hips = this.bones.get("mixamorigHips");
    const q = new Quaternion();
    const e = new Euler();
    for (const [name, l] of this.layers) {
      l.w += (l.target - l.w) * (1 - Math.exp(-dt * l.rate));
      if (Math.abs(l.w - l.target) < 0.002) l.w = l.target;
      if (l.w <= 0.001) continue;
      const def = POSES[name];
      if (def.hips && hips) {
        hips.position.x = hips.position.x * (1 - l.w) + (this.hipsRest.x + def.hips[0]) * l.w;
        hips.position.y += def.hips[1] * l.w;
        hips.position.z += def.hips[2] * l.w;
      }
      for (const [boneName, [x, y, z]] of Object.entries(def.bones)) {
        const b = this.bones.get(boneName);
        if (!b) continue;
        q.setFromEuler(e.set(x * DEG, y * DEG, z * DEG));
        const base = def.absolute ? this.rest.get(boneName)! : b.quaternion;
        const target = base.clone().multiply(q);
        b.quaternion.slerp(target, l.w);
      }
    }
  }

  /** Speaking: a slow nod and a small hand gesture over the idle. */
  private applyTalk(dt: number): void {
    this.talkTime = this.talking ? this.talkTime + dt : Math.max(0, this.talkTime - dt * 3);
    const k = Math.min(1, this.talkTime * 3);
    if (k <= 0) return;
    const t = this.talkTime;
    const nod = (Math.sin(t * 5.1) * 0.6 + Math.sin(t * 2.3) * 0.4) * 6 * k;
    this.rotateLocal("mixamorigHead", nod, Math.sin(t * 1.7) * 4 * k, 0);
    this.rotateLocal("mixamorigSpine2", 0, Math.sin(t * 1.3) * 3 * k, 0);
    if (!this.hasPose("carry") && !this.hasPose("palm") && !this.hasPose("folded") && !this.hasPose("lap")) {
      this.rotateLocal("mixamorigRightForeArm", 0, 0, (-18 + Math.sin(t * 3.1) * 10) * k);
    }
  }

  private rotateLocal(bone: string, x: number, y: number, z: number): void {
    const b = this.bones.get(bone);
    if (b) b.quaternion.multiply(new Quaternion().setFromEuler(new Euler(x * DEG, y * DEG, z * DEG)));
  }

  /** Turns neck and head (world space, clamped) towards the look target. */
  private applyLook(dt: number): void {
    this.lookWeight += (this.lookTargetWeight - this.lookWeight) * (1 - Math.exp(-dt * 4));
    if (this.lookWeight < 0.01) return;
    const head = this.bones.get("mixamorigHead");
    const neck = this.bones.get("mixamorigNeck");
    if (!head || !neck) return;
    this.model.updateMatrixWorld(true);
    const eye = head.getWorldPosition(new Vector3());
    const d = this.world.lookTarget().clone().sub(eye);
    let yaw = Math.atan2(d.x, d.z) - this.yaw;
    yaw = Math.atan2(Math.sin(yaw), Math.cos(yaw));
    const pitch = Math.atan2(d.y, Math.hypot(d.x, d.z));
    const cy = Math.max(-1.1, Math.min(1.1, yaw)) * this.lookWeight;
    const cp = Math.max(-0.45, Math.min(0.45, pitch)) * this.lookWeight;
    for (const [bone, share] of [[neck, 0.4], [head, 0.6]] as const) {
      const right = new Vector3(Math.cos(this.yaw + cy), 0, -Math.sin(this.yaw + cy));
      const qw = new Quaternion().setFromAxisAngle(UP, cy * share).premultiply(new Quaternion().setFromAxisAngle(right, -cp * share));
      const world = bone.getWorldQuaternion(new Quaternion());
      const parent = bone.parent!.getWorldQuaternion(new Quaternion());
      bone.quaternion.copy(parent.invert().multiply(qw.multiply(world)));
      bone.updateMatrixWorld(true);
    }
  }

  debug(): Record<string, unknown> {
    return {
      id: this.id,
      present: this.present,
      visible: this.root.visible,
      position: this.root.position.toArray().map((v) => +v.toFixed(2)),
      yaw: +this.yaw.toFixed(2),
      anim: this.currentName,
      walking: !!this.walk,
      poses: [...this.layers].filter(([, l]) => l.target > 0).map(([n]) => n),
    };
  }
}
