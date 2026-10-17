import { Quaternion, Vector3 } from "three";
import type { StaticBuilder } from "../builder";
import { V, deg } from "../props";
import { buildShell, type ShellDef } from "./shell";
import { buildBlueprintFloor, type BuiltFloor } from "./blueprintFloor";
import { compactPlan, type FloorPlan } from "./plans";
import { switchbackStair, type Entrance } from "./stairs";

export interface BuildingDef {
  name: string;
  chunk: string;
  position: Vector3;
  shell: ShellDef;
  plans: string[];
  extras?: (b: StaticBuilder) => void;
}

const TALL = new Set(["food-ground", "medical-ground", "maintenance-ground", "admin-ground"]);

/** Building placements from PrisonCampusPrototype._spawn_buildings + building scripts. */
export const BUILDINGS: BuildingDef[] = [
  {
    name: "Food Services",
    chunk: "food",
    position: V(-48, 0, -51.5),
    plans: ["food-ground"],
    shell: {
      title: "FOOD SERVICES & CATERING", width: 38, height: 5.5, depth: 33.2, thickness: 0.45,
      openings: [
        { side: "south", offset: 0, width: 3.2, height: 3.0, label: "CAFETERIA & DINING HALL" },
        { side: "west", offset: -1.0, width: 3.6, height: 3.4, label: "KITCHEN SERVICE & RECEIVING" },
      ],
    },
    extras: (b) => b.box(V(-19 - 2.0, -0.04, -1), V(4.0, 0.08, 8.0), { mat: "concrete_ext", color: 0x7c7e77 }),
  },
  {
    name: "Medical & Wellness",
    chunk: "medical",
    position: V(-48, 0, 51.5),
    plans: ["medical-ground"],
    shell: {
      title: "MEDICAL WING & RECREATION WELLNESS", width: 37.2, height: 6, depth: 33.2, thickness: 0.45,
      openings: [
        { side: "north", offset: 0, width: 3.2, height: 3.0, label: "INFIRMARY & RECREATION WELLNESS" },
        { side: "east", offset: -1.0, width: 2.8, height: 2.8, label: "SECURE GYM & SHOWER ACCESS" },
        { side: "west", offset: -1.0, width: 3.6, height: 3.4, label: "EMERGENCY VEHICLE ACCESS" },
      ],
      wallColor: 0x9a9d95,
    },
  },
  {
    name: "Security HQ",
    chunk: "hq",
    position: V(48, 0, -51.5),
    plans: ["hq-0", "hq-1", "nidra-b2"],
    shell: {
      title: "SECURITY HEADQUARTERS & COMMAND", width: 35.2, height: 8.6, depth: 33.2, thickness: 0.45,
      openings: [
        { side: "south", offset: 0, width: 3.0, height: 3.2, label: "SECURITY HQ — COMMAND & SURVEILLANCE" },
        { side: "west", offset: -1.0, width: 2.4, height: 2.8, label: "STAFF ACCESS ONLY" },
      ],
      wallMat: "concrete_ext", wallColor: 0x5f6560, roofColor: 0x3a3e3b,
    },
    extras: (b) => {
      b.box(V(0, 8.6 * 0.75, 33.2 / 2 + 0.03), V(35.2 - 6, 1.4, 0.1), { mat: "glass", color: 0x142830, collide: false });
      for (let x = -14; x <= 14; x += 2) b.box(V(x, 6.45, 16.66), V(0.08, 1.45, 0.08), { mat: "dark_ext", collide: false });
    },
  },
  {
    name: "Maintenance",
    chunk: "maintenance",
    position: V(48, 0, 51.5),
    plans: ["maintenance-ground", "maintenance-b1"],
    shell: {
      title: "MAINTENANCE & UTILITIES", width: 35.2, height: 5.5, depth: 33.2, thickness: 0.45,
      openings: [
        { side: "north", offset: 0, width: 3.0, height: 3.0, label: "FACILITY MAINTENANCE & UTILITIES" },
        { side: "south", offset: 0, width: 3.8, height: 3.4, label: "SERVICE YARD & WASTE MANAGEMENT" },
      ],
      wallColor: 0x7f8279,
    },
    extras: (b) => {
      b.box(V(35.2 / 2 + 2.0, 1.25, 0), V(3.5, 2.5, 8.0), { mat: "dark_ext", color: 0x3c423e });
      for (let z = -3.5; z <= 3.5; z += 0.5) b.box(V(35.2 / 2 + 3.76, 1.25, z), V(0.03, 2.3, 0.04), { mat: "metal_ext", collide: false });
      b.sign("DANGER · HIGH VOLTAGE", V(35.2 / 2 + 3.8, 1.9, 0), deg(90), 0xf0c84a, 0.004);
    },
  },
  {
    name: "Administration",
    chunk: "admin",
    position: V(0, 0, 71),
    plans: ["admin-ground"],
    shell: {
      title: "ADMINISTRATION & INTAKE PROCESSING", width: 39.2, height: 6, depth: 24, thickness: 0.45,
      openings: [
        { side: "north", offset: 0, width: 3.4, height: 3.2, label: "PRISON INTAKE & PROCESSING" },
        { side: "south", offset: 0, width: 3.6, height: 3.2, label: "VISITOR RECEPTION & ADMINISTRATION" },
      ],
      wallColor: 0x9b9789,
    },
    extras: (b) => {
      b.box(V(0, 4.2, 12 + 2.5), V(8.0, 0.4, 5.0), { mat: "dark_ext", color: 0x3c413e });
      for (const x of [-3.6, 3.6]) b.box(V(x, 2.0, 12 + 4.6), V(0.4, 4.0, 0.4), { mat: "metal_ext", color: 0x4f5650 });
      b.fixture(V(0, 3.95, 12 + 2.5), V(1.2, 0.05, 0.3), { nightOnly: true, color: 0xff9a45, intensity: 8, range: 12, backplate: false });
    },
  },
  {
    name: "Cellhouse B",
    chunk: "cellhouseB",
    position: V(50, 0, 0),
    plans: ["cellhouse-b-0", "cellhouse-b-1"],
    shell: {
      title: "CELLHOUSE B — HIGH SECURITY FACILITY", width: 35.2, height: 9, depth: 44.8, thickness: 0.5,
      openings: [
        { side: "west", offset: 0, width: 3.0, height: 3.2, label: "HIGH SECURITY — AUTHORIZED ONLY" },
        { side: "north", offset: 0, width: 3.6, height: 3.4, label: "SECURE TRANSPORT SALLY PORT" },
      ],
      wallMat: "concrete_ext", wallColor: 0x5c615c, roofColor: 0x343835,
    },
    extras: (b) => cellhouseBFence(b, 35.2, 44.8),
  },
];

/** Builds every blueprint building; returns the floors keyed by plan id. */
export function buildBlueprintBuildings(b: StaticBuilder, plans: FloorPlan[]): Map<string, BuiltFloor> {
  const byId = new Map(plans.map((p) => [p.id, p]));
  const floors = new Map<string, BuiltFloor>();
  for (const def of BUILDINGS) {
    b.within(def.position, 0, () => {
      b.setChunk("exterior", false);
      buildShell(b, def.shell);
      def.extras?.(b);
      b.setChunk(def.chunk, true);
      for (const id of def.plans) {
        const src = byId.get(id);
        if (!src) continue;
        const plan = compactPlan(src);
        b.within(V(0, plan.elevation, 0), 0, () => {
          floors.set(id, buildBlueprintFloor(b, plan, TALL.has(id) ? 4.8 : 4.0));
        });
      }
      if (def.chunk === "cellhouseB") {
        connectStairs(b, floors, "cellhouse-b-0", "cellhouse-b-1", "stairn");
        connectStairs(b, floors, "cellhouse-b-0", "cellhouse-b-1", "stairs");
      }
      if (def.chunk === "hq") {
        connectStairs(b, floors, "hq-0", "hq-1", "stairs");
        nidraShaft(b, floors);
      }
      if (def.chunk === "maintenance") connectStairs(b, floors, "maintenance-b1", "maintenance-ground", "stair");
    });
  }
  wayfinding(b);
  return floors;
}

function entrance(floor: BuiltFloor, roomId: string): Entrance {
  const r = floor.rooms.get(roomId)!;
  for (const d of floor.plan.doors) {
    if (d.a !== roomId && d.b !== roomId) continue;
    if (d.kind === "staff" && roomId === "stairn" && floor.plan.id.startsWith("cellhouse-b")) continue;
    if (d.axis === "x") return { side: Math.abs(d.y - r.y) < 0.01 ? "n" : "s", offset: d.x - r.x - r.w / 2 };
    return { side: Math.abs(d.x - r.x) < 0.01 ? "w" : "e", offset: d.y - r.y - r.d / 2 };
  }
  return { side: "s", offset: 0 };
}

/** CampusInteriorAssembly._connect_stairs: a switchback in the lower floor's stair room. */
function connectStairs(b: StaticBuilder, floors: Map<string, BuiltFloor>, lowerId: string, upperId: string, roomId: string, buildLower = true, continues = false): void {
  const lower = floors.get(lowerId);
  const upper = floors.get(upperId);
  if (!lower || !upper) return;
  const r = lower.rooms.get(roomId)!;
  const local = lower.point(r.x + r.w / 2, r.y + r.d / 2, lower.plan.elevation);
  const secondary = lowerId === "cellhouse-b-0" && roomId === "stairn" ? [{ side: "e" as const, offset: -3.85, width: 1.1 }] : [];
  b.within(local, 0, () =>
    switchbackStair(b, {
      width: r.w,
      depth: r.d,
      lower: entrance(lower, roomId),
      upper: entrance(upper, roomId),
      secondaryUpper: secondary,
      buildLowerLanding: buildLower,
      continuesAbove: continues,
    }),
  );
}

/** HQ's north stair runs B2 → sealed B1 shaft → ground → upper. */
function nidraShaft(b: StaticBuilder, floors: Map<string, BuiltFloor>): void {
  const b2 = floors.get("nidra-b2");
  if (!b2) return;
  const r = b2.rooms.get("stairn")!;
  const c = b2.point(r.x + r.w / 2, r.y + r.d / 2, 0);
  b.within(V(c.x, -4, c.z), 0, () => {
    for (const x of [-3, 3]) b.box(V(x, 2, 0), V(0.22, 4, 9.22), { mat: "concrete", color: 0x676f66 });
    for (const z of [-4.5, 4.5]) b.box(V(0, 2, z), V(6, 4, 0.22), { mat: "concrete", color: 0x676f66 });
  });
  for (const elevation of [-8, -4]) {
    b.within(V(c.x, elevation, c.z), 0, () =>
      switchbackStair(b, { width: 6, depth: 9, lower: { side: "s", offset: 0 }, upper: { side: "s", offset: 0 }, continuesAbove: true, buildLowerLanding: elevation === -8 }),
    );
  }
  connectStairs(b, floors, "hq-0", "hq-1", "stairn", false, false);
}

function cellhouseBFence(b: StaticBuilder, w: number, d: number): void {
  const fw = w + 8;
  const fd = d + 8;
  const fh = 3.6;
  const seg = (center: Vector3, size: Vector3) => {
    b.box(center, size, { mat: "fence", color: 0xffffff, occlude: false });
    // Top rail + razor coil.
    const alongX = size.x > size.z;
    const len = alongX ? size.x : size.z;
    b.box(V(center.x, fh + 0.03, center.z), alongX ? V(len, 0.06, 0.08) : V(0.08, 0.06, len), { mat: "metal_ext", collide: false });
    b.cylinder(V(center.x, fh + 0.28, center.z), 0.22, len, { mat: "iron", collide: false, quat: alongX ? qz90 : qx90 });
  };
  const ns = (fw - 7.2) / 2;
  const nc = 3.6 + ns / 2;
  seg(V(-nc, fh / 2, -fd / 2), V(ns, fh, 0.06));
  seg(V(nc, fh / 2, -fd / 2), V(ns, fh, 0.06));
  seg(V(0, fh / 2, fd / 2), V(fw, fh, 0.06));
  seg(V(fw / 2, fh / 2, 0), V(0.06, fh, fd));
  const ws = (fd - 3.0) / 2;
  const wc = 1.5 + ws / 2;
  seg(V(-fw / 2, fh / 2, -wc), V(0.06, fh, ws));
  seg(V(-fw / 2, fh / 2, wc), V(0.06, fh, ws));
  for (let x = -fw / 2; x <= fw / 2 + 0.01; x += 3) for (const z of [-fd / 2, fd / 2]) b.box(V(x, fh / 2, z), V(0.1, fh, 0.1), { mat: "metal_ext", color: 0x4b524d, collide: false });
  for (let z = -fd / 2; z <= fd / 2 + 0.01; z += 3) for (const x of [-fw / 2, fw / 2]) b.box(V(x, fh / 2, z), V(0.1, fh, 0.1), { mat: "metal_ext", color: 0x4b524d, collide: false });
  for (const cfg of [
    { name: "SecurityPerimeterWestGate", width: 3.0, pos: V(-(w + 8) / 2 - 0.28, 0, 0), yaw: -Math.PI / 2 },
    { name: "SecurityPerimeterNorthGate", width: 7.2, pos: V(0, 0, -(d + 8) / 2 - 0.28), yaw: Math.PI },
  ]) {
    b.door({
      kind: "gate", position: cfg.pos, yaw: cfg.yaw, width: cfg.width, height: 3.6, requiredKey: "security_key",
      persistentId: cfg.name, displayName: "High Security Sector Gate", startsLocked: true, openDirection: 1, slideDistance: cfg.width * 0.9, color: 0x343a38,
    });
  }
}

const qz90 = new Quaternion().setFromAxisAngle(new Vector3(0, 0, 1), Math.PI / 2);
const qx90 = new Quaternion().setFromAxisAngle(new Vector3(1, 0, 0), Math.PI / 2);

function wayfinding(b: StaticBuilder): void {
  b.setChunk("exterior", false);
  for (const cfg of [
    { pos: V(-27.5, 0, 8), text: "CELLHOUSE A  ←\nCAFETERIA  ↑\nMEDICAL / GYM / POOL  ↓" },
    { pos: V(27.5, 0, 8), text: "HIGH SECURITY  →\nSECURITY HQ  ↑\nMAINTENANCE  ↓" },
  ]) {
    b.box(cfg.pos.clone().add(V(0, 1.2, 0)), V(0.12, 2.4, 0.12), { mat: "metal_ext", color: 0x3a443d });
    b.box(cfg.pos.clone().add(V(0, 2.1, 0)), V(2.5, 1.0, 0.1), { mat: "metal_ext", color: 0x263b30, collide: false });
    b.sign(cfg.text, cfg.pos.clone().add(V(0, 2.1, 0.06)), 0, 0xd9dfc9, 0.0035);
    b.sign(cfg.text, cfg.pos.clone().add(V(0, 2.1, -0.06)), Math.PI, 0xd9dfc9, 0.0035);
  }
}
