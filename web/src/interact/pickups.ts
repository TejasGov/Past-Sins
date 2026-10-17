import {
  AdditiveBlending, Color, Group, Mesh, MeshBasicMaterial, MeshStandardMaterial, OctahedronGeometry, PointLight, Quaternion, SphereGeometry, Vector3,
} from "three";
import { gsap } from "gsap";
import { MeshKit } from "../world/builder";
import type { MaterialLibrary } from "../render/materials";
import { markInteractable, type Interactable } from "./interactable";

const V = (x: number, y: number, z: number) => new Vector3(x, y, z);

export interface PickupContext {
  materials: MaterialLibrary;
  prepare: (m: MeshStandardMaterial) => void;
}

/** CampusMountedKey: a painted key tag hanging from a rack hook. */
export class KeyPickup implements Interactable {
  readonly root = new Group();
  collected = false;
  private readonly baseScale: number;

  constructor(
    ctx: PickupContext,
    readonly keyId: string,
    readonly displayName: string,
    rackLabel: string,
    private onCollect: (k: KeyPickup) => boolean,
    scale = 0.72,
  ) {
    const kit = new MeshKit(ctx.materials);
    kit.box(V(0, 0, 0), V(0.32, 0.46, 0.03), "metal", 0xe8bd42);
    kit.box(V(0, 0.06, 0.017), V(0.24, 0.12, 0.005), "metal", 0x22201a);
    kit.cylinder(V(0, 0.3, 0), 0.06, 0.015, "metal", 0xd0d6d2, new Quaternion().setFromAxisAngle(V(1, 0, 0), Math.PI / 2));
    kit.box(V(0, 0.42, 0), V(0.035, 0.12, 0.02), "metal", 0xc0c6c2);
    kit.box(V(0.02, -0.12, 0.016), V(0.2, 0.03, 0.005), "metal", 0x22201a);
    const mesh = kit.build("KeyTag");
    mesh.castShadow = false;
    this.root.add(mesh);
    this.root.scale.setScalar(scale);
    this.baseScale = scale;
    this.root.userData.rackLabel = rackLabel;
    markInteractable(this.root, this);
  }

  getInteractionPrompt(): string {
    return this.collected ? "" : "[E] Pick Up Key";
  }

  /** Back on its hook (a wipe). */
  reset(): void {
    gsap.killTweensOf(this.root.scale);
    this.collected = false;
    this.root.visible = true;
    this.root.scale.setScalar(this.baseScale);
  }

  interact(): void {
    if (this.collected) return;
    this.collected = true;
    if (this.onCollect(this)) {
      gsap.to(this.root.scale, { x: 0.01, y: 0.01, z: 0.01, duration: 0.25, ease: "back.in(2)", onComplete: () => (this.root.visible = false) });
    } else {
      this.root.visible = false;
    }
  }
}

/** CampusRestingMemory: a glowing shard resting on Parth's shelf. */
export class MemoryShard implements Interactable {
  readonly root = new Group();
  collected = false;
  private crystal: Mesh;
  private halo: Mesh;
  readonly light: PointLight;
  private t = Math.random() * 10;

  constructor(prepare: (m: MeshStandardMaterial) => void, readonly memoryId: string, private onCollect: (s: MemoryShard) => void) {
    const mat = new MeshStandardMaterial({
      color: 0x6fd6e8,
      emissive: new Color(0x2fb6d4),
      emissiveIntensity: 2.2,
      roughness: 0.15,
      metalness: 0.1,
      transparent: true,
      opacity: 0.88,
    });
    prepare(mat);
    this.crystal = new Mesh(new OctahedronGeometry(0.13, 0), mat);
    this.crystal.scale.set(0.75, 1.7, 0.75);
    this.crystal.position.y = 0.2;
    this.crystal.castShadow = false;
    this.root.add(this.crystal);
    this.halo = new Mesh(
      new SphereGeometry(0.32, 16, 12),
      new MeshBasicMaterial({ color: 0x3ec8e6, transparent: true, opacity: 0.12, blending: AdditiveBlending, depthWrite: false }),
    );
    this.halo.position.y = 0.2;
    this.root.add(this.halo);
    this.light = new PointLight(0x55d4ee, 3.5, 3.2, 2);
    this.light.position.y = 0.25;
    this.root.add(this.light);
    markInteractable(this.root, this);
  }

  update(dt: number): void {
    if (this.collected) return;
    this.t += dt;
    this.crystal.rotation.y += dt * 0.6;
    const pulse = 0.5 + 0.5 * Math.sin(this.t * 2.2);
    (this.crystal.material as MeshStandardMaterial).emissiveIntensity = 4 + pulse * 4;
    (this.halo.material as MeshBasicMaterial).opacity = 0.1 + pulse * 0.12;
    this.light.intensity = 2.5 + pulse * 2 + (Math.random() < 0.02 ? -2 : 0);
  }

  getInteractionPrompt(): string {
    return this.collected ? "" : "[E] Collect memory shard";
  }

  interact(): void {
    if (this.collected) return;
    this.collected = true;
    this.onCollect(this);
  }

  dissolve(): void {
    gsap.to(this.crystal.scale, { x: 0.01, y: 3, z: 0.01, duration: 0.9, ease: "power3.in" });
    gsap.to(this.light, { intensity: 14, duration: 0.4, yoyo: true, repeat: 1, onComplete: () => (this.light.intensity = 0) });
    gsap.to(this.halo.scale, { x: 4, y: 4, z: 4, duration: 0.9, ease: "power2.out", onComplete: () => (this.root.visible = false) });
  }
}

/**
 * KeypadLocker / CampusKeypadLocker: a hollow steel cabinet whose prompt
 * changes once the clue is remembered; opening reveals the access card.
 */
export class KeypadLocker implements Interactable {
  readonly root = new Group();
  private doorPivot = new Group();
  private keypadMat: MeshStandardMaterial;
  isOpen = false;
  readonly card: AccessCardPickup;

  constructor(
    ctx: PickupContext,
    readonly code: string,
    private knowsClue: (clue: string) => boolean,
    rewardLabel: string,
    onCard: (card: AccessCardPickup) => boolean,
    private feedback: (ok: boolean) => void,
  ) {
    const body = new MeshKit(ctx.materials);
    const steel = 0x646e67;
    for (const x of [-0.565, 0.565]) body.box(V(x, 0, 0), V(0.07, 2.2, 0.75), "metal", steel);
    for (const y of [-1.065, 1.065]) body.box(V(0, y, 0), V(1.2, 0.07, 0.75), "metal", steel);
    body.box(V(0, 0, 0.34), V(1.06, 2.06, 0.07), "metal", 0x3b423e);
    body.box(V(0, -0.18, -0.015), V(1.06, 0.08, 0.65), "metal", steel);
    body.box(V(0, 0.55, -0.015), V(1.06, 0.05, 0.65), "metal", steel);
    body.box(V(-0.3, -0.05, 0.05), V(0.22, 0.18, 0.3), "plastic", 0x3c4a55);
    body.box(V(0.3, 0.65, 0.05), V(0.3, 0.2, 0.25), "plastic", 0x5a3a2c);
    this.root.add(body.build("LockerBody"));
    this.doorPivot.position.set(-0.55, 0, -0.43);
    this.root.add(this.doorPivot);
    const door = new MeshKit(ctx.materials);
    door.box(V(0.55, 0, 0), V(1.1, 2.05, 0.06), "metal", 0x4f5e5e);
    for (const y of [0.7, 0.78, 0.86]) door.box(V(0.55, y, -0.035), V(0.6, 0.03, 0.01), "dark", 0x252a28);
    door.box(V(0.98, 0, -0.05), V(0.04, 0.3, 0.04), "steel", 0xb0b6b2);
    door.box(V(0.86, 0.36, -0.05), V(0.28, 0.42, 0.06), "dark", 0x1f2523);
    this.doorPivot.add(door.build("LockerDoor"));
    this.keypadMat = new MeshStandardMaterial({ color: 0x0f3c45, emissive: new Color(0x63b9ac), emissiveIntensity: 1.2, roughness: 0.4 });
    ctx.prepare(this.keypadMat);
    const pad = new Mesh(new SphereGeometry(1, 4, 2), this.keypadMat);
    pad.scale.set(0.11, 0.15, 0.01);
    pad.position.set(0.86, 0.38, -0.085);
    pad.rotation.y = Math.PI / 4;
    this.doorPivot.add(pad);
    for (let r = 0; r < 4; r++) for (let c = 0; c < 3; c++) {
      const key = new Mesh(new SphereGeometry(1, 4, 2), this.keypadMat);
      key.scale.set(0.022, 0.018, 0.008);
      key.position.set(0.8 + c * 0.06, 0.28 + r * 0.05 - 0.1, -0.09);
      this.doorPivot.add(key);
    }
    this.card = new AccessCardPickup(ctx, rewardLabel, onCard);
    this.card.root.position.set(0, -0.12, -0.06);
    this.card.root.visible = false;
    this.root.add(this.card.root);
    markInteractable(this.root, this);
    markInteractable(this.card.root, this.card);
  }

  getInteractionPrompt(): string {
    if (this.isOpen) return "";
    return this.knowsClue(this.code) ? "[E] Enter remembered code" : "[E] Examine keypad";
  }

  /** Shut with the card back inside (a wipe). */
  reset(): void {
    gsap.killTweensOf(this.doorPivot.rotation);
    this.isOpen = false;
    this.doorPivot.rotation.y = 0;
    this.card.reset();
  }

  interact(): void {
    if (this.isOpen) return;
    if (!this.knowsClue(this.code)) {
      this.flash(0xe61f14);
      this.feedback(false);
      return;
    }
    this.isOpen = true;
    this.flash(0x26ff73);
    this.feedback(true);
    this.card.root.visible = true;
    gsap.to(this.doorPivot.rotation, { y: (105 * Math.PI) / 180, duration: 0.75, ease: "power2.out", delay: 0.35 });
  }

  private flash(hex: number): void {
    gsap.killTweensOf(this.keypadMat.emissive);
    this.keypadMat.emissive.set(hex);
    this.keypadMat.emissiveIntensity = 3;
    const base = new Color(0x63b9ac);
    gsap.to(this.keypadMat.emissive, { r: base.r, g: base.g, b: base.b, duration: 0.4, delay: 0.65 });
  }
}

/** The MAINTENANCE ACCESS CARD revealed inside the locker. */
export class AccessCardPickup implements Interactable {
  readonly root = new Group();
  collected = false;
  private home: Vector3 | null = null;

  constructor(ctx: PickupContext, readonly label: string, private onCollect: (c: AccessCardPickup) => boolean) {
    const kit = new MeshKit(ctx.materials);
    kit.box(V(0, 0.03, 0), V(0.32, 0.02, 0.2), "hazard", 0xb69b49);
    kit.box(V(-0.06, 0.042, 0), V(0.12, 0.004, 0.1), "paper", 0x2a2b26);
    kit.box(V(0.09, 0.042, 0.05), V(0.06, 0.004, 0.05), "steel", 0xd4c58a);
    const mesh = kit.build("AccessCard");
    mesh.castShadow = false;
    this.root.add(mesh);
  }

  getInteractionPrompt(): string {
    return this.collected || !this.root.visible ? "" : `[E] Take ${this.label.toLowerCase()}`;
  }

  reset(): void {
    gsap.killTweensOf(this.root.position);
    gsap.killTweensOf(this.root.scale);
    if (this.home) this.root.position.copy(this.home);
    this.root.scale.setScalar(1);
    this.collected = false;
    this.root.visible = false;
  }

  interact(): void {
    if (this.collected || !this.root.visible) return;
    this.home ??= this.root.position.clone();
    this.collected = true;
    this.onCollect(this);
    gsap.to(this.root.position, { y: this.root.position.y + 0.25, duration: 0.3, ease: "power2.out" });
    gsap.to(this.root.scale, { x: 0.01, y: 0.01, z: 0.01, duration: 0.3, delay: 0.1, onComplete: () => (this.root.visible = false) });
  }
}
