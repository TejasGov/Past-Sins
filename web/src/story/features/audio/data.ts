import type { Mix } from "../../../audio/engine";
import type { AmbienceLevels } from "../../../audio/ambience";
import type { Layer, MotifDef } from "../../../audio/cues";
import type { VoiceDef } from "../../../audio/voice";
import type { Surface } from "../../../audio/synth";

/** public/data/story/features/audio.json (every field optional; defaults below). */
export interface AudioData {
  mix: Mix;
  /** Mute toggle (M is the minimap). */
  muteKey: string;
  messages: { muted: string; unmuted: string };
  ambience: AmbienceLevels;
  /** Ceiling height (m) where a room starts to sound like a hall, and where it is fully one. */
  hall: { from: number; to: number; roomReverb: number; hallReverb: number; outdoorReverb: number };
  /** Random distant clanks inside these chunks' halls (the Cellhouse A atrium). */
  clanks: { chunks: string[]; every: [number, number]; gain: number };
  rain: { drops: number; roofDrips: number; thunderEvery: [number, number]; thunder: number; fade: number };
  /** First matching rule wins; else indoor → "concrete", outdoor → wet in rain or `outdoor`. */
  surfaces: { chunk?: string; minY?: number; maxY?: number; surface: Surface }[];
  outdoor: Surface;
  footsteps: { gain: number; guardGain: number; guardRange: number; guardStride: number };
  tension: { from: number; bpm: [number, number]; heartbeat: number; drone: number; breathHold: number };
  klaxon: { gain: number; period: number; maxSeconds: number };
  underwater: { cutoff: number; dip: number };
  /** Ambience level while a memory plays / during a capture. */
  ducking: { memory: number; capture: number };
  motif: MotifDef;
  /**
   * Cues by event: `shard`, `shard:<id>`, `capture`, `capture:<reason>`, `wipe`,
   * `act`, `act:<n>`, `ending`, `ending:<id>`, `signal:<id>`, `dialogue:<audio id>`,
   * `swim:enter`, `swim:surface`, `swim:dive`. Most specific wins.
   */
  cues: Record<string, Layer[]>;
  voices: Record<string, VoiceDef>;
}

export const AUDIO_DEFAULTS: AudioData = {
  mix: { master: 0.85, music: 0.7, sfx: 0.9, ambience: 0.7, voice: 1 },
  muteKey: "KeyN",
  messages: { muted: "SOUND OFF", unmuted: "SOUND ON" },
  ambience: { roomTone: 0.5, hum: 0.012, buzz: 0.02, hall: 0.25, wind: 0.32, crickets: 0.012, rainOpen: 0.22, rainRoof: 0.5, underwater: 0.9, searchlight: 0.12 },
  hall: { from: 5, to: 9, roomReverb: 0.35, hallReverb: 0.9, outdoorReverb: 0.08 },
  clanks: { chunks: ["cellhouseA"], every: [7, 16], gain: 0.5 },
  rain: { drops: 9, roofDrips: 0.6, thunderEvery: [35, 80], thunder: 0.8, fade: 0.25 },
  surfaces: [],
  outdoor: "gravel",
  footsteps: { gain: 1, guardGain: 0.8, guardRange: 26, guardStride: 1.5 },
  tension: { from: 6, bpm: [62, 138], heartbeat: 0.7, drone: 0.12, breathHold: 0.6 },
  klaxon: { gain: 0.7, period: 1.25, maxSeconds: 40 },
  underwater: { cutoff: 380, dip: 0.3 },
  ducking: { memory: 0.35, capture: 0.45 },
  motif: { digits: [2, 7, 1, 8], unit: 0.17, root: 60, scale: [0, 2, 3, 5, 7, 8, 10] },
  cues: {},
  voices: {},
};

/** Shallow per-section merge of the JSON over the defaults. */
export function readAudioData(raw: unknown): AudioData {
  const d = (raw && typeof raw === "object" ? raw : {}) as Partial<Record<keyof AudioData, unknown>>;
  const out = { ...AUDIO_DEFAULTS } as Record<string, unknown>;
  for (const [k, v] of Object.entries(d)) {
    const base = (AUDIO_DEFAULTS as unknown as Record<string, unknown>)[k];
    out[k] = base && typeof base === "object" && !Array.isArray(base) && v && typeof v === "object" && !Array.isArray(v) ? { ...base, ...v } : v;
  }
  return out as unknown as AudioData;
}
