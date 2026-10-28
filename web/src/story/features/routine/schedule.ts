import type { BeatDef } from "./data";

/** One beat on one day, in absolute cycle hours ((day − 1) · 24 + clock hour). */
export interface Occurrence {
  beat: BeatDef;
  day: number;
  start: number;
  end: number;
  key: string;
}

/** Clock time → absolute cycle hours. */
export function absHours(dayNumber: number, timeHours: number): number {
  return (dayNumber - 1) * 24 + timeHours;
}

function length(b: BeatDef): number {
  const d = (((b.until - b.at) % 24) + 24) % 24;
  return d === 0 ? 24 : d;
}

/** Every occurrence starting on days [fromDay, toDay]. */
export function occurrences(beats: BeatDef[], fromDay: number, toDay: number): Occurrence[] {
  const out: Occurrence[] = [];
  for (let day = Math.max(1, fromDay); day <= toDay; day++) {
    for (const beat of beats) {
      if (beat.day !== undefined && beat.day !== day) continue;
      const start = absHours(day, beat.at);
      out.push({ beat, day, start, end: start + length(beat), key: `${beat.id}@${day}` });
    }
  }
  return out;
}

/**
 * Which beats fire as the clock moves. Normal play advances a few
 * thousandths of an hour per frame and fires every start crossed. A
 * backwards jump (the wipe → 06:00 day one, the Act III night restart →
 * 19:00) forgets what fired and re-fires the beat that is on at the new
 * time; a big forward jump (dev time, sleeping through the night) fires only
 * the beat that is on, not everything skipped.
 */
export class Schedule {
  private fired = new Set<string>();
  private last: number | null = null;
  /** Largest per-update advance still treated as continuous time. */
  maxStep = 0.75;

  constructor(readonly beats: BeatDef[]) {}

  /** Advances to absolute hour `t`; returns the occurrences that start now, in time order. */
  advance(t: number): Occurrence[] {
    const day = Math.floor(t / 24) + 1;
    const near = occurrences(this.beats, day - 1, day + 1);
    const out: Occurrence[] = [];
    const last = this.last;
    this.last = t;
    if (last === null || t < last - 1e-6 || t - last > this.maxStep) {
      if (last === null || t < last) this.fired.clear();
      for (const o of near) {
        if (o.start > t) continue;
        if (t < o.end && !this.fired.has(o.key)) out.push(o);
        this.fired.add(o.key);
      }
    } else {
      for (const o of near) {
        if (o.start > last && o.start <= t && !this.fired.has(o.key)) {
          this.fired.add(o.key);
          out.push(o);
        }
      }
    }
    // Drop keys from days long gone so the set stays small over a long cycle.
    if (this.fired.size > 64) for (const k of [...this.fired]) if (Number(k.split("@")[1]) < day - 2) this.fired.delete(k);
    return out.sort((a, b) => a.start - b.start);
  }

  /** Forget everything (wipe): the next advance re-fires whatever is on. */
  reset(): void {
    this.fired.clear();
    this.last = null;
  }

  /** The beat that is on at `t` (a day-specific beat outranks the daily one under it; else the latest start). */
  active(t: number, ok: (b: BeatDef) => boolean = () => true): Occurrence | null {
    const day = Math.floor(t / 24) + 1;
    let best: Occurrence | null = null;
    for (const o of occurrences(this.beats, day - 1, day)) {
      if (o.start > t || t >= o.end || !ok(o.beat)) continue;
      if (!best) best = o;
      else {
        const rank = (x: Occurrence) => (x.beat.day !== undefined ? 1 : 0);
        if (rank(o) > rank(best) || (rank(o) === rank(best) && o.start > best.start)) best = o;
      }
    }
    return best;
  }

  /** The next beat to start after `t`. */
  next(t: number, ok: (b: BeatDef) => boolean = () => true): Occurrence | null {
    const day = Math.floor(t / 24) + 1;
    let best: Occurrence | null = null;
    for (const o of occurrences(this.beats, day, day + 1)) {
      if (o.start <= t || !ok(o.beat)) continue;
      if (!best || o.start < best.start) best = o;
    }
    return best;
  }
}
