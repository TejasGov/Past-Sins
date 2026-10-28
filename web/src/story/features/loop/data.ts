import type { DocumentDef, Place } from "../../types";

type Vec3 = [number, number, number];

/** One subtitle line (dialogue events carry `audio` so the audio feature can voice it). */
export interface LoopLine {
  speaker?: string;
  text: string;
  seconds?: number;
  audio?: string;
}

/** public/data/story/features/loop.json. Every string the player reads comes from here. */
export interface LoopData {
  capture?: {
    skipHint?: string;
    liftCaption?: string;
    chairCaption?: string;
    again?: LoopLine;
    /** Optional lines while Parth is seized, keyed by capture reason. */
    seize?: Record<string, LoopLine[]>;
  };
  wake?: { banner?: string; sub?: string; infirmarySub?: string; reloadSub?: string };
  nightRestart?: { hour?: number; banner?: string; sub?: string; reasons?: string[] };
  coldOpen?: { lines?: LoopLine[] };
  wall?: {
    prompt?: string;
    title?: string;
    style?: DocumentDef["style"];
    entryFormat?: string;
    cycleFormat?: string;
    codeFormat?: string;
    docEntry?: string;
    docCodes?: string;
    empty?: string;
    footer?: string;
    /** Older, half-erased marks drawn faintly under the real entries. */
    faded?: string[];
  };
  stash?: {
    prompt?: string;
    title?: string;
    put?: string;
    take?: string;
    leave?: string;
    empty?: string;
    stored?: string;
    retrieved?: string;
    items?: Record<string, { label: string; category?: string }>;
  };
  alarm?: { message?: string; captureAfter?: number; noiseEvery?: number };
  dose?: { hour?: number; lines?: LoopLine[] };
  infirmary?: { bed?: Place; eye?: Vec3; look?: Vec3; sit?: Vec3; sitLook?: Vec3; stand?: Vec3; standYaw?: number; shard?: string };
}

/** Fills `{key}` placeholders. */
export function fill(template: string | undefined, values: Record<string, string | number>): string {
  return (template ?? "").replace(/\{(\w+)\}/g, (m, k: string) => (k in values ? String(values[k]) : m));
}
