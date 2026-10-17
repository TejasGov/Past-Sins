import { Group, Material, Mesh, Vector3, type Object3D } from "three";
import { gsap } from "gsap";
import RAPIER from "@dimforge/rapier3d-compat";
import { DOOR_GROUPS, Layer, type Physics } from "../physics/physics";
import { MeshKit } from "../world/builder";
import type { MaterialLibrary } from "../render/materials";
import type { DoorSpec } from "../world/types";
import type { AccessManager } from "../systems/access";
import type { Player } from "../player/player";
import { markInteractable, type Interactable } from "./interactable";

export interface DoorContext {
  physics: Physics;
  materials: MaterialLibrary;
  access: AccessManager;
  message: (text: string, duration?: number) => void;
  /** Leaves of solid doors are added here while closed (guard LOS / interaction blocking). */
  occluders: Set<Object3D>;
  onNoise?: (position: Vector3, intensity: number) => void;
}

const V = (x: number, y: number, z: number) => new Vector3(x, y, z);

/**
 * NormalDoor (swing) and PrisonSlidingGate (slide) in one class: generic
 * prompts, keyed locks with persistent unlock IDs, a doorway-occupancy check
 * before closing, and a fixed collider that is disabled while open/moving.
 */
export class Door implements Interactable {
  readonly root = new Group();
  private pivot = new Group();
  private leaf: Mesh;
  private frame: Mesh | null = null;
  private ledGroup = -1;
  readonly collider: RAPIER.Collider;
  isOpen = false;
  isLocked = false;
  private moving = false;
  private readonly slide: boolean;
  private readonly solid: boolean;
  private readonly thickness: number;

  constructor(readonly spec: DoorSpec, private ctx: DoorContext) {
    this.slide = spec.kind !== "door";
    this.solid = spec.kind === "door" || spec.kind === "shutter";
    this.thickness = this.slide ? 0.1 : 0.14;
    this.root.position.copy(spec.position);
    this.root.rotation.y = spec.yaw;
    this.root.name = `Door:${spec.persistentId}`;
    this.root.add(this.pivot);
    if (!this.slide) this.pivot.position.x = -spec.width / 2;
    this.leaf = this.slide ? this.buildGateLeaf() : this.buildDoorLeaf();
    this.pivot.add(this.leaf);
    if (this.slide) this.frame = this.buildReader();
    markInteractable(this.root, this);

    const half = V(spec.width / 2, spec.height / 2, this.thickness / 2 + 0.02);
    const center = V(0, spec.height / 2, 0).applyAxisAngle(V(0, 1, 0), spec.yaw).add(spec.position);
    this.collider = ctx.physics.world.createCollider(descFor(half, center, spec.yaw));
    this.isLocked = spec.startsLocked && !ctx.access.isAccessUnlocked(spec.persistentId);
    this.applyPose(false);
    this.updateIndicators();
  }

  // ── Interactable ───────────────────────────────────────────────────────────
  getInteractionPrompt(_player: Player): string {
    if (this.moving) return "";
    if (this.slide) {
      if (this.isLocked) return this.hasKey() ? "[E] Unlock Gate" : "[E] Locked";
      return this.isOpen ? "[E] Close Gate" : "[E] Open Gate";
    }
    if (this.isLocked && !this.hasKey()) return "[E] Locked";
    return this.isOpen ? "[E] Close Door" : "[E] Open Door";
  }

  interact(_player: Player): void {
    if (this.moving) return;
    if (this.isLocked) {
      if (!this.hasKey()) {
        this.ctx.message(this.spec.requiredKey || this.slide ? "KEY REQUIRED" : `${this.spec.displayName.toUpperCase()} LOCKED`);
        return;
      }
      this.unlock();
      if (this.slide) {
        this.ctx.message("ACCESS GRANTED");
        this.moving = true;
        gsap.delayedCall(0.28, () => {
          this.moving = false;
          this.animateTo(true);
        });
        return;
      }
    }
    if (this.isOpen && this.doorwayBlocked()) {
      this.ctx.message(this.slide ? "GATEWAY BLOCKED" : "DOORWAY BLOCKED");
      return;
    }
    this.animateTo(!this.isOpen);
  }

  // ── State ──────────────────────────────────────────────────────────────────
  hasKey(): boolean {
    const a = this.ctx.access;
    if (this.spec.requiredKey && a.hasKey(this.spec.requiredKey)) return true;
    return !!this.spec.masterKey && a.hasKey(this.spec.masterKey);
  }

  unlock(): void {
    this.isLocked = false;
    if (this.spec.persistentId) this.ctx.access.unlockAccess(this.spec.persistentId);
    this.updateIndicators();
  }

  /** Dev Mode: force a state without key checks. */
  setState(open: boolean, locked: boolean): void {
    gsap.killTweensOf(this.pivot.rotation);
    gsap.killTweensOf(this.leaf.position);
    this.moving = false;
    this.isLocked = locked;
    this.isOpen = open && !locked;
    this.applyPose(false);
    this.updateIndicators();
  }

  get isMoving(): boolean {
    return this.moving;
  }

  /** AI helper: guards open unlocked doors in their way. */
  openForAI(): void {
    if (!this.isOpen && !this.moving && !this.isLocked) this.animateTo(true);
  }

  private animateTo(open: boolean): void {
    this.moving = true;
    this.isOpen = open;
    this.collider.setEnabled(false);
    this.ctx.occluders.delete(this.leaf);
    this.ctx.onNoise?.(this.root.position.clone(), this.slide ? 0.45 : 0.2);
    const done = () => {
      this.moving = false;
      if (!open && this.doorwayBlocked()) {
        this.ctx.message(this.slide ? "GATEWAY BLOCKED" : "DOORWAY BLOCKED");
        this.animateTo(true);
        return;
      }
      this.applyPose(false);
    };
    const dir = this.spec.openDirection >= 0 ? 1 : -1;
    if (this.slide) {
      const target = open ? (this.spec.slideDistance ?? this.spec.width * 0.9) * dir : 0;
      gsap.to(this.leaf.position, { x: target, duration: 0.75, ease: "power2.inOut", onComplete: done });
    } else {
      const target = open ? ((this.spec.openAngle ?? 95) * Math.PI) / 180 * dir : 0;
      gsap.to(this.pivot.rotation, { y: target, duration: 0.6, ease: "power2.inOut", onComplete: done });
    }
  }

  private applyPose(animated: boolean): void {
    void animated;
    const dir = this.spec.openDirection >= 0 ? 1 : -1;
    if (this.slide) this.leaf.position.x = this.isOpen ? (this.spec.slideDistance ?? this.spec.width * 0.9) * dir : 0;
    else this.pivot.rotation.y = this.isOpen ? ((this.spec.openAngle ?? 95) * Math.PI) / 180 * dir : 0;
    this.collider.setEnabled(!this.isOpen);
    if (this.solid && !this.isOpen) this.ctx.occluders.add(this.leaf);
    else this.ctx.occluders.delete(this.leaf);
  }

  private doorwayBlocked(): boolean {
    const s = this.spec;
    const center = V(0, s.height / 2, 0).applyAxisAngle(V(0, 1, 0), s.yaw).add(s.position);
    const half = V((s.width + 0.35) / 2, s.height / 2, Math.max(0.85, s.width * 0.72) / 2);
    return this.ctx.physics.boxOverlaps(center, half, s.yaw, Layer.PLAYER | Layer.GUARD) !== null;
  }

  private updateIndicators(): void {
    if (!this.frame || this.ledGroup < 0) return;
    const mats = this.frame.material as Material[];
    mats[this.ledGroup] = this.ctx.materials.get(this.isLocked ? "emissive_red" : "emissive_green");
  }

  // ── Visuals ────────────────────────────────────────────────────────────────
  private buildDoorLeaf(): Mesh {
    const s = this.spec;
    const w = s.width;
    const h = s.height;
    const t = this.thickness;
    const kit = new MeshKit(this.ctx.materials);
    const paint = s.color && s.color !== 0x727f75 ? s.color : 0x4f6468;
    kit.box(V(w / 2, h / 2, 0), V(w - 0.02, h - 0.02, t), "metal", paint);
    for (const z of [-1, 1]) {
      const zz = z * (t / 2 + 0.006);
      kit.box(V(w / 2, 0.15, zz), V(w - 0.1, 0.26, 0.01), "steel", 0x9aa19c);
      kit.box(V(w / 2, h * 0.72, zz), V(Math.min(0.42, w * 0.35), 0.5, 0.012), "glass", 0x31444a);
      kit.box(V(w - 0.12, 1.05, z * (t / 2 + 0.05)), V(0.14, 0.03, 0.03), "steel", 0xb0b6b2);
      kit.box(V(w - 0.12, 1.05, z * (t / 2 + 0.025)), V(0.05, 0.05, 0.05), "steel", 0xb0b6b2);
      kit.box(V(w / 2, h * 0.5, zz), V(0.5, 0.09, 0.01), "paper", 0xd6d2bf);
    }
    for (const y of [0.35, h - 0.35]) kit.box(V(0.01, y, 0), V(0.04, 0.14, t + 0.02), "steel", 0x777d79);
    const mesh = kit.build("DoorLeaf");
    return mesh;
  }

  private buildGateLeaf(): Mesh {
    const s = this.spec;
    const w = s.width;
    const h = s.height;
    const kit = new MeshKit(this.ctx.materials);
    const color = s.color ?? 0x343a38;
    if (s.kind === "glass") {
      const pane = (w - 0.22) / 2;
      for (const x of [-pane / 2 - 0.045, pane / 2 + 0.045]) kit.box(V(x, h / 2, 0), V(pane, h - 0.18, 0.06), "glass", 0x6d9ca2);
      for (const x of [-w / 2 + 0.055, 0, w / 2 - 0.055]) kit.box(V(x, h / 2, 0), V(0.1, h, 0.12), "metal", color);
      for (const y of [0.08, h - 0.08]) kit.box(V(0, y, 0), V(w, 0.14, 0.12), "metal", color);
    } else {
      kit.box(V(0, h - 0.06, 0), V(w, 0.12, 0.09), "metal", color);
      kit.box(V(0, 0.06, 0), V(w, 0.12, 0.09), "metal", color);
      kit.box(V(0, h * 0.45, 0), V(w, 0.08, 0.07), "metal", color);
      for (const x of [-w / 2 + 0.04, w / 2 - 0.04]) kit.box(V(x, h / 2, 0), V(0.08, h, 0.09), "metal", color);
      const bars = Math.max(4, Math.round(w / 0.13));
      for (let i = 1; i < bars; i++) kit.cylinder(V(-w / 2 + (i * w) / bars, h / 2, 0), 0.018, h - 0.2, "iron", 0x8d9690);
      kit.box(V(w / 2 - 0.16, 1.05, 0.06), V(0.2, 0.26, 0.08), "dark", 0x2c312e);
      if (s.label) kit.box(V(0, h * 0.72, 0.05), V(Math.min(1.2, w * 0.5), 0.22, 0.02), "hazard", 0xd8b448);
    }
    return kit.build("GateLeaf");
  }

  /** Key reader beside the opening (static); its LED group swaps red/green. */
  private buildReader(): Mesh {
    const s = this.spec;
    const kit = new MeshKit(this.ctx.materials);
    kit.box(V(s.width / 2 + 0.12, 1.25, 0.12), V(0.18, 0.28, 0.12), "hazard", 0xd8b448);
    kit.box(V(s.width / 2 + 0.12, 1.25, 0.185), V(0.14, 0.22, 0.02), "dark", 0x1f2422);
    kit.box(V(s.width / 2 + 0.12, 1.33, 0.2), V(0.05, 0.03, 0.03), "emissive_red");
    const mesh = kit.build("KeyReader");
    const mats = mesh.material as Material[];
    this.ledGroup = mats.findIndex((m) => m === this.ctx.materials.get("emissive_red"));
    mesh.castShadow = false;
    this.root.add(mesh);
    return mesh;
  }

  get position(): Vector3 {
    return this.spec.position;
  }
}

function descFor(half: Vector3, center: Vector3, yaw: number): RAPIER.ColliderDesc {
  const q = { x: 0, y: Math.sin(yaw / 2), z: 0, w: Math.cos(yaw / 2) };
  return RAPIER.ColliderDesc.cuboid(half.x, half.y, half.z).setTranslation(center.x, center.y, center.z).setRotation(q).setCollisionGroups(DOOR_GROUPS);
}
