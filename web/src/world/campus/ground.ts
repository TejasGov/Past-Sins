import type { StaticBuilder } from "../builder";
import { V } from "../props";

export interface Rect {
  x: number;
  z: number;
  w: number;
  d: number;
}

function intersects(a: Rect, b: Rect): boolean {
  return a.x < b.x + b.w && b.x < a.x + a.w && a.z < b.z + b.d && b.z < a.z + a.d;
}

/** Splits `regions` around `hole` (port of _create_excavated_ground's rect logic). */
export function subtract(regions: Rect[], hole: Rect): Rect[] {
  const out: Rect[] = [];
  for (const r of regions) {
    if (!intersects(r, hole)) {
      out.push(r);
      continue;
    }
    const ox = Math.max(r.x, hole.x);
    const oz = Math.max(r.z, hole.z);
    const ox2 = Math.min(r.x + r.w, hole.x + hole.w);
    const oz2 = Math.min(r.z + r.d, hole.z + hole.d);
    const parts: Rect[] = [
      { x: r.x, z: r.z, w: r.w, d: oz - r.z },
      { x: r.x, z: oz2, w: r.w, d: r.z + r.d - oz2 },
      { x: r.x, z: oz, w: ox - r.x, d: oz2 - oz },
      { x: ox2, z: oz, w: r.x + r.w - ox2, d: oz2 - oz },
    ];
    for (const p of parts) if (p.w > 0.001 && p.d > 0.001) out.push(p);
  }
  return out;
}

/**
 * Campus terrain (PrisonCampusPrototype._create_excavated_ground): solid
 * 156 × 188 m ground cut at the basement stair shafts and the pool basin; its
 * grass surface is also removed under finished building floors so the two
 * never z-fight.
 */
export function buildGround(b: StaticBuilder, holes: Rect[], buildingFloors: Rect[]): void {
  let regions: Rect[] = [{ x: -78, z: -94, w: 156, d: 188 }];
  for (const h of holes) regions = subtract(regions, h);
  for (const r of regions) b.blocker(V(r.x + r.w / 2, -0.2, r.z + r.d / 2), V(r.w, 0.4, r.d), true);
  let visual = regions.slice();
  for (const f of buildingFloors) visual = subtract(visual, f);
  for (const r of visual) {
    b.box(V(r.x + r.w / 2, -0.2, r.z + r.d / 2), V(r.w, 0.4, r.d), { mat: "grass", color: 0x8a9478, collide: false, occlude: false, shadow: false });
  }
  // Wide grass beyond the wall so the fogged horizon is not a void.
  for (const [x, z, w, d] of [[-260, -300, 182, 600], [78, -300, 182, 600], [-78, -300, 156, 206], [-78, 94, 156, 206]]) {
    b.box(V(x + w / 2, -0.25, z + d / 2), V(w, 0.4, d), { mat: "grass", color: 0x7a8468, collide: false, occlude: false, shadow: false });
  }
}
