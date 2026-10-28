import { Vector3 } from "three";
import type { StaticBuilder } from "../../../world/builder";
import type { BuiltFloor } from "../../../world/campus/blueprintFloor";
import { V } from "../../../world/props";
import { chunkAt, resolvePlace } from "../../place";
import type { ContentData, ContentPlace, FurnitureDef, PlateDef, Vec3 } from "./data";

interface Frame {
  position: Vector3;
  yaw: number;
}

const rotate = (o: Vec3, yaw: number) => {
  const c = Math.cos(yaw);
  const s = Math.sin(yaw);
  return new Vector3(c * o[0] + s * o[2], o[1], -s * o[0] + c * o[2]);
};

/** Resolves a content place at build time: a built door's frame or any story Place. */
function resolveFrame(p: ContentPlace, b: StaticBuilder, floors: Map<string, BuiltFloor>): Frame | null {
  if ("door" in p) {
    const d = b.doors.find((x) => x.persistentId === p.door);
    if (!d) return null;
    return { position: d.position.clone().add(rotate(p.offset ?? [0, 0, 0], d.yaw)), yaw: d.yaw + (p.yaw ?? 0) };
  }
  const r = resolvePlace(p, b.anchors, floors);
  return r ? { position: r.position, yaw: r.yaw } : null;
}

/**
 * Static part of W5: furniture the story props sit on, anchors for the
 * trigger data (`{ "anchor": id }`), the lift keypads and the doorplates.
 */
export function buildContentStatic(b: StaticBuilder, floors: Map<string, BuiltFloor>, data: ContentData | null): void {
  if (!data) return;
  const previous = b.chunkName;
  for (const def of data.anchors ?? []) {
    const frame = resolveFrame(def.at, b, floors);
    if (!frame) {
      console.warn(`[content] anchor "${def.id}": place not found`, def.at);
      continue;
    }
    b.setChunk(chunkAt(frame.position, b.chunks), true);
    const top = def.build ? furniture(b, frame, def.build) : 0;
    const local = def.local ?? [0, top, 0];
    b.anchors.set(def.id, { position: frame.position.clone().add(rotate(local, frame.yaw)), yaw: frame.yaw + (def.yaw ?? 0) });
  }
  for (const plate of data.plates ?? []) doorplate(b, floors, plate);
  b.setChunk(previous, true);
}

/** Builds one piece of furniture in its own frame; returns the height of its top surface. */
function furniture(b: StaticBuilder, frame: Frame, f: FurnitureDef): number {
  let top = 0;
  b.within(frame.position, frame.yaw, () => {
    top = build(b, f);
  });
  return top;
}

function build(b: StaticBuilder, f: FurnitureDef): number {
  const leg = { mat: "steel" as const, color: 0x6d736f, collide: false, shadow: false };
  switch (f.kind) {
    case "table":
    case "deck": {
      const [w, d, h] = f.size ?? [1.4, 0.7, 0.85];
      b.box(V(0, h, 0), V(w, 0.05, d), { mat: "steel", color: f.color ?? 0x8f958c, occlude: false });
      for (const x of [-w / 2 + 0.06, w / 2 - 0.06]) for (const z of [-d / 2 + 0.06, d / 2 - 0.06]) b.box(V(x, h / 2, z), V(0.05, h, 0.05), leg);
      b.box(V(0, 0.2, 0), V(w - 0.12, 0.03, d - 0.12), { ...leg, color: 0x5f6661 });
      if (f.kind === "deck") {
        // Reel-to-reel archive deck and stacks of labelled cassettes.
        b.box(V(0, h + 0.11, -0.05), V(0.62, 0.17, 0.4), { mat: "dark", color: 0x23282a, collide: false });
        for (const x of [-0.15, 0.15]) {
          b.cylinder(V(x, h + 0.21, -0.05), 0.11, 0.02, { mat: "plastic", color: 0x4b5254, shadow: false });
          b.cylinder(V(x, h + 0.225, -0.05), 0.03, 0.02, { mat: "steel", shadow: false });
        }
        b.box(V(0.2, h + 0.08, 0.152), V(0.12, 0.03, 0.005), { mat: "emissive_red", collide: false, shadow: false });
        for (let i = 0; i < 4; i++) b.box(V(-w / 2 + 0.16, h + 0.04 + i * 0.022, 0.12 - (i % 2) * 0.02), V(0.11, 0.018, 0.07), { mat: "plastic", color: 0x2a2b2c, collide: false, shadow: false });
      }
      b.blocker(V(0, h / 2, 0), V(w, h, d));
      return h + 0.025;
    }
    case "trolley": {
      const [w, d, h] = f.size ?? [0.8, 0.5, 0.9];
      b.box(V(0, h, 0), V(w, 0.03, d), { mat: "steel", color: f.color ?? 0xc3cac6, occlude: false });
      for (const s of [-1, 1]) b.box(V(0, h + 0.04, s * (d / 2 - 0.01)), V(w, 0.06, 0.015), { ...leg, color: 0xb2b9b5 });
      b.box(V(0, 0.3, 0), V(w - 0.04, 0.03, d - 0.04), { ...leg, color: 0xb2b9b5 });
      for (const x of [-w / 2 + 0.03, w / 2 - 0.03]) for (const z of [-d / 2 + 0.03, d / 2 - 0.03]) {
        b.box(V(x, h / 2 + 0.04, z), V(0.025, h - 0.08, 0.025), leg);
        b.cylinder(V(x, 0.04, z), 0.04, 0.03, { mat: "dark", shadow: false });
      }
      // Rows of ordinary vials and a box of paper cups.
      for (let i = 0; i < 7; i++) b.cylinder(V(-w / 2 + 0.1 + i * 0.05, h + 0.06, -0.12), 0.014, 0.09, { mat: "glass", color: 0xcfe0e4, shadow: false });
      b.box(V(-0.22, h + 0.06, 0.1), V(0.2, 0.1, 0.14), { mat: "paper", color: 0xd8d4c4, collide: false, shadow: false });
      b.blocker(V(0, h / 2, 0), V(w, h, d));
      return h + 0.015;
    }
    case "hookboard":
    case "hookstand": {
      const [w, hgt] = f.size ?? [0.7, 0.5, 0];
      const y = 1.45;
      if (f.kind === "hookstand") {
        b.box(V(0, y / 2, -0.04), V(0.08, y, 0.08), { mat: "metal", color: 0x3b423e, occlude: false });
        b.box(V(0, 0.02, -0.04), V(0.5, 0.04, 0.4), { mat: "metal", color: 0x3b423e, collide: false });
      }
      b.box(V(0, y, 0), V(w, hgt, 0.03), { mat: "wood", color: f.color ?? 0x6f5a40, collide: false });
      for (const x of [-w / 3, 0, w / 3]) b.box(V(x, y + 0.08, 0.04), V(0.02, 0.02, 0.06), { mat: "steel", color: 0xb0b6b2, collide: false, shadow: false });
      if (f.label) b.sign(f.label, V(0, y + hgt / 2 + 0.09, 0.02), 0, 0xd8d2bf, 0.0022);
      return 0;
    }
    case "junction": {
      b.box(V(0, 1.35, 0.09), V(0.46, 0.56, 0.18), { mat: "metal", color: f.color ?? 0x6b746e, collide: false });
      b.box(V(0, 1.35, 0.185), V(0.4, 0.5, 0.01), { mat: "metal", color: 0x7b847e, collide: false, shadow: false });
      b.box(V(0, 1.55, 0.192), V(0.3, 0.06, 0.004), { mat: "hazard", collide: false, shadow: false });
      b.box(V(0.03, 2.2, 0.06), V(0.05, 1.15, 0.05), { mat: "steel", collide: false, shadow: false });
      b.box(V(-0.12, 1.12, 0.2), V(0.04, 0.04, 0.02), { mat: "emissive_red", collide: false, shadow: false });
      if (f.label) b.sign(f.label, V(0, 1.72, 0.03), 0, 0xd2c98e, 0.0022);
      return 0;
    }
    case "keypad": {
      b.box(V(0, 1.3, 0.025), V(0.26, 0.4, 0.05), { mat: "steel", color: f.color ?? 0x8a928e, collide: false });
      b.box(V(0, 1.43, 0.052), V(0.18, 0.07, 0.005), { mat: "emissive_cyan", collide: false, shadow: false });
      for (let r = 0; r < 4; r++) for (let c = 0; c < 3; c++) {
        b.box(V(-0.06 + c * 0.06, 1.34 - r * 0.05, 0.054), V(0.04, 0.034, 0.008), { mat: "dark", color: 0x2a2f2c, collide: false, shadow: false });
      }
      b.box(V(0.1, 1.16, 0.052), V(0.02, 0.02, 0.005), { mat: "emissive_red", collide: false, shadow: false });
      if (f.label) b.sign(f.label, V(0, 1.6, 0.03), 0, 0xd2c98e, 0.0022);
      return 0;
    }
    case "nameplate": {
      b.box(V(0, 0.035, 0), V(0.34, 0.07, 0.05), { mat: "wood", color: f.color ?? 0x3a2e22, collide: false, shadow: false });
      if (f.label) b.sign(f.label, V(0, 0.04, 0.027), 0, 0xe2d6a8, 0.0011);
      return 0.07;
    }
  }
}

function doorplate(b: StaticBuilder, floors: Map<string, BuiltFloor>, p: PlateDef): void {
  const floor = floors.get(p.plan);
  const [a, c] = p.door;
  const door = floor?.doors.find((d) => (d.a === a && d.b === c) || (d.a === c && d.b === a));
  const side = floor?.roomCenters.get(p.side);
  if (!floor || !door || !side) {
    console.warn(`[content] doorplate ${p.plan} ${a}/${c}: door or room not found`);
    return;
  }
  const at = floor.toWorld(door.position);
  const normal = floor.toWorld(door.position.clone().add(door.normal)).sub(at);
  if (normal.dot(side.clone().sub(at)) < 0) normal.negate();
  const axis = floor.toWorld(door.position.clone().add(door.axis === "x" ? V(1, 0, 0) : V(0, 0, 1))).sub(at);
  const along = p.along ?? door.clearWidth / 2 + 0.45;
  const yaw = Math.atan2(normal.x, normal.z);
  const h = p.height ?? 1.55;
  const center = at.clone().addScaledVector(normal, 0.125).addScaledVector(axis, along);
  b.setChunk(chunkAt(center, b.chunks), true);
  const lineH = 0.075;
  b.within(center, yaw, () => {
    b.box(V(0, h, 0), V(0.46, 0.05 + lineH * p.lines.length, 0.015), { mat: "metal", color: 0x2b302d, collide: false, shadow: false });
    p.lines.forEach((text, i) => {
      const y = h + ((p.lines.length - 1) / 2 - i) * lineH;
      b.sign(text, V(0, y, 0.004), 0, i === 0 ? 0xe2d8b0 : 0xb7b09a, i === 0 ? 0.0019 : 0.0012);
    });
  });
}
