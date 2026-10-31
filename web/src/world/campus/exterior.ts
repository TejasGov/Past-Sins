import { Quaternion, Vector3 } from "three";
import type { StaticBuilder } from "../builder";
import { V, bench, cctvCamera, deg, place, trashBin } from "../props";

const qz90 = new Quaternion().setFromAxisAngle(new Vector3(0, 0, 1), Math.PI / 2);
const qx90 = new Quaternion().setFromAxisAngle(new Vector3(1, 0, 0), Math.PI / 2);

/** CampusPerimeter: 156 × 188 m wall, two sally ports, fence/wire tops. */
export function buildPerimeter(b: StaticBuilder): void {
  const hw = 78;
  const hd = 94;
  const h = 5.2;
  const t = 0.6;
  const wall = (c: Vector3, s: Vector3) => {
    b.box(c, s, { mat: "concrete_ext", color: 0x8e8f87 });
    const alongX = s.x > s.z;
    const len = alongX ? s.x : s.z;
    b.box(V(c.x, h + 0.08, c.z), alongX ? V(len, 0.16, t + 0.2) : V(t + 0.2, 0.16, len), { mat: "concrete_ext", color: 0x777870, collide: false });
    b.cylinder(V(c.x, h + 1.05, c.z), 0.3, len, { mat: "iron", color: 0x6b6158, collide: false, quat: alongX ? qz90 : qx90 });
  };
  wall(V(-hw, h / 2, 0), V(t, h, hd * 2));
  wall(V(hw, h / 2, 0), V(t, h, hd * 2));
  const ns = (hw * 2 - 10) / 2;
  wall(V(-hw + ns / 2, h / 2, -hd), V(ns, h, t));
  wall(V(hw - ns / 2, h / 2, -hd), V(ns, h, t));
  const ss = (hw * 2 - 12) / 2;
  wall(V(-hw + ss / 2, h / 2, hd), V(ss, h, t));
  wall(V(hw - ss / 2, h / 2, hd), V(ss, h, t));
  // Nav export: everything inside the wall that isn't under a roof.
  b.navRegion(-hw + 1, -hd + 1, hw - 1, hd - 1, 0, { spacing: 6, exterior: true, tag: "exterior" });
  sallyPort(b, V(0, 0, -hd), V(10, h, 8), "NORTH SERVICE SALLY PORT");
  sallyPort(b, V(0, 0, hd), V(12, h, 10), "MAIN SECURE VEHICLE SALLY PORT");
  // Fence posts above the wall.
  for (let x = -hw; x <= hw; x += 6) for (const z of [-hd, hd]) b.box(V(x, h + 0.5, z), V(0.08, 1.0, 0.08), { mat: "metal_ext", collide: false, shadow: false });
  for (let z = -hd; z <= hd; z += 6) for (const x of [-hw, hw]) b.box(V(x, h + 0.5, z), V(0.08, 1.0, 0.08), { mat: "metal_ext", collide: false, shadow: false });
  // Perimeter sodium floods on the inside face every 24 m.
  for (let x = -hw + 12; x < hw; x += 24) for (const z of [-hd + 0.4, hd - 0.4]) perimeterLamp(b, V(x, 0, z), z < 0 ? 0 : Math.PI);
  for (let z = -hd + 12; z < hd; z += 24) for (const x of [-hw + 0.4, hw - 0.4]) perimeterLamp(b, V(x, 0, z), x < 0 ? Math.PI / 2 : -Math.PI / 2);
}

function perimeterLamp(b: StaticBuilder, at: Vector3, yaw: number): void {
  b.within(at, yaw, () => {
    b.box(V(0, 4.9, 0.25), V(0.08, 0.08, 0.5), { mat: "metal_ext", collide: false });
    b.box(V(0, 4.8, 0.5), V(0.5, 0.18, 0.3), { mat: "dark_ext", collide: false });
    b.box(V(0, 4.7, 0.5), V(0.42, 0.03, 0.22), { mat: "emissive_night", collide: false, shadow: false });
    b.lightPoint(V(0, 4.3, 1.4), 0xff8f3a, 22, 22, true);
  });
}

function sallyPort(b: StaticBuilder, center: Vector3, size: Vector3, label: string): void {
  b.within(center, 0, () => {
    const pier = 1.2;
    for (const s of [-1, 1]) b.box(V(s * (size.x / 2 - pier / 2), size.y / 2, 0), V(pier, size.y, size.z), { mat: "concrete_ext", color: 0x8b8c84 });
    b.box(V(0, size.y - 0.5, 0), V(size.x, 1.0, size.z), { mat: "concrete_ext", color: 0x8b8c84 });
    const gw = size.x - pier * 2;
    for (const z of [-size.z * 0.45, size.z * 0.45]) {
      b.box(V(0, (size.y - 1) / 2, z), V(gw, size.y - 1, 0.25), { mat: "dark_ext", color: 0x2e3431 });
      for (let x = -gw / 2 + 0.4; x < gw / 2; x += 0.8) b.box(V(x, (size.y - 1) / 2, z + 0.15), V(0.12, size.y - 1.2, 0.06), { mat: "metal_ext", color: 0x3b423e, collide: false });
      b.box(V(0, size.y - 1.6, z + 0.15), V(gw * 0.8, 0.5, 0.04), { mat: "hazard", collide: false, shadow: false });
    }
    b.box(V(size.x / 2 + 1.5, 1.5, 0), V(2.2, 3.0, 3.0), { mat: "metal_ext", color: 0x5d665f });
    b.box(V(size.x / 2 + 1.5, 1.7, -1.51), V(1.6, 0.8, 0.04), { mat: "glass", collide: false, shadow: false });
    b.sign(label, V(0, size.y - 0.5, size.z / 2 + 0.02), 0, 0xe0d5a8, 0.005);
    b.sign(label, V(0, size.y - 0.5, -size.z / 2 - 0.02), Math.PI, 0xe0d5a8, 0.005);
  });
}

/** CentralYardGrounds + CampusRecreationAnnex (yard dressing, pool deck, gates). */
export function buildYard(b: StaticBuilder): void {
  b.box(V(0, 0.005, 0), V(52, 0.01, 54), { mat: "concrete_ext", color: 0x6c6d67, collide: false, shadow: false });
  b.box(V(-14, 0.012, 0), V(16, 0.01, 24), { mat: "court", color: 0x7d7a70, collide: false, shadow: false });
  b.box(V(14, 0.012, -12), V(16, 0.01, 16), { mat: "concrete_ext", color: 0x65665f, collide: false, shadow: false });
  b.box(V(14, 0.012, 12), V(16, 0.01, 16), { mat: "grass", color: 0x7f8a64, collide: false, shadow: false });
  for (const [c, s] of [[V(0, 0.02, -23.8), V(46, 0.012, 2.5)], [V(0, 0.02, 23.8), V(46, 0.012, 2.5)], [V(-22.5, 0.02, 0), V(2.5, 0.012, 50)], [V(22.5, 0.02, 0), V(2.5, 0.012, 50)]] as const) {
    b.box(c, s, { mat: "rubber", color: 0x8a4c3c, collide: false, shadow: false });
  }
  // Court lines.
  const line = 0xdedcc7;
  for (const z of [-11, 0, 11]) b.box(V(-14, 0.019, z), V(14, 0.004, 0.08), { mat: "paper", color: line, collide: false, shadow: false });
  for (const x of [-21, -7]) b.box(V(x, 0.019, 0), V(0.08, 0.004, 22), { mat: "paper", color: line, collide: false, shadow: false });
  for (let i = 0; i < 24; i++) {
    const a0 = (i / 24) * Math.PI * 2;
    const a1 = ((i + 1) / 24) * Math.PI * 2;
    const p0 = V(-14 + Math.cos(a0) * 1.8, 0.019, Math.sin(a0) * 1.8);
    const p1 = V(-14 + Math.cos(a1) * 1.8, 0.019, Math.sin(a1) * 1.8);
    b.bar(p0, p1, 0.06, { mat: "paper", color: line, collide: false, shadow: false });
  }
  for (const s of [-1, 1]) {
    b.within(V(-14, 0, s * 12.3), s > 0 ? Math.PI : 0, () => {
      b.box(V(0, 1.6, -0.5), V(0.14, 3.2, 0.14), { mat: "metal_ext", color: 0x3f4743 });
      b.box(V(0, 3.05, -0.1), V(1.4, 0.9, 0.05), { mat: "plastic", color: 0xd8dad2, collide: false });
      b.cylinder(V(0, 2.8, 0.25), 0.24, 0.03, { mat: "iron", color: 0xb54a2c, collide: false });
    });
  }
  // Exercise stations.
  for (const [x, z] of [[10, -16], [17, -16]]) {
    b.within(V(x, 0, z), 0, () => {
      for (const s of [-0.7, 0.7]) b.box(V(s, 1.2, 0), V(0.1, 2.4, 0.1), { mat: "metal_ext", color: 0x3f4743 });
      b.cylinder(V(0, 2.35, 0), 0.025, 1.5, { mat: "steel", quat: qz90 });
    });
  }
  b.within(V(10, 0, -10), 0, () => {
    for (const x of [-0.3, 0.3]) for (const z of [-0.9, 0.9]) b.box(V(x, 0.6, z), V(0.07, 1.2, 0.07), { mat: "metal_ext", collide: false });
    for (const x of [-0.3, 0.3]) b.cylinder(V(x, 1.2, 0), 0.03, 1.9, { mat: "steel", quat: qx90 });
    b.blocker(V(0, 0.6, 0), V(0.7, 1.2, 1.9));
  });
  place(b, V(18, 0, -7), 0, bench);
  // Garden: planters + paths.
  b.box(V(14, 0.02, 12), V(1.8, 0.028, 16), { mat: "gravel", color: 0x979b90, collide: false, shadow: false });
  b.box(V(14, 0.02, 12), V(16, 0.028, 1.8), { mat: "gravel", color: 0x979b90, collide: false, shadow: false });
  for (const [x, z] of [[9, 7], [19, 7], [9, 18], [19, 18]]) {
    b.box(V(x, 0.3, z), V(2.4, 0.6, 1.2), { mat: "concrete_ext", color: 0x8a8b84 });
    b.box(V(x, 0.62, z), V(2.2, 0.06, 1.0), { mat: "grass", color: 0x4f5c33, collide: false });
  }
  place(b, V(10.5, 0, 13.8), 0, bench);
  place(b, V(18, 0, 13.8), 0, bench);
  place(b, V(-18, 0, 19), 180, bench);
  place(b, V(4, 0, 23), 0, trashBin);
  place(b, V(22, 0, -18.5), 0, trashBin);
  for (const [x, z, yaw] of [[-22.5, -23, -135], [22.5, 23, 45]]) {
    b.within(V(x, 0, z), deg(yaw), () => {
      b.box(V(0, 1.7, 0), V(0.14, 3.4, 0.14), { mat: "metal_ext", color: 0x3f4743 });
      b.within(V(0, 3.3, 0.05), 0, () => cctvCamera(b));
    });
  }
  // Yard fence with gate gaps (CentralYardGrounds._build_fence_enclosure).
  const fh = 3.2;
  const fence = (c: Vector3, s: Vector3) => {
    b.box(c, s, { mat: "fence", occlude: false });
    const alongX = s.x > s.z;
    const len = alongX ? s.x : s.z;
    b.box(V(c.x, fh, c.z), alongX ? V(len, 0.06, 0.06) : V(0.06, 0.06, len), { mat: "metal_ext", collide: false });
    const n = Math.floor(len / 3);
    for (let i = 0; i <= n; i++) {
      const t = -len / 2 + (i * len) / Math.max(1, n);
      b.box(alongX ? V(c.x + t, fh / 2, c.z) : V(c.x, fh / 2, c.z + t), V(0.08, fh, 0.08), { mat: "metal_ext", color: 0x4b524d, collide: false });
    }
  };
  const HW = 26;
  const HD = 27;
  const nsw = (HW * 2 - 4) / 2;
  fence(V(-HW + nsw / 2, fh / 2, -HD), V(nsw, fh, 0.05));
  fence(V(HW - nsw / 2, fh / 2, -HD), V(nsw, fh, 0.05));
  fence(V(-HW + nsw / 2, fh / 2, HD), V(nsw, fh, 0.05));
  fence(V(HW - nsw / 2, fh / 2, HD), V(nsw, fh, 0.05));
  fence(V(-HW, fh / 2, -14.5), V(0.05, fh, 25));
  fence(V(-HW, fh / 2, 7.5), V(0.05, fh, 11));
  fence(V(-HW, fh / 2, 22), V(0.05, fh, 10));
  const esd = (HD * 2 - 4) / 2;
  fence(V(HW, fh / 2, -HD + esd / 2), V(0.05, fh, esd));
  fence(V(HW, fh / 2, HD - esd / 2), V(0.05, fh, esd));
  for (const [x, z, alongZ] of [[0, -HD, false], [0, HD, false], [-HW, 0, true], [-HW, 15, true], [HW, 0, true]] as const) {
    for (const s of [-2, 2]) b.box(alongZ ? V(x, fh / 2, z + s) : V(x + s, fh / 2, z), V(0.2, fh, 0.2), { mat: "dark_ext", color: 0x2e3431 });
  }
  for (const g of [
    { name: "central_yard_south_gate", p: V(0, 0, 27.2), yaw: 0, label: "YARD / POOL" },
    { name: "central_yard_north_gate", p: V(0, 0, -27.2), yaw: 0, label: "YARD" },
    { name: "central_yard_west_main_gate", p: V(-26.2, 0, 0), yaw: 90, label: "YARD" },
    { name: "central_yard_west_secondary_gate", p: V(-26.2, 0, 15), yaw: 90, label: "YARD" },
    { name: "central_yard_east_gate", p: V(26.2, 0, 0), yaw: 90, label: "YARD" },
  ]) {
    b.door({
      kind: "gate", position: g.p, yaw: deg(g.yaw), width: 4.0, height: 3.2, slideDistance: 4.3, openDirection: 1, requiredKey: "",
      persistentId: g.name, displayName: "Recreation Gate", startsLocked: false, label: g.label, color: 0x6d7a71,
    });
  }
  b.anchor("yard_center", V(0, 0, 0));
  // Yard flood masts (sodium) at the four corners.
  for (const [x, z] of [[-24, -25], [24, -25], [-24, 25], [24, 25]]) {
    b.box(V(x, 4, z), V(0.2, 8, 0.2), { mat: "metal_ext", color: 0x3f4743 });
    b.box(V(x, 8.05, z), V(0.9, 0.25, 0.5), { mat: "dark_ext", collide: false });
    b.box(V(x, 7.93, z), V(0.8, 0.03, 0.4), { mat: "emissive_night", collide: false, shadow: false });
    b.lightPoint(V(x * 0.92, 7.4, z * 0.92), 0xff9640, 40, 30, true);
  }
}

/** SwimmingPool (20 × 10 × 2.4 m) at the annex, origin at deck level. */
export function buildPool(b: StaticBuilder, center = V(-14, 0, 42.5)): void {
  const size = { x: 20, z: 10 };
  const depth = 2.4;
  b.within(center, 0, () => {
    const tile = 0xbccdca;
    b.box(V(0, -depth - 0.12, 0), V(size.x + 0.4, 0.24, size.z + 0.4), { mat: "tile_shower", color: tile });
    for (const s of [-1, 1]) {
      b.box(V(0, -depth / 2, s * (size.z / 2 + 0.1)), V(size.x + 0.4, depth, 0.2), { mat: "tile_shower", color: tile });
      b.box(V(s * (size.x / 2 + 0.1), -depth / 2, 0), V(0.2, depth, size.z), { mat: "tile_shower", color: tile });
      b.box(V(0, 0.025, s * (size.z / 2 + 0.16)), V(size.x + 0.6, 0.05, 0.32), { mat: "concrete_ext", color: 0xe0dcca });
      for (const end of [-1, 1]) b.box(V(s * (size.x / 2 + 0.16), 0.025, (end * (size.z / 2 + 1.3)) / 2), V(0.32, 0.05, size.z / 2 - 1.3), { mat: "concrete_ext", color: 0xe0dcca });
      poolSteps(b, s, size.x, depth);
    }
    for (const z of [-3, 0, 3]) b.box(V(0, -depth + 0.006, z), V(size.x - 0.2, 0.008, 0.07), { mat: "tile_shower", color: 0x28565d, collide: false, shadow: false });
    b.within(V(0, 0, -size.z / 2 - 1.05), 0, () => {
      for (const x of [-1.35, 1.35]) b.box(V(x, 1.15, 0), V(0.08, 2.3, 0.08), { mat: "metal_ext", color: 0x63776c });
      b.box(V(0, 1.9, 0), V(3, 0.85, 0.08), { mat: "metal_ext", color: 0x42665f, collide: false });
      b.sign("COMMUNITY POOL — 2.4 m\nWASD SWIM   SPACE RISE   C DIVE\nSTEPS AT BOTH ENDS — NO DIVING", V(0, 1.9, 0.05), 0, 0xedf2df, 0.0027);
    });
    // Deck paths around the basin.
    for (const [c, s] of [[V(0, 0, -6.75), V(27, 0.028, 3.5)], [V(0, 0, 6.75), V(27, 0.028, 3.5)], [V(-11.75, 0, 0), V(3.5, 0.028, 10)], [V(11.75, 0, 0), V(3.5, 0.028, 10)]] as const) {
      b.box(c.clone().add(V(0, 0.014, 0)), s, { mat: "concrete_ext", color: 0x979b90, collide: false, shadow: false });
    }
    place(b, V(-4.5, 0.03, 7.8), 180, bench);
    place(b, V(-9, 0.03, 7.9), 0, trashBin);
  });
  b.anchor("pool", center, 0, { sizeX: size.x, sizeZ: size.z, depth, surfaceY: -0.12 });
  // Gazebo + recreation security kiosk.
  b.within(V(-36, 0.035, 28), 0, () => {
    for (const x of [-1.6, 1.6]) for (const z of [-1.6, 1.6]) b.box(V(x, 1.3, z), V(0.14, 2.6, 0.14), { mat: "wood", color: 0x6f5a40 });
    b.box(V(0, 2.7, 0), V(4.0, 0.2, 4.0), { mat: "dark_ext", color: 0x3c413e });
    place(b, V(0, 0, 0.8), 0, bench);
  });
  b.within(V(-31, 0.035, 29), deg(90), () => {
    b.box(V(0, 1.3, 0), V(2.4, 2.6, 2.0), { mat: "metal_ext", color: 0x5d665f });
    b.box(V(0, 1.6, 1.01), V(1.8, 0.8, 0.04), { mat: "glass", collide: false, shadow: false });
    b.box(V(0, 2.7, 0), V(2.8, 0.15, 2.4), { mat: "dark_ext", collide: false });
    b.sign("RECREATION SECURITY", V(0, 2.4, 1.05), 0, 0xe0d5a8, 0.0028);
  });
}

function poolSteps(b: StaticBuilder, side: number, poolX: number, depth: number): void {
  const run = Math.min(6, poolX * 0.3);
  b.within(V(side * (poolX / 2 - run), -depth, 0), (side * Math.PI) / 2, () => {
    const count = Math.ceil(depth / 0.2);
    const incline = run - 0.6;
    for (let i = 0; i < count; i++) {
      const h = (depth * (i + 1)) / count;
      b.box(V(0, h / 2 - 0.02, ((i + 0.5) * incline) / count), V(2.4, h - 0.04, incline / count + 0.01), { mat: "tile_shower", color: 0xaabfb9, collide: false });
    }
    b.box(V(0, depth / 2, run - 0.3), V(2.4, depth, 0.6), { mat: "tile_shower", color: 0xaabfb9, collide: false });
    const pts: Vector3[] = [];
    for (const x of [-1.2, 1.2]) pts.push(V(x, -0.1, 0), V(x, 0, 0), V(x, depth, incline), V(x, depth, run + 0.1), V(x, -0.1, run + 0.1));
    b.ramp(pts);
    for (const s of [-1, 1]) {
      const x = s * 1.12;
      for (const e of [0, 1]) b.cylinder(V(x, depth * e + 0.45, run * e), 0.035, 0.9, { mat: "steel", color: 0xa4bab4 });
      b.bar(V(x, 0.9, 0), V(x, depth + 0.9, run), 0.055, { mat: "steel", color: 0xa4bab4 });
    }
  });
}

/** RoadsAndPaths. */
export function buildRoads(b: StaticBuilder): void {
  const road = (c: Vector3, s: Vector3) => {
    b.box(c, s, { mat: "asphalt", color: 0x7d7f7a, collide: false, shadow: false });
  };
  road(V(0, 0.01, -88), V(150, 0.02, 6));
  road(V(0, 0.01, 88), V(150, 0.02, 6));
  road(V(-72, 0.01, 0), V(6, 0.02, 176));
  road(V(72, 0.01, 0), V(6, 0.02, 176));
  road(V(0, 0.015, -31), V(140, 0.02, 5));
  road(V(0, 0.015, 31), V(140, 0.02, 5));
  road(V(0, 0.018, -61), V(5, 0.02, 54));
  road(V(5, 0.018, 45.5), V(5, 0.02, 27));
  // Dashed centre lines on the cross roads.
  for (let x = -66; x <= 66; x += 4) for (const z of [-31, 31]) b.box(V(x, 0.03, z), V(1.8, 0.004, 0.12), { mat: "paper", color: 0xd8cf9a, collide: false, shadow: false });
  const path = (c: Vector3, s: Vector3) => b.box(c, s, { mat: "gravel", color: 0x9a9a90, collide: false, shadow: false });
  path(V(-70.5, 0.025, 0), V(3.0, 0.03, 3.5));
  path(V(-27, 0.025, 0), V(2.0, 0.03, 3.5));
  path(V(29.3, 0.025, 0), V(6.6, 0.03, 3.5));
  path(V(-48, 0.025, -34.2), V(3.5, 0.03, 1.6));
  path(V(48, 0.025, -34.2), V(3.5, 0.03, 1.6));
  path(V(-48, 0.025, 34.2), V(3.5, 0.03, 1.6));
  path(V(48, 0.025, 34.2), V(3.5, 0.03, 1.6));
  path(V(2.5, 0.025, 59), V(5.0, 0.03, 3.5));
  path(V(0, 0.025, -27.75), V(4.0, 0.03, 1.6));
  path(V(0, 0.025, 27.75), V(4.0, 0.03, 1.5));
  path(V(-67.5, 0.025, -51.5), V(3.0, 0.03, 4.0));
  path(V(-67.8, 0.025, 50.5), V(2.4, 0.03, 4.0));
  path(V(48, 0.025, 76.5), V(4.0, 0.03, 17.0));
  path(V(0, 0.025, 84), V(4.0, 0.03, 2.0));
  path(V(0, 0.025, -87.7), V(6.0, 0.03, 5.4));
  path(V(-28.45, 0.025, 50.5), V(1.9, 0.03, 3.0));
  path(V(-1, 0.025, 30.5), V(3.0, 0.03, 7.0));
  for (let z = 28.5; z <= 33; z += 0.8) b.box(V(-1, 0.035, z), V(2.8, 0.012, 0.36), { mat: "paper", color: 0xdedcc7, collide: false, shadow: false });
  // Street lamps along the cross roads.
  for (let x = -60; x <= 60; x += 20) for (const z of [-34, 34]) {
    if (Math.abs(x) < 5) continue;
    // Post-top lantern (Poly Haven street_lamp_01, 3.87 m) scaled to 6.2 m; its glass is the night diffuser.
    const scale = 1.6;
    b.prop("street_lamp_01", V(x, 0, z), { scale, yaw: z < 0 ? 0 : Math.PI, glow: "night" });
    b.blocker(V(x, 1.6, z), V(0.3, 3.2, 0.3), false);
    b.lightPoint(V(x, 3.3 * scale, z), 0xff9a45, 30, 24, true);
  }
}

export interface TowerConfig {
  name: string;
  pos: Vector3;
  ladderRot: number;
  light: boolean;
  beamRot: number;
  beamPitch: number;
}

export const TOWERS: TowerConfig[] = [
  { name: "NorthWestPerimeterTower", pos: V(-66, 0, -80), ladderRot: 39, light: true, beamRot: 39, beamPitch: 45 },
  { name: "NorthEastPerimeterTower", pos: V(66, 0, -80), ladderRot: -39, light: false, beamRot: -39, beamPitch: 32 },
  { name: "SouthWestPerimeterTower", pos: V(-66, 0, 80), ladderRot: 141, light: false, beamRot: 141, beamPitch: 32 },
  { name: "SouthEastPerimeterTower", pos: V(66, 0, 80), ladderRot: -141, light: true, beamRot: -141, beamPitch: 45 },
  { name: "CentralYardNorthTower", pos: V(25, 0, -36.5), ladderRot: -35, light: true, beamRot: -35, beamPitch: 32 },
  { name: "CentralYardSouthTower", pos: V(-25, 0, 36.5), ladderRot: 145, light: false, beamRot: 145, beamPitch: 32 },
  { name: "ServiceLoadingTower", pos: V(-66, 0, -72), ladderRot: 49, light: false, beamRot: 49, beamPitch: 32 },
  { name: "CellhouseBSecurityTower", pos: V(66, 0, -38), ladderRot: -66, light: false, beamRot: -66, beamPitch: 32 },
];

/** Watchtower prop: footings, stilts, bracing, deck, octagonal cabin, ladder cage. */
export function buildTowers(b: StaticBuilder): void {
  const H = 7;
  for (const t of TOWERS) {
    b.within(t.pos, 0, () => {
      const f = 1.75;
      for (const x of [-f, f]) for (const z of [-f, f]) {
        b.box(V(x, 0.2, z), V(0.8, 0.4, 0.8), { mat: "concrete_ext", color: 0x8b8c84 });
        b.box(V(x, H / 2 + 0.2, z), V(0.24, H, 0.24), { mat: "dark_ext", color: 0x353b37 });
      }
      for (const lvl of [H * 0.35, H * 0.7]) {
        for (const s of [-f, f]) {
          b.box(V(0, lvl, s), V(f * 2, 0.12, 0.12), { mat: "metal_ext", collide: false });
          b.box(V(s, lvl, 0), V(0.12, 0.12, f * 2), { mat: "metal_ext", collide: false });
        }
        b.bar(V(-f, lvl - 1.2, -f), V(f, lvl, -f), 0.08, { mat: "metal_ext", collide: false });
        b.bar(V(f, lvl - 1.2, f), V(-f, lvl, f), 0.08, { mat: "metal_ext", collide: false });
      }
      const deckY = H + 0.2;
      b.box(V(0, deckY, 0), V(4.5, 0.25, 4.5), { mat: "dark_ext", color: 0x353b37 });
      for (let a = 0; a < 4; a++) {
        const yaw = (a * Math.PI) / 2;
        b.within(V(0, 0, 0), yaw, () => {
          b.box(V(0, deckY + 1.15, 2.2), V(4.4, 0.06, 0.06), { mat: "metal_ext", collide: false });
          b.box(V(0, deckY + 0.65, 2.2), V(4.4, 0.04, 0.04), { mat: "metal_ext", collide: false });
          for (const x of [-2.15, 0, 2.15]) b.box(V(x, deckY + 0.6, 2.2), V(0.06, 1.0, 0.06), { mat: "metal_ext", collide: false });
        });
      }
      const cabinY = deckY + 0.25 + 1.25;
      for (let i = 0; i < 8; i++) {
        const a = (i / 8) * Math.PI * 2 + Math.PI / 8;
        const r = 1.75 * Math.cos(Math.PI / 8);
        b.within(V(Math.sin(a) * r, cabinY, Math.cos(a) * r), a, () => {
          b.box(V(0, -0.75, 0), V(1.45, 1.0, 0.1), { mat: "metal_ext", color: 0x5a635d });
          b.box(V(0, 1.0, 0), V(1.45, 0.5, 0.1), { mat: "metal_ext", color: 0x5a635d });
          b.box(V(0, 0.3, 0), V(1.35, 0.9, 0.05), { mat: "glass", color: 0x102028, collide: false, shadow: false });
          b.box(V(0.7, 0, 0), V(0.08, 2.5, 0.12), { mat: "dark_ext", collide: false });
        });
      }
      b.box(V(0, cabinY - 0.6, 0), V(0.9, 0.9, 0.9), { mat: "dark", color: 0x2c312e, collide: false });
      b.box(V(0, cabinY + 0.25, 0), V(0.25, 0.25, 0.25), { mat: t.light ? "emissive_night" : "emissive_red", collide: false, shadow: false });
      const roofY = cabinY + 1.35;
      b.box(V(0, roofY, 0), V(3.8, 0.2, 3.8), { mat: "dark_ext", color: 0x2e3330 });
      b.cylinder(V(0.95, roofY + 0.92, 0.7), 0.025, 1.5, { mat: "dark_ext" });
      // Ladder with safety cage.
      b.within(V(0, 0, 0), deg(t.ladderRot), () => {
        const lz = 2.35;
        for (const x of [-0.25, 0.25]) b.box(V(x, H / 2, lz), V(0.05, H, 0.08), { mat: "dark_ext", collide: false });
        for (let y = 0.3; y < H; y += 0.3) b.box(V(0, y, lz), V(0.46, 0.035, 0.035), { mat: "steel", collide: false, shadow: false });
        for (let y = 2.2; y < H; y += 0.9) b.box(V(0, y, lz + 0.35), V(0.75, 0.03, 0.7), { mat: "hazard", collide: false, shadow: false });
      });
      // Searchlight fixture on the roof edge.
      const yaw = deg(t.beamRot);
      const fwd = V(Math.sin(yaw), 0, Math.cos(yaw));
      const edge = 1.9 / Math.max(Math.abs(fwd.x), Math.abs(fwd.z)) - 0.12;
      const fixture = fwd.clone().multiplyScalar(edge).add(V(0, roofY + 0.1, 0));
      b.cylinder(fixture.clone().add(V(0, 0.15, 0)), 0.12, 0.3, { mat: "dark_ext" });
      b.anchor(`tower:${t.name}`, fixture.clone().add(V(0, 0.45, 0)), yaw, { light: t.light, pitch: t.beamPitch, name: t.name });
    });
  }
}
