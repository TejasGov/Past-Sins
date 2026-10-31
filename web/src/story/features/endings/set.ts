import { Quaternion, Vector3 } from "three";
import type { StaticBuilder } from "../../../world/builder";
import { V } from "../../../world/props";
import type { EndingsData } from "./data";

const UPRIGHT = new Quaternion();

/**
 * Let Go's two places, built with the static world (visual only, no
 * colliders): the town on the horizon beyond the reservoir — low houses and
 * the temple water tank on its legs — and the Varma family's doorstep, a
 * narrow lane far off the campus where the camera walks Parth to the door.
 */
export function buildEndingSets(b: StaticBuilder, data: EndingsData): void {
  const prev = b.chunkName;
  b.setChunk("exterior", false);
  buildTown(b, V(...data.letGo.town.center));
  buildDoorstep(b, V(...data.letGo.doorstep.origin));
  b.setChunk(prev, false);
}

function buildTown(b: StaticBuilder, c: Vector3): void {
  const roof = 0x4a4741;
  const walls = [0x8d877a, 0x7e786c, 0x9a9283, 0x847d70];
  const houses: [number, number, number, number, number][] = [
    [-34, 6, 7, 5, 4], [-24, -3, 8, 6, 5.5], [-14, 8, 6, 5, 4.2], [-6, -6, 9, 7, 6.5], [6, 4, 7, 6, 4.8],
    [16, -4, 10, 6, 5.2], [26, 7, 6, 5, 4], [34, -2, 8, 7, 6], [44, 5, 7, 5, 4.4], [-44, -4, 9, 6, 5],
  ];
  houses.forEach(([x, z, w, d, h], i) => {
    const at = c.clone().add(V(x, 0, z));
    b.box(at.clone().add(V(0, h / 2, 0)), V(w, h, d), { mat: "concrete_ext", color: walls[i % walls.length], collide: false, occlude: false });
    b.box(at.clone().add(V(0, h + 0.15, 0)), V(w + 0.6, 0.3, d + 0.6), { mat: "dark_ext", color: roof, collide: false, occlude: false });
  });
  // The temple's tank on its four legs: the shape Parth would know anywhere.
  const tank = c.clone().add(V(4, 0, 14));
  for (const [sx, sz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
    b.box(tank.clone().add(V(sx * 2.2, 5, sz * 2.2)), V(0.35, 10, 0.35), { mat: "concrete_ext", color: 0x6f6b62, collide: false, occlude: false });
  }
  b.box(tank.clone().add(V(0, 4.2, 0)), V(4.8, 0.25, 4.8), { mat: "concrete_ext", color: 0x6f6b62, collide: false, occlude: false });
  b.cylinder(tank.clone().add(V(0, 11.6, 0)), 3.1, 3.2, { mat: "concrete_ext", color: 0x7b766b, quat: UPRIGHT, collide: false });
  b.cylinder(tank.clone().add(V(0, 13.35, 0)), 3.3, 0.3, { mat: "dark_ext", color: 0x4e4a43, quat: UPRIGHT, collide: false });
  // A small shikhara behind it.
  const temple = c.clone().add(V(-8, 0, 20));
  b.box(temple.clone().add(V(0, 2.5, 0)), V(6, 5, 6), { mat: "plaster", color: 0xb9ad94, collide: false, occlude: false });
  for (let i = 0; i < 4; i++) {
    const s = 4.6 - i * 1.05;
    b.box(temple.clone().add(V(0, 5.5 + i * 1.6, 0)), V(s, 1.6, s), { mat: "plaster", color: 0xc2b59a, collide: false, occlude: false });
  }
}

/** The lane and the Varma front door. Local frame: the door is at the origin, the lane runs towards −Z. */
function buildDoorstep(b: StaticBuilder, origin: Vector3): void {
  b.within(origin, 0, () => {
    const lime = 0xd6cfbc;
    b.box(V(0, -0.05, -6), V(9, 0.1, 16), { mat: "concrete_ext", color: 0x6b675e, collide: false, occlude: false });
    // The house front with a deep door reveal; neighbours' walls frame the lane.
    b.box(V(-2.75, 2.75, 0.2), V(4.5, 5.5, 0.4), { mat: "plaster", color: lime, collide: false, occlude: false });
    b.box(V(2.75, 2.75, 0.2), V(4.5, 5.5, 0.4), { mat: "plaster", color: lime, collide: false, occlude: false });
    b.box(V(0, 4.0, 0.2), V(1.0, 3.0, 0.4), { mat: "plaster", color: lime, collide: false, occlude: false });
    b.box(V(0, 1.25, 0.32), V(1.0, 2.5, 0.08), { mat: "wood", color: 0x5a3b26, collide: false, occlude: false });
    for (const y of [0.55, 1.25, 1.95]) b.box(V(0, y, 0.27), V(0.92, 0.05, 0.02), { mat: "wood", color: 0x463020, collide: false, occlude: false });
    b.box(V(0.36, 1.1, 0.26), V(0.04, 0.16, 0.04), { mat: "steel", color: 0x9a8f6a, collide: false, occlude: false });
    for (const s of [-1, 1]) b.box(V(s * 0.56, 1.3, 0.05), V(0.12, 2.7, 0.3), { mat: "wood", color: 0x3e2a1c, collide: false, occlude: false });
    b.box(V(0, 2.65, 0.05), V(1.24, 0.12, 0.3), { mat: "wood", color: 0x3e2a1c, collide: false, occlude: false });
    b.box(V(0, 0.09, -0.35), V(1.6, 0.18, 0.7), { mat: "concrete_ext", color: 0x8a857a, collide: false, occlude: false });
    // Nameplate beside the door.
    b.box(V(0.95, 1.62, -0.01), V(0.42, 0.16, 0.02), { mat: "metal", color: 0x9b8a55, collide: false, occlude: false });
    b.sign("VARMA", V(0.95, 1.62, -0.025), Math.PI, 0x2a2418, 0.0024);
    // A barred window and a tulsi pot on its little plinth.
    b.box(V(-2.2, 1.75, -0.01), V(1.3, 1.1, 0.04), { mat: "dark", color: 0x1d2122, collide: false, occlude: false });
    for (let i = 0; i < 5; i++) b.box(V(-2.72 + i * 0.26, 1.75, -0.04), V(0.03, 1.1, 0.03), { mat: "steel", color: 0x6e6c63, collide: false, occlude: false });
    b.box(V(1.9, 0.35, -0.6), V(0.7, 0.7, 0.7), { mat: "plaster", color: 0xb78b5e, collide: false, occlude: false });
    b.box(V(1.9, 0.85, -0.6), V(0.3, 0.3, 0.3), { mat: "plaster", color: 0x3f6a33, collide: false, occlude: false });
    for (const s of [-1, 1]) b.box(V(s * 4.6, 2.6, -7), V(0.4, 5.2, 14), { mat: "plaster", color: s < 0 ? 0xbdb6a3 : 0xa9a291, collide: false, occlude: false });
    b.box(V(0, 5.6, 0.1), V(9.2, 0.25, 0.9), { mat: "dark_ext", color: 0x4a4741, collide: false, occlude: false });
    // The porch bulb, still on in the morning.
    b.box(V(0, 2.95, -0.12), V(0.12, 0.12, 0.12), { mat: "emissive_always", collide: false, shadow: false });
    b.lightPoint(V(0, 2.8, -0.6), 0xffd6a0, 6, 7, false);
  });
}
