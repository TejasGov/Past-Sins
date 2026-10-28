import { BoxGeometry, Group, Mesh, MeshBasicMaterial } from "three";
import type { Game } from "../../../game/game";
import type { StoryDirector } from "../../director";
import { markInteractable, type Interactable } from "../../../interact/interactable";
import { resolvePlace } from "../../place";
import { CellFrame } from "./cell";
import { DoseStation, dietaryWindow, runDose, sayLines } from "./dose";
import { RoutineHud, clock, fill } from "./hud";
import { ScreenLook } from "./look";
import { Schedule, absHours, type Occurrence } from "./schedule";
import type { BeatDef, MissedDef, RoutineData } from "./data";

type LockState = "idle" | "waiting" | "closing" | "locking" | "locked" | "missed";

/** Moves `v` towards `target` by at most `step`. */
function approach(v: number, target: number, step: number): number {
  return v + Math.sign(target - v) * Math.min(Math.abs(target - v), step);
}

/** The bunk in N03: after lights out, sleep through to the morning count. */
class Bunk implements Interactable {
  readonly root = new Group();
  constructor(
    private prompt: () => string,
    private onUse: () => void,
    size: [number, number, number],
  ) {
    const hit = new Mesh(new BoxGeometry(...size), new MeshBasicMaterial({ visible: false }));
    this.root.add(hit);
    markInteractable(this.root, this);
  }
  getInteractionPrompt(): string {
    return this.prompt();
  }
  interact(): void {
    if (this.prompt()) this.onUse();
  }
}

/**
 * W2 · The daily routine on the 12-real-minute clock (data:
 * data/story/features/routine.json): every beat emits `routine:<id>`;
 * the 06:00 count and 19:00 lock-in check N03; lights out at 21:00; the
 * dietary-window dose at breakfast and dinner (Swallow / Pocket it) and the
 * withdrawal that follows a pocketed pill; a HUD line under the clock.
 */
export class RoutineRuntime {
  readonly story: StoryDirector;
  readonly schedule: Schedule;
  readonly cell: CellFrame | null;
  readonly hud: RoutineHud;
  readonly look: ScreenLook;
  readonly station: DoseStation;
  /** Withdrawal 0..1 (effects strength) and lights-out 0..1 (before the indoor weighting). */
  withdrawal = 0;
  dark = 0;
  lightsOut = false;
  private served = new Set<string>();
  private countDeadline = -1;
  private countResult: "" | "present" | "missed" | "excused" = "";
  private lock: LockState = "idle";
  private lockDeadline = -1;
  private lockTimer = 0;
  private holdTimer = 0;
  private holdFloor = 0;
  private withdrawalOn = false;
  private onsetSaid = false;
  private sleeping = 0;
  private fade = 0;
  private fadeTarget = 0;
  private fadeOwned = false;
  private seq = 0;

  constructor(
    readonly game: Game,
    readonly data: RoutineData,
  ) {
    this.story = game.story;
    this.schedule = new Schedule(data.beats);
    const anchor = game.anchors.get(data.cell.anchor);
    const gate = game.doors.find((d) => d.spec.persistentId === data.cell.gate) ?? null;
    if (!anchor) console.warn(`[routine] anchor "${data.cell.anchor}" not found; count and lock-in are off`);
    if (!gate) console.warn(`[routine] gate "${data.cell.gate}" not found`);
    this.cell = anchor ? new CellFrame(anchor, data.cell, gate) : null;
    this.hud = new RoutineHud(game.hud.root);
    this.look = new ScreenLook(game);
    this.station = new DoseStation(game, data.dose, () => void this.offerDose());
    if (!this.station.place(dietaryWindow(game.floors, data.dose.window), game)) console.warn("[routine] dietary window not found; no dose");
    this.spawnBunk();
  }

  private get t(): number {
    return absHours(this.game.env.dayNumber, this.game.env.timeHours);
  }

  private get ok(): (b: BeatDef) => boolean {
    return (b) => !b.when || this.story.check(b.when);
  }

  get inCell(): boolean {
    return !!this.cell && this.cell.contains(this.game.player.position);
  }

  // ── Frame ─────────────────────────────────────────────────────────────────
  update(dt: number): void {
    const g = this.game;
    this.hud.update(dt);
    if (!this.story.capturing && !g.failureInProgress) {
      for (const o of this.schedule.advance(this.t)) this.fire(o);
      this.updateCount();
      this.updateLockin(dt);
    }
    if (this.holdTimer > 0) {
      this.holdTimer -= dt;
      if (g.suspicion.value < this.holdFloor) g.suspicion.addSuspicion(this.holdFloor - g.suspicion.value);
    }
    this.updateDose();
    this.station.update(dt);
    this.updateWithdrawal(dt);
    const wd = this.data.withdrawal;
    const lo = this.data.lightsOut;
    this.dark = approach(this.dark, this.lightsOut && this.cameraInDarkChunk() ? 1 : 0, dt / Math.max(0.01, lo.rampSeconds));
    this.look.apply(dt, this.withdrawal, this.dark * g.lighting.indoor, wd, lo);
    if (this.fadeOwned) {
      this.fade = approach(this.fade, this.fadeTarget, dt / Math.max(0.01, this.data.sleep.fadeSeconds));
      g.render.fade.uniforms.get("amount")!.value = this.fade;
    }
    this.updateHud();
  }

  // ── Beats ─────────────────────────────────────────────────────────────────
  private fire(o: Occurrence): void {
    const b = o.beat;
    if (b.when && !this.story.check(b.when)) return;
    this.story.signal(`routine:${b.id}`, { day: o.day, hour: b.at, until: b.until, label: b.label, ...b.signalData });
    this.hud.flash();
    void sayLines(this.story, b.lines);
    if (b.actions?.length) void this.story.run(b.actions);
    if (b.id === "count") this.startCount(o);
    else if (b.id === "lockin") this.startLockin(o);
    else if (b.id === "lightsout") this.setLightsOut(true);
  }

  private setLightsOut(on: boolean): void {
    if (this.lightsOut === on) return;
    this.lightsOut = on;
    this.story.setFlag("cycle:lights_out", on);
    if (on) this.game.hud.showMessage(this.data.lightsOut.message, 2.2);
  }

  private cameraInDarkChunk(): boolean {
    const cam = this.game.render.camera.position;
    for (const c of this.game.chunks.values()) {
      if (!c.interior || c.bounds.isEmpty() || c.bounds.distanceToPoint(cam) > 0.5) continue;
      if (this.data.lightsOut.chunks.includes(c.name.split("_")[0])) return true;
    }
    return false;
  }

  // ── 06:00 count ───────────────────────────────────────────────────────────
  private startCount(o: Occurrence): void {
    this.setLightsOut(false);
    this.countDeadline = absHours(o.day, this.data.count.checkAt);
    this.countResult = "";
  }

  private updateCount(): void {
    if (this.countDeadline < 0 || this.t < this.countDeadline) return;
    this.countDeadline = -1;
    const c = this.data.count;
    if (this.inCell) {
      this.countResult = "present";
      void sayLines(this.story, c.presentLines);
    } else if (c.excuseWhen && this.story.check(c.excuseWhen)) this.countResult = "excused";
    else {
      this.countResult = "missed";
      this.missed(c.missed, "count");
    }
    if (c.openGate) this.cell?.unlock(true, this.game.player);
    this.story.setFlag("cycle:locked_in", false);
    this.lock = "idle";
  }

  // ── 19:00 lock-in ─────────────────────────────────────────────────────────
  private startLockin(o: Occurrence): void {
    const l = this.data.lockin;
    this.cell?.restoreKey();
    this.lockDeadline = absHours(o.day, l.graceUntil < o.beat.at ? l.graceUntil + 24 : l.graceUntil);
    this.lock = "waiting";
    this.story.setFlag("cycle:locked_in", false);
  }

  private updateLockin(dt: number): void {
    const l = this.data.lockin;
    const cell = this.cell;
    if (!cell || this.lock === "idle" || this.lock === "locked") return;
    const p = this.game.player;
    switch (this.lock) {
      case "waiting":
        if (this.inCell) {
          this.lock = "closing";
          this.lockTimer = l.closeDelay;
        } else if (this.t >= this.lockDeadline) {
          this.lock = "missed";
          this.missed(l.missed, "lockin");
          cell.close(p);
          this.lockTimer = 0.9;
        }
        break;
      case "closing":
        if (!this.inCell) this.lock = "waiting";
        else if ((this.lockTimer -= dt) <= 0) {
          cell.close(p);
          this.lock = "locking";
          this.lockTimer = 0.9;
        }
        break;
      case "locking":
        if ((this.lockTimer -= dt) > 0) break;
        if (cell.gate?.isOpen) {
          // Stepped back out into the doorway: the officer waits.
          this.lock = this.inCell ? "closing" : "waiting";
          this.lockTimer = l.closeDelay;
          break;
        }
        this.lockGate();
        this.lock = "locked";
        this.story.setFlag("cycle:locked_in");
        this.game.hud.showMessage(l.lockedMessage, 2.2);
        void sayLines(this.story, l.lockedLines);
        break;
      case "missed":
        // Lock the empty cell once the gate is shut.
        if (this.lockTimer > 0 && (this.lockTimer -= dt) <= 0) {
          if (cell.gate?.isOpen) {
            cell.close(p);
            this.lockTimer = 0.9;
          } else this.lockGate();
        }
        break;
    }
  }

  private lockGate(): void {
    const l = this.data.lockin;
    if (!l.lock || (l.leaveUnlockedWhen && this.story.check(l.leaveUnlockedWhen))) return;
    this.cell?.lock(l.gateKey);
  }

  /** Not in N03 when it mattered: suspicion held up for a while, the listed guards check the cell, `alarm`. */
  private missed(m: MissedDef, reason: string): void {
    const g = this.game;
    g.hud.showMessage(m.message, 2.6);
    void sayLines(this.story, m.lines);
    g.suspicion.addSuspicion(m.suspicion);
    this.holdFloor = m.suspicion;
    this.holdTimer = m.holdSeconds;
    const at = this.cell?.doorstep;
    if (at) for (const guard of g.guards.guards) if (m.alertGuards.includes(guard.def.id)) guard.hearNoise(at, 1e4, "routine");
    this.story.setFlag(m.flag);
    this.story.signal("alarm", { reason });
  }

  // ── The dose ──────────────────────────────────────────────────────────────
  private doseBeat(): Occurrence | null {
    return this.schedule.active(this.t, (b) => !!b.dose && this.ok(b));
  }

  private updateDose(): void {
    if (this.station.busy) return;
    const o = this.doseBeat();
    this.station.offering = !!o && !this.served.has(o.key) && !this.story.capturing;
  }

  private async offerDose(): Promise<void> {
    const o = this.doseBeat();
    if (!o || this.served.has(o.key)) return;
    this.served.add(o.key);
    await runDose(this.game, this.data.dose, this.station, o.beat.id, o.day);
  }

  private updateWithdrawal(dt: number): void {
    const wd = this.data.withdrawal;
    const on = this.story.hasFlag("cycle:withdrawal") && !this.story.capturing;
    const p = this.game.player;
    if (on !== this.withdrawalOn) {
      this.withdrawalOn = on;
      if (on) p.enterRestrictedZone("withdrawal", wd.suspicionMultiplier);
      else p.exitRestrictedZone("withdrawal");
      this.onsetSaid = false;
    }
    this.withdrawal = approach(this.withdrawal, on ? 1 : 0, dt / Math.max(0.01, on ? wd.onsetSeconds : wd.recoverSeconds));
    if (on && !this.onsetSaid && this.withdrawal >= 0.5) {
      this.onsetSaid = true;
      void sayLines(this.story, wd.onsetLines);
    }
  }

  // ── Sleep ─────────────────────────────────────────────────────────────────
  private spawnBunk(): void {
    const s = this.data.sleep;
    const g = this.game;
    const place = resolvePlace(s.at, g.anchors, g.floors, g.chunks);
    if (!place) return;
    const bunk = new Bunk(
      () => (!this.sleeping && this.inCell && (!s.when || this.story.check(s.when)) ? s.prompt : ""),
      () => void this.sleep(),
      s.size,
    );
    bunk.root.position.copy(place.position);
    bunk.root.rotation.y = place.yaw;
    g.chunkGroup("cellhouseA").add(bunk.root);
    g.interaction.register(bunk);
  }

  /** Fade out on the bunk, wake just before the count. */
  async sleep(): Promise<void> {
    const s = this.data.sleep;
    const g = this.game;
    const token = ++this.seq;
    this.sleeping = token;
    g.player.setControlEnabled(false);
    try {
      await sayLines(this.story, s.lines);
      this.fadeOwned = true;
      this.fadeTarget = 1;
      await this.story.sleep(s.fadeSeconds + 0.4);
      if (token !== this.seq) return;
      const h = g.env.timeHours;
      g.env.advanceHours(((s.wakeHour - h + 24) % 24) || 24);
      this.story.signal("routine:slept", { day: g.env.dayNumber, hour: g.env.timeHours });
      await this.story.sleep(0.8);
      if (token !== this.seq) return;
      this.fadeTarget = 0;
      await this.story.sleep(s.fadeSeconds);
      await sayLines(this.story, s.wakeLines);
    } finally {
      if (token === this.seq) {
        this.sleeping = 0;
        this.fadeOwned = false;
        g.render.fade.uniforms.get("amount")!.value = 0;
        this.fade = 0;
        if (!this.story.capturing) g.player.setControlEnabled(true);
      }
    }
  }

  // ── HUD ───────────────────────────────────────────────────────────────────
  private updateHud(): void {
    const h = this.data.hud;
    const t = this.t;
    const cur = this.schedule.active(t, this.ok);
    const nxt = this.schedule.next(t, this.ok);
    let urgent = false;
    let now = h.idle;
    if (cur) {
      const b = cur.beat;
      let hint = b.hint ?? "";
      if (b.id === "count") {
        if (this.countDeadline >= 0 && !this.inCell) [hint, urgent] = [h.toCell, true];
        else if (this.countResult === "missed") hint = this.data.count.missed.hint ?? hint;
      } else if (b.id === "lockin") {
        if ((this.lock === "waiting" || this.lock === "closing") && !this.inCell) [hint, urgent] = [h.toCell, true];
        else if (this.lock === "locked") hint = this.data.lockin.lockedHint ?? hint;
        else if (this.lock === "missed") hint = this.data.lockin.missed.hint ?? hint;
      } else if (b.dose && this.served.has(cur.key)) hint = this.data.dose.servedHint ?? hint;
      now = fill(hint ? h.now : h.nowNoHint, { label: b.label, hint, time: clock(b.at) });
    }
    const next = nxt ? fill(h.next, { label: nxt.beat.label, time: clock(nxt.beat.at) }) : "";
    this.hud.set(now, next, h.separator, urgent);
  }

  // ── Wipe ──────────────────────────────────────────────────────────────────
  onWipe(): void {
    this.seq++;
    this.schedule.reset();
    this.served.clear();
    this.countDeadline = -1;
    this.countResult = "";
    this.lock = "idle";
    this.holdTimer = 0;
    this.lightsOut = false;
    this.dark = 0;
    this.withdrawal = 0;
    this.withdrawalOn = false;
    this.onsetSaid = false;
    this.game.player.exitRestrictedZone("withdrawal");
    this.station.offering = false;
    this.cell?.restoreKey();
    this.look.reset();
    if (this.fadeOwned) {
      this.fadeOwned = false;
      this.fade = 0;
      this.game.render.fade.uniforms.get("amount")!.value = 0;
    }
    this.sleeping = 0;
  }

  /** Automation / dev: `__game.story.features.find((f) => f.id === "routine").runtime.debugInfo()`. */
  debugInfo(): Record<string, unknown> {
    const t = this.t;
    return {
      hud: this.hud.textContent,
      now: this.schedule.active(t, this.ok)?.key ?? null,
      next: this.schedule.next(t, this.ok)?.key ?? null,
      inCell: this.inCell,
      count: this.countDeadline >= 0 ? `pending until ${clock(this.countDeadline % 24)}` : this.countResult || "-",
      lock: this.lock,
      lightsOut: this.lightsOut,
      dark: +this.dark.toFixed(2),
      offering: this.station.offering,
      served: [...this.served],
      withdrawal: +this.withdrawal.toFixed(2),
      gate: this.cell?.gate ? { open: this.cell.gate.isOpen, locked: this.cell.gate.isLocked, key: this.cell.gate.spec.requiredKey } : null,
    };
  }
}
