import { Box3, Group, Mesh, MeshBasicMaterial, BoxGeometry, Quaternion, Vector3, type MeshStandardMaterial } from "three";
import { MeshKit } from "../world/builder";
import { MemoryShard } from "../interact/pickups";
import { markInteractable, type Interactable } from "../interact/interactable";
import type { MaterialLibrary } from "../render/materials";
import type { TriggerDef } from "./types";

const V = (x: number, y: number, z: number) => new Vector3(x, y, z);
const proxyMaterial = new MeshBasicMaterial({ visible: false });

/** Small greybox props for interact triggers (sized to sit on a desk/shelf; origin at the base). */
function buildModel(kind: TriggerDef["model"], materials: MaterialLibrary): Mesh | null {
  const kit = new MeshKit(materials);
  const upright = new Quaternion();
  switch (kind) {
    case "paper":
      kit.box(V(0, 0.003, 0), V(0.22, 0.004, 0.3), "paper", 0xd6d0bd);
      kit.box(V(0.03, 0.006, 0.02), V(0.21, 0.003, 0.29), "paper", 0xe2ddcc);
      break;
    case "photo":
      kit.box(V(0, 0.003, 0), V(0.15, 0.004, 0.1), "paper", 0xcfc7b0);
      break;
    case "box":
      kit.box(V(0, 0.12, 0), V(0.42, 0.24, 0.3), "wood", 0x7a684e);
      break;
    case "tumbler":
      kit.cylinder(V(0, 0.06, 0), 0.04, 0.12, "steel", 0xb7bcb6, upright);
      break;
    case "vial":
      kit.cylinder(V(0, 0.045, 0), 0.015, 0.09, "glass", 0x9fd3e0, upright);
      kit.cylinder(V(0, 0.095, 0), 0.017, 0.015, "plastic", 0x3c4a55, upright);
      break;
    case "bag":
      kit.box(V(0, 0.14, 0), V(0.4, 0.28, 0.2), "paper", 0x8a7a5a);
      kit.box(V(0, 0.29, 0), V(0.3, 0.02, 0.21), "paper", 0x6f6247);
      break;
    case "tape":
      kit.box(V(0, 0.008, 0), V(0.1, 0.016, 0.064), "plastic", 0x2a2b2c);
      kit.box(V(0, 0.017, 0), V(0.07, 0.002, 0.03), "paper", 0xd8d2bf);
      break;
    case "panel":
      kit.box(V(0, 0.3, 0), V(0.5, 0.6, 0.08), "metal", 0x4f5a54);
      kit.box(V(0, 0.38, 0.045), V(0.32, 0.18, 0.01), "dark", 0x16302b);
      break;
    default:
      return null;
  }
  const mesh = kit.build(`Trigger:${kind}`);
  mesh.castShadow = false;
  return mesh;
}

/** An E-prompt story prop (or a glowing shard) driven by a TriggerDef. */
export class TriggerProp implements Interactable {
  readonly root = new Group();
  readonly shard: MemoryShard | null = null;
  private busy = false;

  constructor(
    readonly def: TriggerDef,
    materials: MaterialLibrary,
    prepare: (m: MeshStandardMaterial) => void,
    private available: () => boolean,
    private fire: (t: TriggerProp) => Promise<void>,
  ) {
    if (def.model === "shard") {
      this.shard = new MemoryShard(prepare, def.id, () => void this.activate());
      this.root.add(this.shard.root);
    } else {
      const mesh = buildModel(def.model ?? "none", materials);
      if (mesh) this.root.add(mesh);
      // Generous invisible hit volume so small props are easy to aim at.
      const hit = new Mesh(new BoxGeometry(0.5, 0.5, 0.5), proxyMaterial);
      hit.position.y = 0.2;
      this.root.add(hit);
      markInteractable(this.root, this);
    }
  }

  getInteractionPrompt(): string {
    if (this.busy || !this.available()) return "";
    return this.def.prompt ?? "[E] Examine";
  }

  interact(): void {
    void this.activate();
  }

  private async activate(): Promise<void> {
    if (this.busy || !this.available()) {
      if (this.shard) this.shard.collected = false;
      return;
    }
    this.busy = true;
    try {
      await this.fire(this);
    } finally {
      this.busy = false;
    }
  }

  update(dt: number, visible: boolean): void {
    this.root.visible = visible;
    if (this.shard) {
      this.shard.collected = !visible;
      if (visible) this.shard.update(dt);
    }
  }
}

/** Walk-in volume. */
export class TriggerZone {
  inside = false;
  constructor(
    readonly def: TriggerDef,
    readonly box: Box3,
  ) {}
}
