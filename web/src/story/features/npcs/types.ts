import type { Action, Condition, DialogueDef, DocumentDef, Place } from "../../types";

/** A Place, or a point in a door's frame (x along the leaf, +z out of its normal side). */
export type NpcPlace = Place | { door: string; offset?: [number, number, number]; yaw?: number };

/** How a guard.glb stand-in is dressed (data/story/features/npcs.json `look`). */
export interface LookDef {
  /** Multiply colour per GLB material name ("Ch35_body", "Ch35_body1", "Ch35_body2"; "*" = all). */
  tint?: Record<string, string>;
  /** Flat colour per material name (texture dropped). */
  flat?: Record<string, string>;
  /** Texture kept as shading detail, recoloured to this (keeps folds, drops the navy). */
  recolor?: Record<string, string>;
  /** How much of the texture's shading survives the recolour (0 flat … 1 full; default 0.75). */
  contrast?: number;
  /** Hide these GLB meshes by material name (Ch35_body2 = head + tactical gear). */
  hide?: string[];
  /** Replace the gas-mask head with a plain face of this skin colour. */
  face?: { skin: string; brows?: string };
  /** Unlit black: only ever seen backlit through glass. */
  ink?: boolean;
  scale?: number;
  /** Prop ids from props.ts (tumbler, cap, shawl, coat, kurta, hair, photo…). */
  props?: string[];
}

/** One thing a talk does, in order. Unknown keys are ignored. */
export type Step =
  | { dialogue: string }
  | { run: Action[] }
  | { shard: string; focus?: string }
  | { document: string }
  | { pose: string; actor?: string; weight?: number }
  | { do: string }
  | { wait: number }
  | { if: Condition; then: Step[]; else?: Step[] };

export interface TalkDef {
  when?: Condition;
  /** Freeze Parth and turn him to the speaker for the whole talk (conversations with choices). */
  lock?: boolean;
  steps: Step[];
}

export interface NpcDef {
  /** Subtitle speaker name: lines with this speaker animate this actor. */
  speaker: string;
  look: LookDef;
  /** Talk prompt (default `talkPrompt`). */
  prompt?: string;
  /** Talk hit volume in the actor's frame (size, centre); default covers the torso. */
  hit?: { size: [number, number, number]; offset: [number, number, number] };
  talk: TalkDef[];
}

export interface TokenDef {
  var?: string;
  cycle?: boolean;
  add?: number;
  /** "Words" = capitalised words (sentence start). */
  format?: "number" | "words" | "Words" | "ordinal";
}

export interface BhosleDef extends NpcDef {
  home: NpcPlace;
  homePose?: string;
  gate: NpcPlace;
  tumblerAt: NpcPlace;
  lunchAway: NpcPlace;
  lunchHours: [number, number];
  walkSpeed: number;
  morning: {
    line: { speaker: string; text: string; seconds?: number };
    counter: string;
    /** Parth must be this close (and in control) before he says it. */
    hearDistance: number;
    /** Leaves the chai and goes back at this hour if Parth never comes. */
    giveUpHour: number;
    /** Starts the morning round on its own in this window if no `routine:count` arrived. */
    fallbackHours: [number, number];
    after?: Action[];
  };
  lockin: {
    act: number;
    line: { speaker: string; text: string; seconds?: number };
    after?: Action[];
  };
  chai: { prompt: string; actions: Action[]; cardPrompt: string; cardWhen: Condition; cardActions: Action[] };
}

export interface KabirDef extends NpcDef {
  stand: NpcPlace;
  door: string;
  visits: string;
  seenFlag: string;
  freedFlag: string;
  followFlag: string;
  follow: { near: number; far: number; walk: number; run: number; repath: number };
  freedLines?: { speaker: string; text: string }[];
}

export interface MotherDef extends NpcDef {
  seat: NpcPlace;
  entrance: NpcPlace;
  visit: { day: number; hours: [number, number] };
}

export interface MeeraDef extends NpcDef {
  /** Behind the real observation window (Observation room). */
  stand: NpcPlace;
  /** Light panel behind her. */
  backlight: { at: NpcPlace; size: [number, number]; color: string };
  /** Shown while she is (act ≥ this, conversation not over, Parth in Interrogation A or the chair). */
  present: Condition;
  room: { plan: string; room: string };
}

export interface ChairDef {
  /** Seat in the restraint chair (feet), and where the seated camera looks. */
  eye: NpcPlace;
  look: NpcPlace;
  standUp: NpcPlace;
  shard: string;
  dialogue: string;
  /** Sets/flags handled in data; these run before the conversation starts. */
  before?: Action[];
  after?: Action[];
  /** Fallback window when the plan window is missing (see BUILD_PLAN finding). */
  falseWindow: { z: number; glass: [number, number, number]; meera: [number, number, number] };
}

export interface NpcsData {
  talkPrompt: string;
  tokens: Record<string, TokenDef>;
  documents: DocumentDef[];
  dialogue?: DialogueDef[];
  /** Distance beyond which NPCs are hidden and skip animation. */
  drawDistance: number;
  bhosle: BhosleDef;
  kabir: KabirDef;
  mother: MotherDef;
  meera: MeeraDef;
  chair: ChairDef;
}
