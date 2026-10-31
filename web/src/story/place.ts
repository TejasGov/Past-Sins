import { Vector3 } from "three";
import type { Anchor } from "../world/types";
import type { BuiltFloor } from "../world/campus/blueprintFloor";
import type { ChunkInfo } from "../world/builder";
import type { Place, ResolvedPlace } from "./types";

/**
 * Resolves a data Place against the built world. Anchor offsets are in the
 * anchor's frame; plan-room offsets are world-axis metres from the room
 * centre at floor level (buildings are axis-aligned). Works both at
 * build time (pass builder anchors/floors) and at runtime.
 */
export function resolvePlace(p: Place, anchors: Map<string, Anchor>, floors: Map<string, BuiltFloor>, chunks?: Map<string, ChunkInfo>): ResolvedPlace | null {
  let position: Vector3;
  let yaw = p.yaw ?? 0;
  const o = ("offset" in p ? p.offset : undefined) ?? [0, 0, 0];
  if ("anchor" in p) {
    const a = anchors.get(p.anchor);
    if (!a) return null;
    const c = Math.cos(a.yaw);
    const s = Math.sin(a.yaw);
    position = new Vector3(a.position.x + c * o[0] + s * o[2], a.position.y + o[1], a.position.z - s * o[0] + c * o[2]);
    yaw += a.yaw;
  } else if ("plan" in p) {
    const c = floors.get(p.plan)?.roomCenters.get(p.room);
    if (!c) return null;
    position = c.clone().add(new Vector3(o[0], o[1], o[2]));
  } else {
    position = new Vector3(...p.position);
  }
  return { position, yaw, chunk: chunkAt(position, chunks) };
}

/** Interior chunk containing the point (so props cull with their building), else "exterior". */
export function chunkAt(p: Vector3, chunks?: Map<string, ChunkInfo>): string {
  if (!chunks) return "exterior";
  for (const c of chunks.values()) {
    if (c.interior && !c.bounds.isEmpty() && c.bounds.containsPoint(p) && !c.name.includes("_cells")) return c.name;
  }
  return "exterior";
}
