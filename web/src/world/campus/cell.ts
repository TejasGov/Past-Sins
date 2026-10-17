import { Quaternion, Vector3 } from "three";
import type { StaticBuilder } from "../builder";
import { V, deg } from "../props";

export interface CellOptions {
  accessId: string;
  displayName: string;
  numberLabel: string;
  isParth: boolean;
  upperTier: boolean;
}

const W = 5.7;
const D = 5.0;
const H = 3.55;
const GATE = 1.35;

function hashString(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619);
  return Math.abs(h);
}

/**
 * Port of CampusPrisonCell (front_direction = +1). Local +X is the barred
 * front facing the gallery; local X spans 5.7 m, Z 5.0 m. Origin = floor.
 */
export function prisonCell(b: StaticBuilder, o: CellOptions): void {
  const wall = 0x444743;
  const floor = 0x303330;
  const front = 0x292d2b;
  const rear = -W / 2;
  const fx = W / 2;
  b.box(V(0, -0.06, 0), V(W, 0.12, D), { mat: "concrete", color: floor });
  b.box(V(0, H, 0), V(W, 0.14, D), { mat: "concrete", color: wall });
  b.box(V(rear, H / 2, 0), V(0.2, H, D), { mat: "concrete", color: wall });
  b.box(V(0, H / 2, -D / 2), V(W, H, 0.18), { mat: "concrete", color: wall });
  b.box(V(0, H / 2, D / 2), V(W, H, 0.18), { mat: "concrete", color: wall });
  const sideLen = (D - GATE) / 2;
  const sideOff = GATE / 2 + sideLen / 2;
  for (const s of [-1, 1]) b.box(V(fx, 1.42, s * sideOff), V(0.18, 2.84, sideLen), { mat: "concrete", color: front });
  // Full-width transom above the front (Godot left an open slot above the side walls).
  b.box(V(fx, 3.195, 0), V(0.2, 0.71, D), { mat: "concrete", color: front });
  for (const s of [-1, 1]) b.box(V(fx + 0.085, 1.4, s * (GATE / 2 + 0.05)), V(0.17, 2.8, 0.1), { mat: "metal", color: front });

  // Sliding barred door, owned by the cell (spawned as a PrisonSlidingGate).
  b.door({
    kind: "gate",
    position: V(fx + 0.26, 0, 0),
    yaw: deg(90),
    width: GATE,
    height: 2.8,
    slideDistance: 1.55,
    openDirection: 1,
    requiredKey: o.isParth ? "" : `${o.accessId}_key`,
    masterKey: "cell_master_key",
    persistentId: o.accessId,
    displayName: o.displayName,
    startsLocked: !o.isParth,
    color: 0x9aa49d,
  });

  // Wall-bracket bed.
  const bedX = rear + 0.62;
  b.box(V(bedX, 0.43, -1.0), V(1.05, 0.12, 2.0), { mat: "metal", color: 0x292d2b });
  b.box(V(bedX + 0.03, 0.57, -1.0), V(0.95, 0.18, 1.88), { mat: "fabric", color: 0x4d544f, collide: false });
  b.box(V(bedX, 0.7, -1.72), V(0.78, 0.12, 0.34), { mat: "fabric", color: 0x6f756f, collide: false });
  b.box(V(bedX + 0.05, 0.67, -0.55), V(0.9, 0.04, 0.9), { mat: "fabric", color: 0x3b4650, collide: false, yaw: 0.05 });
  for (const z of [-1.72, -0.28]) {
    b.box(V(rear + 0.3, 0.31, z), V(0.5, 0.12, 0.12), { mat: "metal", color: 0x292d2b, collide: false });
    b.box(V(rear + 0.12, 0.48, z), V(0.12, 0.5, 0.18), { mat: "metal", color: 0x292d2b, collide: false });
  }

  // Sanitary corner behind a chest-high privacy wall.
  b.box(V(rear + 0.88, 0.8, 0.48), V(1.72, 1.6, 0.14), { mat: "concrete", color: 0x4b4f4b });
  const tx = rear + 0.55;
  b.cylinder(V(tx, 0.22, 1.72), 0.22, 0.44, { mat: "steel", color: 0x7f8783, collide: true });
  b.cylinder(V(tx + 0.16, 0.48, 1.72), 0.3, 0.18, { mat: "steel", color: 0x929a96 });
  b.box(V(tx - 0.1, 0.72, 2.08), V(0.48, 0.5, 0.22), { mat: "steel", color: 0x7d8582, collide: false });
  const bx = rear + 1.42;
  b.cylinder(V(bx, 0.36, 1.72), 0.13, 0.72, { mat: "steel", color: 0x777f7b });
  b.box(V(bx, 0.78, 1.72), V(0.62, 0.16, 0.48), { mat: "steel", color: 0x929a96, collide: false });
  b.box(V(bx, 1.0, 1.94), V(0.62, 0.42, 0.08), { mat: "steel", color: 0x858d89, collide: false });
  b.box(V(bx, 1.55, 2.38), V(0.42, 0.55, 0.02), { mat: "steel", color: 0xb6bdb9, collide: false, shadow: false });

  // Cupboard.
  b.box(V(0.1, 0.68, -2.16), V(0.82, 1.36, 0.52), { mat: "wood", color: 0x6b5845 });
  b.box(V(-0.105, 0.7, -1.89), V(0.38, 1.22, 0.04), { mat: "wood", color: 0x7a6650, collide: false });
  b.box(V(0.305, 0.7, -1.89), V(0.38, 1.22, 0.04), { mat: "wood", color: 0x76624c, collide: false });

  // Wooden chair.
  const chair = V(0.25, 0, 1.45);
  b.box(chair.clone().add(V(0, 0.48, 0)), V(0.58, 0.06, 0.56), { mat: "wood", color: 0x765d43 });
  for (const x of [-0.22, 0.22]) for (const z of [-0.2, 0.2]) b.cylinder(chair.clone().add(V(x, 0.22, z)), 0.03, 0.44, { mat: "wood", color: 0x5f4a36 });
  for (const x of [-0.23, 0.23]) b.cylinder(chair.clone().add(V(x, 0.82, -0.23)), 0.03, 0.72, { mat: "wood", color: 0x644e39 });
  for (const y of [0.72, 0.94]) b.box(chair.clone().add(V(0, y, -0.23)), V(0.5, 0.09, 0.05), { mat: "wood", color: 0x765d43, collide: false });

  // Deterministic personal items (Godot hashed the access id into 6 variants).
  const variant = hashString(o.accessId) % 6;
  const books = [0x65523d, 0x405869, 0x6b443c];
  if ([0, 2, 5].includes(variant) || o.isParth) {
    for (let i = 0; i < 2 + (variant === 5 ? 1 : 0); i++) {
      b.box(V(0.08 + i * 0.015, 1.405 + i * 0.055, -2.14), V(0.38 - i * 0.02, 0.05, 0.24), { mat: "paper", color: books[i % 3], collide: false });
    }
  }
  if ([1, 3, 5].includes(variant)) {
    for (let i = 0; i < 2; i++) b.box(V(-2.05, 0.7 + i * 0.055, -0.62), V(0.42, 0.05, 0.32), { mat: "fabric", color: 0x555e61, collide: false });
  }
  if ([0, 3, 4].includes(variant)) b.cylinder(V(-1.42, 0.95, 1.7), 0.065, 0.16, { mat: "plastic", color: 0x9ca29c });
  if ([2, 4].includes(variant) || o.isParth) {
    for (let i = 0; i < 3; i++) b.box(V(0.25 + i * 0.008, 0.555 + i * 0.008, 1.44), V(0.36, 0.008, 0.25), { mat: "paper", color: 0xc5c0a9, collide: false, shadow: false, yaw: i * 0.2 });
  }

  // Wall tube lamp beside the entrance: caged emissive tube + pool light.
  b.within(V(1.2, 2.05, -D / 2 + 0.09), 0, () => {
    b.box(V(0, 0, 0.04), V(0.74, 0.14, 0.06), { mat: "metal", color: 0x535c55, collide: false });
    b.box(V(0, 0, 0.1), V(0.64, 0.06, 0.06), { mat: o.isParth ? "emissive_always" : "emissive_night", collide: false, shadow: false });
    for (const x of [-0.3, -0.1, 0.1, 0.3]) b.box(V(x, 0, 0.13), V(0.015, 0.16, 0.015), { mat: "iron", collide: false, shadow: false });
  });
  b.lightPoint(V(1.0, 2.1, -D / 2 + 1.1), o.isParth ? 0xffd2a0 : 0xffcf8a, o.isParth ? 1.5 : 1.2, 7, !o.isParth, o.isParth ? 0.35 : 0);

  b.sign(o.numberLabel, V(fx + 0.12, 2.5, -1.28), deg(90), 0xd4cfad, 0.0024);
}

/** Parth's spawn and memory shelf, in the cell's local frame. */
export const PARTH_SPAWN_LOCAL = V(-0.25, 0.05, 0.55);
export const PARTH_SPAWN_YAW = deg(-90);

export function memoryShelf(b: StaticBuilder): Vector3 {
  // CampusSessionContent._memory_shelf: bracketed shelf on the north partition.
  const at = V(1.5, 0, -2.4);
  b.within(at, 0, () => {
    b.box(V(0, 0.7, 0), V(0.76, 0.44, 0.05), { mat: "concrete", color: 0x73756a, collide: false });
    b.box(V(0, 0.82, 0.24), V(0.76, 0.06, 0.48), { mat: "wood", color: 0x75634d });
    for (const x of [-0.25, 0.25]) b.box(V(x, 0.72, 0.19), V(0.06, 0.12, 0.4), { mat: "dark", color: 0x333c36, collide: false });
  });
  return b.toWorld(at.clone().add(V(0, 0.85, 0.24)));
}

export const _unused = new Quaternion();
