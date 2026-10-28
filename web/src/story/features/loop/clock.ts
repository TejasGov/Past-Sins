interface Run {
  tl: gsap.core.Timeline;
  skippable: boolean;
  onSkip?: () => void;
  resolve: (skipped: boolean) => void;
}

/**
 * Plays GSAP timelines on game time: each timeline is paused and advanced by
 * `update(dt)` from the story tick, so cinematics stay frame-exact under
 * `await __game.stepAsync()` (GSAP's own ticker follows wall-clock time).
 */
export class CineClock {
  private runs: Run[] = [];

  get busy(): boolean {
    return this.runs.length > 0;
  }

  get skippable(): boolean {
    return this.runs.some((r) => r.skippable);
  }

  /** Resolves with true if the player skipped it. */
  play(tl: gsap.core.Timeline, skippable = false, onSkip?: () => void): Promise<boolean> {
    tl.pause(0);
    return new Promise((resolve) => this.runs.push({ tl, skippable, onSkip, resolve }));
  }

  update(dt: number): void {
    for (const r of [...this.runs]) {
      r.tl.time(Math.min(r.tl.duration(), r.tl.time() + dt));
      if (r.tl.time() >= r.tl.duration()) this.finish(r, false);
    }
  }

  /** Ends every skippable timeline now (their remaining callbacks don't fire). */
  skip(): void {
    for (const r of [...this.runs]) {
      if (!r.skippable) continue;
      r.tl.kill();
      r.onSkip?.();
      this.finish(r, true);
    }
  }

  private finish(r: Run, skipped: boolean): void {
    const i = this.runs.indexOf(r);
    if (i < 0) return;
    this.runs.splice(i, 1);
    r.resolve(skipped);
  }
}
