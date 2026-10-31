/** FNV-1a string hash, used to seed per-room randomness from stable ids. */
export function hashString(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619);
  return h >>> 0;
}

/**
 * Deterministic PRNG (mulberry32). Set dressing draws from one seeded per room,
 * so layouts look hand-dressed but are identical on every load: colliders, the
 * guard nav graph and saves stay stable.
 */
export class Rng {
  private state: number;

  constructor(seed: string | number) {
    this.state = typeof seed === "number" ? seed >>> 0 : hashString(seed);
  }

  next(): number {
    let t = (this.state = (this.state + 0x6d2b79f5) >>> 0);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  range(min: number, max: number): number {
    return min + (max - min) * this.next();
  }

  /** Integer in [min, max]. */
  int(min: number, max: number): number {
    return Math.floor(this.range(min, max + 1));
  }

  chance(p: number): boolean {
    return this.next() < p;
  }

  sign(): 1 | -1 {
    return this.next() < 0.5 ? -1 : 1;
  }

  pick<T>(items: readonly T[]): T {
    return items[Math.floor(this.next() * items.length)];
  }

  weighted<T>(items: readonly (readonly [T, number])[]): T {
    let total = 0;
    for (const [, w] of items) total += w;
    let r = this.next() * total;
    for (const [item, w] of items) if ((r -= w) <= 0) return item;
    return items[items.length - 1][0];
  }

  /** A child generator, so adding draws in one place doesn't reshuffle everything after it. */
  fork(salt: string): Rng {
    return new Rng(hashString(`${this.state}:${salt}`));
  }
}
