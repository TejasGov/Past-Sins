import type { Vector3 } from "three";
import type { StaticBuilder } from "../world/builder";
import type { BuiltFloor } from "../world/campus/blueprintFloor";
import type { Game } from "../game/game";

/**
 * Story data contracts ("Again" outline, docs/story/AGAIN_OUTLINE.md). Every
 * piece of story content is JSON under public/data/story/ (listed in its
 * index.json); features in src/story/features/ add behaviour the data can't
 * express. See docs/story/BUILD_PLAN.md for ownership and vocabulary.
 */

/** Where something sits in the world. Plan rooms resolve to the room centre at floor level. */
export type Place =
  | { anchor: string; offset?: [number, number, number]; yaw?: number }
  | { plan: string; room: string; offset?: [number, number, number]; yaw?: number }
  | { position: [number, number, number]; yaw?: number };

/** Data-driven condition; every listed key must hold (implicit AND). */
export interface Condition {
  all?: Condition[];
  any?: Condition[];
  not?: Condition;
  flag?: string;
  /** Story shard / memory id already recovered. */
  shard?: string;
  /** Inventory item or key id held. */
  item?: string;
  /** Code learned (memory clues and `learnCode` actions). */
  code?: string;
  act?: number;
  actAtLeast?: number;
  cycleAtLeast?: number;
  /** Clock window in hours [from, to); wraps midnight when from > to. */
  hours?: [number, number];
  /** Day of the current cycle (1-based; visitation is day 3). */
  day?: number;
}

/** Data-driven actions, run in order (some wait: shards, documents, dialogue). */
export type Action =
  | { setFlag: string }
  | { clearFlag: string }
  | { shard: string }
  | { wall: string; text: string }
  | { give: { id: string; label: string; category?: "KEY" | "ACCESS_CARD" | "MISSION_ITEM" | "EQUIPMENT" } }
  | { take: string }
  | { learnCode: string }
  | { message: string; seconds?: number }
  | { say: string; speaker?: string; seconds?: number }
  | { dialogue: string }
  | { document: string }
  | { act: number }
  | { objective: string }
  | { wait: number }
  | { signal: string; data?: Record<string, unknown> }
  | { capture: string };

export interface TriggerDef {
  id: string;
  at: Place;
  /** "interact" = E prompt on a prop; "zone" = fires when Parth walks into the volume. */
  kind: "interact" | "zone";
  prompt?: string;
  /** Zone half-extents in metres (default 1.5 × 1.5 × 1.5). */
  size?: [number, number, number];
  /** Prop model for interact triggers. */
  model?: "paper" | "box" | "tumbler" | "vial" | "bag" | "tape" | "panel" | "photo" | "shard" | "none";
  /** Available/visible only while this holds. */
  when?: Condition;
  /** Default true: fires once ever (flag `trigger:<id>`). False: every time. */
  once?: boolean;
  actions: Action[];
}

export interface DocumentDef {
  id: string;
  title: string;
  body: string;
  /** Small print under the body (signatures, stamps). */
  footer?: string;
  style?: "paper" | "memo" | "file" | "note" | "screen";
}

export type DialogueNode =
  | { speaker: string; text: string; seconds?: number; audio?: string; when?: Condition; actions?: Action[] }
  | { choice: { text: string; when?: Condition; actions?: Action[]; goto?: string }[]; prompt?: string }
  | { label: string }
  | { goto: string }
  | { end: true };

export interface DialogueDef {
  id: string;
  nodes: DialogueNode[];
}

export interface ObjectiveDef {
  id: string;
  act: number;
  title: string;
  text: string;
  /** Shown only while this holds (default always). */
  when?: Condition;
  /** Complete once this holds. */
  done: Condition;
}

/** public/data/story/index.json: which content files to load (one per workstream to avoid conflicts). */
export interface StoryIndex {
  triggers: string[];
  documents: string[];
  dialogue: string[];
  objectives: string[];
  /** Extra shard ids to prefetch (ones only feature code plays; triggers/dialogue are scanned automatically). */
  shards?: string[];
  /** Feature-owned JSON blobs, keyed by feature id, loaded verbatim. */
  features: Record<string, string>;
}

export interface WallEntry {
  id: string;
  text: string;
  cycle: number;
}

export type StoryEvents = {
  flag: { flag: string; on: boolean };
  shard: { id: string };
  wall: WallEntry;
  /** Parth has been caught (or chose to be); the capture sequence is starting. */
  capture: { reason: string };
  /** A wipe finished: Parth is waking in N03 on a new cycle. */
  wipe: { cycle: number };
  act: { act: number };
  dialogue: { id: string; speaker: string; text: string; audio?: string };
  /** Free-form feature-to-feature signal (vocabulary in BUILD_PLAN.md). */
  signal: { id: string; data?: Record<string, unknown> };
  ending: { id: string };
};

/** What a feature module receives. */
export interface StoryContext {
  game: Game;
  /** The feature's JSON from index.json `features[id]` (null if none). */
  data: unknown;
}

/**
 * A story feature (one per workstream). All hooks are optional; register in
 * src/story/features/index.ts.
 */
export interface StoryFeature {
  id: string;
  /** Static geometry before the world is finalized (signs, culverts, plates). */
  buildStatic?(b: StaticBuilder, floors: Map<string, BuiltFloor>, data: unknown): void;
  init?(ctx: StoryContext): void | Promise<void>;
  update?(dt: number): void;
  /** Called after the default per-cycle reset, before Parth wakes. */
  onWipe?(cycle: number): void;
}

export interface ResolvedPlace {
  position: Vector3;
  yaw: number;
  chunk: string;
}
