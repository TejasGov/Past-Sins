import type { Vector3 } from "three";

/**
 * Nav export hooks. World builders record walkable data here as they build;
 * src/ai/nav.ts turns it (plus floor plans and door specs) into the guard
 * waypoint graph. Nothing in the world reads it back.
 */

/** A world-space polyline whose consecutive points are walkable straight lines (stairs, landings). */
export interface NavPath {
  points: Vector3[];
  tag: string;
}

/**
 * A walkable floor rectangle sampled into a grid of waypoints. The rect is in
 * the recording frame (origin + yaw); grid lines pass through `align`.
 */
export interface NavRegion {
  origin: Vector3;
  yaw: number;
  x0: number;
  z0: number;
  x1: number;
  z1: number;
  /** Floor height in the recording frame. */
  y: number;
  spacing: number;
  align: [number, number];
  /** Outdoor region: points under a roof are dropped (interiors have their own nav). */
  exterior: boolean;
  tag: string;
}

export interface NavExport {
  paths: NavPath[];
  regions: NavRegion[];
}

/** Key of the anchor whose `data` is the builder's NavExport (anchors reach Game unchanged). */
export const NAV_ANCHOR = "__nav";
