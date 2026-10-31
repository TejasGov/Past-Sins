import type { AudioEngine } from "./engine";
import * as S from "./synth";

/**
 * Data-driven cues: a cue is a list of layers (audio.json `cues`), each a
 * synth instrument with parameters and an optional delay `at` in seconds.
 * String values starting with `$` read from the event payload
 * (`{"type": "motifNote", "index": "$segment"}` on `breath_segment`).
 */
export interface Layer {
  type: string;
  at?: number;
  [k: string]: unknown;
}

export interface MotifDef {
  /** e = 2.718…: the rhythm, and the scale degrees (1-based, 8 = the octave). */
  digits: number[];
  /** Seconds per digit unit; the four notes last 2·7·1·8 units (18 in all). */
  unit: number;
  /** MIDI note of scale degree 1. */
  root: number;
  /** Semitones of the scale (natural minor). */
  scale: number[];
}

/** Hooks for layers that change engine/director state rather than play a sound. */
export interface CueHost {
  klaxon(on: boolean): void;
  duck(amount: number, seconds: number, release: number): void;
  scene(name: string, on: boolean, seconds?: number): void;
  voice(id: string): void;
}

export class CuePlayer {
  readonly log: { cue: string; at: number }[] = [];

  constructor(
    private e: AudioEngine,
    private cues: Record<string, Layer[]>,
    readonly motif: MotifDef,
    private host: CueHost,
  ) {}

  has(name: string): boolean {
    return !!this.cues[name];
  }

  /** Plays the first cue that exists among `names` (most specific first). Returns its name. */
  play(names: string[], data?: Record<string, unknown>): string | null {
    const name = names.find((n) => this.cues[n]);
    if (!name || !this.e.ctx) return null;
    this.log.push({ cue: name, at: +this.e.now.toFixed(2) });
    if (this.log.length > 30) this.log.shift();
    for (const layer of this.cues[name]) this.layer(resolve(layer, data));
    return name;
  }

  /** Scale degree (1-based; 8 = octave above 1) → MIDI. */
  degree(d: number, octave = 0): number {
    const s = this.motif.scale;
    const i = Math.max(0, Math.round(d) - 1);
    return this.motif.root + 12 * (octave + Math.floor(i / s.length)) + s[i % s.length];
  }

  /**
   * The 2·7·1·8 figure: four notes on degrees 2, 7, 1, 8 whose lengths are
   * 2, 7, 1 and 8 units. Returns its length in seconds.
   */
  playMotif(t: number, o: { unit?: number; octave?: number; gain?: number; timbre?: S.Timbre; pad?: boolean; resolve?: boolean; cut?: boolean; count?: number }): number {
    const unit = o.unit ?? this.motif.unit;
    const level = o.gain ?? 0.6;
    const digits = this.motif.digits.slice(0, o.count ?? this.motif.digits.length);
    let at = t;
    digits.forEach((d, i) => {
      const len = d * unit;
      const last = i === digits.length - 1;
      const ring = last && o.cut ? Math.min(len, unit * 1.2) : Math.max(1.2, len * 1.4);
      S.note(this.e, this.degree(d, o.octave ?? 0), at, level, o.timbre ?? "bell", ring);
      if (o.pad) S.note(this.e, this.degree(d, (o.octave ?? 0) - 1), at, level * 0.8, "pad", Math.max(0.6, len));
      at += len;
    });
    if (o.resolve) {
      // "It never ends": the figure lifts to the 3rd above the octave instead of stopping.
      S.note(this.e, this.degree(10, o.octave ?? 0), at, level * 0.8, o.timbre ?? "bell", 4);
      S.note(this.e, this.degree(1, (o.octave ?? 0) - 1), at, level * 0.6, "pad", 4);
    }
    return at - t;
  }

  private layer(l: Layer): void {
    const e = this.e;
    const t = e.now + 0.02 + (l.at ?? 0);
    const g = num(l.gain, 1);
    const delay = (fn: () => void) => (l.at ? window.setTimeout(fn, l.at * 1000) : fn());
    switch (l.type) {
      case "motif":
        this.playMotif(t, { unit: opt(l.unit), octave: opt(l.octave), gain: num(l.gain, 0.6), timbre: l.timbre as S.Timbre, pad: !!l.pad, resolve: !!l.resolve, cut: !!l.cut, count: opt(l.count) });
        break;
      case "motifNote": {
        const i = Math.max(0, Math.min(this.motif.digits.length - 1, Math.round(num(l.index, 0))));
        S.note(e, this.degree(this.motif.digits[i], num(l.octave, 0)), t, num(l.gain, 0.5), (l.timbre as S.Timbre) ?? "glass", num(l.length, 2));
        break;
      }
      case "note":
        S.note(e, num(l.midi, 60), t, g, (l.timbre as S.Timbre) ?? "bell", num(l.length, 2));
        break;
      case "chord":
        S.chord(e, (l.notes as number[]) ?? [48, 55, 63], t, num(l.seconds, 4), g, (l.timbre as S.Timbre) ?? "pad");
        break;
      case "boom":
        S.boom(e, t, g);
        break;
      case "hit":
        S.hit(e, t, g);
        break;
      case "swell":
        S.swell(e, t, num(l.seconds, 2), g);
        break;
      case "whine":
        S.whine(e, t, num(l.seconds, 4), g, num(l.freq, 7200));
        break;
      case "tapeStop":
        S.tapeStop(e, t, num(l.seconds, 1.4), g);
        break;
      case "chime":
        S.chime(e, t, g, (l.notes as number[]) ?? undefined);
        break;
      case "buzzer":
        S.buzzer(e, t, num(l.seconds, 1.2), g);
        break;
      case "motor":
        S.motor(e, t, num(l.seconds, 5), g);
        break;
      case "powerDown":
        S.powerDown(e, t, g);
        break;
      case "heartbeat":
        S.heartbeat(e, t, g, num(l.interval, 0.9));
        break;
      case "splash":
        delay(() => S.splash(e, g));
        break;
      case "bubbles":
        S.bubbles(e, num(l.amount, 0.5), t);
        break;
      case "gasp":
        S.gasp(e, g, t);
        break;
      case "breath":
        S.breath(e, !!l.heavy, t);
        break;
      case "choke":
        S.choke(e, t);
        break;
      case "thunder":
        delay(() => S.thunder(e, g));
        break;
      case "klaxon":
        delay(() => this.host.klaxon(l.on !== false));
        break;
      case "duck":
        delay(() => this.host.duck(num(l.amount, 0.5), num(l.seconds, 2), num(l.release, 1)));
        break;
      case "scene":
        delay(() => this.host.scene(String(l.name), l.on !== false, opt(l.seconds)));
        break;
      case "voice":
        delay(() => this.host.voice(String(l.id)));
        break;
      default:
        console.warn(`[audio] unknown cue layer "${l.type}"`);
    }
  }
}

function num(v: unknown, d: number): number {
  return typeof v === "number" && Number.isFinite(v) ? v : d;
}

function opt(v: unknown): number | undefined {
  return typeof v === "number" && Number.isFinite(v) ? v : undefined;
}

function resolve(l: Layer, data?: Record<string, unknown>): Layer {
  const out: Layer = { ...l };
  for (const [k, v] of Object.entries(l)) {
    if (typeof v === "string" && v.startsWith("$")) out[k] = data?.[v.slice(1)];
  }
  return out;
}
