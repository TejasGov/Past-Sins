import type { Action, Condition } from "../../types";

/** One spoken count / line (subtitle + `dialogue` event; `audio` is an optional voice clip id). */
export interface WaterLine {
  text: string;
  seconds?: number;
  audio?: string;
}

/** public/data/story/features/water.json. Every section is optional; missing keys fall back to DEFAULTS. */
export interface WaterData {
  breath: {
    /** The pattern, in seconds (2·7·1·8 = 18 s). */
    segments: number[];
    labels: string[];
    /** Caption beside the meter. */
    caption: string;
    /** After the meter empties, seconds of choking before Parth drowns (reaching air in time saves him). */
    chokeSeconds: number;
    /** Refill at the pool surface (seconds of breath per second). Air pockets refill at once. */
    refillPerSecond: number;
    speaker: string;
    /** Raman's count, one line per segment, said as the segment starts. */
    count: WaterLine[];
    /** When Raman counts (default: after T1, or from Act III). */
    countWhen?: Condition;
    /** story.capture reason for drowning. */
    drownReason: string;
  };
  pool: {
    t1: { shard: string; when?: Condition; /** Pool-local rect [x0, z0, x1, z1] (shallow end). */ region: [number, number, number, number]; /** Seconds under before it plays. */ delay: number };
    grate: {
      /** Pool-local centre of the drain grate on the floor. */
      at: [number, number, number];
      prompt: string;
      /** Breath that counts as "a full breath" when the dive starts. */
      fullBreath: number;
      /** The memory comes on this segment (3 = the final 8). */
      atSegment: number;
      t2: { shard: string; when?: Condition };
      t3: { shard: string; when?: Condition };
      /** Shimmer (withdrawal) while this holds and a grate shard is still to come. */
      shimmerWhen?: Condition;
      /** Messages when the grate does nothing. */
      notYet: string;
      needFullBreath: string;
      done: string;
      letGoPrompt: string;
    };
    t3: {
      /** Pool-local deck positions of the guards waiting when Parth surfaces. */
      guards: [number, number, number][];
      /** Pool-local position of the PA speaker horn. */
      speaker: [number, number, number];
      surfaceLines: Action[];
      speakerLines: Action[];
      /** After Act III is set (default: the guards take him). */
      after: Action[];
    };
  };
  culvert: {
    hatchPrompt: string;
    hatchWhen?: Condition;
    ladderPrompt: string;
    sumpSign: string;
    outfallSign: string;
    enterLines: Action[];
    /** Pocket gaps in seconds of swimming (sump → pocket 0 → 1 → 2 → the end of the final 8). */
    gaps: number[];
  };
  hand: {
    shard: string;
    releasePrompt: string;
    holdPrompt: string;
    /** Seconds the key must be held to choose. */
    holdSeconds: number;
    releasedLines: Action[];
    takenLines: Action[];
    /** Clock when Parth surfaces in the reservoir. */
    dawnHours: number;
  };
  route: {
    /** Door persistentIds re-keyed in buildStatic: the Gated Landing takes Bhosle's card. */
    landingDoor: string;
    landingKey: string;
    /** Other B1 gates the card also opens (masterKey). */
    masterDoors: string[];
  };
}

export const DEFAULTS: WaterData = {
  breath: {
    segments: [2, 7, 1, 8],
    labels: [],
    caption: "",
    chokeSeconds: 3,
    refillPerSecond: 9,
    speaker: "",
    count: [],
    countWhen: { any: [{ shard: "t1_summer" }, { actAtLeast: 3 }] },
    drownReason: "drowned",
  },
  pool: {
    t1: { shard: "t1_summer", region: [-10, -5, 0, 5], delay: 1.2 },
    grate: {
      at: [7, -2.4, -3.6],
      prompt: "",
      fullBreath: 17.5,
      atSegment: 3,
      t2: { shard: "t2_deeper", when: { flag: "cycle:withdrawal" } },
      t3: { shard: "t3_the_hand", when: { all: [{ flag: "cycle:withdrawal" }, { flag: "cycle:jagran" }, { shard: "t2_deeper" }] } },
      shimmerWhen: { flag: "cycle:withdrawal" },
      notYet: "",
      needFullBreath: "",
      done: "",
      letGoPrompt: "",
    },
    t3: {
      guards: [[11.0, 0, -2.6], [10.9, 0, 0.9], [8.6, 0, -6.1]],
      speaker: [11.9, 0, -5.4],
      surfaceLines: [],
      speakerLines: [],
      after: [{ wait: 1 }, { capture: "caught" }],
    },
  },
  culvert: {
    hatchPrompt: "",
    ladderPrompt: "",
    sumpSign: "",
    outfallSign: "",
    enterLines: [],
    gaps: [2, 7, 1, 8],
  },
  hand: {
    shard: "t4_surface",
    releasePrompt: "",
    holdPrompt: "",
    holdSeconds: 1.4,
    releasedLines: [],
    takenLines: [],
    dawnHours: 6.1,
  },
  route: {
    landingDoor: "campus_maintenance-b1_spine_landing",
    landingKey: "bhosle_card",
    masterDoors: ["campus_maintenance-b1_spine_crossw"],
  },
};

/** Numbers and structure only: every line the player reads lives in the JSON. */
/** DEFAULTS overlaid with the JSON, one level deep per section (and per pool sub-section). */
export function readData(raw: unknown): WaterData {
  const j = (raw ?? {}) as Partial<Record<keyof WaterData, Record<string, unknown>>>;
  const d = DEFAULTS;
  const pool = (j.pool ?? {}) as Partial<Record<keyof WaterData["pool"], Record<string, unknown>>>;
  return {
    breath: { ...d.breath, ...(j.breath as Partial<WaterData["breath"]>) },
    pool: {
      t1: { ...d.pool.t1, ...(pool.t1 as Partial<WaterData["pool"]["t1"]>) },
      grate: { ...d.pool.grate, ...(pool.grate as Partial<WaterData["pool"]["grate"]>) },
      t3: { ...d.pool.t3, ...(pool.t3 as Partial<WaterData["pool"]["t3"]>) },
    },
    culvert: { ...d.culvert, ...(j.culvert as Partial<WaterData["culvert"]>) },
    hand: { ...d.hand, ...(j.hand as Partial<WaterData["hand"]>) },
    route: { ...d.route, ...(j.route as Partial<WaterData["route"]>) },
  };
}
