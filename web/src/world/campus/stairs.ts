import { Vector3 } from "three";
import type { StaticBuilder } from "../builder";
import { V } from "../props";

/**
 * Port of CampusStairFlight: smooth, lip-free convex ramp collision under
 * solid visual treads. Local +Z is ascent; origin is the bottom finished floor.
 */
export function stairFlight(b: StaticBuilder, run: number, rise: number, width: number, steps: number, color = 0x4a504c): void {
  const corners: Vector3[] = [];
  for (const x of [-width / 2, width / 2]) for (const end of [0, 1]) for (const th of [-0.14, 0]) corners.push(V(x, rise * end + th, run * end));
  b.ramp(corners);
  const sd = run / steps;
  const sr = rise / steps;
  for (let i = 0; i < steps; i++) {
    const top = (i + 0.5) * sr;
    const h = Math.min(top + 0.02, sr + 0.12);
    b.box(V(0, top - h / 2, (i + 0.5) * sd), V(width - 0.02, h, sd + 0.015), { mat: "concrete", color, collide: false });
    // Worn nosing strip on each tread edge.
    b.box(V(0, top - 0.01, i * sd + 0.04), V(width - 0.1, 0.025, 0.05), { mat: "steel", color: 0x7b807a, collide: false, shadow: false });
  }
  for (const side of [-1, 1]) {
    const x = side * (width / 2 - 0.065);
    b.bar(V(x, -0.09, 0), V(x, rise - 0.09, run), 0.18, { mat: "concrete", color: 0x3a3f3c });
    b.railing(V(x, 0, 0), V(x, rise, run), 0x626963);
  }
}

export interface Entrance {
  side: "n" | "s" | "e" | "w";
  offset: number;
  width?: number;
}

export interface SwitchbackOptions {
  width: number;
  depth: number;
  floorRise?: number;
  lower: Entrance;
  upper: Entrance;
  secondaryUpper?: Entrance[];
  buildLowerLanding?: boolean;
  continuesAbove?: boolean;
}

const AISLE = 1.2;
const LANDING = 1.3;
const SLAB = 0.16;

/**
 * Port of CampusSwitchbackStair: two flights around an intermediate landing,
 * a landing ring with bypass aisles and perimeter rails with entrance gaps.
 * Origin is the lower finished floor at the footprint centre.
 */
export function switchbackStair(b: StaticBuilder, o: SwitchbackOptions): void {
  const rise = o.floorRise ?? 4;
  let layoutYaw = 0;
  if (o.lower.side === "n") layoutYaw = Math.PI;
  else if (o.lower.side === "e") layoutYaw = Math.PI / 2;
  else if (o.lower.side === "w") layoutYaw = -Math.PI / 2;
  const swap = o.lower.side === "e" || o.lower.side === "w";
  const iw = swap ? o.depth : o.width;
  const id = swap ? o.width : o.depth;
  const runEnd = id / 2 - LANDING;
  const flightWidth = (iw - AISLE * 2 - 0.3) / 2;
  const flightX = flightWidth / 2 + 0.15;
  const mid = Math.min(1.2, rise * 0.3);
  const color = 0x454b46;

  b.within(V(0, 0, 0), layoutYaw, () => {
    const ring = (y: number) => {
      for (const side of [-1, 1]) {
        b.box(V(0, y - SLAB / 2, side * (id / 2 - LANDING / 2)), V(iw, SLAB, LANDING), { mat: "concrete", color });
        b.box(V(side * (iw / 2 - AISLE / 2), y - SLAB / 2, 0), V(AISLE, SLAB, runEnd * 2), { mat: "concrete", color });
      }
    };
    if (o.buildLowerLanding ?? true) {
      ring(0);
      b.box(V(0, -SLAB / 2, 0), V(iw - AISLE * 2, SLAB, runEnd * 2), { mat: "concrete", color });
    }
    ring(rise);
    b.box(V(0, mid - SLAB / 2, -id / 2 + LANDING / 2), V(iw - 2 * AISLE, SLAB, LANDING), { mat: "concrete", color: 0x535952 });
    b.within(V(-flightX, 0, runEnd), Math.PI, () => stairFlight(b, runEnd * 2, mid, flightWidth, Math.max(8, Math.ceil(mid / 0.175))));
    b.within(V(flightX, mid, -runEnd), 0, () => stairFlight(b, runEnd * 2, rise - mid, flightWidth, Math.max(8, Math.ceil((rise - mid) / 0.175))));

    const rail = 0x636b65;
    const edgeX = iw / 2 - AISLE;
    for (const side of [-1, 1]) {
      b.railing(V(side * edgeX, rise, -runEnd), V(side * edgeX, rise, runEnd), rail);
      b.railing(V(side * edgeX, mid, -id / 2), V(side * edgeX, mid, -runEnd), rail);
    }
    b.railing(V(-edgeX, rise, -runEnd), V(edgeX, rise, -runEnd), rail);
    if (o.continuesAbove) {
      b.railing(V(-edgeX, rise, runEnd), V(-flightX - flightWidth / 2 + 0.065, rise, runEnd), rail);
      b.railing(V(-flightX + flightWidth / 2 - 0.065, rise, runEnd), V(flightX - flightWidth / 2 + 0.065, rise, runEnd), rail);
    } else {
      b.railing(V(-edgeX, rise, runEnd), V(flightX - flightWidth / 2 + 0.065, rise, runEnd), rail);
    }
    b.railing(V(flightX + flightWidth / 2 - 0.065, rise, runEnd), V(edgeX, rise, runEnd), rail);

    // Upper perimeter rails, open only at the declared upper entrances.
    const toLayout = (p: Vector3) => {
      // Inverse of the layout yaw.
      const c = Math.cos(-layoutYaw);
      const s = Math.sin(-layoutYaw);
      return V(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
    };
    const entrances = [o.upper, ...(o.secondaryUpper ?? [])].map((e) => ({
      point: toLayout(entrancePoint(o.width, o.depth, e, rise)),
      width: e.width ?? 1.6,
    }));
    for (const sideName of ["n", "s", "e", "w"] as const) {
      const horizontal = sideName === "n" || sideName === "s";
      const edge = horizontal ? id / 2 : iw / 2;
      const span = horizontal ? iw / 2 : id / 2;
      const fixed = sideName === "n" || sideName === "w" ? -edge : edge;
      const openings: [number, number][] = [];
      for (const e of entrances) {
        const ef = horizontal ? e.point.z : e.point.x;
        if (Math.abs(ef - fixed) > 0.05) continue;
        const off = horizontal ? e.point.x : e.point.z;
        const half = e.width / 2 + 0.05;
        openings.push([off - half, off + half]);
      }
      openings.sort((a, c) => a[0] - c[0]);
      const intervals: [number, number][] = [];
      let cursor = -span;
      for (const [lo, hi] of openings) {
        intervals.push([cursor, Math.max(cursor, lo)]);
        cursor = Math.max(cursor, hi);
      }
      intervals.push([cursor, span]);
      for (const [lo, hi] of intervals) {
        if (hi - lo < 0.02) continue;
        const a = horizontal ? V(lo, rise, fixed) : V(fixed, rise, lo);
        const c = horizontal ? V(hi, rise, fixed) : V(fixed, rise, hi);
        b.railing(a, c, rail);
      }
    }
    const steel = 0x333b35;
    for (const xs of [-1, 1]) {
      for (const zs of [-1, 1]) b.box(V(xs * (iw / 2 - 0.12), rise / 2, zs * (id / 2 - 0.12)), V(0.18, rise, 0.18), { mat: "dark", color: steel });
      b.box(V(xs * (iw / 2 - AISLE - 0.12), mid / 2, -id / 2 + 0.12), V(0.18, mid, 0.18), { mat: "dark", color: steel });
    }
  });
}

function entrancePoint(width: number, depth: number, e: Entrance, y: number): Vector3 {
  const w = e.width ?? 1.6;
  const margin = w / 2 + 0.1;
  const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));
  if (e.side === "n" || e.side === "s") {
    return V(clamp(e.offset, -width / 2 + margin, width / 2 - margin), y, e.side === "n" ? -depth / 2 : depth / 2);
  }
  return V(e.side === "w" ? -width / 2 : width / 2, y, clamp(e.offset, -depth / 2 + margin, depth / 2 - margin));
}
