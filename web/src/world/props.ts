import { Quaternion, Vector3 } from "three";
import type { StaticBuilder } from "./builder";

export const V = (x: number, y: number, z: number) => new Vector3(x, y, z);
export const deg = (d: number) => (d * Math.PI) / 180;
const qx = (a: number) => new Quaternion().setFromAxisAngle(new Vector3(1, 0, 0), a);
const qz = (a: number) => new Quaternion().setFromAxisAngle(new Vector3(0, 0, 1), a);

/**
 * Procedural prop library. Each prop is authored in its own local frame (the
 * Godot scenes' convention: origin at floor contact, facing +Z) and merged into
 * the static batches by the builder.
 */
export function place(b: StaticBuilder, at: Vector3, yawDeg: number, fn: (b: StaticBuilder) => void): void {
  b.within(at, deg(yawDeg), () => fn(b));
}

export function bench(b: StaticBuilder): void {
  b.box(V(0, 0.45, 0), V(1.9, 0.07, 0.42), { mat: "wood", color: 0x7a6247 });
  for (const x of [-0.8, 0.8]) {
    b.box(V(x, 0.22, 0), V(0.07, 0.44, 0.36), { mat: "dark", color: 0x3a403c, collide: false });
    b.box(V(x, 0.02, 0), V(0.1, 0.04, 0.42), { mat: "dark", color: 0x3a403c, collide: false });
  }
}

export function securityConsole(b: StaticBuilder): void {
  b.box(V(0, 0.48, 0), V(2.4, 0.96, 0.8), { mat: "dark", color: 0x2a302d });
  b.box(V(0, 0.99, -0.05), V(2.5, 0.06, 0.95), { mat: "metal", color: 0x59615d, collide: false });
  for (const x of [-0.75, 0, 0.75]) {
    b.box(V(x, 1.3, -0.25), V(0.62, 0.42, 0.06), { mat: "dark", color: 0x1c2120, collide: false, quat: qx(deg(-8)) });
    b.box(V(x, 1.3, -0.215), V(0.54, 0.34, 0.01), { mat: "screen", collide: false, shadow: false, quat: qx(deg(-8)) });
  }
  b.box(V(0.2, 1.04, 0.15), V(0.6, 0.03, 0.2), { mat: "plastic", color: 0x2c302e, collide: false });
  b.box(V(-0.95, 1.12, 0.15), V(0.2, 0.22, 0.16), { mat: "dark", color: 0x1c2120, collide: false });
  b.box(V(0.95, 1.035, 0.2), V(0.04, 0.02, 0.02), { mat: "emissive_green", collide: false, shadow: false });
}

export function trashBin(b: StaticBuilder): void {
  b.cylinder(V(0, 0.42, 0), 0.26, 0.84, { mat: "metal", color: 0x48524d, collide: true });
  b.cylinder(V(0, 0.86, 0), 0.28, 0.05, { mat: "dark", color: 0x2c312e });
}

export function cleaningCart(b: StaticBuilder): void {
  b.box(V(0, 0.55, 0), V(1.1, 0.06, 0.55), { mat: "plastic", color: 0x3f5a6b });
  b.box(V(0, 0.15, 0), V(1.1, 0.06, 0.55), { mat: "plastic", color: 0x3f5a6b, collide: false });
  for (const x of [-0.5, 0.5]) for (const z of [-0.22, 0.22]) b.cylinder(V(x, 0.35, z), 0.02, 0.6, { mat: "steel" });
  b.cylinder(V(-0.25, 0.75, 0), 0.18, 0.38, { mat: "plastic", color: 0xc9b84a, collide: false });
  b.box(V(0.3, 0.9, 0), V(0.04, 0.8, 0.04), { mat: "wood", color: 0x8a6b4a, collide: false });
}

export function drinkingFountain(b: StaticBuilder): void {
  b.box(V(0, 0.45, 0.18), V(0.5, 0.9, 0.36), { mat: "steel", color: 0xa7aeaa });
  b.box(V(0, 0.95, 0.2), V(0.48, 0.1, 0.42), { mat: "steel", color: 0xbcc3bf, collide: false });
  b.cylinder(V(0, 1.03, 0.12), 0.02, 0.08, { mat: "steel" });
}

export function noticeBoard(b: StaticBuilder): void {
  b.box(V(0, 1.55, 0.03), V(1.6, 1.0, 0.05), { mat: "wood", color: 0x7a684e, collide: false });
  const papers = [[-0.5, 1.7], [0.05, 1.65], [0.5, 1.75], [-0.3, 1.35], [0.35, 1.32]];
  papers.forEach(([x, y], i) =>
    b.box(V(x, y, 0.06), V(0.3, 0.38, 0.008), { mat: "paper", color: i % 2 ? 0xd8d3bd : 0xc5c0a9, collide: false, shadow: false, quat: qz(deg((i - 2) * 2.5)) }),
  );
}

export function wallClock(b: StaticBuilder): void {
  b.cylinder(V(0, 2.4, 0.04), 0.24, 0.06, { mat: "plastic", color: 0xd0d3cc, quat: qx(Math.PI / 2) });
  b.box(V(0, 2.45, 0.075), V(0.02, 0.14, 0.01), { mat: "dark", color: 0x111111, collide: false, shadow: false });
  b.box(V(0.05, 2.4, 0.075), V(0.11, 0.015, 0.01), { mat: "dark", color: 0x111111, collide: false, shadow: false });
}

export function cctvCamera(b: StaticBuilder): void {
  b.box(V(0, 0, 0.08), V(0.12, 0.12, 0.16), { mat: "dark", color: 0x2a2f2c, collide: false });
  b.box(V(0, -0.08, 0.32), V(0.16, 0.14, 0.38), { mat: "plastic", color: 0xb9bdb7, collide: false, quat: qx(deg(18)) });
  b.box(V(0, -0.16, 0.52), V(0.11, 0.1, 0.02), { mat: "dark", color: 0x0b0d0c, collide: false, quat: qx(deg(18)) });
  b.box(V(0.05, -0.04, 0.45), V(0.018, 0.018, 0.018), { mat: "emissive_red", collide: false, shadow: false });
}

export function electricalBox(b: StaticBuilder): void {
  b.box(V(0, 1.5, 0.12), V(0.7, 0.9, 0.24), { mat: "metal", color: 0x6b746e, collide: false });
  b.box(V(0, 1.5, 0.245), V(0.62, 0.8, 0.01), { mat: "metal", color: 0x7b847e, collide: false });
  b.box(V(0, 1.75, 0.255), V(0.32, 0.08, 0.005), { mat: "hazard", collide: false, shadow: false });
  b.box(V(0, 2.5, 0.06), V(0.08, 1.1, 0.08), { mat: "steel", collide: false });
}

export function pipeRun(b: StaticBuilder, length = 4): void {
  for (const [y, r] of [[3.2, 0.07], [3.42, 0.05], [3.6, 0.09]] as const) {
    b.cylinder(V(0, y, 0.15), r, length, { mat: "steel", color: 0x8e938d, quat: qz(Math.PI / 2), collide: false });
  }
}

export function locker(b: StaticBuilder, color = 0x59615d): void {
  b.box(V(0, 0.92, 0), V(0.66, 1.74, 0.56), { mat: "metal", color });
  b.box(V(0, 0.94, 0.3), V(0.58, 1.62, 0.04), { mat: "metal", color: 0x667069, collide: false });
  for (const x of [-0.16, 0, 0.16]) b.box(V(x, 1.53, 0.33), V(0.09, 0.025, 0.025), { mat: "dark", collide: false });
  b.box(V(0.21, 0.96, 0.33), V(0.04, 0.25, 0.03), { mat: "dark", collide: false });
}

export function desk(b: StaticBuilder, width = 1.6, depth = 0.7): void {
  b.box(V(0, 0.75, 0), V(width, 0.05, depth), { mat: "wood", color: 0x69716c });
  for (const x of [-width / 2 + 0.06, width / 2 - 0.06]) for (const z of [-depth / 2 + 0.06, depth / 2 - 0.06]) {
    b.box(V(x, 0.36, z), V(0.05, 0.72, 0.05), { mat: "dark", color: 0x2a2f2c, collide: false });
  }
  b.box(V(0, 0.42, -depth / 2 + 0.03), V(width - 0.15, 0.5, 0.03), { mat: "metal", color: 0x59615d, collide: false });
}

export function officeChair(b: StaticBuilder): void {
  b.box(V(0, 0.5, 0), V(0.52, 0.08, 0.52), { mat: "fabric", color: 0x3e4542 });
  b.box(V(0, 0.9, -0.24), V(0.5, 0.55, 0.06), { mat: "fabric", color: 0x3e4542, collide: false });
  b.cylinder(V(0, 0.25, 0), 0.03, 0.45, { mat: "steel" });
  b.box(V(0, 0.04, 0), V(0.55, 0.03, 0.06), { mat: "dark", collide: false });
  b.box(V(0, 0.04, 0), V(0.06, 0.03, 0.55), { mat: "dark", collide: false });
}

export function monitor(b: StaticBuilder): void {
  b.box(V(0, 0.92, 0), V(0.1, 0.28, 0.1), { mat: "dark", collide: false });
  b.box(V(0, 1.18, 0), V(0.62, 0.4, 0.06), { mat: "dark", color: 0x1c2120, collide: false });
  b.box(V(0, 1.18, 0.032), V(0.55, 0.33, 0.005), { mat: "screen", collide: false, shadow: false });
}

export function shelfUnit(b: StaticBuilder, width = 1.8, height = 2.0, depth = 0.5, color = 0x5c6660): void {
  for (const x of [-width / 2, width / 2]) b.box(V(x, height / 2, 0), V(0.04, height, depth), { mat: "metal", color, collide: false });
  for (let i = 0; i < 4; i++) b.box(V(0, 0.12 + (i * (height - 0.2)) / 3, 0), V(width, 0.03, depth), { mat: "metal", color, collide: false });
  b.blocker(V(0, height / 2, 0), V(width, height, depth), false);
}

export function boxesStack(b: StaticBuilder, seed: number): void {
  const r = (n: number) => {
    const x = Math.sin(seed * 91.7 + n * 13.1) * 43758.5;
    return x - Math.floor(x);
  };
  for (let i = 0; i < 3; i++) {
    const w = 0.4 + r(i) * 0.25;
    b.box(V((r(i + 5) - 0.5) * 0.3, 0.2 + i * 0.4, (r(i + 9) - 0.5) * 0.2), V(w, 0.38, 0.4), {
      mat: "plastic", color: i % 2 ? 0x8b7556 : 0x9d8763, collide: i === 0, yaw: (r(i + 2) - 0.5) * 0.4,
    });
  }
}

export function table(b: StaticBuilder, w: number, d: number, h = 0.76, color = 0x8f958c, mat: "steel" | "wood" | "metal" = "steel"): void {
  b.box(V(0, h, 0), V(w, 0.05, d), { mat, color });
  for (const x of [-w / 2 + 0.07, w / 2 - 0.07]) for (const z of [-d / 2 + 0.07, d / 2 - 0.07]) {
    b.box(V(x, h / 2, z), V(0.05, h, 0.05), { mat: "steel", color: 0x6d736f, collide: false });
  }
}
