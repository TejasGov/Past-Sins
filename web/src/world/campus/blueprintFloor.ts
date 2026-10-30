import { Vector3 } from "three";
import type { StaticBuilder } from "../builder";
import type { MaterialKey } from "../../render/materials";
import { V } from "../props";
import type { FloorPlan, PlanDoor, PlanRoom } from "./plans";
import { furnishRoom, type Opening } from "./furnisher";

const WALL = 0.22;
const DOOR_HEIGHT = 2.65;

export interface DoorRecord extends PlanDoor {
  clearWidth: number;
  position: Vector3; // local (building frame)
  normal: Vector3;
}

export interface BuiltFloor {
  plan: FloorPlan;
  storyHeight: number;
  /** World-space room centres at floor level. */
  roomCenters: Map<string, Vector3>;
  rooms: Map<string, PlanRoom>;
  doors: DoorRecord[];
  /** Local (building-frame) helpers for later attachments. */
  point(x: number, z: number, y?: number): Vector3;
  /** Nav export hook: building-frame point (point(), DoorRecord.position) → world. */
  toWorld(local: Vector3): Vector3;
}

export function wallColorFor(planId: string): number {
  if (planId.startsWith("food")) return 0x83856f;
  if (planId.startsWith("medical")) return 0x98a29a;
  if (planId.startsWith("nidra")) return 0xa3aeab;
  if (planId.startsWith("hq")) return 0x56605a;
  if (planId.startsWith("admin")) return 0x8f8b7d;
  return 0x6f736a;
}

function wallMaterial(planId: string): MaterialKey {
  if (planId.startsWith("medical") || planId.startsWith("admin") || planId.startsWith("nidra") || planId.startsWith("hq")) return "plaster";
  return "concrete";
}

function floorMaterial(planId: string, room: PlanRoom): { mat: MaterialKey; color: number } {
  if (room.floor_finish === "gym_rubber") return { mat: "rubber", color: 0x6a6f6a };
  if (room.floor_finish === "tile_shower") return { mat: "tile_shower", color: 0xb8c0bb };
  if (room.type === "medical" || planId.startsWith("nidra")) return { mat: "tiles", color: 0xb5bcb7 };
  if (planId.startsWith("food") && room.type === "service") return { mat: "tiles", color: 0x9da39a };
  if (planId.startsWith("admin") || planId.startsWith("hq")) return { mat: "tiles", color: 0x7d827c };
  return { mat: "concrete", color: 0x626861 };
}

/** Port of CampusBlueprintFloor._access_for. */
function accessFor(planId: string, d: PlanDoor, roomType: (id: string) => string): string {
  if (planId.startsWith("cellhouse-b")) {
    if (roomType(d.a) === "cell") return `cell_${planId}_${d.a}`;
    return "security_key";
  }
  if (planId.startsWith("hq")) return "security_key";
  if (planId.startsWith("nidra")) return "lab_key";
  if (planId.startsWith("maintenance")) return d.kind === "staff" || d.kind === "gate" ? "service_key" : "";
  if (planId === "food-ground") return d.kind === "staff" ? "service_key" : "";
  if (planId === "medical-ground") return d.kind === "staff" || d.a === "medicine" ? "medical_key" : "";
  if (planId === "admin-ground") {
    if ((d.a === "public" || d.a === "visitation") && d.b !== "OUTSIDE" && d.b !== "secure") return "";
    return d.kind === "staff" || d.kind === "gate" ? "security_key" : "";
  }
  return "";
}

/**
 * Port of CampusBlueprintFloor: shared boundaries are unioned before door
 * openings are cut, rooms get slabs/ceilings/fixtures/furniture, thresholds
 * become door/gate specs. The builder frame must be at the building origin
 * with y = the plan's elevation.
 */
export function buildBlueprintFloor(b: StaticBuilder, plan: FloorPlan, storyHeight: number, furnish = true): BuiltFloor {
  const W = plan.width;
  const D = plan.depth;
  const point = (x: number, z: number, y = 0) => V(x - W / 2, y, z - D / 2);
  const rooms = new Map(plan.rooms.map((r) => [r.id, r]));
  const roomType = (id: string) => rooms.get(id)?.type ?? "outside";
  const center = (r: PlanRoom) => point(r.x + r.w / 2, r.y + r.d / 2);
  const wallColor = wallColorFor(plan.id);
  const wallMat = wallMaterial(plan.id);

  // ── thresholds ──
  const doors: DoorRecord[] = [];
  for (const src of plan.doors) {
    const d = { ...src } as DoorRecord;
    const a = rooms.get(d.a);
    const bRoom = rooms.get(d.b);
    if ((roomType(d.a) === "stair" || roomType(d.b) === "stair") && d.kind === "door") d.kind = "open";
    const pos = point(d.x, d.y);
    const target = mountRoom(a, bRoom, d);
    let normal = d.axis === "x" ? V(0, 0, 1) : V(1, 0, 0);
    if (target && center(target).sub(pos).dot(normal) < 0) normal.negate();
    if (!bRoom) normal = normal.negate();
    let width = d.width;
    if ((d.kind === "gate" || d.kind === "glass") && bRoom && target) {
      const c = d.axis === "x" ? d.x : d.y;
      const lo = d.axis === "x" ? target.x : target.y;
      const hi = lo + (d.axis === "x" ? target.w : target.d);
      width = Math.min(width, (Math.min(c - lo, hi - c) - 0.2) / 0.75);
    }
    d.clearWidth = width;
    d.position = pos;
    d.normal = normal;
    doors.push(d);
  }
  if (plan.id === "nidra-b2") {
    // Observation glass into Interrogation A/B, on their shared (compacted) boundary.
    const wy = rooms.get("observation")?.y ?? 25.2;
    for (const x of [4.375, 12.125]) {
      doors.push({
        a: "observation", b: x < 8 ? "interrogationa" : "interrogationb", x, y: wy, axis: "x", width: 3, clearWidth: 3,
        kind: "window", position: point(x, wy), normal: V(0, 0, 1),
      });
    }
  }

  // ── boundaries ──
  const lines = new Map<string, { axis: "x" | "z"; fixed: number; ranges: [number, number][]; cuts: number[] }>();
  for (const r of plan.rooms) {
    const edges: ["x" | "z", number, number, number][] = [
      ["x", r.y, r.x, r.x + r.w], ["x", r.y + r.d, r.x, r.x + r.w], ["z", r.x, r.y, r.y + r.d], ["z", r.x + r.w, r.y, r.y + r.d],
    ];
    for (const [axis, fixed, s, e] of edges) {
      const key = `${axis}:${fixed.toFixed(3)}`;
      let line = lines.get(key);
      if (!line) lines.set(key, (line = { axis, fixed, ranges: [], cuts: [] }));
      line.ranges.push([s, e]);
      line.cuts.push(s, e);
    }
  }
  for (const line of lines.values()) {
    const openings: [number, number][] = [];
    for (const d of doors) {
      const fixed = d.axis === "x" ? d.y : d.x;
      if (d.axis !== line.axis || Math.abs(fixed - line.fixed) > 0.001) continue;
      const c = d.axis === "x" ? d.x : d.y;
      const w = d.clearWidth;
      line.cuts.push(c - w / 2, c + w / 2);
      openings.push([c - w / 2, c + w / 2]);
    }
    line.cuts.sort((p, q) => p - q);
    for (let i = 0; i < line.cuts.length - 1; i++) {
      const s = line.cuts[i];
      const e = line.cuts[i + 1];
      if (e - s < 0.001) continue;
      const mid = (s + e) / 2;
      if (!line.ranges.some(([lo, hi]) => mid > lo - 0.001 && mid < hi + 0.001)) continue;
      const opening = openings.some(([lo, hi]) => mid > lo && mid < hi);
      const low = opening ? DOOR_HEIGHT : 0;
      const h = storyHeight - low;
      const pos = line.axis === "x" ? point(mid, line.fixed, low + h / 2) : point(line.fixed, mid, low + h / 2);
      const size = line.axis === "x" ? V(e - s, h, WALL) : V(WALL, h, e - s);
      b.box(pos, size, { mat: wallMat, color: wallColor });
      // Painted dado band on the lower wall gives interiors an institutional read.
      if (!opening && h > 2) {
        const dado = line.axis === "x" ? V(e - s, 1.1, WALL + 0.012) : V(WALL + 0.012, 1.1, e - s);
        const dpos = line.axis === "x" ? point(mid, line.fixed, 0.55) : point(line.fixed, mid, 0.55);
        b.box(dpos, dado, { mat: "plaster", color: darken(wallColor, 0.72), collide: false, shadow: false });
      }
    }
  }

  // ── rooms ──
  const roomCenters = new Map<string, Vector3>();
  for (const r of plan.rooms) {
    const c = center(r);
    roomCenters.set(r.id, b.toWorld(c));
    if (r.type === "stair" || r.type === "lift" || r.type === "void") continue;
    const fm = floorMaterial(plan.id, r);
    b.box(c.clone().add(V(0, -0.1, 0)), V(r.w, 0.2, r.d), { mat: fm.mat, color: fm.color });
    b.box(c.clone().add(V(0, storyHeight - 0.1, 0)), V(r.w, 0.2, r.d), { mat: wallMat, color: darken(wallColor, 0.85) });
    const lighting = r.lighting_type ?? r.type;
    const nightOnly = lighting === "cellblock";
    const mountY = storyHeight - 0.24;
    const lab = plan.id.startsWith("nidra");
    if (r.type === "cell") {
      const side = r.id.startsWith("n") ? 1 : -1;
      b.box(c.clone().add(V(side * 1.3, 2.05, -r.d / 2 + WALL / 2 + 0.05)), V(0.64, 0.06, 0.06), { mat: "emissive_night", collide: false, shadow: false });
      b.lightPoint(c.clone().add(V(side * 1.3, 2.0, -r.d / 2 + 0.6)), 0xffcf8a, 2.2, 6, true);
    } else {
      // Long rooms get a row of diffusers; each is a light-pool candidate.
      const count = Math.max(1, Math.round(Math.max(r.w, r.d) / 6));
      const alongX = r.w >= r.d;
      for (let i = 0; i < count; i++) {
        const t = (i + 0.5) / count - 0.5;
        const off = alongX ? V(t * r.w, 0, 0) : V(0, 0, t * r.d);
        const len = Math.min((alongX ? r.w : r.d) / count - 0.6, 1.4);
        const size = alongX ? V(len, 0.025, 0.19) : V(0.19, 0.025, len);
        b.fixture(c.clone().add(off).add(V(0, mountY - 0.05, 0)), size, {
          nightOnly,
          color: lab ? 0xf2f6ff : 0xffdcaa,
          intensity: lab ? 5 : 4.2,
          range: Math.max(7, Math.min(13, Math.max(r.w, r.d) * 0.9)),
          flicker: hashFlicker(plan.id + r.id + i),
        });
      }
    }
    if (furnish) {
      const openings: Opening[] = doors
        .filter((d) => d.a === r.id || d.b === r.id)
        .map((d) => ({ position: d.position.clone().sub(c), width: d.clearWidth, axis: d.axis, kind: d.kind }));
      b.within(c, 0, () => furnishRoom(b, plan.id, r, openings, storyHeight));
    }
    if (r.type !== "corridor" && r.w * r.d > 20) {
      b.sign(r.label.replace(/\n/g, " / ").toUpperCase(), c.clone().add(V(0, storyHeight - 0.65, -r.d / 2 + WALL / 2 + 0.02)), 0, 0xc9cfc4, 0.0032);
    }
  }

  // ── thresholds → fixtures and door specs ──
  for (const d of doors) buildThreshold(b, plan, d, rooms, roomType, wallColor, wallMat);

  const frameOrigin = b.toWorld(V(0, 0, 0));
  const frameYaw = b.worldYaw(0);
  const toWorld = (local: Vector3) => {
    const c = Math.cos(frameYaw);
    const s = Math.sin(frameYaw);
    return V(frameOrigin.x + c * local.x + s * local.z, frameOrigin.y + local.y, frameOrigin.z - s * local.x + c * local.z);
  };
  return { plan, storyHeight, roomCenters, rooms, doors, point, toWorld };
}

function mountRoom(a: PlanRoom | undefined, b: PlanRoom | undefined, d: PlanDoor): PlanRoom | undefined {
  if (!b) return a;
  if (!a) return b;
  let best = a;
  let space = -1;
  for (const room of [a, b]) {
    const c = d.axis === "x" ? d.x : d.y;
    const lo = d.axis === "x" ? room.x : room.y;
    const hi = lo + (d.axis === "x" ? room.w : room.d);
    let candidate = Math.min(c - lo, hi - c);
    if (room.type === "stair") candidate = -2;
    if (candidate > space) {
      space = candidate;
      best = room;
    }
  }
  return best;
}

function buildThreshold(
  b: StaticBuilder, plan: FloorPlan, d: DoorRecord, rooms: Map<string, PlanRoom>, roomType: (id: string) => string, wallColor: number, wallMat: MaterialKey,
): void {
  const width = d.clearWidth;
  const yaw = Math.atan2(d.normal.x, d.normal.z);
  if (d.kind === "sealed" || d.kind === "window" || d.kind === "hatch") {
    b.within(d.position, yaw, () => {
      if (d.kind === "sealed") {
        const lift = d.a === "lift";
        b.box(V(0, DOOR_HEIGHT / 2, 0), V(width, DOOR_HEIGHT, 0.2), { mat: lift ? "steel" : "metal", color: lift ? 0x737b77 : 0x6a726c });
        if (lift) b.box(V(0, DOOR_HEIGHT / 2, 0.105), V(0.03, DOOR_HEIGHT - 0.1, 0.01), { mat: "dark", collide: false });
        else for (let y = 0.3; y < DOOR_HEIGHT; y += 0.35) b.box(V(0, y, 0.105), V(width - 0.1, 0.05, 0.02), { mat: "dark", collide: false });
        b.box(V(0, DOOR_HEIGHT + 0.12, 0.13), V(width * 0.8, 0.16, 0.02), { mat: "hazard", collide: false, shadow: false });
        b.sign(lift ? "ELEVATOR / OFFLINE" : "FUTURE SERVICE TUNNEL / SEALED", V(0, DOOR_HEIGHT - 0.45, 0.13), 0, 0xd2c98e, 0.0022);
      } else {
        b.box(V(0, 0.48, 0), V(width, 0.96, 0.22), { mat: wallMat, color: wallColor });
        b.box(V(0, 2.37, 0), V(width, 0.56, 0.22), { mat: wallMat, color: wallColor });
        if (d.kind === "window") {
          b.box(V(0, 1.52, 0), V(width, 1.12, 0.08), { mat: "glass", color: 0x597473, occlude: false });
        } else {
          b.box(V(0, 0.98, 0), V(width, 0.08, 0.75), { mat: "steel", color: 0x929c99 });
          b.box(V(0, 1.79, 0), V(width, 0.6, 0.12), { mat: "steel", color: 0x6e7772 });
        }
      }
    });
    return;
  }
  if (d.kind === "open") return;
  const gateMode = d.kind === "gate" || d.kind === "glass" || d.b === "OUTSIDE";
  const access = accessFor(plan.id, d, roomType);
  const label = rooms.get(d.a)?.label.replace(/\n/g, " / ").toUpperCase() ?? "ACCESS";
  let depth = d.b === "OUTSIDE" ? 0.77 : 0.31;
  if (gateMode) depth += 0.06;
  b.door({
    kind: d.kind === "glass" ? "glass" : gateMode ? "gate" : "door",
    position: d.position.clone().add(d.normal.clone().multiplyScalar(depth)),
    yaw,
    width,
    height: DOOR_HEIGHT,
    requiredKey: access,
    masterKey: roomType(d.a) === "cell" ? "cell_master_key" : undefined,
    persistentId: `campus_${plan.id}_${d.a}_${d.b}`,
    displayName: label,
    startsLocked: access !== "",
    openDirection: gateMode ? 1 : -1,
    openAngle: 90,
    slideDistance: width * 0.78,
    color: 0x727f75,
    planId: plan.id,
  });
  const reveal = d.b === "OUTSIDE" ? 0.77 : 0.31;
  const axis = d.axis === "x" ? V(1, 0, 0) : V(0, 0, 1);
  for (const side of [-1, 1]) {
    const p = d.position.clone().add(axis.clone().multiplyScalar(side * (width / 2 + 0.04))).add(d.normal.clone().multiplyScalar(reveal / 2));
    const sz = d.axis === "x" ? V(0.08, DOOR_HEIGHT, reveal) : V(reveal, DOOR_HEIGHT, 0.08);
    b.box(p.add(V(0, DOOR_HEIGHT / 2, 0)), sz, { mat: "metal", color: 0x535d55 });
  }
  b.within(d.position.clone().add(d.normal.clone().multiplyScalar(reveal + 0.16)), yaw, () => {
    b.sign(label, V(0, 2.97, 0), 0, 0xd8dccf, 0.0028);
  });
}

function darken(hex: number, f: number): number {
  const r = Math.round(((hex >> 16) & 255) * f);
  const g = Math.round(((hex >> 8) & 255) * f);
  const bl = Math.round((hex & 255) * f);
  return (r << 16) | (g << 8) | bl;
}

function hashFlicker(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
  return Math.abs(h) % 17 === 0 ? 0.8 : 0;
}
