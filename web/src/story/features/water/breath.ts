/**
 * Breath as a position in Raman's pattern (2·7·1·8 = 18 s). The air Parth
 * last breathed sets a window of the pattern: the pool's surface gives the
 * whole 18 s; in the culvert each air space only gives the next segment, so
 * the pockets have to come where the pattern says they will.
 */
export class Breath {
  readonly starts: number[];
  readonly total: number;
  /** Window of the pattern the current breath covers (seconds). */
  from = 0;
  length: number;
  /** Seconds of the window still in the lungs. */
  left: number;
  /** Seconds spent choking once `left` hit zero. */
  choke = 0;

  constructor(readonly segments: number[]) {
    let t = 0;
    this.starts = segments.map((s) => ((t += s), t - s));
    this.total = t;
    this.length = t;
    this.left = t;
  }

  /** Seconds into the pattern. */
  get position(): number {
    return this.from + (this.length - this.left);
  }

  /** Segment the breath is in (the last one of the window once it is spent). */
  get segment(): number {
    return this.segmentAt(Math.min(this.position, this.from + this.length - 1e-4));
  }

  segmentAt(t: number): number {
    for (let i = this.segments.length - 1; i >= 0; i--) if (t >= this.starts[i] - 1e-6) return i;
    return 0;
  }

  /** A full 18 s from the two. */
  get full(): boolean {
    return this.from === 0 && this.length === this.total && this.left >= this.total - 0.05;
  }

  /** Window covering one segment (culvert air spaces). */
  windowFor(segment: number): [number, number] {
    const i = Math.max(0, Math.min(this.segments.length - 1, segment));
    return [this.starts[i], this.segments[i]];
  }

  /** Under water: the pattern runs on; past the end Parth chokes. */
  hold(dt: number): void {
    if (this.left > 0) this.left = Math.max(0, this.left - dt);
    else this.choke += dt;
  }

  /** At air: a new window is a gulp (all at once); the same window refills at `rate`. */
  breathe(from: number, length: number, dt: number, rate: number): void {
    this.choke = 0;
    if (from !== this.from || length !== this.length) {
      this.from = from;
      this.length = length;
      this.left = length;
      return;
    }
    this.left = Math.min(length, this.left + rate * dt);
  }

  reset(): void {
    this.from = 0;
    this.length = this.total;
    this.left = this.total;
    this.choke = 0;
  }

  /**
   * Per segment: [remaining fraction, available] for the meter. Segments
   * outside the window are unavailable; inside it they drain left to right.
   */
  segmentFill(i: number): [number, boolean] {
    const a = this.starts[i];
    const b = a + this.segments[i];
    const w0 = this.from;
    const w1 = this.from + this.length;
    if (b <= w0 + 1e-6 || a >= w1 - 1e-6) return [0, false];
    const lo = Math.max(a, this.position);
    const hi = Math.min(b, w1);
    return [Math.max(0, hi - lo) / this.segments[i], true];
  }
}
