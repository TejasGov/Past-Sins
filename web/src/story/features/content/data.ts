import type { Condition, Place } from "../../types";

/** Shape of public/data/story/features/content.json (W5 · Content & interactables). */
export type Vec3 = [number, number, number];

/**
 * Any story Place, or a frame taken from a built door (`door` = its persistentId;
 * offset in the door's local frame, yaw relative to the door's).
 */
export type ContentPlace = Place | { door: string; offset?: Vec3; yaw?: number };

export type FurnitureKind = "table" | "trolley" | "hookboard" | "hookstand" | "junction" | "keypad" | "deck" | "nameplate";

/** Static furniture built at a place; local +Z faces the room. */
export interface FurnitureDef {
  kind: FurnitureKind;
  /** Width, depth, height (metres); each kind has defaults. */
  size?: Vec3;
  color?: number;
  /** Painted label (hook boards, junction box, keypad, desk nameplate). */
  label?: string;
}

/** A named anchor for triggers (`{ "anchor": id }`), optionally with furniture built under it. */
export interface AnchorDef {
  id: string;
  at: ContentPlace;
  build?: FurnitureDef;
  /** Anchor position in the frame of `at` (default: centred on the furniture's top). */
  local?: Vec3;
  yaw?: number;
}

/** Doorplate beside a plan door, on the `side` room's face of the wall. */
export interface PlateDef {
  plan: string;
  door: [string, string];
  side: string;
  /** Metres along the wall from the opening centre (default: just past the frame). */
  along?: number;
  height?: number;
  lines: string[];
}

/** Mesh attached to a story trigger prop (model "none"); hidden with it. */
export interface PropModelDef {
  kind: "keytag" | "clipboard" | "drawer" | "radio" | "folder" | "vial" | "wire" | "sheet";
  color?: number;
  /** Lying flat (keys on a desk) instead of hanging. */
  flat?: boolean;
}

export interface SubtitleLine {
  speaker?: string;
  text: string;
  seconds?: number;
  /** Plays only the first time (sets this flag). */
  onceFlag?: string;
}

export interface LiftStop {
  at: Place;
  /** Flag set on arrival. */
  flag?: string;
  /** Subtitles over the black ride. */
  lines?: SubtitleLine[];
}

export interface ContentData {
  anchors?: AnchorDef[];
  plates?: PlateDef[];
  models?: Record<string, PropModelDef>;
  /** Keeps `flag` equal to "the locker with this code is open" (the M04 note sits inside). */
  locker?: { code: string; flag: string };
  /** Sets `flag` while Parth is on this floor plan and `when` holds. */
  regions?: { flag: string; plan: string; when?: Condition }[];
  lift?: { fadeOut: number; hold: number; fadeIn: number; stops: Record<string, LiftStop> };
  /** Running shower water while `when` holds. */
  water?: { at: Place; when: Condition; top?: number }[];
  /** Forty cycles on the HQ surveillance wall (M12). */
  monitors?: {
    at: Place;
    when: Condition;
    cols: number;
    rows: number;
    spacing: [number, number];
    screen: [number, number];
    cycles: number;
    highlight: number[];
    labels: { cycle: string; route: string; rec: string };
  };
  /** Guard detection cones shown while this flag holds (M12's patrol gaps). */
  patrolGaps?: { flag: string };
}
