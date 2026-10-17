import { Quaternion, Vector3 } from "three";
import type { StaticBuilder } from "../builder";
import {
  V, bench, boxesStack, cctvCamera, desk, electricalBox, locker, monitor, noticeBoard, officeChair, shelfUnit, table, trashBin, wallClock,
} from "../props";
import type { PlanRoom } from "./plans";

export interface Opening {
  position: Vector3; // relative to the room centre
  width: number;
  axis: "x" | "z";
  kind: string;
}

type Fn = (b: StaticBuilder) => void;
const qx = (a: number) => new Quaternion().setFromAxisAngle(new Vector3(1, 0, 0), a);

/**
 * Compact port of CampusRoomFurnisher.dress: deliberate room-local recipes with
 * doorway reservations (nothing is placed within a door's swing/approach).
 */
export function furnishRoom(b: StaticBuilder, planId: string, r: PlanRoom, openings: Opening[], storyHeight: number): void {
  const ctx = new RoomContext(b, r, openings);
  const id = r.id;
  const label = r.label.toUpperCase();
  const key = `${planId}:${id}`;

  if (r.type === "cell") return secureCell(ctx);
  if (r.type === "corridor") return corridor(ctx, storyHeight);
  if (planId === "food-ground") {
    if (id === "dining") return dining(ctx);
    if (id === "kitchen") return kitchen(ctx);
    if (id === "prep") return ctx.rowAlong("n", 2.0, 0.8, (bb) => table(bb, 1.8, 0.75, 0.9, 0x9aa19c)), ctx.center((bb) => table(bb, 2.4, 1.0, 0.9, 0x9aa19c));
    if (id === "serving") return serving(ctx);
    if (id === "wash") return ctx.rowAlong("e", 1.8, 0.8, sinkUnit), ctx.rowAlong("w", 1.9, 0.5, (bb) => shelfUnit(bb, 1.6, 1.8, 0.45, 0x8d948f));
    if (id === "dry" || id === "cold") return ctx.perimeter(2.0, 0.5, (bb) => shelfUnit(bb, 1.8, 2.0, 0.5, id === "cold" ? 0xa3aaa6 : 0x5c6660));
    if (id === "receiving") return ctx.scatter(4, 1.2, (bb, i) => boxesStack(bb, i + 3)), ctx.rowAlong("n", 2.2, 0.5, (bb) => shelfUnit(bb));
  }
  if (planId === "medical-ground") {
    if (id === "ward") return ward(ctx);
    if (id === "exam" || id === "treatment") return ctx.rowAlong("n", 2.6, 0.9, examBed), ctx.corner((bb) => desk(bb, 1.4, 0.65)), ctx.rowAlong("s", 1.2, 0.45, (bb) => locker(bb, 0xd5dcd6));
    if (id === "consult") return ctx.center((bb) => { desk(bb, 1.6, 0.8); bb.within(V(0, 0, -0.75), 0, () => officeChair(bb)); bb.within(V(0, 0, 0.75), Math.PI, () => officeChair(bb)); });
    if (id === "medicine") return ctx.perimeter(1.4, 0.5, (bb) => locker(bb, 0xc9d1cb));
    if (id === "gym") return gym(ctx);
    if (id === "changing") return ctx.rowAlong("n", 0.7, 0.55, (bb) => locker(bb, 0x55708a)), ctx.rowAlong("s", 2.2, 0.45, bench);
    if (id === "showers") return showers(ctx);
    if (id === "toilets") return toilets(ctx);
  }
  if (planId.startsWith("hq") || planId === "admin-ground" || planId.startsWith("cellhouse-b")) {
    if (/SURVEILLANCE|CONTROL/.test(label)) return surveillance(ctx);
    if (/SERVER/.test(label)) return ctx.rowsOf(2, 1.1, (bb) => serverRack(bb));
    if (/KEY|EVIDENCE|EQUIPMENT|RECORDS|ARCHIVE/.test(label)) return ctx.perimeter(1.6, 0.5, (bb) => shelfUnit(bb, 1.5, 2.1, 0.5, 0x46514b));
    if (/VISITATION/.test(label)) return visitation(ctx);
    if (/BRIEFING|PLANNING|INTERVIEW|PROCESSING|CHECKPOINT/.test(label)) return ctx.center((bb) => meetingTable(bb, Math.min(4, r.w - 3), 1.2));
    if (/HOLDING|WAITING/.test(label)) return ctx.rowAlong("n", 2.2, 0.45, bench), ctx.rowAlong("s", 2.2, 0.45, bench);
    if (/WC/.test(label)) return toilets(ctx);
    if (/SPECIAL ROOM/.test(label)) return ctx.center((bb) => restraintChair(bb));
    return offices(ctx);
  }
  if (planId.startsWith("maintenance")) {
    if (id === "workshop") return workshop(ctx);
    if (id === "dirty" || id === "clean") return laundry(ctx, id === "clean");
    if (id === "tool") return ctx.rowAlong("w", 1.9, 0.5, (bb) => shelfUnit(bb, 1.7, 2.0, 0.5, 0x5c6660)), ctx.rowAlong("n", 2.5, 0.8, workbench);
    if (/PLANT|DISTRIBUTION|PUMP|UTILIT|VENTILATION|SUMP/.test(label)) return plant(ctx, key);
    return ctx.perimeter(2.0, 0.5, (bb) => shelfUnit(bb)), ctx.scatter(3, 1.4, (bb, i) => boxesStack(bb, i + 11));
  }
  if (planId === "nidra-b2") {
    if (id === "lab" || id === "chem") return lab(ctx);
    if (id.startsWith("interrogation")) return ctx.center((bb) => { table(bb, 1.4, 0.8, 0.76, 0x6d736f, "steel"); restraintChairAt(bb, V(0, 0, -0.9)); bb.within(V(0, 0, 0.9), Math.PI, () => officeChair(bb)); });
    if (id === "subjects") return ctx.rowAlong("n", 3.0, 1.0, examBed), ctx.rowAlong("s", 3.0, 0.6, (bb) => restraintChair(bb));
    if (id === "samples") return ctx.perimeter(1.4, 0.7, fridgeUnit);
    if (id === "hazmat") return ctx.perimeter(1.2, 0.5, (bb) => locker(bb, 0xc8a335));
    if (id === "clean") return ctx.rowAlong("n", 0.7, 0.5, (bb) => locker(bb, 0xc9d1cb)), ctx.rowAlong("s", 2.2, 0.45, bench);
    if (id === "observation") return ctx.rowAlong("n", 2.0, 0.7, (bb) => { desk(bb, 1.6, 0.6); bb.within(V(0, 0, 0), 0, () => monitor(bb)); });
    return ctx.perimeter(1.6, 0.5, (bb) => shelfUnit(bb, 1.5, 2.1, 0.5, 0x8d9894));
  }
  return offices(ctx);
}

// ── Placement helper ─────────────────────────────────────────────────────────
class RoomContext {
  readonly hw: number;
  readonly hd: number;
  constructor(readonly b: StaticBuilder, readonly r: PlanRoom, readonly openings: Opening[]) {
    this.hw = r.w / 2;
    this.hd = r.d / 2;
  }

  /** True if an item footprint (centre, half extents) intrudes on a door reservation. */
  blocked(x: number, z: number, hx: number, hz: number): boolean {
    for (const o of this.openings) {
      if (o.kind === "hatch" || o.kind === "window" || o.kind === "sealed") continue;
      const ox = o.position.x;
      const oz = o.position.z;
      const along = o.width / 2 + 0.55;
      const depth = 1.7;
      const zx = o.axis === "x" ? along : depth;
      const zz = o.axis === "x" ? depth : along;
      if (Math.abs(x - ox) < hx + zx && Math.abs(z - oz) < hz + zz) return true;
    }
    return Math.abs(x) + hx > this.hw - 0.12 || Math.abs(z) + hz > this.hd - 0.12;
  }

  place(x: number, z: number, yaw: number, hx: number, hz: number, fn: Fn): boolean {
    const c = Math.abs(Math.cos(yaw));
    const ex = c > 0.5 ? hx : hz;
    const ez = c > 0.5 ? hz : hx;
    if (this.blocked(x, z, ex, ez)) return false;
    this.b.within(V(x, 0, z), yaw, () => fn(this.b));
    return true;
  }

  /** Items along one wall, facing into the room. Item local +Z faces the room. */
  rowAlong(side: "n" | "s" | "e" | "w", spacing: number, depth: number, fn: Fn, width = spacing * 0.9): void {
    const horizontal = side === "n" || side === "s";
    const len = horizontal ? this.r.w : this.r.d;
    const count = Math.max(1, Math.floor((len - 0.6) / spacing));
    const yaw = side === "n" ? 0 : side === "s" ? Math.PI : side === "w" ? Math.PI / 2 : -Math.PI / 2;
    const inset = depth / 2 + 0.16;
    for (let i = 0; i < count; i++) {
      const t = -((count - 1) * spacing) / 2 + i * spacing;
      const x = horizontal ? t : side === "w" ? -this.hw + inset : this.hw - inset;
      const z = horizontal ? (side === "n" ? -this.hd + inset : this.hd - inset) : t;
      this.place(x, z, yaw, width / 2, depth / 2, fn);
    }
  }

  perimeter(spacing: number, depth: number, fn: Fn): void {
    for (const s of ["n", "s", "e", "w"] as const) this.rowAlong(s, spacing, depth, fn, Math.min(spacing * 0.9, 1.8));
  }

  center(fn: Fn): void {
    this.b.within(V(0, 0, 0), 0, () => fn(this.b));
  }

  corner(fn: Fn): void {
    this.place(this.hw - 1.1, -this.hd + 0.6, 0, 0.8, 0.4, fn);
  }

  rowsOf(rows: number, spacing: number, fn: Fn): void {
    const cols = Math.max(1, Math.floor((this.r.w - 2) / spacing));
    for (let rr = 0; rr < rows; rr++) {
      const z = rows === 1 ? 0 : -this.hd * 0.45 + (rr * this.hd * 0.9) / (rows - 1);
      for (let c = 0; c < cols; c++) this.place(-((cols - 1) * spacing) / 2 + c * spacing, z, 0, spacing * 0.45, 0.5, fn);
    }
  }

  scatter(count: number, radius: number, fn: (b: StaticBuilder, i: number) => void): void {
    const seed = this.r.x * 13.1 + this.r.y * 7.7;
    for (let i = 0; i < count; i++) {
      const rx = (Math.sin(seed + i * 12.9898) * 43758.5453) % 1;
      const rz = (Math.sin(seed + i * 78.233) * 12345.678) % 1;
      const x = rx * (this.hw - radius);
      const z = rz * (this.hd - radius);
      this.place(x, z, rx * 3, 0.45, 0.45, (bb) => fn(bb, i));
    }
  }
}

// ── Recipes ──────────────────────────────────────────────────────────────────
function corridor(ctx: RoomContext, storyHeight: number): void {
  const long = Math.max(ctx.r.w, ctx.r.d);
  if (long > 10) {
    // Exposed service pipes along the ceiling of long corridors.
    const alongX = ctx.r.w >= ctx.r.d;
    const off = (alongX ? ctx.hd : ctx.hw) - 0.35;
    for (const [dy, rad] of [[0.35, 0.06], [0.55, 0.045]] as const) {
      const y = storyHeight - dy;
      const q = new Quaternion().setFromAxisAngle(new Vector3(0, 0, 1), Math.PI / 2);
      if (alongX) ctx.b.cylinder(V(0, y, -off), rad, ctx.r.w - 0.3, { mat: "steel", color: 0x7e837d, quat: q, collide: false });
      else ctx.b.cylinder(V(-off, y, 0), rad, ctx.r.d - 0.3, { mat: "steel", color: 0x7e837d, quat: qx(Math.PI / 2), collide: false });
    }
    ctx.rowAlong(ctx.r.w >= ctx.r.d ? "n" : "w", 9, 0.4, (bb) => bb.within(V(0, 2.9, 0.05), 0, () => cctvCamera(bb)), 0.4);
  }
  if (long > 8) ctx.rowAlong(ctx.r.w >= ctx.r.d ? "s" : "e", 12, 0.3, (bb) => { noticeBoard(bb); trashBin(bb); }, 1.6);
}

function secureCell(ctx: RoomContext): void {
  ctx.rowAlong("n", ctx.r.w, 1.0, (bb) => {
    bb.box(V(0, 0.43, 0), V(2.0, 0.12, 0.95), { mat: "concrete", color: 0x5a5f5b });
    bb.box(V(0, 0.55, 0), V(1.9, 0.14, 0.85), { mat: "fabric", color: 0x4d5560, collide: false });
  }, 2.1);
  ctx.place(ctx.hw - 0.5, ctx.hd - 0.5, Math.PI, 0.3, 0.3, (bb) => {
    bb.cylinder(V(0, 0.22, 0), 0.22, 0.44, { mat: "steel", color: 0x8a928e, collide: true });
    bb.cylinder(V(0, 0.48, 0.1), 0.28, 0.16, { mat: "steel", color: 0x9aa29e });
  });
}

function dining(ctx: RoomContext): void {
  const cols = 4;
  const rows = 3;
  for (let rr = 0; rr < rows; rr++) for (let c = 0; c < cols; c++) {
    const x = -ctx.hw + 3.2 + c * ((ctx.r.w - 6.4) / (cols - 1));
    const z = -ctx.hd + 3.0 + rr * ((ctx.r.d - 6) / (rows - 1));
    ctx.place(x, z, 0, 1.4, 1.2, (bb) => {
      table(bb, 2.4, 0.9, 0.76, 0x8f958c, "steel");
      for (const s of [-1, 1]) {
        bb.box(V(0, 0.45, s * 0.85), V(2.4, 0.06, 0.32), { mat: "steel", color: 0x7b827c });
        bb.box(V(0, 0.22, s * 0.85), V(0.08, 0.44, 0.08), { mat: "steel", color: 0x5f6661, collide: false });
      }
    });
  }
  ctx.rowAlong("w", 6, 0.3, (bb) => { noticeBoard(bb); wallClock(bb); }, 1.6);
}

function kitchen(ctx: RoomContext): void {
  ctx.rowAlong("n", 2.2, 0.9, (bb) => {
    bb.box(V(0, 0.45, 0), V(2.0, 0.9, 0.85), { mat: "steel", color: 0x9ba29e });
    bb.box(V(0, 0.92, 0), V(2.0, 0.04, 0.85), { mat: "steel", color: 0xb5bcb8, collide: false });
    for (const x of [-0.5, 0.5]) bb.cylinder(V(x, 0.96, 0.05), 0.2, 0.04, { mat: "dark", color: 0x1e2220 });
    bb.box(V(0, 2.5, -0.1), V(2.1, 0.6, 1.1), { mat: "steel", color: 0x8e9591, collide: false });
  });
  for (const x of [-ctx.hw * 0.4, ctx.hw * 0.4]) ctx.place(x, 0.8, 0, 1.6, 0.6, (bb) => table(bb, 3.0, 1.1, 0.9, 0xa3aaa6));
  ctx.rowAlong("s", 2.4, 0.7, (bb) => shelfUnit(bb, 2.0, 1.8, 0.6, 0x9aa19c));
}

function serving(ctx: RoomContext): void {
  ctx.rowAlong("w", 2.6, 0.9, (bb) => {
    bb.box(V(0, 0.45, 0), V(2.3, 0.9, 0.8), { mat: "steel", color: 0x9ba29e });
    for (let i = -1; i <= 1; i++) bb.box(V(i * 0.65, 0.93, 0), V(0.5, 0.06, 0.4), { mat: "steel", color: 0xc7cdc9, collide: false });
  });
}

function sinkUnit(b: StaticBuilder): void {
  b.box(V(0, 0.45, 0), V(1.6, 0.9, 0.7), { mat: "steel", color: 0x9ea6a2 });
  b.box(V(0, 0.88, 0.02), V(1.3, 0.06, 0.5), { mat: "dark", color: 0x3a3f3c, collide: false });
  b.cylinder(V(0, 1.1, -0.28), 0.025, 0.4, { mat: "steel" });
}

function ward(ctx: RoomContext): void {
  for (const side of ["w", "e"] as const) ctx.rowAlong(side, 3.6, 2.1, (bb) => {
    hospitalBed(bb);
    bb.box(V(0.95, 0.4, -0.55), V(0.45, 0.8, 0.45), { mat: "metal", color: 0xd0d6d1 });
    bb.cylinder(V(-0.9, 1.0, -0.4), 0.02, 2.0, { mat: "steel" });
    bb.box(V(1.25, 1.1, 0.4), V(0.03, 2.2, 2.0), { mat: "fabric", color: 0x7d9aa0, collide: false });
  }, 2.6);
}

function hospitalBed(b: StaticBuilder): void {
  b.box(V(0, 0.55, 0.1), V(0.95, 0.1, 2.0), { mat: "steel", color: 0xa9b1ad });
  b.box(V(0, 0.68, 0.1), V(0.9, 0.16, 1.92), { mat: "fabric", color: 0xd8dcd6, collide: false });
  b.box(V(0, 0.8, -0.72), V(0.7, 0.1, 0.36), { mat: "fabric", color: 0xeceee8, collide: false });
  b.box(V(0, 0.85, -0.9), V(0.95, 0.6, 0.05), { mat: "steel", color: 0x9aa29e, collide: false });
  for (const x of [-0.42, 0.42]) for (const z of [-0.85, 1.05]) b.box(V(x, 0.25, z), V(0.05, 0.5, 0.05), { mat: "steel", collide: false });
}

function examBed(b: StaticBuilder): void {
  b.box(V(0, 0.75, 0), V(0.75, 0.12, 1.9), { mat: "fabric", color: 0x3d5f68 });
  b.box(V(0, 0.36, 0), V(0.5, 0.7, 1.5), { mat: "metal", color: 0xbac2bd, collide: false });
}

function gym(ctx: RoomContext): void {
  ctx.rowAlong("n", 3.2, 1.3, (bb) => {
    for (const x of [-0.6, 0.6]) bb.box(V(x, 1.1, 0), V(0.08, 2.2, 0.08), { mat: "dark" });
    bb.cylinder(V(0, 1.4, 0), 0.03, 1.8, { mat: "steel", quat: new Quaternion().setFromAxisAngle(new Vector3(0, 0, 1), Math.PI / 2) });
    for (const x of [-0.75, 0.75]) bb.cylinder(V(x, 1.4, 0), 0.22, 0.06, { mat: "dark", color: 0x1c1f1d, quat: new Quaternion().setFromAxisAngle(new Vector3(0, 0, 1), Math.PI / 2) });
    bb.box(V(0, 0.42, 0.6), V(0.35, 0.1, 1.2), { mat: "fabric", color: 0x2b2f2d });
  });
  ctx.rowAlong("s", 2.6, 1.0, (bb) => {
    bb.box(V(0, 0.45, 0), V(0.5, 0.9, 1.3), { mat: "metal", color: 0x3a3f3c });
    bb.box(V(0, 1.0, -0.5), V(0.5, 0.25, 0.2), { mat: "plastic", color: 0x222624, collide: false });
  });
  ctx.place(ctx.hw * 0.5, 0, 0, 0.3, 0.3, (bb) => {
    bb.box(V(0, 3.4, 0), V(0.1, 1.2, 0.1), { mat: "steel", collide: false });
    bb.cylinder(V(0, 2.1, 0), 0.22, 1.2, { mat: "fabric", color: 0x5b2b25, collide: true });
  });
}

function showers(ctx: RoomContext): void {
  ctx.rowAlong("w", 2.2, 1.0, showerStall, 1.2);
  ctx.rowAlong("e", 2.2, 1.0, showerStall, 1.2);
}

function showerStall(b: StaticBuilder): void {
  for (const x of [-0.6, 0.6]) b.box(V(x, 1.0, 0.1), V(0.06, 2.0, 1.0), { mat: "tile_shower", color: 0xd5dad5 });
  b.cylinder(V(0, 2.0, -0.35), 0.06, 0.06, { mat: "steel" });
  b.box(V(0, 2.05, -0.43), V(0.04, 0.04, 0.2), { mat: "steel", collide: false });
  b.cylinder(V(0, 0.005, 0.1), 0.08, 0.01, { mat: "dark", collide: false, shadow: false });
}

function toilets(ctx: RoomContext): void {
  ctx.rowAlong("w", 1.4, 1.5, (bb) => {
    for (const x of [-0.68, 0.68]) bb.box(V(x, 1.0, 0), V(0.05, 1.9, 1.5), { mat: "metal", color: 0x7b8f8a });
    bb.cylinder(V(0, 0.2, -0.3), 0.2, 0.4, { mat: "plastic", color: 0xe4e6e0, collide: false });
    bb.box(V(0, 0.65, -0.62), V(0.4, 0.4, 0.15), { mat: "plastic", color: 0xe4e6e0, collide: false });
  }, 1.4);
  ctx.rowAlong("e", 1.1, 0.5, (bb) => {
    bb.box(V(0, 0.95, -0.05), V(0.45, 0.6, 0.35), { mat: "plastic", color: 0xe8eae4, collide: false });
    bb.box(V(0.4, 1.0, 0.1), V(0.04, 1.2, 0.6), { mat: "metal", color: 0x7b8f8a, collide: false });
  });
}

function offices(ctx: RoomContext): void {
  const n = Math.max(1, Math.min(4, Math.floor(ctx.r.w / 3)));
  for (let i = 0; i < n; i++) {
    const x = -ctx.hw + (i + 0.5) * (ctx.r.w / n);
    ctx.place(x, -ctx.hd + 1.2, 0, 0.85, 0.75, (bb) => {
      desk(bb, 1.5, 0.7);
      bb.within(V(0, 0, -0.1), 0, () => monitor(bb));
      bb.within(V(0, 0, 0.7), Math.PI, () => officeChair(bb));
      bb.box(V(-0.45, 0.8, 0.05), V(0.3, 0.02, 0.22), { mat: "paper", color: 0xd6d2c0, collide: false, shadow: false, yaw: 0.2 });
    });
  }
  ctx.rowAlong("s", 1.2, 0.55, (bb) => fileCabinet(bb));
  ctx.rowAlong("e", 4, 0.1, noticeBoard, 1.6);
}

function fileCabinet(b: StaticBuilder): void {
  b.box(V(0, 0.66, 0), V(0.5, 1.32, 0.6), { mat: "metal", color: 0x5f6863 });
  for (let i = 0; i < 4; i++) b.box(V(0, 0.18 + i * 0.32, 0.305), V(0.16, 0.03, 0.02), { mat: "steel", collide: false, shadow: false });
}

function meetingTable(b: StaticBuilder, w: number, d: number): void {
  table(b, w, d, 0.76, 0x6e5a45, "wood");
  const n = Math.max(1, Math.floor(w / 1.0));
  for (let i = 0; i < n; i++) {
    const x = -w / 2 + 0.5 + i * ((w - 1) / Math.max(1, n - 1));
    b.within(V(x, 0, -d / 2 - 0.45), 0, () => officeChair(b));
    b.within(V(x, 0, d / 2 + 0.45), Math.PI, () => officeChair(b));
  }
}

function surveillance(ctx: RoomContext): void {
  ctx.rowAlong("n", ctx.r.w - 1.2, 0.3, (bb) => {
    const w = ctx.r.w - 1.6;
    const cols = Math.max(2, Math.floor(w / 0.75));
    for (let r = 0; r < 3; r++) for (let c = 0; c < cols; c++) {
      const x = -w / 2 + 0.375 + c * (w - 0.75) / (cols - 1);
      bb.box(V(x, 1.35 + r * 0.5, 0), V(0.68, 0.44, 0.08), { mat: "dark", color: 0x161a19, collide: false });
      bb.box(V(x, 1.35 + r * 0.5, 0.045), V(0.62, 0.38, 0.01), { mat: "screen", collide: false, shadow: false });
    }
  }, ctx.r.w - 1.2);
  for (const z of [-0.6, 1.4]) ctx.place(0, z, 0, Math.min(3, ctx.hw - 1), 0.5, (bb) => {
    const w = Math.min(6, ctx.r.w - 2.4);
    bb.box(V(0, 0.45, 0), V(w, 0.9, 0.75), { mat: "dark", color: 0x262b29 });
    for (let x = -w / 2 + 0.6; x < w / 2; x += 1.2) bb.within(V(x, 0.05, -0.15), 0, () => monitor(bb));
  });
}

function serverRack(b: StaticBuilder): void {
  b.box(V(0, 1.1, 0), V(0.8, 2.2, 0.95), { mat: "dark", color: 0x1c2225 });
  for (let i = 0; i < 9; i++) {
    b.box(V(0, 0.3 + i * 0.2, 0.48), V(0.7, 0.12, 0.01), { mat: "dark", color: 0x2a3033, collide: false, shadow: false });
    b.box(V(0.28, 0.3 + i * 0.2, 0.49), V(0.03, 0.02, 0.01), { mat: i % 3 ? "emissive_green" : "emissive_cyan", collide: false, shadow: false });
  }
}

function visitation(ctx: RoomContext): void {
  const n = Math.floor((ctx.r.w - 2) / 1.6);
  for (let i = 0; i < n; i++) {
    const x = -ctx.hw + 1.4 + i * 1.6;
    ctx.b.box(V(x, 0.45, 0), V(1.4, 0.9, 0.5), { mat: "wood", color: 0x7c6a52 });
    ctx.b.box(V(x, 1.5, 0), V(1.2, 1.2, 0.04), { mat: "glass", color: 0x6d8f92, occlude: false });
    ctx.b.box(V(x + 0.7, 1.3, 0), V(0.06, 1.6, 0.6), { mat: "metal", color: 0x5c6660 });
    ctx.b.box(V(x - 0.3, 1.25, 0.2), V(0.06, 0.16, 0.06), { mat: "dark", collide: false });
  }
}

function workshop(ctx: RoomContext): void {
  ctx.rowAlong("n", 2.6, 0.85, workbench);
  ctx.rowAlong("s", 2.0, 0.5, (bb) => shelfUnit(bb, 1.8, 2.0, 0.5, 0x5c6660));
  ctx.rowAlong("w", 1.8, 0.2, (bb) => {
    bb.box(V(0, 1.6, 0.03), V(1.5, 1.0, 0.04), { mat: "wood", color: 0x6f5a40, collide: false });
    for (let i = 0; i < 6; i++) bb.box(V(-0.6 + i * 0.24, 1.6 + Math.sin(i) * 0.2, 0.08), V(0.05, 0.35, 0.04), { mat: "steel", collide: false, shadow: false });
  }, 1.6);
  ctx.place(0, 0.5, 0, 1.2, 0.6, (bb) => table(bb, 2.2, 1.0, 0.85, 0x6d736f, "metal"));
}

function workbench(b: StaticBuilder): void {
  b.box(V(0, 0.9, 0), V(2.2, 0.08, 0.8), { mat: "wood", color: 0x6b5843 });
  for (const x of [-1.0, 1.0]) b.box(V(x, 0.45, 0), V(0.08, 0.9, 0.7), { mat: "metal", color: 0x4c5550, collide: false });
  b.box(V(0, 0.25, 0), V(2.0, 0.04, 0.7), { mat: "metal", color: 0x4c5550, collide: false });
  b.box(V(0.7, 1.0, -0.1), V(0.3, 0.12, 0.2), { mat: "metal", color: 0x9a3b2c, collide: false });
  b.box(V(-0.5, 0.97, 0.1), V(0.4, 0.06, 0.25), { mat: "steel", collide: false, shadow: false });
  b.blocker(V(0, 0.47, 0), V(2.2, 0.94, 0.8));
}

function laundry(ctx: RoomContext, clean: boolean): void {
  ctx.rowAlong("n", 1.3, 0.9, (bb) => {
    bb.box(V(0, 0.65, 0), V(1.1, 1.3, 0.85), { mat: "steel", color: 0xb7beba });
    bb.cylinder(V(0, 0.7, 0.43), 0.32, 0.04, { mat: "glass", quat: qx(Math.PI / 2), collide: false });
    bb.box(V(0.3, 1.18, 0.43), V(0.3, 0.1, 0.02), { mat: "dark", collide: false });
  });
  if (clean) ctx.place(0, 1, 0, 1.6, 0.6, (bb) => table(bb, 3.0, 1.0, 0.9, 0x9aa19c));
  else ctx.rowAlong("s", 1.8, 0.8, (bb) => { bb.box(V(0, 0.45, 0), V(1.0, 0.9, 0.7), { mat: "fabric", color: 0x3e4f5c }); });
}

function plant(ctx: RoomContext, key: string): void {
  const seed = key.length;
  ctx.rowsOf(2, 3.2, (bb) => {
    bb.box(V(0, 0.08, 0), V(2.4, 0.16, 1.4), { mat: "metal", color: 0x4a5450 });
    bb.cylinder(V(0, 0.95, 0), 0.6, 1.4, { mat: "metal", color: seed % 2 ? 0x51685d : 0x5d6a72, quat: new Quaternion().setFromAxisAngle(new Vector3(0, 0, 1), Math.PI / 2), collide: true });
    bb.box(V(0.9, 0.7, 0.5), V(0.4, 0.5, 0.3), { mat: "dark", collide: false });
    bb.cylinder(V(-0.9, 2.2, 0), 0.08, 2.2, { mat: "steel", collide: false });
  });
  ctx.rowAlong("e", 1.6, 0.3, electricalBox, 1);
}

function lab(ctx: RoomContext): void {
  ctx.rowAlong("n", 2.2, 0.8, (bb) => {
    table(bb, 2.0, 0.75, 0.9, 0xdfe4e0, "metal");
    bb.box(V(-0.5, 1.05, -0.1), V(0.35, 0.3, 0.3), { mat: "plastic", color: 0xd8dcd8, collide: false });
    bb.cylinder(V(0.3, 1.0, 0), 0.04, 0.18, { mat: "glass", collide: false });
    bb.cylinder(V(0.45, 1.0, 0.05), 0.035, 0.14, { mat: "glass", collide: false });
    bb.within(V(0.55, 0, -0.15), 0, () => monitor(bb));
  });
  ctx.rowAlong("s", 1.3, 0.7, fridgeUnit);
  ctx.place(0, 0, 0, 1.3, 0.6, (bb) => table(bb, 2.4, 1.0, 0.9, 0xdfe4e0, "metal"));
}

function fridgeUnit(b: StaticBuilder): void {
  b.box(V(0, 0.95, 0), V(1.0, 1.9, 0.7), { mat: "metal", color: 0xdfe4e0 });
  b.box(V(0, 1.2, 0.36), V(0.85, 1.1, 0.02), { mat: "glass", collide: false });
  b.box(V(0.35, 1.75, 0.36), V(0.08, 0.04, 0.01), { mat: "emissive_cyan", collide: false, shadow: false });
}

function restraintChair(b: StaticBuilder): void {
  restraintChairAt(b, V(0, 0, 0));
}

function restraintChairAt(b: StaticBuilder, at: Vector3): void {
  b.within(at, 0, () => {
    b.box(V(0, 0.5, 0), V(0.65, 0.1, 0.6), { mat: "steel", color: 0x6d736f });
    b.box(V(0, 1.0, 0.27), V(0.65, 1.0, 0.08), { mat: "steel", color: 0x6d736f, collide: false });
    for (const x of [-0.3, 0.3]) {
      b.box(V(x, 0.7, -0.05), V(0.08, 0.06, 0.5), { mat: "steel", color: 0x6d736f, collide: false });
      b.box(V(x, 0.74, -0.1), V(0.1, 0.05, 0.12), { mat: "fabric", color: 0x3a2a20, collide: false });
    }
    b.box(V(0, 0.25, 0), V(0.5, 0.5, 0.5), { mat: "steel", color: 0x5a605c, collide: false });
  });
}

export { locker };
