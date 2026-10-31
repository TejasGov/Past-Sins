import {
  AdditiveBlending, BoxGeometry, CanvasTexture, CylinderGeometry, Group, Mesh, MeshBasicMaterial, MeshStandardMaterial, PlaneGeometry, Quaternion, Vector3,
  type Material, type Object3D, type Scene,
} from "three";
import { markInteractable, type Interactable } from "../../../interact/interactable";
import type { StaticBuilder } from "../../../world/builder";
import { GuardVisual, loadCharacter, type CharacterAsset } from "../../../ai/guardVisual";
import { V } from "../../../world/props";

const proxy = new MeshBasicMaterial({ visible: false });

/** An invisible E-prompt volume whose prompt and action come from the runtime. */
export class WaterProp implements Interactable {
  readonly root = new Group();

  constructor(size: Vector3, private prompt: () => string, private use: () => void) {
    const hit = new Mesh(new BoxGeometry(size.x, size.y, size.z), proxy);
    this.root.add(hit);
    markInteractable(this.root, this);
  }

  getInteractionPrompt(): string {
    return this.prompt();
  }

  interact(): void {
    this.use();
  }
}

/** Static pool dressing (pool-local coordinates): the deep-end drain grate and the deck PA speaker. */
export function buildPoolStatic(b: StaticBuilder, origin: Vector3, grate: Vector3, speaker: Vector3): void {
  b.within(origin, 0, () => {
    const g = grate;
    const steel = { mat: "plastic" as const, color: 0xd9e0dc, collide: false };
    b.box(V(g.x, g.y + 0.004, g.z), V(0.98, 0.008, 0.6), { mat: "dark", color: 0x000000, collide: false, shadow: false });
    for (const s of [-1, 1]) {
      b.box(V(g.x + s * 0.53, g.y + 0.03, g.z), V(0.08, 0.06, 0.76), steel);
      b.box(V(g.x, g.y + 0.03, g.z + s * 0.34), V(1.14, 0.06, 0.08), steel);
    }
    for (let x = -0.4; x <= 0.401; x += 0.1) b.box(V(g.x + x, g.y + 0.03, g.z), V(0.045, 0.05, 0.62), steel);
    const sp = speaker;
    b.box(V(sp.x, 1.6, sp.z), V(0.09, 3.2, 0.09), { mat: "metal_ext", color: 0x4e5852 });
    b.box(V(sp.x, 3.05, sp.z + 0.1), V(0.3, 0.24, 0.18), { mat: "dark_ext", color: 0x2d3330, collide: false });
    const horn = new Quaternion().setFromAxisAngle(V(1, 0, 0), Math.PI / 2 + 0.35);
    b.cylinder(V(sp.x, 2.9, sp.z + 0.3), 0.15, 0.34, { mat: "metal_ext", color: 0x6b746e, quat: horn });
    b.cylinder(V(sp.x, 2.83, sp.z + 0.46), 0.07, 0.04, { mat: "dark_ext", color: 0x1a1e1c, quat: horn });
  });
}

/** Withdrawal shimmer over the grate: a soft, breathing glow (additive). */
export class GrateShimmer {
  readonly mesh: Mesh;
  private material: MeshBasicMaterial;
  private level = 0;
  private t = 0;

  constructor(at: Vector3) {
    const c = document.createElement("canvas");
    c.width = c.height = 128;
    const ctx = c.getContext("2d")!;
    const grad = ctx.createRadialGradient(64, 64, 4, 64, 64, 64);
    grad.addColorStop(0, "rgba(255,255,255,1)");
    grad.addColorStop(0.45, "rgba(255,255,255,0.45)");
    grad.addColorStop(1, "rgba(255,255,255,0)");
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, 128, 128);
    this.material = new MeshBasicMaterial({ map: new CanvasTexture(c), color: 0x8eeaff, transparent: true, opacity: 0, blending: AdditiveBlending, depthWrite: false, toneMapped: false });
    this.mesh = new Mesh(new PlaneGeometry(1.9, 1.4), this.material);
    this.mesh.rotation.x = -Math.PI / 2;
    this.mesh.position.copy(at).add(V(0, 0.09, 0));
    this.mesh.renderOrder = 4;
    this.mesh.name = "WaterGrateShimmer";
  }

  update(dt: number, on: boolean): void {
    this.t += dt;
    this.level += ((on ? 1 : 0) - this.level) * Math.min(1, dt * 1.5);
    this.material.opacity = this.level * (0.1 + 0.07 * Math.sin(this.t * 2.3) + 0.03 * Math.sin(this.t * 7.1));
    this.mesh.visible = this.level > 0.01;
  }
}

/**
 * The small hand in the culvert: forearm, palm up, four curling fingers and a
 * thumb, reaching towards local −Z. Unlit-ish (emissive) so it reads in the
 * black water.
 */
export class HandRig {
  readonly root = new Group();
  private rig = new Group();
  private joints: Group[][] = [];
  private material: MeshStandardMaterial;
  private t = 0;
  /** 0 hidden … 1 fully there. */
  private presence = 0;
  private presenceTarget = 0;
  private reach = 0;
  private reachTarget = 0;
  private curlTarget = 0.35;
  private curl = 0.35;
  private drop = 0;
  mode: "hidden" | "reach" | "grip" | "gone" = "hidden";

  constructor(prepare: (m: Material) => void) {
    this.material = new MeshStandardMaterial({ color: 0xdcc6b2, roughness: 0.62, emissive: 0x6a5446, emissiveIntensity: 1.5, transparent: true, opacity: 0 });
    prepare(this.material);
    const m = this.material;
    const cyl = (r: number, len: number) => {
      const mesh = new Mesh(new CylinderGeometry(r, r * 0.92, len, 10), m);
      mesh.rotation.x = Math.PI / 2;
      return mesh;
    };
    const arm = cyl(0.03, 0.46);
    arm.position.set(0, -0.01, 0.27);
    const palm = new Mesh(new BoxGeometry(0.074, 0.024, 0.078), m);
    palm.position.set(0, 0, 0);
    this.rig.add(arm, palm);
    const fingers: [number, number][] = [[-0.027, 0.032], [-0.009, 0.038], [0.009, 0.036], [0.027, 0.028]];
    for (const [x, len] of fingers) this.joints.push(this.finger(x, len, 0.0075));
    const thumb = new Group();
    thumb.position.set(0.04, 0, 0.012);
    thumb.rotation.y = 0.75;
    const tj = this.finger(0, 0.03, 0.0085, thumb);
    this.joints.push(tj);
    this.rig.add(thumb);
    this.rig.scale.setScalar(1.9);
    // Up out of the dark beyond the bars, towards Parth, a little side-on so the fingers read.
    this.root.rotation.set(0.32, 0.5, 0, "YXZ");
    this.root.add(this.rig);
    this.root.visible = false;
    this.root.name = "WaterHand";
  }

  private finger(x: number, len: number, r: number, parent: Object3D = this.rig): Group[] {
    const base = new Group();
    base.position.set(x, 0, -0.039);
    const a = new Mesh(new CylinderGeometry(r, r, len, 8), this.material);
    a.rotation.x = Math.PI / 2;
    a.position.z = -len / 2;
    base.add(a);
    const mid = new Group();
    mid.position.z = -len;
    const b = new Mesh(new CylinderGeometry(r * 0.9, r * 0.75, len * 0.8, 8), this.material);
    b.rotation.x = Math.PI / 2;
    b.position.z = -len * 0.4;
    mid.add(b);
    base.add(mid);
    parent.add(base);
    return [base, mid];
  }

  /** Comes out of the dark, open, reaching. */
  reachOut(): void {
    this.mode = "reach";
    this.root.visible = true;
    this.presenceTarget = 1;
    this.reachTarget = 1;
    this.curlTarget = 0.3;
  }

  /** Parth takes it: the fingers close. */
  grip(): void {
    this.mode = "grip";
    this.curlTarget = 1.25;
    this.reachTarget = 1.15;
  }

  /** Parth lets go: it slips back into the dark. */
  letGo(): void {
    this.mode = "gone";
    this.presenceTarget = 0;
    this.reachTarget = -0.6;
    this.curlTarget = 0.9;
  }

  reset(): void {
    this.mode = "hidden";
    this.presence = this.presenceTarget = 0;
    this.reach = this.reachTarget = 0;
    this.curl = this.curlTarget = 0.35;
    this.drop = 0;
    this.material.opacity = 0;
    this.root.visible = false;
  }

  update(dt: number): void {
    if (!this.root.visible) return;
    this.t += dt;
    const k = (rate: number) => Math.min(1, dt * rate);
    this.presence += (this.presenceTarget - this.presence) * k(this.mode === "gone" ? 0.9 : 0.7);
    this.reach += (this.reachTarget - this.reach) * k(this.mode === "gone" ? 0.6 : 0.5);
    this.curl += (this.curlTarget - this.curl) * k(this.mode === "grip" ? 3 : 1.5);
    if (this.mode === "gone") this.drop += dt * 0.12;
    this.material.opacity = Math.min(1, this.presence * 1.15);
    const sway = this.mode === "reach" ? Math.sin(this.t * 1.3) * 0.02 : 0;
    this.rig.position.set(sway, Math.sin(this.t * 0.9) * 0.015 - this.drop, -0.28 * this.reach);
    this.rig.rotation.set(-0.08 + Math.sin(this.t * 0.7) * 0.03, Math.sin(this.t * 0.5) * 0.06, 0);
    const beckon = this.mode === "reach" ? 0.18 * (0.5 + 0.5 * Math.sin(this.t * 1.6)) : 0;
    this.joints.forEach(([base, mid], i) => {
      const c = this.curl + beckon * (i === 4 ? 0.3 : 1) + Math.sin(this.t * 1.6 + i * 0.5) * 0.04;
      base.rotation.x = c * 0.8;
      mid.rotation.x = c * 0.9;
    });
    if (this.mode === "gone" && this.presence < 0.01) this.root.visible = false;
  }
}

let assetPromise: Promise<CharacterAsset | null> | null = null;

/** Guards waiting at the pool deck when Parth surfaces from T3 (guard.glb stand-ins, not the patrol AI). */
export class DeckGuards {
  private visuals: GuardVisual[] = [];

  constructor(private scene: Scene, private prepare: (m: Material) => void) {}

  /** Starts loading the character early (the T3 memory covers the wait). */
  preload(): void {
    assetPromise ??= loadCharacter(this.prepare);
  }

  async spawn(positions: Vector3[], face: Vector3): Promise<void> {
    this.preload();
    const asset = await assetPromise!;
    this.dispose();
    positions.forEach((p, i) => {
      const v = new GuardVisual(asset, this.prepare);
      v.root.position.copy(p);
      const d = face.clone().sub(p);
      v.root.rotation.y = Math.atan2(-d.x, -d.z) + Math.PI;
      v.play(i === 0 ? "gunplay" : "idle", 0);
      v.update(1 / 60);
      this.scene.add(v.root);
      this.visuals.push(v);
    });
  }

  get active(): boolean {
    return this.visuals.length > 0;
  }

  update(dt: number): void {
    for (const v of this.visuals) v.update(dt);
  }

  dispose(): void {
    for (const v of this.visuals) this.scene.remove(v.root);
    this.visuals = [];
  }
}
