import { gsap } from "gsap";
import { Vector2, Vector3, type Uniform } from "three";
import type { Game } from "../../../game/game";
import type { StoryDirector } from "../../director";
import type { ItemCategory } from "../../../systems/inventory";
import { resolvePlace } from "../../place";
import { CineClock } from "./clock";
import { LoopOverlay } from "./overlay";
import { CaptureSet } from "./set";
import { CELL_SHOTS, CellFrame, CellHotspot, CellMarks, HOTSPOTS } from "./cell";
import { fill, type LoopData, type LoopLine } from "./data";

type Where = "cell" | "infirmary";
type WakeKind = "cold_open" | "wipe" | "reload" | "night_restart";

interface WakeMarks {
  lying: Vector3;
  lyingLook: Vector3;
  sitting: Vector3;
  sitLook: Vector3;
  tally?: { eye: Vector3; look: Vector3 };
  feet: Vector3;
  yaw: number;
}

const SEEN_KEY = "blacksite.ghostexit.loop.seen.v1";
const NIGHT_RESTART_REASONS = ["caught", "alarm", "dose", "drowned", "count", "dev"];
const v3 = (a: readonly number[]) => new Vector3(a[0], a[1], a[2]);

/** Per-browser "already seen" marks, so intros can be skipped across `?fresh` saves. */
function seen(): { coldOpen?: boolean; capture?: boolean } {
  try {
    return JSON.parse(localStorage.getItem(SEEN_KEY) ?? "{}") as { coldOpen?: boolean; capture?: boolean };
  } catch {
    return {};
  }
}

function markSeen(key: "coldOpen" | "capture"): void {
  try {
    localStorage.setItem(SEEN_KEY, JSON.stringify({ ...seen(), [key]: true }));
  } catch {
    // Storage blocked: the intro just stays unskippable.
  }
}

/**
 * W1 runtime: the capture cinematic (seized → HQ restricted lift → NIDRA B2
 * Interrogation A → "Again."), waking (N03 or Infirmary bed 4), the cold
 * open, the N03 tally / wall / cistern stash, the B1 stair alarm, the 21:00
 * dose knock-out, the act 1 → 2 transition and the Act III night restart.
 * Every cinematic runs on game time (CineClock), so `__game.stepAsync()`
 * drives it exactly.
 */
export class LoopRuntime {
  readonly story: StoryDirector;
  readonly clock = new CineClock();
  readonly overlay: LoopOverlay;
  readonly set: CaptureSet;
  readonly frame: CellFrame | null = null;
  readonly marks: CellMarks | null = null;
  /** A loop cinematic owns the camera and controls. */
  busy = false;
  private introArmed = false;
  private introDone = false;
  private pendingWake: { first: boolean; infirmary: boolean } | null = null;
  private klaxonState: { t: number; noise: number; pos: Vector3 } | null = null;
  private lastHour = -1;
  private envWasEnabled = true;
  /** Bumped whenever a capture takes over, so an interrupted sequence doesn't hand control back. */
  private seq = 0;
  private refreshTimer = 0;
  private readonly chromaBase: Vector2;

  constructor(
    readonly game: Game,
    readonly data: LoopData,
  ) {
    const g = game;
    const story = g.story;
    this.story = story;
    this.chromaBase = g.render.chroma.offset.clone();
    this.overlay = new LoopOverlay(g.hud.root);
    this.set = new CaptureSet(g);
    story.wipeBanner = false;
    story.captureHandler = (reason) => this.onCapture(reason);

    const spawn = g.anchors.get("parth_spawn");
    if (spawn) {
      const frame = new CellFrame(spawn);
      this.frame = frame;
      const marks = new CellMarks(frame, (m) => g.render.prepareMaterial(m));
      this.marks = marks;
      const cells = g.chunkGroup("cellhouseA_cells");
      cells.add(marks.group);
      const wall = new CellHotspot(frame, HOTSPOTS.wall.center, HOTSPOTS.wall.size, () => (this.busy ? "" : (data.wall?.prompt ?? "")), () => this.readWall());
      const cistern = new CellHotspot(
        frame,
        HOTSPOTS.cistern.center,
        HOTSPOTS.cistern.size,
        () => (this.busy || !story.hasFlag("stash_unlocked") ? "" : (data.stash?.prompt ?? "")),
        () => void this.openStash(),
      );
      for (const h of [wall, cistern]) {
        cells.add(h.root);
        g.interaction.register(h);
      }
    } else console.warn("[loop] parth_spawn anchor missing: no N03 wall, tally or stash");

    story.events.on("wall", () => this.refreshWall());
    story.events.on("capture", () => this.stopKlaxon());
    story.events.on("wipe", () => void this.wakeAfterWipe());
    story.events.on("signal", ({ id, data: d }) => {
      if (id === "alarm" && d?.reason === "b1_stair") this.startKlaxon();
    });
    g.memory.events.on("clue_learned", () => this.refreshWall());
    // The cold open waits for the real start click (automation calling begin() skips it).
    g.hud.start.addEventListener("click", () => (this.introArmed = true));
    // A reload is another wake-up: the klaxon isn't saved, so the stair may sound again.
    story.setFlag("cycle:loop_alarm", false);
    this.refreshTally();
    this.refreshWall();
  }

  // ── Frame tick ────────────────────────────────────────────────────────────
  update(dt: number): void {
    const g = this.game;
    if (this.introArmed && !this.introDone) {
      this.introDone = true;
      this.intro();
    }
    if (this.clock.skippable && g.input.justPressed("KeyE")) this.clock.skip();
    this.clock.update(dt);
    if (this.set.escortGroup.visible) this.set.poseEscorts(g.cine.position, dt);
    this.tickKlaxon(dt);
    this.checkDose();
    this.refreshTimer -= dt;
    if (this.refreshTimer <= 0) {
      // Codes learned through data actions have no event of their own.
      this.refreshTimer = 1;
      this.refreshWall();
    }
  }

  onWipe(_cycle: number): void {
    const s = this.story;
    const infirmary = s.hasFlag("cycle:jagran") && !!this.infirmaryPlace();
    this.pendingWake = { first: !s.hasFlag("capture_first"), infirmary };
    this.begin();
    this.uniform("amount").value = 1;
    const m = this.wakeMarks(infirmary ? "infirmary" : "cell");
    if (m) this.game.player.teleport(m.feet, m.yaw, 0);
    this.refreshTally();
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  private uniform(name: "amount" | "desaturate" | "color"): Uniform {
    return this.game.render.fade.uniforms.get(name)!;
  }

  /** Takes the camera and controls (idempotent). */
  private begin(): void {
    const g = this.game;
    g.player.setControlEnabled(false);
    if (this.busy) return;
    this.busy = true;
    g.hud.setVisible(false);
    g.hud.root.classList.add("loop-cine");
    this.envWasEnabled = g.env.cycleEnabled;
    g.env.cycleEnabled = false;
  }

  /** Hands everything back. */
  private end(): void {
    const g = this.game;
    this.busy = false;
    g.cine.weight = 0;
    this.uniform("amount").value = 0;
    this.uniform("desaturate").value = 0;
    g.render.chroma.offset.copy(this.chromaBase);
    this.overlay.clear();
    this.set.window.visible = false;
    this.set.escortGroup.visible = false;
    g.hud.setVisible(true);
    g.hud.root.classList.remove("loop-cine");
    g.env.cycleEnabled = this.envWasEnabled;
    g.player.setControlEnabled(true);
  }

  private cut(eye: Vector3, look: Vector3): void {
    const c = this.game.cine;
    c.position.copy(eye);
    c.look.copy(look);
    c.weight = 1;
  }

  private say(line: LoopLine | undefined, id: string): void {
    if (!line?.text) return;
    const speaker = line.speaker ?? "";
    this.story.events.emit("dialogue", { id, speaker, text: line.text, audio: line.audio });
    void this.story.ui.say(speaker, line.text, line.seconds);
  }

  private beat(beat: string, reason?: string): void {
    this.story.signal("loop:capture_beat", reason ? { beat, reason } : { beat });
  }

  private chromaKick(tl: gsap.core.Timeline, at: number, strength = 0.008, repeat = 5): void {
    const c = this.game.render.chroma.offset;
    tl.to(c, { x: strength, y: strength * 0.6, duration: 0.1, yoyo: true, repeat, ease: "sine.inOut" }, at);
    tl.set(c, { x: this.chromaBase.x, y: this.chromaBase.y }, at + 0.1 * (repeat + 1));
  }

  // ── Capture ───────────────────────────────────────────────────────────────
  /** `story.captureHandler`: the cinematic, then "wipe" — or, in Act III, a night restart ("handled"). */
  async onCapture(reason: string): Promise<"wipe" | "handled"> {
    this.seq++;
    this.clock.cancel();
    this.stopKlaxon();
    this.story.addVar("loop:captures");
    const restart = this.data.nightRestart?.reasons ?? NIGHT_RESTART_REASONS;
    if (this.story.state.act === 3 && restart.includes(reason)) return this.nightRestart(reason);
    await this.captureCinematic(reason);
    return "wipe";
  }

  /** Seized: the camera is driven to the floor and the screen goes grey, then black. Returns its length. */
  private addSeize(tl: gsap.core.Timeline, reason: string): number {
    const g = this.game;
    const amount = this.uniform("amount");
    const desat = this.uniform("desaturate");
    tl.call(() => this.beat("seized", reason), [], 0);
    if (reason === "dose" || reason === "drowned") {
      tl.to(desat, { value: 0.85, duration: 0.6 }, 0);
      tl.to(amount, { value: 1, duration: 0.7, ease: "power1.in" }, 0);
      return 1.0;
    }
    const cam = g.render.camera;
    const eye = cam.position.clone();
    const fwd = cam.getWorldDirection(new Vector3()).setY(0);
    if (fwd.lengthSq() < 1e-4) fwd.set(0, 0, -1);
    fwd.normalize();
    this.cut(eye, eye.clone().add(fwd));
    g.cine.weight = 0;
    const floor = g.player.position.y;
    tl.to(g.cine, { weight: 1, duration: 0.2 }, 0);
    tl.to(g.cine.position, { x: eye.x + fwd.x * 0.3, y: floor + 0.55, z: eye.z + fwd.z * 0.3, duration: 0.85, ease: "power3.in" }, 0.05);
    tl.to(g.cine.look, { x: eye.x + fwd.x * 1.4, y: floor, z: eye.z + fwd.z * 1.4, duration: 0.8, ease: "power2.in" }, 0.05);
    this.chromaKick(tl, 0.85);
    tl.to(desat, { value: 0.85, duration: 0.8 }, 0);
    tl.to(amount, { value: 0.55, duration: 0.6 }, 0.25);
    tl.to(amount, { value: 1, duration: 0.6, ease: "power2.in" }, 1.3);
    (this.data.capture?.seize?.[reason] ?? []).forEach((line, i) => tl.call(() => this.say(line, "capture_seize"), [], 0.15 + i * 1.8));
    return 2.1;
  }

  /** The full capture: seized → HQ restricted lift → descent → the chair, the glass, "Again." → black. */
  private async captureCinematic(reason: string): Promise<void> {
    const g = this.game;
    const c = this.data.capture ?? {};
    const skippable = this.story.hasFlag("loop:capture_seen") || !!seen().capture;
    this.begin();
    const amount = this.uniform("amount");
    const desat = this.uniform("desaturate");
    const o = this.overlay;
    const S = this.set;
    const tl = gsap.timeline();
    let t = this.addSeize(tl, reason);
    tl.to([o.barTop, o.barBottom], { scaleY: 1, duration: 0.6, ease: "power2.out" }, t);

    // HQ restricted lift: dragged across the vestibule between two guards, head down.
    const L = S.lift;
    t += 0.5;
    tl.call(
      () => {
        this.cut(L.from, L.look);
        S.escortGroup.visible = S.escortsReady;
        o.setCaption(c.liftCaption ?? "");
        this.beat("lift", reason);
      },
      [],
      t,
    );
    tl.to(g.cine.position, { x: L.to.x, z: L.to.z, duration: 4.0, ease: "none" }, t);
    tl.to(g.cine.position, { y: `-=0.07`, duration: 0.42, yoyo: true, repeat: 9, ease: "sine.inOut" }, t);
    tl.to(desat, { value: 0.8, duration: 0.2 }, t);
    tl.to(amount, { value: 0.38, duration: 0.7 }, t);
    tl.to(o.caption, { opacity: 1, duration: 0.8 }, t + 0.5);
    tl.to(o.caption, { opacity: 0, duration: 0.6 }, t + 3.2);
    tl.to(amount, { value: 1, duration: 0.6, ease: "power1.in" }, t + 3.5);
    t += 4.2;

    // The descent: black, light from the shaft sliding past.
    tl.call(() => ((S.escortGroup.visible = false), this.beat("descent", reason)), [], t);
    tl.to(o.streaks, { opacity: 1, duration: 0.4 }, t);
    tl.to(o.streaks, { opacity: 0, duration: 0.4 }, t + 1.5);
    t += 2.0;

    // NIDRA B2, Interrogation A: the chair, the glass, her silhouette, the speaker.
    tl.call(
      () => {
        this.cut(S.chair.eye, S.chair.look);
        S.window.visible = true;
        o.setCaption(c.chairCaption ?? "");
        this.beat("chair", reason);
      },
      [],
      t,
    );
    tl.to(g.cine.position, { x: S.chair.push.x, y: S.chair.push.y, z: S.chair.push.z, duration: 7.6, ease: "sine.inOut" }, t);
    tl.to(desat, { value: 0.62, duration: 0.2 }, t);
    tl.to(amount, { value: 0.12, duration: 1.6, ease: "power1.out" }, t + 0.1);
    tl.to(o.caption, { opacity: 1, duration: 0.8 }, t + 0.7);
    tl.to(o.caption, { opacity: 0, duration: 0.6 }, t + 3.0);
    tl.call(() => (this.beat("again", reason), this.say(c.again, "capture")), [], t + 3.0);
    this.chromaKick(tl, t + 3.0, 0.004, 3);
    tl.to(amount, { value: 1, duration: 2.0, ease: "power2.in" }, t + 6.0);
    t += 8.4;
    tl.call(() => this.beat("black", reason), [], t - 0.3);
    tl.to({}, { duration: 0.01 }, t);

    o.setSkipHint(skippable ? (c.skipHint ?? "") : null);
    await this.clock.play(tl, skippable, () => {
      amount.value = 1;
      this.story.ui.clearSubtitles();
    });
    o.setSkipHint(null);
    S.window.visible = false;
    S.escortGroup.visible = false;
    o.caption.style.opacity = "0";
    o.streaks.style.opacity = "0";
    g.render.chroma.offset.copy(this.chromaBase);
    amount.value = 1;
    this.story.setFlag("loop:capture_seen");
    markSeen("capture");
  }

  /** Act III: a capture restarts the night in N03 at 19:00 — same cycle, inventory kept. */
  private async nightRestart(reason: string): Promise<"handled"> {
    const g = this.game;
    const nr = this.data.nightRestart ?? {};
    this.begin();
    const tl = gsap.timeline();
    const t = this.addSeize(tl, reason);
    tl.to({}, { duration: 0.01 }, t);
    await this.clock.play(tl);
    this.uniform("amount").value = 1;
    if (nr.banner) void this.story.ui.banner(nr.banner, nr.sub ?? "", 3.6);
    await this.story.sleep(4);
    g.detentionReset();
    g.env.setTimeHours(nr.hour ?? 19);
    this.story.addVar("loop:night_restarts");
    this.story.signal("loop:night_restart", { reason });
    await this.wake("cell", "night_restart");
    return "handled";
  }

  // ── Waking ────────────────────────────────────────────────────────────────
  private infirmaryPlace(): Vector3 | null {
    const bed = this.data.infirmary?.bed;
    const g = this.game;
    return bed ? (resolvePlace(bed, g.anchors, g.floors)?.position ?? null) : null;
  }

  private wakeMarks(where: Where): WakeMarks | null {
    if (where === "infirmary") {
      const bed = this.infirmaryPlace();
      const d = this.data.infirmary ?? {};
      if (!bed) return null;
      const at = (o: readonly number[] | undefined, fallback: number[]) => bed.clone().add(v3(o ?? fallback));
      return {
        lying: at(d.eye, [0.66, 0.98, 0]),
        lyingLook: at(d.look, [-0.6, 2.6, 0]),
        sitting: at(d.sit, [0.1, 1.28, -0.25]),
        sitLook: at(d.sitLook, [-2.4, 1.15, -0.4]),
        feet: at(d.stand, [0, 0, -1]),
        yaw: d.standYaw ?? Math.PI / 2,
      };
    }
    const f = this.frame;
    if (!f) return null;
    const p = (a: readonly number[]) => f.toWorld(a[0], a[1], a[2]);
    return {
      lying: p(CELL_SHOTS.lying.eye),
      lyingLook: p(CELL_SHOTS.lying.look),
      sitting: p(CELL_SHOTS.sitting.eye),
      sitLook: p(CELL_SHOTS.sitting.look),
      tally: { eye: p(CELL_SHOTS.tally.eye), look: p(CELL_SHOTS.tally.look) },
      feet: p(CELL_SHOTS.stand.feet),
      // Facing the wall: the first thing every cycle shows is what he already knows.
      yaw: f.facing(CELL_SHOTS.stand.dir[0], CELL_SHOTS.stand.dir[1]),
    };
  }

  private async wakeAfterWipe(): Promise<void> {
    const w = this.pendingWake;
    this.pendingWake = null;
    if (!w) return;
    const s = this.story;
    if (w.first) {
      // The first capture was always going to happen: the loop is the story.
      s.setFlag("capture_first");
      if (s.state.act < 2) {
        s.setAct(2);
        await s.sleep(4.6);
      }
    }
    if (w.infirmary) {
      // Jagran made this wipe shallow: he wakes where she sat with him, and remembers the cistern.
      s.setFlag("cycle:loop_infirmary");
      s.setFlag("stash_unlocked");
    }
    const token = this.seq;
    await this.wake(w.infirmary ? "infirmary" : "cell", "wipe");
    const shard = this.data.infirmary?.shard;
    if (w.infirmary && shard && token === this.seq) await s.playShard(shard);
  }

  /**
   * Eyes open (lids + fade), a breath, sit up, glance at the tally, then the
   * camera hands back to Parth standing in the cell (or beside bed 4).
   */
  async wake(where: Where, kind: WakeKind): Promise<void> {
    const g = this.game;
    const token = this.seq;
    const m = this.wakeMarks(where) ?? (where === "infirmary" ? this.wakeMarks("cell") : null);
    this.begin();
    const amount = this.uniform("amount");
    const desat = this.uniform("desaturate");
    const o = this.overlay;
    if (!m) {
      this.end();
      return;
    }
    g.player.teleport(m.feet, m.yaw, 0);
    this.cut(m.lying, m.lyingLook);
    this.refreshTally();
    const cycle = this.story.state.cycle;
    this.story.signal("loop:wake", { where, kind, cycle });
    const tl = gsap.timeline();
    let t = 0;
    if (kind === "cold_open") {
      // Smash cut: he's already sitting bolt upright, gasping.
      tl.set(amount, { value: 0 }, 0);
      tl.set(desat, { value: 0.3 }, 0);
      tl.set(o.flash, { opacity: 0.85 }, 0);
      tl.to(o.flash, { opacity: 0, duration: 0.45, ease: "power2.out" }, 0.02);
      tl.to(g.cine.position, { x: m.sitting.x, y: m.sitting.y, z: m.sitting.z, duration: 0.42, ease: "power3.out" }, 0);
      tl.to(g.cine.look, { x: m.sitLook.x, y: m.sitLook.y + 0.6, z: m.sitLook.z, duration: 0.5, ease: "power3.out" }, 0);
      tl.call(() => this.story.signal("loop:gasp"), [], 0);
      this.chromaKick(tl, 0, 0.012, 3);
      for (let i = 0; i < 3; i++) tl.to(g.cine.position, { y: `+=${0.05 - i * 0.012}`, duration: 0.45 + i * 0.15, yoyo: true, repeat: 1, ease: "sine.inOut" }, 0.6 + i * 1.25);
      tl.call(() => this.story.signal("loop:breath", { heavy: true }), [], 0.6);
      tl.to(g.cine.look, { x: m.sitLook.x, y: m.sitLook.y, z: m.sitLook.z, duration: 2.0, ease: "sine.inOut" }, 1.0);
      tl.to(desat, { value: 0, duration: 3 }, 0.5);
      t = 4.4;
    } else {
      // Eyes open: half, a slow blink, then properly. A breath.
      tl.set(o.lidTop, { yPercent: 0 }, 0);
      tl.set(o.lidBottom, { yPercent: 0 }, 0);
      tl.set(amount, { value: 0.35 }, 0);
      tl.set(desat, { value: 0.6 }, 0);
      tl.to(o.lidTop, { yPercent: -45, duration: 0.9, ease: "power1.out" }, 0.5);
      tl.to(o.lidBottom, { yPercent: 45, duration: 0.9, ease: "power1.out" }, 0.5);
      tl.to([o.lidTop, o.lidBottom], { yPercent: 0, duration: 0.22, ease: "power2.in" }, 1.6);
      tl.to(o.lidTop, { yPercent: -112, duration: 1.3, ease: "power2.out" }, 2.0);
      tl.to(o.lidBottom, { yPercent: 112, duration: 1.3, ease: "power2.out" }, 2.0);
      tl.to(amount, { value: 0, duration: 2.2 }, 1.9);
      tl.to([o.barTop, o.barBottom], { scaleY: 0, duration: 1.4, ease: "power2.inOut" }, 2.2);
      tl.to(desat, { value: 0, duration: 3.2 }, 1.9);
      tl.call(() => this.story.signal("loop:breath", { heavy: false }), [], 2.4);
      tl.to(g.cine.position, { y: `+=0.035`, duration: 1.1, yoyo: true, repeat: 1, ease: "sine.inOut" }, 2.4);
      t = 4.6;
      tl.to(g.cine.position, { x: m.sitting.x, y: m.sitting.y, z: m.sitting.z, duration: 1.5, ease: "power2.inOut" }, t);
      tl.to(g.cine.look, { x: m.sitLook.x, y: m.sitLook.y, z: m.sitLook.z, duration: 1.5, ease: "power2.inOut" }, t);
      t += 1.7;
    }
    // A new cycle: look under the bunk, where the count is kept.
    if (m.tally && (kind === "wipe" || kind === "cold_open")) {
      tl.to(g.cine.position, { x: m.tally.eye.x, y: m.tally.eye.y, z: m.tally.eye.z, duration: 1.3, ease: "power2.inOut" }, t);
      tl.to(g.cine.look, { x: m.tally.look.x, y: m.tally.look.y, z: m.tally.look.z, duration: 1.2, ease: "power2.inOut" }, t);
      t += 3.0;
    }
    const w = this.data.wake ?? {};
    // A wipe always wakes him at 06:00; a reload or the first start keeps the session's clock.
    const sub = kind === "reload" || kind === "cold_open" ? w.reloadSub : where === "infirmary" ? w.infirmarySub : w.sub;
    const banner = kind === "night_restart" ? "" : fill(w.banner, { cycle });
    tl.call(() => banner && void this.story.ui.banner(banner, sub ?? "", 3.4), [], t);
    tl.to(g.cine, { weight: 0, duration: 1.5, ease: "power2.inOut" }, t);
    t += 1.6;
    tl.to({}, { duration: 0.01 }, t);
    const skippable = kind !== "cold_open" && (this.story.hasFlag("loop:capture_seen") || !!seen().capture);
    o.setSkipHint(skippable ? (this.data.capture?.skipHint ?? "") : null);
    await this.clock.play(tl, skippable, () => {
      if (banner) void this.story.ui.banner(banner, sub ?? "", 2.4);
    });
    if (token === this.seq) this.end();
  }

  // ── Cold open ─────────────────────────────────────────────────────────────
  /** First start click of a session: the cold open on a fresh save, otherwise a short wake. */
  intro(): void {
    const s = this.story;
    if (this.busy || s.capturing) return;
    if (!s.hasFlag("cold_open_done") && s.state.cycle === 41 && s.state.act === 1) void this.coldOpen();
    else {
      s.setFlag("cold_open_done");
      void this.wake("cell", "reload");
    }
  }

  /** Black, water, a child counting "two… seven… one… eight…", a small hand slipping free — then N03. */
  async coldOpen(): Promise<void> {
    const o = this.overlay;
    const token = this.seq;
    this.begin();
    this.uniform("amount").value = 1;
    const m = this.wakeMarks("cell");
    if (m) this.cut(m.lying, m.lyingLook);
    gsap.set(o.water, { opacity: 1 });
    gsap.set(o.adultHand, { y: -70, opacity: 0 });
    gsap.set(o.childHand, { y: 60, opacity: 0, scale: 1, transformOrigin: "50% 50%" });
    this.story.signal("cold_open");
    const tl = gsap.timeline();
    let t = 1.2;
    const lines = this.data.coldOpen?.lines ?? [];
    let eight = t;
    lines.forEach((line, i) => {
      if (i === lines.length - 1) eight = t;
      tl.call(() => this.say(line, "cold_open"), [], t);
      t += line.seconds ?? 1.4;
    });
    // Two hands in dark water; the small one holds on, then slips.
    tl.to(o.adultHand, { opacity: 0.85, y: -24, duration: 3.2, ease: "sine.out" }, 1.4);
    tl.to(o.childHand, { opacity: 0.9, y: 6, duration: 3.0, ease: "sine.out" }, 1.8);
    tl.to(o.childHand, { y: 14, rotation: 4, duration: 0.6, yoyo: true, repeat: 3, ease: "sine.inOut" }, 4.8);
    tl.to(o.childHand, { y: 300, opacity: 0, rotation: -14, duration: 2.4, ease: "power2.in" }, eight + 0.5);
    tl.to(o.adultHand, { y: -60, duration: 1.4, ease: "power2.out" }, eight + 0.8);
    tl.to(o.adultHand, { opacity: 0.25, duration: 1.6 }, eight + 1.4);
    const cut = eight + 3.0;
    tl.set(o.water, { opacity: 0 }, cut);
    tl.to({}, { duration: 0.01 }, cut);
    const skippable = !!seen().coldOpen;
    o.setSkipHint(skippable ? (this.data.capture?.skipHint ?? "") : null);
    await this.clock.play(tl, skippable, () => {
      gsap.set(o.water, { opacity: 0 });
      this.story.ui.clearSubtitles();
    });
    this.story.setFlag("cold_open_done");
    markSeen("coldOpen");
    if (token === this.seq) await this.wake("cell", "cold_open");
  }

  // ── The 21:00 dose (first cycle only) ─────────────────────────────────────
  private checkDose(): void {
    const h = this.game.env.timeHours;
    const hour = this.data.dose?.hour ?? 21;
    const crossed = this.lastHour >= 0 && this.lastHour < hour && h >= hour && h - this.lastHour < 1;
    this.lastHour = h;
    const s = this.story;
    if (crossed && !s.hasFlag("capture_first") && s.state.act === 1 && !s.capturing && !this.busy) void this.knockout();
  }

  /** Parth was never caught on his first cycle: the dose takes him down where he stands. */
  async knockout(): Promise<void> {
    const g = this.game;
    const token = this.seq;
    this.begin();
    this.story.signal("loop:knockout");
    const amount = this.uniform("amount");
    const desat = this.uniform("desaturate");
    const cam = g.render.camera;
    const eye = cam.position.clone();
    const fwd = cam.getWorldDirection(new Vector3()).setY(0);
    if (fwd.lengthSq() < 1e-4) fwd.set(0, 0, -1);
    fwd.normalize();
    const side = new Vector3(-fwd.z, 0, fwd.x);
    this.cut(eye, eye.clone().add(fwd));
    g.cine.weight = 0;
    const floor = g.player.position.y;
    const tl = gsap.timeline();
    tl.to(g.cine, { weight: 1, duration: 0.4 }, 0);
    (this.data.dose?.lines ?? []).forEach((line, i) => tl.call(() => this.say(line, "loop_dose"), [], 0.3 + i * 2.6));
    tl.to(desat, { value: 0.8, duration: 3 }, 0);
    tl.to(amount, { value: 0.45, duration: 1.6 }, 0.2);
    tl.to(amount, { value: 0.2, duration: 0.8, yoyo: true, repeat: 1 }, 1.8);
    tl.to(g.cine.look, { x: `+=${side.x * 0.8}`, z: `+=${side.z * 0.8}`, duration: 1.1, yoyo: true, repeat: 1, ease: "sine.inOut" }, 0.4);
    this.chromaKick(tl, 1.2, 0.006, 7);
    tl.to(g.cine.position, { x: eye.x + side.x * 0.4, y: floor + 0.35, z: eye.z + side.z * 0.4, duration: 1.0, ease: "power3.in" }, 3.0);
    tl.to(g.cine.look, { x: eye.x + side.x * 2, y: floor + 0.1, z: eye.z + side.z * 2, duration: 1.0, ease: "power2.in" }, 3.0);
    tl.to(amount, { value: 1, duration: 0.5 }, 3.8);
    tl.to({}, { duration: 0.01 }, 4.4);
    await this.clock.play(tl);
    if (token === this.seq) void this.story.capture("dose");
  }

  // ── The B1 service stair alarm (acts 1–2) ─────────────────────────────────
  startKlaxon(): void {
    const g = this.game;
    if (this.klaxonState || this.story.capturing) return;
    this.klaxonState = { t: this.data.alarm?.captureAfter ?? 12, noise: 0, pos: g.player.position.clone() };
    if (this.data.alarm?.message) g.hud.showMessage(this.data.alarm.message, 3);
    this.overlay.klaxon(true);
    g.suspicion.value = 100;
    this.story.signal("loop:klaxon", { on: true });
  }

  private tickKlaxon(dt: number): void {
    const k = this.klaxonState;
    if (!k) return;
    const g = this.game;
    k.t -= dt;
    k.noise -= dt;
    if (g.suspicion.value < 100) g.suspicion.value = 100;
    if (k.noise <= 0) {
      k.noise = this.data.alarm?.noiseEvery ?? 2.5;
      g.noise.emitNoise(k.pos, 1, "ALARM", "alarm");
      g.noise.emitNoise(g.player.position, 1, "ALARM", "alarm");
    }
    // Nobody got to him first: the facility does.
    if (k.t <= 0) {
      this.stopKlaxon();
      void this.story.capture("alarm");
    }
  }

  stopKlaxon(): void {
    if (!this.klaxonState) return;
    this.klaxonState = null;
    this.overlay.klaxon(false);
    this.story.signal("loop:klaxon", { on: false });
  }

  // ── N03: tally, wall, stash ───────────────────────────────────────────────
  refreshTally(): void {
    this.marks?.setTally(Math.max(0, this.story.state.cycle - 1));
  }

  refreshWall(): void {
    const w = this.data.wall ?? {};
    this.marks?.setWall({
      entries: this.story.state.wall,
      codes: [...this.story.state.codes],
      faded: w.faded ?? [],
      entryFormat: (e) => fill(w.entryFormat ?? "{text}", { text: e.text, cycle: e.cycle }),
      cycleFormat: (e) => fill(w.cycleFormat ?? "{cycle}", { text: e.text, cycle: e.cycle }),
      codeFormat: (code) => fill(w.codeFormat ?? "{code}", { code }),
    });
  }

  readWall(): void {
    const w = this.data.wall ?? {};
    const s = this.story.state;
    const lines = s.wall.map((e) => fill(w.docEntry ?? "{text}", { text: e.text, cycle: e.cycle }));
    let body = lines.length ? lines.join("\n\n") : (w.empty ?? "");
    if (s.codes.size) body += `\n\n${fill(w.docCodes ?? "{codes}", { codes: [...s.codes].join("   ") })}`;
    void this.story.ui.showDocument({ id: "loop_wall", title: w.title ?? "", body, footer: w.footer, style: w.style ?? "note" });
  }

  private itemLabel(id: string): string {
    return this.data.stash?.items?.[id]?.label ?? id.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
  }

  private itemCategory(id: string): ItemCategory {
    const c = this.data.stash?.items?.[id]?.category;
    if (c) return c as ItemCategory;
    return id.endsWith("_key") ? "KEY" : id.endsWith("_card") ? "ACCESS_CARD" : "MISSION_ITEM";
  }

  /** The cistern: hide things in it, take them out. Whatever is inside survives the wipe. */
  async openStash(): Promise<void> {
    const g = this.game;
    const s = this.story;
    const st = this.data.stash ?? {};
    for (let guard = 0; guard < 20; guard++) {
      const stash = [...s.state.stash];
      const carried = g.inventory.entries().filter((e) => !e.def.devOnly && !s.state.stash.has(e.def.id));
      const options: { label: string; run: () => void }[] = [
        ...stash.map((id) => ({
          label: fill(st.take, { item: this.itemLabel(id) }),
          run: () => {
            const label = this.itemLabel(id);
            if (!g.inventory.add({ id, displayName: label, category: this.itemCategory(id) }, 1, true)) return;
            s.state.stash.delete(id);
            s.save();
            g.hud.showMessage(fill(st.retrieved, { item: label.toUpperCase() }), 2);
            s.signal("loop:stash", { action: "take", item: id });
          },
        })),
        ...carried.map((e) => ({
          label: fill(st.put, { item: e.def.displayName }),
          run: () => {
            if (!g.inventory.remove(e.def.id)) return;
            s.state.stash.add(e.def.id);
            s.save();
            g.hud.showMessage(fill(st.stored, { item: e.def.displayName.toUpperCase() }), 2);
            s.signal("loop:stash", { action: "put", item: e.def.id });
          },
        })),
        { label: st.leave ?? "", run: () => undefined },
      ];
      const prompt = stash.length ? (st.title ?? "") : `${st.title ?? ""}  ·  ${st.empty ?? ""}`;
      const pick = await s.ui.choose(options.map((x) => x.label), prompt);
      if (pick === options.length - 1) return;
      options[pick].run();
    }
  }

  debugInfo(): Record<string, unknown> {
    return {
      busy: this.busy,
      klaxon: this.klaxonState ? +this.klaxonState.t.toFixed(1) : null,
      stash: [...this.story.state.stash],
      escorts: this.set.escortsReady,
      windowSet: this.set.ok,
    };
  }
}
