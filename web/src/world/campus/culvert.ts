import { Box3, Mesh, Quaternion, Vector3, type BufferAttribute, type Object3D } from "three";
import type { StaticBuilder } from "../builder";
import type { BuiltFloor } from "./blueprintFloor";
import { subtract, type Rect } from "./ground";
import { SWIM_TUNING, SwimmingPool } from "../pool";
import { V } from "../props";

/**
 * The Ghost Exit drainage culvert ("Again", Act III): a flooded sump under
 * Maintenance B1's Drainage / Sump room, a box culvert running south under the
 * yard and the perimeter wall, three air pockets spaced 2, 7 and 1 seconds of
 * swimming apart, the final 8 to a trash-racked outfall, and the reservoir
 * outside the wall. Built by the water story feature's `buildStatic`
 * (src/story/features/water) so no campus file changes.
 */

/** Perimeter wall line (exterior.ts buildPerimeter: hd = 94, 0.6 m thick). */
const PERIMETER_Z = 94;
/** The far grass beyond the south wall (ground.ts buildGround): x −78…78, z 94…300, y −0.45…−0.05. */
const OUTER_GRASS = { x0: -78, x1: 78, z0: 94, z1: 300, y0: -0.45, y1: -0.05 };
const OUTER_GRASS_COLOR = 0x7a8468;

const WALL = 0.3;
const TUBE_WIDTH = 2.6;
const TUBE_HEIGHT = 2.2;
const POCKET = { width: 1.3, length: 1.4, height: 1.5, air: 0.75 };
const RACK_GAP = 1.3;

export interface PocketLayout {
  index: number;
  /** −1 west wall, +1 east wall. */
  side: number;
  min: Vector3;
  max: Vector3;
  surfaceY: number;
  center: Vector3;
}

export interface CulvertLayout {
  /** Tube centreline x. */
  x: number;
  /** Pump-room floor point at the hatch centre. */
  hatch: Vector3;
  slabBottom: number;
  /** Tube interior (y0 floor, y1 ceiling; z0 = shaft's north wall, z1 = outfall). */
  tube: { x0: number; x1: number; y0: number; y1: number; z0: number; z1: number };
  /** Sump shaft under the hatch: z range and water surface (air above up to `slabBottom`). */
  shaft: { z0: number; z1: number; surfaceY: number };
  pockets: PocketLayout[];
  /** Where the final 8 would end at full speed (the reservoir surface). */
  finalZ: number;
  outletZ: number;
  /** Where the small hand reaches from (in front of the broken rack). */
  hand: Vector3;
  handZone: Box3;
  reservoir: { x0: number; x1: number; z0: number; z1: number; floorY: number; surfaceY: number; rampZ: number };
  /** Feet position for climbing out beside the hatch, and for arriving in the sump. */
  pumpRoomExit: Vector3;
  sumpEntry: Vector3;
}

/**
 * Lays the culvert out from the Drainage / Sump room of maintenance-b1:
 * pockets sit `gaps[i]` seconds of swimming apart (SWIM_TUNING.swimSpeed).
 */
export function culvertLayout(floors: Map<string, BuiltFloor>, gaps: number[] = [2, 7, 1, 8], swimSpeed = SWIM_TUNING.swimSpeed): CulvertLayout | null {
  const floor = floors.get("maintenance-b1");
  const center = floor?.roomCenters.get("pump");
  if (!floor || !center) return null;
  const x = center.x;
  const hz = center.z;
  const slabBottom = center.y - 0.2;
  const y1 = slabBottom - 0.7;
  const y0 = y1 - TUBE_HEIGHT;
  const x0 = x - TUBE_WIDTH / 2;
  const x1 = x + TUBE_WIDTH / 2;
  const shaft = { z0: hz - 1.2, z1: hz + 1.2, surfaceY: slabBottom - 0.42 };
  const pockets: PocketLayout[] = [];
  let z = hz;
  for (let i = 0; i < 3; i++) {
    z += (gaps[i] ?? 0) * swimSpeed;
    const side = i % 2 === 0 ? -1 : 1;
    const px0 = side < 0 ? x0 : x1 - POCKET.width;
    const min = V(px0, y1 - 0.3, z - POCKET.length / 2);
    const max = V(px0 + POCKET.width, y1 + POCKET.air, z + POCKET.length / 2);
    pockets.push({ index: i, side, min, max, surfaceY: max.y, center: V(px0 + POCKET.width / 2, y1, z) });
  }
  const finalZ = z + (gaps[3] ?? 0) * swimSpeed;
  const outletZ = Math.max(PERIMETER_Z + 6, z + 7);
  const hand = V(x, y0 + 0.95, outletZ - 0.6);
  const handZone = new Box3(V(x0, y0 - 0.5, outletZ - 2.8), V(x1, y1 + 0.5, outletZ - 0.2));
  const reservoir = { x0: x - 14, x1: x + 14, z0: outletZ, z1: outletZ + 30, floorY: y0 - 0.3, surfaceY: -0.7, rampZ: outletZ + 16 };
  return {
    x,
    hatch: center.clone(),
    slabBottom,
    tube: { x0, x1, y0, y1, z0: shaft.z0, z1: outletZ },
    shaft,
    pockets,
    finalZ,
    outletZ,
    hand,
    handZone,
    reservoir,
    pumpRoomExit: V(x - 1.4, center.y + 0.05, hz),
    sumpEntry: V(x, shaft.surfaceY - 1.45, hz + 0.2),
  };
}

/** The swimmable volumes: sump, flooded tube (ceilinged), the pockets and the reservoir. */
export function culvertWater(L: CulvertLayout): SwimmingPool[] {
  const t = L.tube;
  const dark = { deep: 0x05100f, shallow: 0x0d2524, sky: 0x31403e };
  const blackFog = { color: 0x0a1514, density: 0.24 };
  const out = [
    SwimmingPool.box(V(t.x0, t.y0, L.shaft.z0), V(t.x1, L.shaft.surfaceY, L.shaft.z1), { tag: "culvert:sump", colors: dark, fog: blackFog }),
    SwimmingPool.box(V(t.x0, t.y0, L.shaft.z1), V(t.x1, t.y1, t.z1 + 0.6), { tag: "culvert:tube", ceiling: true, fog: blackFog }),
  ];
  for (const p of L.pockets) out.push(SwimmingPool.box(p.min, p.max, { tag: `culvert:pocket:${p.index}`, colors: dark, fog: blackFog }));
  const r = L.reservoir;
  out.push(
    SwimmingPool.box(V(r.x0, r.floorY, r.z0), V(r.x1, r.surfaceY, r.z1), {
      tag: "reservoir",
      colors: { deep: 0x15231f, shallow: 0x3c5650, sky: 0xa9b4b4 },
      fog: { color: 0x1c2a27, density: 0.13 },
    }),
  );
  return out;
}

export interface CulvertText {
  /** Painted on the sump room wall beside the hatch. */
  sumpSign?: string;
  /** Stencilled on the outfall headwall (reservoir side). */
  outfallSign?: string;
}

/** Static geometry. Call from a story feature's buildStatic (world frame, before finalize). */
export function buildCulvert(b: StaticBuilder, L: CulvertLayout, text: CulvertText = {}): void {
  const prev = b.chunkName;
  // Pump room: the hatch sits in Maintenance's interior batches.
  b.setChunk("maintenance", true);
  buildHatch(b, L, text);
  b.setChunk("culvert", true);
  buildShaftAndTube(b, L);
  for (const p of L.pockets) buildPocket(b, L, p);
  buildRack(b, L);
  b.setChunk("water", false);
  buildReservoir(b, L, text);
  b.setChunk(prev, false);
}

const concrete = (color: number) => ({ mat: "concrete" as const, color });

function buildHatch(b: StaticBuilder, L: CulvertLayout, text: CulvertText): void {
  const h = L.hatch;
  const y = h.y;
  // Steel frame flush on the slab, lid hinged open against the north side.
  for (const s of [-1, 1]) {
    b.box(V(h.x + s * 0.66, y + 0.02, h.z), V(0.12, 0.04, 1.44), { mat: "steel", color: 0x59605a, collide: false });
    b.box(V(h.x, y + 0.02, h.z + s * 0.66), V(1.2, 0.04, 0.12), { mat: "steel", color: 0x59605a, collide: false });
  }
  const lid = new Quaternion().setFromAxisAngle(V(1, 0, 0), -1.35);
  b.box(V(h.x, y + 0.62, h.z - 0.86), V(1.24, 0.05, 1.24), { mat: "metal", color: 0x4c5650, quat: lid, collide: false });
  // Sump pump, riser pipe and hazard plate.
  b.cylinder(V(h.x + 1.45, y + 0.45, h.z - 0.3), 0.32, 0.9, { mat: "metal", color: 0x3f5a52, collide: true });
  b.cylinder(V(h.x + 1.45, y + 1.4, h.z - 0.3), 0.07, 1.0, { mat: "steel", color: 0x7d847e });
  b.bar(V(h.x + 1.45, y + 0.6, h.z - 0.3), V(h.x + 0.45, y + 0.05, h.z - 0.3), 0.12, { mat: "steel", color: 0x6d756f });
  b.box(V(h.x, y + 0.004, h.z + 1.05), V(1.4, 0.008, 0.5), { mat: "hazard", collide: false, shadow: false });
  if (text.sumpSign) b.sign(text.sumpSign, V(h.x, y + 1.9, L.hatch.z + 3.86), Math.PI, 0xe0c25e, 0.0026);
}

function buildShaftAndTube(b: StaticBuilder, L: CulvertLayout): void {
  const t = L.tube;
  const top = L.slabBottom;
  const zs = t.z0 - WALL;
  const wallColor = 0x4d554e;
  // Floor (silted) from the shaft's north wall to the outfall.
  b.box(V(L.x, t.y0 - 0.15, (zs + t.z1) / 2), V(TUBE_WIDTH + 2 * WALL, 0.3, t.z1 - zs), concrete(0x394036));
  // Shaft: full-height walls up to the B1 slab, north wall and the header over the tube mouth.
  const shaftLen = L.shaft.z1 - zs;
  for (const s of [-1, 1]) b.box(V(L.x + s * (TUBE_WIDTH / 2 + WALL / 2), (t.y0 - 0.3 + top) / 2, zs + shaftLen / 2), V(WALL, top - t.y0 + 0.3, shaftLen), concrete(wallColor));
  b.box(V(L.x, (t.y0 - 0.3 + top) / 2, zs + WALL / 2), V(TUBE_WIDTH, top - t.y0 + 0.3, WALL), concrete(wallColor));
  b.box(V(L.x, (t.y1 + top) / 2, L.shaft.z1 + WALL / 2), V(TUBE_WIDTH, top - t.y1, WALL), concrete(wallColor));
  // Hatch seen from below: frame and the lit room through it.
  for (const s of [-1, 1]) {
    b.box(V(L.hatch.x + s * 0.6, top - 0.04, L.hatch.z), V(0.12, 0.08, 1.32), { mat: "steel", color: 0x59605a, collide: false });
    b.box(V(L.hatch.x, top - 0.04, L.hatch.z + s * 0.6), V(1.08, 0.08, 0.12), { mat: "steel", color: 0x59605a, collide: false });
  }
  b.box(V(L.hatch.x, top - 0.012, L.hatch.z), V(1.08, 0.01, 1.08), { mat: "paper", color: 0x8f8a7c, collide: false, shadow: false });
  // Ladder on the shaft's north wall.
  const lz = t.z0 + 0.09;
  for (const s of [-0.24, 0.24]) b.box(V(L.x + s, (t.y0 + top) / 2, lz), V(0.05, top - t.y0, 0.06), { mat: "steel", color: 0x7a817b, collide: false });
  for (let y = t.y0 + 0.3; y < top - 0.1; y += 0.3) b.box(V(L.x, y, lz + 0.03), V(0.48, 0.035, 0.035), { mat: "steel", color: 0x8d948e, collide: false, shadow: false });
  // Tube walls and ceiling (with pocket openings) to the outfall.
  const tubeStart = L.shaft.z1 + WALL;
  const len = t.z1 - L.shaft.z1;
  for (const s of [-1, 1]) b.box(V(L.x + s * (TUBE_WIDTH / 2 + WALL / 2), (t.y0 - 0.3 + t.y1 + WALL) / 2, L.shaft.z1 + len / 2), V(WALL, t.y1 - t.y0 + 0.3 + WALL, len), concrete(wallColor));
  const cuts = L.pockets.map((p) => [p.min.z, p.max.z, p] as const).sort((a, c) => a[0] - c[0]);
  let z = tubeStart;
  const ceiling = (za: number, zb: number, xa = t.x0, xb = t.x1) => {
    if (zb - za > 0.001 && xb - xa > 0.001) b.box(V((xa + xb) / 2, t.y1 + WALL / 2, (za + zb) / 2), V(xb - xa, WALL, zb - za), concrete(0x444b45));
  };
  for (const [za, zb, p] of cuts) {
    ceiling(z, za);
    if (p.side < 0) ceiling(za, zb, p.max.x, t.x1);
    else ceiling(za, zb, t.x0, p.min.x);
    z = zb;
  }
  ceiling(z, t.z1);
  // Ribs every 3 m and a silt line so swimming reads as motion in the dark.
  for (let rz = tubeStart + 1.5; rz < t.z1 - 0.5; rz += 3) {
    for (const s of [-1, 1]) b.box(V(L.x + s * (TUBE_WIDTH / 2 - 0.04), (t.y0 + t.y1) / 2, rz), V(0.08, TUBE_HEIGHT, 0.18), { mat: "concrete", color: 0x59615a, collide: false, shadow: false });
  }
  b.box(V(L.x, t.y0 + 0.02, (tubeStart + t.z1) / 2), V(TUBE_WIDTH - 0.6, 0.04, t.z1 - tubeStart), { mat: "gravel", color: 0x2f342b, collide: false, shadow: false });
  // Faint grey from the hatch above the sump.
  b.lightPoint(V(L.hatch.x, top - 0.3, L.hatch.z), 0xbfc4b6, 1.6, 4.5, false);
}

function buildPocket(b: StaticBuilder, L: CulvertLayout, p: PocketLayout): void {
  const t = L.tube;
  const top = t.y1 + POCKET.height;
  const w = 0.2;
  const color = 0x535a52;
  const midY = (t.y1 + top) / 2;
  const h = top - t.y1;
  const xw = p.max.x - p.min.x;
  const zl = p.max.z - p.min.z;
  for (const s of [-1, 1]) {
    b.box(V(p.center.x, midY, p.center.z + s * (zl / 2 + w / 2)), V(xw + 2 * w, h, w), concrete(color));
    b.box(V(p.center.x + s * (xw / 2 + w / 2), midY, p.center.z), V(w, h, zl), concrete(color));
  }
  b.box(V(p.center.x, top + w / 2, p.center.z), V(xw + 2 * w, w, zl + 2 * w), concrete(color));
  // A rusted vent in the roof: where the air (and a little grey light) seeps in.
  for (let i = -2; i <= 2; i++) b.box(V(p.center.x + i * 0.12, top - 0.03, p.center.z), V(0.03, 0.04, 0.5), { mat: "iron", color: 0x5b4a3c, collide: false, shadow: false });
  b.lightPoint(V(p.center.x, top - 0.35, p.center.z), 0x9db4c4, 1.1, 4.2, false);
}

function buildRack(b: StaticBuilder, L: CulvertLayout): void {
  const t = L.tube;
  const z = t.z1 - 0.12;
  const h = t.y1 - t.y0;
  const steel = { mat: "iron" as const, color: 0x5d4b3d };
  for (let x = t.x0 + 0.13; x < t.x1 - 0.05; x += 0.24) {
    if (Math.abs(x - L.x) < RACK_GAP / 2) {
      // Rusted through: stubs top and bottom, and one bar bent aside.
      b.box(V(x, t.y1 - 0.18, z), V(0.05, 0.36, 0.05), { ...steel, collide: false });
      b.box(V(x, t.y0 + 0.12, z), V(0.05, 0.24, 0.05), { ...steel, collide: false });
      continue;
    }
    b.box(V(x, (t.y0 + t.y1) / 2, z), V(0.05, h, 0.05), steel);
  }
  for (const y of [t.y0 + 0.06, t.y1 - 0.06]) b.box(V(L.x, y, z), V(TUBE_WIDTH, 0.08, 0.08), { ...steel, collide: false });
  b.bar(V(L.x + RACK_GAP / 2 - 0.05, t.y1 - 0.3, z), V(L.x + RACK_GAP / 2 + 0.1, t.y0 + 0.5, z + 0.5), 0.05, { ...steel, collide: false });
}

function buildReservoir(b: StaticBuilder, L: CulvertLayout, text: CulvertText): void {
  const r = L.reservoir;
  const t = L.tube;
  const rim = 0.25;
  const bank = 0x6c6f66;
  const ext = (color: number) => ({ mat: "concrete_ext" as const, color });
  const W = 0.4;
  // Headwall with the outfall mouth.
  const hz = r.z0 - W / 2;
  const hwTop = 1.1;
  const left = t.x0 - (r.x0 - W);
  const right = r.x1 + W - t.x1;
  b.box(V(r.x0 - W + left / 2, (r.floorY - 0.3 + hwTop) / 2, hz), V(left, hwTop - r.floorY + 0.3, W), ext(bank));
  b.box(V(t.x1 + right / 2, (r.floorY - 0.3 + hwTop) / 2, hz), V(right, hwTop - r.floorY + 0.3, W), ext(bank));
  b.box(V(L.x, (t.y1 + hwTop) / 2, hz), V(TUBE_WIDTH, hwTop - t.y1, W), ext(bank));
  b.box(V(L.x, (r.floorY - 0.3 + t.y0) / 2, hz), V(TUBE_WIDTH, t.y0 - r.floorY + 0.3, W), ext(bank));
  b.box(V(L.x, hwTop + 0.06, hz), V(r.x1 - r.x0 + 2 * W, 0.12, W + 0.1), ext(0x5e6159));
  // Outfall mouth surround on the reservoir face.
  for (const s of [-1, 1]) b.box(V(L.x + s * (TUBE_WIDTH / 2 + 0.1), (t.y0 + t.y1) / 2, r.z0 + 0.06), V(0.2, TUBE_HEIGHT + 0.4, 0.12), ext(0x575a52));
  b.box(V(L.x, t.y1 + 0.1, r.z0 + 0.06), V(TUBE_WIDTH + 0.4, 0.2, 0.12), ext(0x575a52));
  if (text.outfallSign) b.sign(text.outfallSign, V(L.x, 0.62, r.z0 + 0.02), 0, 0xd8d2b4, 0.0034);
  // Floor, side banks and the south slope out onto the grass.
  b.box(V((r.x0 + r.x1) / 2, r.floorY - 0.15, (r.z0 + r.rampZ) / 2), V(r.x1 - r.x0, 0.3, r.rampZ - r.z0), { mat: "gravel", color: 0x3f473d });
  for (const s of [-1, 1]) {
    const x = s < 0 ? r.x0 - W / 2 : r.x1 + W / 2;
    b.box(V(x, (r.floorY - 0.3 + rim) / 2, (r.z0 + r.z1) / 2), V(W, rim - r.floorY + 0.3, r.z1 - r.z0), ext(bank));
  }
  const top = OUTER_GRASS.y1;
  b.ramp([
    V(r.x0, r.floorY, r.rampZ), V(r.x1, r.floorY, r.rampZ),
    V(r.x0, top, r.z1), V(r.x1, top, r.z1),
    V(r.x0, r.floorY, r.z1), V(r.x1, r.floorY, r.z1),
  ]);
  const dz = r.z1 - r.rampZ;
  const dy = top - r.floorY;
  const slope = new Quaternion().setFromAxisAngle(V(1, 0, 0), -Math.atan2(dy, dz));
  b.box(V((r.x0 + r.x1) / 2, (r.floorY + top) / 2 - 0.12, (r.rampZ + r.z1) / 2), V(r.x1 - r.x0, 0.24, Math.hypot(dy, dz)), { mat: "gravel", color: 0x55604c, quat: slope, collide: false });
  // A few rip-rap blocks along the waterline of the banks.
  for (let i = 0; i < 14; i++) {
    const s = i % 2 ? 1 : -1;
    const z = r.z0 + 2 + ((i * 7.3) % (r.z1 - r.z0 - 6));
    const x = s < 0 ? r.x0 + 0.35 : r.x1 - 0.35;
    b.box(V(x, r.surfaceY + 0.05, z), V(0.7, 0.5, 0.9 + (i % 3) * 0.3), { mat: "concrete_ext", color: 0x7a7c72, yaw: i * 0.7, collide: false });
  }
  // Walkable ground around the basin (the outer grass is visual only) and a boundary.
  const hole: Rect = { x: r.x0 - W, z: r.z0 - W, w: r.x1 - r.x0 + 2 * W, d: r.z1 - r.z0 + W };
  const apron: Rect = { x: r.x0 - 10, z: PERIMETER_Z + 0.3, w: r.x1 - r.x0 + 20, d: r.z1 + 10 - PERIMETER_Z - 0.3 };
  for (const a of subtract([apron], hole)) b.blocker(V(a.x + a.w / 2, -0.25, a.z + a.d / 2), V(a.w, 0.4, a.d));
  const fence = 3;
  b.blocker(V(apron.x - 0.25, fence / 2, apron.z + apron.d / 2), V(0.5, fence, apron.d));
  b.blocker(V(apron.x + apron.w + 0.25, fence / 2, apron.z + apron.d / 2), V(0.5, fence, apron.d));
  b.blocker(V(apron.x + apron.w / 2, fence / 2, apron.z + apron.d + 0.25), V(apron.w + 1, fence, 0.5));
  // Replacement outer grass with the basin cut out (see punchOuterGrass).
  const outer: Rect = { x: OUTER_GRASS.x0, z: OUTER_GRASS.z0, w: OUTER_GRASS.x1 - OUTER_GRASS.x0, d: OUTER_GRASS.z1 - OUTER_GRASS.z0 };
  const gy = (OUTER_GRASS.y0 + OUTER_GRASS.y1) / 2;
  for (const g of subtract([outer], hole)) {
    b.box(V(g.x + g.w / 2, gy, g.z + g.d / 2), V(g.w, OUTER_GRASS.y1 - OUTER_GRASS.y0, g.d), { mat: "grass", color: OUTER_GRASS_COLOR, collide: false, occlude: false, shadow: false });
  }
}

/**
 * The far grass beyond the south wall is one visual slab (ground.ts), which
 * would cut straight through the reservoir. buildReservoir rebuilds it around
 * the basin; this removes the original box's triangles from the merged static
 * batch (matched exactly on its eight corners, so nothing else is touched).
 * Returns the number of triangles removed (12 when found).
 */
export function punchOuterGrass(root: Object3D): number {
  const g = OUTER_GRASS;
  const near = (v: number, a: number, c: number) => Math.abs(v - a) < 1e-3 || Math.abs(v - c) < 1e-3;
  let removed = 0;
  root.traverse((o) => {
    const mesh = o as Mesh;
    if (!mesh.isMesh || !mesh.name.includes("|grass|")) return;
    const geo = mesh.geometry;
    const pos = geo.getAttribute("position") as BufferAttribute;
    const index = geo.getIndex();
    if (!index) return;
    const onCorner = (i: number) => near(pos.getX(i), g.x0, g.x1) && near(pos.getY(i), g.y0, g.y1) && near(pos.getZ(i), g.z0, g.z1);
    let changed = false;
    for (let t = 0; t < index.count; t += 3) {
      const a = index.getX(t);
      const b = index.getX(t + 1);
      const c = index.getX(t + 2);
      if (a === b && b === c) continue;
      if (onCorner(a) && onCorner(b) && onCorner(c)) {
        index.setX(t + 1, a);
        index.setX(t + 2, a);
        removed++;
        changed = true;
      }
    }
    if (changed) index.needsUpdate = true;
  });
  return removed;
}
