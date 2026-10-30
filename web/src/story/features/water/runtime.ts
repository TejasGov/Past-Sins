import { Vector3, type Object3D } from "three";
import type { Game } from "../../../game/game";
import type { SwimmingPool } from "../../../world/pool";
import { culvertHatchWater, culvertWater, type CulvertLayout } from "../../../world/campus/culvert";
import { Breath } from "./breath";
import { WaterOverlay } from "./overlay";
import { DeckGuards, GrateShimmer, HandRig, WaterProp } from "./props";
import type { WaterData } from "./data";

type Mode = "free" | "transition" | "grip" | "memory" | "t3" | "drowning" | "hand" | "released" | "surfaced" | "taken";

/** Modes in which the breath clock stands still (cinematics, the hand, after the choice). */
const FROZEN: Mode[] = ["transition", "memory", "t3", "drowning", "hand", "released", "surfaced", "taken"];

interface Fade {
  from: number;
  to: number;
  t: number;
  dur: number;
  resolve: () => void;
}

const V = (a: number[]) => new Vector3(a[0], a[1], a[2]);

/**
 * W3 · Water at runtime: breath under water (Raman counts the segments, the
 * meter empties, Parth chokes, drowns → capture), the pool's tank shards
 * (T1 at the shallow end, the deep-end grate for T2 and T3, then Meera over
 * the deck speaker and Act III), and the Ghost Exit culvert (sump → pockets →
 * the hand → the reservoir at dawn). Everything runs on game time, so
 * `__game.stepAsync()` automation is exact.
 */
export class WaterRuntime {
  readonly breath: Breath;
  readonly ui: WaterOverlay;
  mode: Mode = "free";
  /** Dev/automation: the meter never empties. */
  infiniteBreath = false;
  readonly pool: SwimmingPool | null;
  readonly culvert: SwimmingPool[] = [];
  readonly grateAt: Vector3 | null = null;
  readonly speakerAt: Vector3 | null = null;
  readonly hand: HandRig;
  private grate: WaterProp | null = null;
  private hatchWater: SwimmingPool | null = null;
  private shimmer: GrateShimmer | null = null;
  private guards: DeckGuards;
  private guardsCleanup = false;
  private wasUnder = false;
  /** The current dive began from a full 18 s (the grate wants Raman's whole game). */
  private diveFull = false;
  private counted = -1;
  private underTime = 0;
  private t1Timer = 0;
  private tried = new Set<string>();
  private grip: { shard: string; t: number; feet: Vector3 } | null = null;
  private look: Vector3 | null = null;
  private choice: { release: number; hold: number } | null = null;
  private pocketsSeen = new Set<number>();
  private handArmed = true;
  private fades: Fade[] = [];
  private chroma = 0;
  /** Bumped on every reset; async sequences stop when it changes under them. */
  private gen = 0;

  constructor(
    readonly game: Game,
    readonly data: WaterData,
    readonly layout: CulvertLayout | null,
  ) {
    const g = game;
    this.breath = new Breath(data.breath.segments);
    this.ui = new WaterOverlay(g.hud.root, this.breath, data.breath.labels, data.breath.caption);
    this.pool = g.pools.find((p) => p.tag === "pool") ?? g.pools[0] ?? null;
    this.guards = new DeckGuards(g.render.scene, g.render.prepareMaterial);
    this.hand = new HandRig(g.render.prepareMaterial);
    g.render.scene.add(this.hand.root);

    const anchor = g.anchors.get("pool");
    if (anchor) {
      this.grateAt = anchor.position.clone().add(V(data.pool.grate.at));
      this.speakerAt = anchor.position.clone().add(V(data.pool.t3.speaker)).add(new Vector3(0, 2.9, 0.3));
      this.grate = this.prop(this.grateAt.clone().add(new Vector3(0, 0.22, 0)), new Vector3(1.3, 0.44, 0.9), () => this.gratePrompt(), () => this.useGrate());
      this.shimmer = new GrateShimmer(this.grateAt);
      g.render.scene.add(this.shimmer.mesh);
    }

    const L = layout;
    if (L) {
      this.culvert = culvertWater(L);
      for (const w of this.culvert) {
        g.pools.push(w);
        if (w.mesh.visible) g.render.scene.add(w.mesh);
      }
      // Hatch water is only a surface to look at: updated with the pools' clock, not swimmable.
      const hatch = culvertHatchWater(L);
      g.render.scene.add(hatch.mesh);
      this.hatchWater = hatch;
      this.prop(L.hatch.clone().add(new Vector3(0, 0.25, 0)), new Vector3(1.3, 0.5, 1.3), () => this.hatchPrompt(), () => void this.enterSump());
      this.prop(new Vector3(L.x, L.shaft.surfaceY + 0.25, L.tube.z0 + 0.22), new Vector3(0.8, 1.2, 0.36), () => this.ladderPrompt(), () => void this.climbOut());
    } else console.warn("[water] maintenance-b1 pump room not found: no culvert");

    g.story.events.on("capture", () => this.onCapture());
  }

  private prop(at: Vector3, size: Vector3, prompt: () => string, use: () => void): WaterProp {
    const p = new WaterProp(size, prompt, use);
    p.root.position.copy(at);
    this.game.render.scene.add(p.root);
    this.game.interaction.register(p);
    return p;
  }

  // ── Frame ─────────────────────────────────────────────────────────────────
  update(dt: number): void {
    const g = this.game;
    const s = g.story;
    const swim = g.swim;
    this.stepFades(dt);
    this.hatchWater?.update(dt);
    // The water shader's glint follows the sky (it stayed at full sun through the night).
    const sun = Math.min(1, g.env.skySample().daylight * 1.2) * (g.env.weather === "RAINY" ? 0.15 : 1);
    for (const w of g.pools) w.setSun(sun);
    this.hand.update(dt);
    this.guards.update(dt);
    if (this.guardsCleanup && !s.capturing && this.mode !== "t3") {
      this.guardsCleanup = false;
      this.guards.dispose();
    }
    this.shimmer?.update(dt, this.shimmerOn());
    this.updateLook(dt);
    this.updateChroma(dt);

    const vol = swim.water;
    const air = swim.cameraWater ?? vol;
    const under = swim.underwater;
    if (!this.frozen()) this.updateBreath(dt, under, air);

    switch (this.mode) {
      case "free":
        this.checkT1(dt, vol, under);
        if (this.layout && this.handArmed && vol?.tag.startsWith("culvert:") && this.layout.handZone.containsPoint(g.player.center)) void this.offerHand();
        break;
      case "grip":
        this.updateGrip(dt);
        break;
      case "hand":
        this.updateChoice(dt);
        break;
      case "released":
        if (vol?.tag === "reservoir" && !under) this.surfaced();
        break;
    }

    const tag = air?.tag ?? "";
    const b = this.breath;
    const culvert = tag.startsWith("culvert:");
    // In the culvert the meter stays up at the air spaces too: it shows which segment the air bought.
    const ending = this.mode === "hand" || this.mode === "released" || this.mode === "surfaced" || this.mode === "taken";
    const meter = !!vol && !g.hud.memoryPlaying && !ending && (under || culvert || b.left < b.length - 0.05 || b.choke > 0);
    this.ui.darkTarget = culvert ? (under ? 1 : 0.5) : 0;
    this.ui.update(dt, b, meter, Math.min(1, b.choke / this.data.breath.chokeSeconds));
    this.wasUnder = under;
  }

  private frozen(): boolean {
    const g = this.game;
    return this.infiniteBreath || FROZEN.includes(this.mode) || g.hud.memoryPlaying || g.story.capturing || g.failureInProgress || g.player.noclip;
  }

  // ── Breath ────────────────────────────────────────────────────────────────
  private updateBreath(dt: number, under: boolean, air: SwimmingPool | null): void {
    const b = this.breath;
    if (under) {
      if (!this.wasUnder) {
        this.diveFull = b.full;
        this.counted = -1;
        this.underTime = 0;
      }
      b.hold(dt);
      this.underTime += dt;
      const seg = b.segment;
      // A dip at the surface isn't a dive: Raman waits a beat before the first count.
      if (seg !== this.counted && b.left > 0 && (this.counted >= 0 || this.underTime > 0.3)) {
        this.counted = seg;
        this.count(seg);
      }
      if (b.choke >= this.data.breath.chokeSeconds) void this.drown();
      return;
    }
    const [from, length] = this.windowFor(air);
    const choking = b.choke > 0;
    b.breathe(from, length, dt, this.data.breath.refillPerSecond);
    if (this.wasUnder) {
      this.counted = -1;
      this.surfacedAt(air, choking);
    }
  }

  /** Air in the culvert only buys the next segment: the sump the 2, pocket i the segment after it. */
  private windowFor(air: SwimmingPool | null): [number, number] {
    const tag = air?.tag ?? "";
    if (tag === "culvert:sump") return this.breath.windowFor(0);
    const m = /^culvert:pocket:(\d+)$/.exec(tag);
    if (m) return this.breath.windowFor(Number(m[1]) + 1);
    return [0, this.breath.total];
  }

  private surfacedAt(air: SwimmingPool | null, choking: boolean): void {
    const s = this.game.story;
    const m = /^culvert:pocket:(\d+)$/.exec(air?.tag ?? "");
    if (m) {
      const index = Number(m[1]);
      s.signal("air_pocket", { index, first: !this.pocketsSeen.has(index) });
      this.pocketsSeen.add(index);
    }
    if (choking) this.gasp();
  }

  /** Raman says the segment as it starts (`breath_segment` either way, for audio). */
  private count(segment: number): void {
    const s = this.game.story;
    const d = this.data.breath;
    if (d.countWhen && !s.check(d.countWhen)) return;
    s.signal("breath_segment", { segment, label: d.labels[segment] ?? String(d.segments[segment]) });
    const line = d.count[segment];
    if (!line?.text) return;
    s.events.emit("dialogue", { id: "water_count", speaker: d.speaker, text: line.text, audio: line.audio });
    void s.ui.say(d.speaker, line.text, line.seconds);
  }

  private async drown(): Promise<void> {
    if (this.mode === "drowning") return;
    const s = this.game.story;
    this.endGrip(false);
    this.mode = "drowning";
    const gen = this.gen;
    s.signal("breath_out");
    await this.fadeTo(1, 1.1);
    if (gen !== this.gen) return;
    void s.capture(this.data.breath.drownReason);
  }

  private gasp(): void {
    this.chroma = 1;
    this.game.story.signal("water:gasp");
  }

  // ── Pool: T1, the grate (T2 / T3), Meera ──────────────────────────────────
  private checkT1(dt: number, vol: SwimmingPool | null, under: boolean): void {
    const g = this.game;
    const t1 = this.data.pool.t1;
    const pool = this.pool;
    if (!pool || vol !== pool || !under || this.tried.has(t1.shard) || g.memory.hasMemory(t1.shard) || (t1.when && !g.story.check(t1.when))) {
      this.t1Timer = 0;
      return;
    }
    const cam = g.render.camera.position;
    const [x0, z0, x1, z1] = t1.region;
    const lx = cam.x - pool.center.x;
    const lz = cam.z - pool.center.z;
    this.t1Timer = lx >= x0 && lx <= x1 && lz >= z0 && lz <= z1 ? this.t1Timer + dt : 0;
    if (this.t1Timer >= t1.delay) {
      this.t1Timer = 0;
      void this.memory(t1.shard);
    }
  }

  private async memory(id: string, focus?: { root: Object3D }): Promise<void> {
    this.mode = "memory";
    this.tried.add(id);
    const gen = this.gen;
    await this.game.story.playShard(id, focus);
    if (gen === this.gen && this.mode === "memory") this.mode = "free";
  }

  /** Which tank shard the grate gives now (null: nothing). */
  grateShard(): string | null {
    const g = this.game;
    const gd = this.data.pool.grate;
    const has = (id: string) => g.memory.hasMemory(id);
    if (!has(gd.t3.shard) && has(gd.t2.shard) && (!gd.t3.when || g.story.check(gd.t3.when))) return gd.t3.shard;
    if (!has(gd.t2.shard) && (!gd.t2.when || g.story.check(gd.t2.when))) return gd.t2.shard;
    return null;
  }

  private shimmerOn(): boolean {
    const g = this.game;
    const gd = this.data.pool.grate;
    if (g.memory.hasMemory(gd.t2.shard) && g.memory.hasMemory(gd.t3.shard)) return false;
    return !gd.shimmerWhen || g.story.check(gd.shimmerWhen);
  }

  private gratePrompt(): string {
    return this.mode === "free" && this.game.swim.underwater ? this.data.pool.grate.prompt : "";
  }

  private useGrate(): void {
    const g = this.game;
    const gd = this.data.pool.grate;
    if (this.mode !== "free" || !g.swim.underwater) return;
    const shard = this.grateShard();
    if (!shard) {
      const done = g.memory.hasMemory(gd.t2.shard) && g.memory.hasMemory(gd.t3.shard);
      g.hud.showMessage(done ? gd.done : gd.notYet, 2);
      return;
    }
    if (!this.diveFull) {
      g.hud.showMessage(gd.needFullBreath, 2.4);
      return;
    }
    this.mode = "grip";
    this.grip = { shard, t: 0, feet: g.player.position.clone() };
    g.player.setControlEnabled(false);
    this.look = this.grateAt!.clone();
    if (shard === gd.t3.shard) this.guards.preload();
    g.story.signal("water:grip", { shard });
  }

  private updateGrip(dt: number): void {
    const g = this.game;
    const grip = this.grip;
    if (!grip) return;
    grip.t += dt;
    // Hold on at the bars: drift down beside the grate and stay there.
    const target = this.grateAt!.clone().add(new Vector3(0, 0.02, -0.95));
    grip.feet.lerp(target, Math.min(1, dt * 1.6));
    g.player.teleport(grip.feet, g.player.yaw, g.player.pitch);
    if (grip.t > 0.4 && g.input.justPressed("KeyE")) {
      this.endGrip(true);
      return;
    }
    const at = this.data.pool.grate.atSegment;
    if (this.breath.position >= this.breath.starts[at] - 1e-4) {
      const shard = grip.shard;
      this.endGrip(false);
      void this.grateMemory(shard);
    }
  }

  private endGrip(restore: boolean): void {
    if (!this.grip) return;
    this.grip = null;
    this.look = null;
    if (restore) {
      this.mode = "free";
      this.game.player.setControlEnabled(true);
    }
  }

  private async grateMemory(shard: string): Promise<void> {
    const gen = this.gen;
    await this.memory(shard, { root: this.grate!.root });
    if (gen !== this.gen) return;
    if (shard === this.data.pool.grate.t3.shard && this.game.memory.hasMemory(shard)) await this.surfaceIntoGuards();
  }

  /** T3's end: Parth comes up gasping into guards at the deck; Meera, in her own voice; Act III. */
  private async surfaceIntoGuards(): Promise<void> {
    const g = this.game;
    const s = g.story;
    const p = g.player;
    const t3 = this.data.pool.t3;
    const gen = this.gen;
    this.mode = "t3";
    p.setControlEnabled(false);
    for (let i = 0; i < 40 && g.swim.underwater; i++) await s.sleep(0.1);
    if (gen !== this.gen) return;
    this.gasp();
    this.breath.reset();
    const origin = this.pool!.center.clone();
    origin.y = g.anchors.get("pool")?.position.y ?? origin.y;
    const posts = t3.guards.map((a) => origin.clone().add(V(a)));
    void this.guards.spawn(posts, p.eyePosition);
    this.guardsCleanup = true;
    if (posts[0]) this.look = posts[0].clone().add(new Vector3(0, 1.6, 0));
    await s.run(t3.surfaceLines);
    if (gen !== this.gen) return;
    if (this.speakerAt) this.look = this.speakerAt.clone();
    s.signal("water:meera_speaker");
    await s.run(t3.speakerLines);
    if (gen !== this.gen) return;
    s.setAct(3);
    s.signal("water:act3");
    await s.run(t3.after);
    if (gen !== this.gen || this.mode !== "t3") return;
    this.mode = "free";
    this.look = null;
    if (!s.capturing) p.setControlEnabled(true);
  }

  // ── Culvert ───────────────────────────────────────────────────────────────
  private hatchPrompt(): string {
    const c = this.data.culvert;
    if (this.mode !== "free" || this.game.swim.water) return "";
    return !c.hatchWhen || this.game.story.check(c.hatchWhen) ? c.hatchPrompt : "";
  }

  private ladderPrompt(): string {
    return this.mode === "free" && this.game.swim.water?.tag === "culvert:sump" && !this.game.swim.underwater ? this.data.culvert.ladderPrompt : "";
  }

  /** Down through the hatch into the flooded sump (a cut to black: the slab above can't open). */
  async enterSump(): Promise<void> {
    const L = this.layout;
    if (!L || this.mode !== "free") return;
    const g = this.game;
    const s = g.story;
    const gen = this.gen;
    this.mode = "transition";
    g.player.setControlEnabled(false);
    s.signal("water:sump", { enter: true });
    await this.fadeTo(1, 0.7);
    if (gen !== this.gen) return;
    g.player.teleport(L.sumpEntry, Math.PI, 0);
    this.breath.reset();
    this.pocketsSeen.clear();
    this.handArmed = true;
    this.hand.reset();
    await s.sleep(0.4);
    await this.fadeTo(0, 1.0);
    if (gen !== this.gen) return;
    this.mode = "free";
    g.player.setControlEnabled(true);
    void s.run(this.data.culvert.enterLines);
  }

  async climbOut(): Promise<void> {
    const L = this.layout;
    if (!L || this.mode !== "free") return;
    const g = this.game;
    const gen = this.gen;
    this.mode = "transition";
    g.player.setControlEnabled(false);
    g.story.signal("water:sump", { enter: false });
    await this.fadeTo(1, 0.6);
    if (gen !== this.gen) return;
    g.player.teleport(L.pumpRoomExit, -Math.PI / 2, -0.35);
    await g.story.sleep(0.3);
    await this.fadeTo(0, 0.8);
    if (gen !== this.gen) return;
    this.mode = "free";
    g.player.setControlEnabled(true);
  }

  /** The final 8: a small hand in the black water (T4), then let go or hold on. */
  private async offerHand(): Promise<void> {
    const L = this.layout!;
    const g = this.game;
    const s = g.story;
    const p = g.player;
    const gen = this.gen;
    this.mode = "hand";
    this.handArmed = false;
    p.setControlEnabled(false);
    this.hand.root.position.copy(L.hand);
    this.hand.reachOut();
    this.look = L.hand.clone();
    s.signal("water:hand_near");
    await s.sleep(1.8);
    if (gen !== this.gen) return;
    await s.playShard(this.data.hand.shard, { root: this.hand.root });
    if (gen !== this.gen || this.mode !== "hand") return;
    p.setControlEnabled(false);
    this.look = L.hand.clone();
    this.choice = { release: 0, hold: 0 };
    this.ui.showHand(this.data.hand.releasePrompt, this.data.hand.holdPrompt);
    s.signal("hand_offered");
  }

  private updateChoice(dt: number): void {
    const c = this.choice;
    if (!c) return;
    const input = this.game.input;
    const need = this.data.hand.holdSeconds;
    const w = input.isDown("KeyW") || input.isDown("ArrowUp");
    const e = input.isDown("KeyE");
    c.release = w && !e ? c.release + dt : Math.max(0, c.release - dt * 2);
    c.hold = e && !w ? c.hold + dt : Math.max(0, c.hold - dt * 2);
    this.ui.setHandProgress(c.release / need, c.hold / need);
    if (c.release >= need) this.releaseHand();
    else if (c.hold >= need) void this.takeHand();
  }

  /** Let go: the hand slips back into the dark; dawn is waiting above the reservoir. */
  releaseHand(): void {
    if (this.mode !== "hand") return;
    const g = this.game;
    const s = g.story;
    this.choice = null;
    this.ui.hideHand();
    this.mode = "released";
    this.hand.letGo();
    this.look = null;
    g.env.setTimeHours(this.data.hand.dawnHours);
    s.setFlag("water:hand_released");
    s.signal("hand_released");
    g.player.setControlEnabled(true);
    void s.run(this.data.hand.releasedLines);
  }

  /** Hold on: the fingers close, the screen goes black, and the water feature stops (the endings take it from here). */
  async takeHand(): Promise<void> {
    if (this.mode !== "hand") return;
    const s = this.game.story;
    this.choice = null;
    this.ui.hideHand();
    this.mode = "taken";
    this.hand.grip();
    s.setFlag("water:hand_taken");
    s.signal("hand_taken");
    void s.run(this.data.hand.takenLines);
    await this.fadeTo(1, 2.6);
  }

  private surfaced(): void {
    const s = this.game.story;
    this.mode = "surfaced";
    this.gasp();
    this.breath.reset();
    s.setFlag("water:surfaced");
    s.signal("reservoir_surfaced");
  }

  // ── Camera, fades, chroma ─────────────────────────────────────────────────
  /** Turns Parth's head towards `look` while the story holds his controls. */
  private updateLook(dt: number): void {
    const p = this.game.player;
    if (!this.look || p.controlEnabled) return;
    const d = this.look.clone().sub(p.eyePosition);
    const yaw = Math.atan2(-d.x, -d.z);
    const pitch = Math.atan2(d.y, Math.hypot(d.x, d.z));
    let dy = yaw - p.yaw;
    dy = Math.atan2(Math.sin(dy), Math.cos(dy));
    const k = Math.min(1, dt * 2.5);
    p.yaw += dy * k;
    p.pitch += (pitch - p.pitch) * k;
  }

  private updateChroma(dt: number): void {
    if (this.chroma <= 0) return;
    this.chroma = Math.max(0, this.chroma - dt * 1.4);
    const k = this.chroma * this.chroma;
    this.game.render.chroma.offset.set(0.0006 + 0.007 * k, 0.0004 + 0.005 * k);
  }

  /** Full-screen black (my overlay, so the render fade other features use is left alone). */
  fadeTo(to: number, seconds: number): Promise<void> {
    for (const f of this.fades) f.resolve();
    this.fades = [];
    return new Promise((resolve) => this.fades.push({ from: this.ui.blackAmount, to, t: 0, dur: Math.max(0.001, seconds), resolve }));
  }

  private stepFades(dt: number): void {
    const f = this.fades[0];
    if (!f) return;
    f.t += dt;
    const k = Math.min(1, f.t / f.dur);
    this.ui.blackAmount = f.from + (f.to - f.from) * (k * k * (3 - 2 * k));
    if (k >= 1) {
      this.fades.shift();
      f.resolve();
    }
  }

  // ── Resets ────────────────────────────────────────────────────────────────
  /** Any capture (drowning, guards, the T3 deck): Act III is secured, then everything lets go. */
  private onCapture(): void {
    const s = this.game.story;
    if (this.mode === "t3" && s.state.act < 3) s.setAct(3);
    this.reset(false);
    void this.fadeTo(0, 1.4);
  }

  onWipe(): void {
    this.reset(true);
  }

  private reset(hard: boolean): void {
    this.gen++;
    this.grip = null;
    this.choice = null;
    this.look = null;
    this.mode = "free";
    this.handArmed = true;
    this.pocketsSeen.clear();
    this.breath.reset();
    this.counted = -1;
    this.t1Timer = 0;
    this.hand.reset();
    this.ui.hideHand();
    if (hard) {
      for (const f of this.fades) f.resolve();
      this.fades = [];
      this.ui.reset();
      this.guards.dispose();
      this.guardsCleanup = false;
      this.tried.clear();
    }
  }

  debugInfo(): Record<string, unknown> {
    const g = this.game;
    const b = this.breath;
    return {
      mode: this.mode,
      breath: { left: +b.left.toFixed(2), from: b.from, length: b.length, segment: b.segment, position: +b.position.toFixed(2), choke: +b.choke.toFixed(2) },
      diveFull: this.diveFull,
      water: g.swim.water?.tag ?? null,
      camera: g.swim.cameraWater?.tag ?? null,
      underwater: g.swim.underwater,
      grate: this.grateShard(),
      pockets: [...this.pocketsSeen],
    };
  }
}
