import { Vector3 } from "three";
import type { Anchor } from "../../../world/types";
import type { Door } from "../../../interact/door";
import type { CellDef } from "./data";

/**
 * Parth's cell N03 for the count and lock-in: an inside-the-cell box in the
 * `parth_spawn` anchor's frame (data), and the cell's sliding gate.
 */
export class CellFrame {
  private readonly c: number;
  private readonly s: number;
  /** The gate's own key requirement, restored whenever the routine unlocks it. */
  private readonly authoredKey: string;

  constructor(
    private anchor: Anchor,
    private def: CellDef,
    readonly gate: Door | null,
  ) {
    this.c = Math.cos(anchor.yaw);
    this.s = Math.sin(anchor.yaw);
    this.authoredKey = gate?.spec.requiredKey ?? "";
  }

  /** World → anchor frame (inverse of resolvePlace's anchor offsets). */
  toLocal(p: Vector3): Vector3 {
    const dx = p.x - this.anchor.position.x;
    const dz = p.z - this.anchor.position.z;
    return new Vector3(this.c * dx - this.s * dz, p.y - this.anchor.position.y, this.s * dx + this.c * dz);
  }

  toWorld(x: number, y: number, z: number): Vector3 {
    const a = this.anchor.position;
    return new Vector3(a.x + this.c * x + this.s * z, a.y + y, a.z - this.s * x + this.c * z);
  }

  /** Feet position inside N03 (behind the gate line). */
  contains(feet: Vector3): boolean {
    const l = this.toLocal(feet);
    const { min, max } = this.def;
    return l.x >= min[0] && l.x <= max[0] && l.y >= min[1] && l.y <= max[1] && l.z >= min[2] && l.z <= max[2];
  }

  get center(): Vector3 {
    const { min, max } = this.def;
    return this.toWorld((min[0] + max[0]) / 2, 0, (min[2] + max[2]) / 2);
  }

  /** On the gallery just outside the gate (where an officer stands for the count). */
  get doorstep(): Vector3 {
    if (!this.gate) return this.center;
    const g = this.gate.spec.position.clone();
    const out = g.clone().sub(this.center).setY(0).normalize();
    return g.addScaledVector(out, 1.1);
  }

  /** Rolls the gate shut (animated) if it is open and unlocked; false when there is no gate. */
  close(player: Parameters<Door["interact"]>[0]): boolean {
    const g = this.gate;
    if (!g) return false;
    if (g.isOpen && !g.isMoving && !g.isLocked) g.interact(player);
    return true;
  }

  lock(key: string): void {
    const g = this.gate;
    if (!g) return;
    g.spec.requiredKey = key;
    g.setState(false, true);
  }

  /** Unlocks (authored key requirement back) and optionally slides it open. */
  unlock(open: boolean, player: Parameters<Door["interact"]>[0]): void {
    const g = this.gate;
    if (!g) return;
    g.spec.requiredKey = this.authoredKey;
    if (g.isLocked) g.setState(false, false);
    if (open && !g.isOpen && !g.isMoving) g.interact(player);
  }

  /** Wipe / detention reset: the gate's authored key requirement. */
  restoreKey(): void {
    if (this.gate) this.gate.spec.requiredKey = this.authoredKey;
  }
}
