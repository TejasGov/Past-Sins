import type { Vector3 } from "three";

/** A door or gate leaf to be spawned as an interactable at runtime. */
export interface DoorSpec {
  kind: "gate" | "door" | "glass" | "shutter";
  /** World position of the opening centre at floor level. */
  position: Vector3;
  /** World yaw; the leaf spans local X with its thickness on local Z. */
  yaw: number;
  width: number;
  height: number;
  requiredKey: string;
  masterKey?: string;
  persistentId: string;
  displayName: string;
  startsLocked: boolean;
  slideDistance?: number;
  openDirection: number;
  openAngle?: number;
  color?: number;
  label?: string;
  /** Owning chunk/building, used for minimap filtering. */
  chunk: string;
  /** Floor plan id when it came from floor_plans.json. */
  planId?: string;
}

export interface Anchor {
  position: Vector3;
  yaw: number;
  data?: Record<string, unknown>;
}
