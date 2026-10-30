import type { StaticBuilder } from "../builder";
import type { MaterialKey } from "../../render/materials";
import { V } from "../props";

export interface ShellOpening {
  side: "north" | "south" | "east" | "west";
  offset: number;
  width: number;
  height: number;
  label?: string;
}

export interface ShellDef {
  title: string;
  width: number;
  height: number;
  depth: number;
  thickness: number;
  openings: ShellOpening[];
  wallMat?: MaterialKey;
  wallColor?: number;
  roofColor?: number;
  /** Rectangular roof hole (local x0, z0, x1, z1) glazed as a skylight. */
  skylight?: [number, number, number, number];
}

/**
 * Port of BuildingShellBase.create_shell_with_openings: collision-backed outer
 * walls with real openings, door frames, a roof slab and identification signs.
 * Adds exterior dressing the greybox lacked: plinth, parapet coping, downpipes,
 * window slits and sodium wall packs over each entrance.
 */
export function buildShell(b: StaticBuilder, def: ShellDef): void {
  const { width: w, height: h, depth: d, thickness: t } = def;
  const mat = def.wallMat ?? "concrete_ext";
  const color = def.wallColor ?? 0x8d8f86;
  const bySide: Record<string, ShellOpening[]> = { north: [], south: [], west: [], east: [] };
  for (const o of def.openings) bySide[o.side].push(o);

  const wallSide = (length: number, fixed: number, alongX: boolean, openings: ShellOpening[]) => {
    const sorted = [...openings].sort((a, c) => a.offset - c.offset);
    let cursor = -length / 2;
    const piece = (s: number, e: number, y0: number, y1: number) => {
      const c = (s + e) / 2;
      const hh = y1 - y0;
      const center = alongX ? V(c, y0 + hh / 2, fixed) : V(fixed, y0 + hh / 2, c);
      const size = alongX ? V(e - s, hh, t) : V(t, hh, e - s);
      b.box(center, size, { mat, color });
    };
    for (const o of sorted) {
      const s = Math.max(-length / 2, o.offset - o.width / 2);
      const e = Math.min(length / 2, o.offset + o.width / 2);
      if (s - cursor > 0.01) piece(cursor, s, 0, h);
      if (h - o.height > 0.01) piece(s, e, o.height, h);
      cursor = e;
    }
    if (length / 2 - cursor > 0.01) piece(cursor, length / 2, 0, h);
  };
  wallSide(w, -d / 2 + t / 2, true, bySide.north);
  wallSide(w, d / 2 - t / 2, true, bySide.south);
  wallSide(d, -w / 2 + t / 2, false, bySide.west);
  wallSide(d, w / 2 - t / 2, false, bySide.east);

  // Roof slab (optionally with a glazed skylight opening) and parapet.
  const roofY = h + 0.15;
  const roofColor = def.roofColor ?? 0x4d524e;
  const rw = w + 0.6;
  const rd = d + 0.6;
  if (def.skylight) {
    const [x0, z0, x1, z1] = def.skylight;
    const slab = (cx0: number, cz0: number, cx1: number, cz1: number) =>
      b.box(V((cx0 + cx1) / 2, roofY, (cz0 + cz1) / 2), V(cx1 - cx0, 0.3, cz1 - cz0), { mat: "dark_ext", color: roofColor });
    slab(-rw / 2, -rd / 2, rw / 2, z0);
    slab(-rw / 2, z1, rw / 2, rd / 2);
    slab(-rw / 2, z0, x0, z1);
    slab(x1, z0, rw / 2, z1);
    // Glazing is non-shadowing; mullions and trusses give the light shafts structure.
    b.box(V((x0 + x1) / 2, roofY + 0.05, (z0 + z1) / 2), V(x1 - x0, 0.04, z1 - z0), { mat: "glass", collide: true, shadow: false, occlude: true });
    for (let x = x0; x <= x1 + 0.01; x += 2) {
      b.box(V(x, roofY - 0.05, (z0 + z1) / 2), V(0.12, 0.3, z1 - z0), { mat: "dark", color: 0x2f3431, collide: false });
    }
    for (const z of [z0 + (z1 - z0) / 3, z0 + (2 * (z1 - z0)) / 3]) {
      b.box(V((x0 + x1) / 2, roofY - 0.05, z), V(x1 - x0, 0.22, 0.1), { mat: "dark", color: 0x2f3431, collide: false });
    }
    for (let x = x0 + 4; x < x1; x += 8) {
      b.bar(V(x, h - 1.2, z0), V(x, h - 0.05, (z0 + z1) / 2), 0.14, { mat: "dark", color: 0x2a2e2b });
      b.bar(V(x, h - 1.2, z1), V(x, h - 0.05, (z0 + z1) / 2), 0.14, { mat: "dark", color: 0x2a2e2b });
      b.box(V(x, h - 1.2, (z0 + z1) / 2), V(0.12, 0.12, z1 - z0), { mat: "dark", color: 0x2a2e2b, collide: false });
    }
  } else {
    b.box(V(0, roofY, 0), V(rw, 0.3, rd), { mat: "dark_ext", color: roofColor });
  }
  const parapetH = 0.6;
  for (const [cx, cz, sx, sz] of [
    [0, -rd / 2 + 0.12, rw, 0.24], [0, rd / 2 - 0.12, rw, 0.24], [-rw / 2 + 0.12, 0, 0.24, rd], [rw / 2 - 0.12, 0, 0.24, rd],
  ]) {
    b.box(V(cx, roofY + 0.15 + parapetH / 2, cz), V(sx, parapetH, sz), { mat: "concrete_ext", color: 0x7f8279 });
    b.box(V(cx, roofY + 0.15 + parapetH + 0.03, cz), V(sx + 0.06, 0.06, sz + 0.06), { mat: "metal_ext", color: 0x5b605a, collide: false });
  }
  // Plinth band hides the slab edge and catches splash grime.
  for (const [cx, cz, sx, sz] of [[0, -d / 2 - 0.04, w + 0.16, 0.1], [0, d / 2 + 0.04, w + 0.16, 0.1], [-w / 2 - 0.04, 0, 0.1, d], [w / 2 + 0.04, 0, 0.1, d]]) {
    if (sx > sz) {
      for (const seg of segmentsAvoiding(-sx / 2, sx / 2, (cz < 0 ? bySide.north : bySide.south))) {
        b.box(V((seg[0] + seg[1]) / 2, 0.3, cz), V(seg[1] - seg[0], 0.6, sz), { mat: "concrete_ext", color: 0x6d6f68, collide: false });
      }
    } else {
      for (const seg of segmentsAvoiding(-sz / 2, sz / 2, (cx < 0 ? bySide.west : bySide.east))) {
        b.box(V(cx, 0.3, (seg[0] + seg[1]) / 2), V(sx, 0.6, seg[1] - seg[0]), { mat: "concrete_ext", color: 0x6d6f68, collide: false });
      }
    }
  }
  // Downpipes at the corners.
  for (const xs of [-1, 1]) for (const zs of [-1, 1]) {
    b.cylinder(V(xs * (w / 2 + 0.1), h / 2, zs * (d / 2 - 0.6)), 0.07, h + 0.3, { mat: "metal_ext", color: 0x4c524e });
  }
  // Narrow high window slits on long walls (dark wired glass, no transparency).
  const slits = (length: number, fixed: number, alongX: boolean, openings: ShellOpening[], out: number) => {
    const count = Math.floor(length / 6);
    for (let i = 0; i < count; i++) {
      const pos = -length / 2 + (i + 0.5) * (length / count);
      if (openings.some((o) => Math.abs(o.offset - pos) < o.width / 2 + 1.2)) continue;
      const y = Math.min(h - 1.4, 3.4);
      const center = alongX ? V(pos, y, fixed + out * 0.01) : V(fixed + out * 0.01, y, pos);
      const size = alongX ? V(0.5, 1.4, 0.05) : V(0.05, 1.4, 0.5);
      b.box(center, size, { mat: "glass", color: 0x223035, collide: false, shadow: false });
      const sill = alongX ? V(pos, y - 0.75, fixed + out * 0.06) : V(fixed + out * 0.06, y - 0.75, pos);
      b.box(sill, alongX ? V(0.7, 0.08, 0.14) : V(0.14, 0.08, 0.7), { mat: "concrete_ext", color: 0x7d7f77, collide: false });
    }
  };
  slits(w, -d / 2, true, bySide.north, -1);
  slits(w, d / 2, true, bySide.south, 1);
  slits(d, -w / 2, false, bySide.west, -1);
  slits(d, w / 2, false, bySide.east, 1);

  // Door frames, signage and sodium wall packs at each opening.
  for (const o of def.openings) {
    const alongX = o.side === "north" || o.side === "south";
    const out = o.side === "north" || o.side === "west" ? -1 : 1;
    const base = alongX ? V(o.offset, 0, out * d / 2) : V(out * w / 2, 0, o.offset);
    const yaw = o.side === "north" ? Math.PI : o.side === "south" ? 0 : o.side === "east" ? Math.PI / 2 : -Math.PI / 2;
    b.within(base, yaw, () => {
      const pw = 0.2;
      for (const s of [-1, 1]) b.box(V(s * (o.width / 2 + pw / 2), o.height / 2, 0), V(pw, o.height, t + 0.1), { mat: "metal_ext", color: 0x4f5650 });
      b.box(V(0, o.height + 0.15, 0), V(o.width + pw * 2, 0.3, t + 0.12), { mat: "metal_ext", color: 0x4f5650 });
      if (o.label) b.sign(o.label, V(0, o.height + 0.55, 0.12), 0, 0xe0d5a8, 0.0042);
      // Wall pack: dark housing + sodium lens; night-only light pool candidate.
      b.box(V(0, o.height + 1.05, 0.12), V(0.42, 0.26, 0.22), { mat: "dark_ext", color: 0x2b302d, collide: false });
      b.box(V(0, o.height + 0.94, 0.16), V(0.34, 0.04, 0.14), { mat: "emissive_night", collide: false, shadow: false });
      b.lightPoint(V(0, o.height + 0.7, 0.9), 0xff9a45, 14, 16, true);
      // Concrete apron outside the threshold.
      b.box(V(0, 0.02, 1.6), V(o.width + 1.6, 0.04, 3.2), { mat: "concrete_ext", color: 0x8a8b84, collide: false });
    });
  }
}

function segmentsAvoiding(lo: number, hi: number, openings: ShellOpening[]): [number, number][] {
  const cuts = openings.map((o) => [o.offset - o.width / 2 - 0.2, o.offset + o.width / 2 + 0.2] as [number, number]).sort((a, c) => a[0] - c[0]);
  const out: [number, number][] = [];
  let cursor = lo;
  for (const [a, c] of cuts) {
    if (a > cursor) out.push([cursor, a]);
    cursor = Math.max(cursor, c);
  }
  if (hi > cursor) out.push([cursor, hi]);
  return out;
}
