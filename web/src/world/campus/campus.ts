import type { StaticBuilder } from "../builder";
import { buildCellhouseA } from "./cellhouseA";
import { buildGround, type Rect } from "./ground";
import { buildBlueprintBuildings } from "./buildings";
import { buildPerimeter, buildPool, buildRoads, buildTowers, buildYard } from "./exterior";
import type { FloorPlan } from "./plans";
import type { BuiltFloor } from "./blueprintFloor";

/** Finished building floors (Godot `_create_excavated_ground` visual cut-outs). */
export const BUILDING_FLOORS: Rect[] = [
  { x: -71.6, z: -16.6, w: 43.2, d: 33.2 },
  { x: 32.9, z: -22.0, w: 34.2, d: 44.0 },
  { x: -66.5, z: -67.6, w: 37, d: 32.2 },
  { x: -66.1, z: 35.4, w: 36.2, d: 32.2 },
  { x: 30.9, z: -67.6, w: 34.2, d: 32.2 },
  { x: 30.9, z: 35.4, w: 34.2, d: 32.2 },
  { x: -19.1, z: 59.5, w: 38.2, d: 23 },
  { x: -71, z: -55.5, w: 4, d: 8 },
];

export const GROUND_HOLES: Rect[] = [
  { x: 40.4, z: 52.1, w: 6, d: 9 },
  { x: 40.4, z: -67.6, w: 6, d: 9 },
  { x: -24, z: 37.5, w: 20, d: 10 },
];

/** PrisonCampusPrototype._assemble_campus, ported module by module. */
export function buildCampus(b: StaticBuilder, plans: FloorPlan[]): Map<string, BuiltFloor> {
  b.setChunk("exterior", false);
  buildGround(b, GROUND_HOLES, BUILDING_FLOORS);
  buildRoads(b);
  buildPerimeter(b);
  buildYard(b);
  buildPool(b);
  buildTowers(b);
  buildCellhouseA(b);
  return buildBlueprintBuildings(b, plans);
}
