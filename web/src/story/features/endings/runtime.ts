import { gsap } from "gsap";
import { Group, Mesh, MeshBasicMaterial, BoxGeometry, Vector3, type Uniform } from "three";
import type { Game } from "../../../game/game";
import { MeshKit } from "../../../world/builder";
import { markInteractable, type Interactable } from "../../../interact/interactable";
import { resolvePlace } from "../../place";
import { StoryState } from "../../state";
import { CineClock } from "../loop/clock";
import { loopFeature } from "../loop";
import { npcsFeature } from "../npcs";
import { waterFeature } from "../water";
import { Credits } from "./credits";
import type { EndingsData, Line } from "./data";

export type EndingId = "let_go" | "hold_on" | "mercy";

const V = (x: number, y: number, z: number) => new Vector3(x, y, z);

/** The Act III temptation: a service pistol on the Chief's desk. */
class PistolProp implements Interactable {
  readonly root = new Group();
  constructor(
    game: Game,
    private prompt: () => string,
    private take: () => void,
  ) {
    const kit = new MeshKit(game.materials);
    kit.box(V(0, 0.018, 0), V(0.2, 0.036, 0.03), "metal", 0x22252a);
    kit.box(V(-0.07, 0.0, 0), V(0.05, 0.03, 0.028), "metal", 0x1a1c20);
    kit.box(V(0.03, 0.006, 0.07), V(0.22, 0.012, 0.16), "paper", 0xcfc7b0);
    const mesh = kit.build("Ending:pistol");
    mesh.castShadow = false;
    this.root.add(mesh);
    const hit = new Mesh(new BoxGeometry(0.45, 0.3, 0.4), new MeshBasicMaterial({ visible: false }));
    hit.position.y = 0.1;
    this.root.add(hit);
    markInteractable(this.root, this);
  }
  getInteractionPrompt(): string {
    return this.prompt();
  }
  interact(): void {
    if (this.prompt()) this.take();
  }
}

/**
 * Integration: the Act III night and the three endings ("Again" outline).
 * - Act III: forced monsoon, `termination_tonight`, and at 02:00 Bhosle comes
 *   for Parth (capture "termination" → W1's 19:00 night restart).
 * - Mercy is locked by firing the pistol on the Chief's desk (`pistol_fired`)
 *   or downing anyone (`harmed_someone`).
 * - Let Go: hand released → surfaced in the reservoir → the camera rises over
 *   the water towards the town and the tank → the Varma doorstep, cut to
 *   black before anyone answers.
 * - Hold On: hand taken (or, in Act III, begging Meera for another wipe at
 *   the glass) → "Good morning, beta" → a new cycle → credits over the cell.
 * - Mercy: confessed awake at the glass, Kabir freed, nobody harmed → Meera
 *   suspends NIDRA and walks them out through Administration into the rain.
 * Every ending ends on the credits and "wake again" (New Game+: the cycle
 * count and the endings seen carry over, nothing else).
 */
export class EndingsRuntime {
  readonly clock = new CineClock();
  readonly credits: Credits;
  active: EndingId | null = null;
  private pendingHoldOn = false;
  private lastHour: number;
  private follow: (() => void) | null = null;

  constructor(
    private game: Game,
    private data: EndingsData,
  ) {
    const g = game;
    const s = g.story;
    this.credits = new Credits(g.hud.root);
    this.lastHour = g.env.timeHours;

    // Wrap the loop's capture handler (W1) rather than replacing it.
    const loopHandler = s.captureHandler;
    s.captureHandler = async (reason) => {
      if (this.active) {
        // An ending is playing: nobody is taken anywhere.
        this.releaseFailure();
        return "handled";
      }
      // Act III, at the glass: begging for another wipe is holding on.
      if (reason === "voluntary" && s.state.act >= 3) this.pendingHoldOn = true;
      return loopHandler ? loopHandler(reason) : "wipe";
    };

    s.events.on("signal", ({ id, data }) => this.onSignal(id, data));
    s.events.on("act", ({ act }) => {
      if (act === 3) this.enterAct3();
    });
    s.events.on("wipe", () => {
      if (this.pendingHoldOn) void this.holdOnCredits();
    });
    // Mercy needs clean hands: firing the pistol or downing anyone closes it.
    g.noise.events.on("weapon_noise_emitted", () => {
      if (!g.dev?.enabled) s.setFlag("pistol_fired");
    });
    for (const guard of g.guards.guards) {
      const knockDown = guard.knockDown.bind(guard);
      guard.knockDown = () => {
        knockDown();
        if (!g.dev?.enabled) s.setFlag("harmed_someone");
      };
    }
    this.spawnPistol();
    if (s.state.act === 3) this.enterAct3(true);
  }

  // ── Act III night ─────────────────────────────────────────────────────────
  private enterAct3(quiet = false): void {
    const g = this.game;
    const s = g.story;
    s.setFlag("termination_tonight");
    if (g.env.weather !== this.data.act3.weather) {
      g.env.setWeather(this.data.act3.weather);
      if (!quiet && this.data.act3.monsoonMessage) g.hud.showMessage(this.data.act3.monsoonMessage, 2.4);
    }
  }

  private spawnPistol(): void {
    const g = this.game;
    const s = g.story;
    const place = resolvePlace(this.data.pistol.at, g.anchors, g.floors, g.chunks);
    if (!place) return;
    const prop = new PistolProp(
      g,
      () => (s.state.act >= 3 && !s.hasFlag("pistol_taken") && !this.active ? this.data.pistol.prompt : ""),
      () => {
        g.weapons?.give();
        s.setFlag("pistol_taken");
        if (this.data.pistol.message) g.hud.showMessage(this.data.pistol.message, 2.4);
      },
    );
    prop.root.position.copy(place.position);
    prop.root.rotation.y = place.yaw;
    g.chunkGroup(place.chunk).add(prop.root);
    g.interaction.register(prop);
    s.events.on("flag", ({ flag, on }) => {
      if (flag === "pistol_taken") prop.root.visible = !on;
    });
    prop.root.visible = !s.hasFlag("pistol_taken");
  }

  update(dt: number): void {
    const g = this.game;
    const s = g.story;
    this.clock.update(dt);
    this.credits.update(dt, g.input);
    this.follow?.();
    // Mercy can become possible in either order (confess, then free Kabir; or the reverse).
    if (!this.active && !s.capturing && this.mercyReady() && !g.hud.memoryPlaying && !npcsFeature.runtime?.meera.seated && !loopFeature.runtime?.busy) void this.mercy();
    if (s.state.act === 3 && !this.active) {
      if (g.env.weather !== this.data.act3.weather) g.env.setWeather(this.data.act3.weather);
      const h = g.env.timeHours;
      const at = this.data.act3.terminationHour;
      const crossed = this.lastHour < at && h >= at && h - this.lastHour < 1;
      if (crossed && s.hasFlag("termination_tonight") && !s.capturing && !this.onTheWayOut()) void this.terminate();
    }
    this.lastHour = g.env.timeHours;
  }

  onWipe(): void {
    // The pistol isn't carried across a wipe.
    this.game.weapons?.remove();
  }

  /** In the basement levels or the water: Bhosle's two o'clock finds an empty cell. */
  private onTheWayOut(): boolean {
    const g = this.game;
    return g.player.position.y < -2 || !!g.swim.water || (waterFeature.runtime?.mode ?? "free") !== "free";
  }

  private async terminate(): Promise<void> {
    const s = this.game.story;
    for (const l of this.data.act3.terminationLines) await this.say(l, "ending_termination");
    if (!this.active && !s.capturing) void s.capture("termination");
  }

  // ── Signals → endings ─────────────────────────────────────────────────────
  private onSignal(id: string, _data?: Record<string, unknown>): void {
    const s = this.game.story;
    if (id === "reservoir_surfaced" && s.hasFlag("water:hand_released")) void this.letGo();
    else if (id === "hand_taken") void this.holdOn();
  }

  private mercyReady(): boolean {
    const s = this.game.story;
    return s.hasFlag("confessed") && s.hasFlag("kabir_freed") && !s.hasFlag("pistol_fired") && !s.hasFlag("harmed_someone");
  }

  // ── Shared cinematic helpers ──────────────────────────────────────────────
  private uniform(name: "amount" | "desaturate"): Uniform {
    return this.game.render.fade.uniforms.get(name)!;
  }

  /** Takes over: no controls, no HUD, no clock, no guards. False if something else already has the stage. */
  private begin(id: EndingId): boolean {
    const g = this.game;
    const s = g.story;
    if (this.active || s.capturing) return false;
    this.active = id;
    loopFeature.runtime?.stopKlaxon();
    s.ui.clearSubtitles();
    s.ui.cancelBlocking();
    g.player.setControlEnabled(false);
    g.hud.setVisible(false);
    g.hud.root.classList.add("loop-cine");
    g.env.cycleEnabled = false;
    g.guards.devInvisible = true;
    g.suspicion.reset();
    g.weapons?.setEquipped(false);
    const npcs = npcsFeature.runtime;
    if (npcs) npcs.suspended = true;
    return true;
  }

  private releaseFailure(): void {
    const g = this.game;
    g.failureInProgress = false;
    g.player.unlockFailure();
    if (this.active) g.player.setControlEnabled(false);
  }

  private cut(eye: Vector3, look: Vector3): void {
    const c = this.game.cine;
    c.position.copy(eye);
    c.look.copy(look);
    c.weight = 1;
  }

  private fade(to: number, seconds: number): Promise<boolean> {
    const tl = gsap.timeline();
    tl.to(this.uniform("amount"), { value: to, duration: Math.max(0.01, seconds), ease: "power1.inOut" });
    return this.clock.play(tl);
  }

  private say(l: Line, id: string): Promise<void> {
    const s = this.game.story;
    s.events.emit("dialogue", { id, speaker: l.speaker, text: l.text, audio: l.audio });
    return s.ui.say(l.speaker, l.text, l.seconds);
  }

  /** Records the ending, rolls the credits and wakes into New Game+. */
  private async finish(id: EndingId, dim: number): Promise<void> {
    const g = this.game;
    const s = g.story;
    s.state.endings.add(id);
    s.events.emit("ending", { id });
    s.save();
    g.hud.setVisible(false);
    await this.credits.play(id, this.data.credits, dim);
    this.newGamePlus();
  }

  /** A new run: cycle count and endings seen carry over; everything else starts again. */
  newGamePlus(): void {
    const st = this.game.story.state;
    StoryState.write({
      cycle: st.cycle + 1,
      act: 1,
      flags: ["ngplus"],
      wall: [],
      codes: [],
      stash: [],
      endings: [...st.endings],
      vars: {},
      memories: { memories: [] },
    });
    location.href = location.pathname;
  }

  // ── Let Go ────────────────────────────────────────────────────────────────
  async letGo(): Promise<void> {
    const g = this.game;
    const s = g.story;
    const d = this.data.letGo;
    if (!this.begin("let_go")) return;
    await s.sleep(d.surfaceSeconds);
    // The camera rises off the water and looks out, past the wall, to the town and the tank.
    const eye = g.render.camera.position.clone();
    const look = V(...d.rise.look);
    const flat = look.clone().sub(eye).setY(0).normalize();
    this.cut(eye, eye.clone().add(flat.clone().multiplyScalar(6)).setY(eye.y + 0.4));
    const tl = gsap.timeline();
    const top = eye.clone().addScaledVector(flat, -d.rise.back).setY(eye.y + d.rise.height);
    tl.to(g.cine.position, { x: top.x, y: top.y, z: top.z, duration: d.rise.seconds, ease: "sine.inOut" }, 0);
    tl.to(g.cine.look, { x: look.x, y: look.y, z: look.z, duration: d.rise.seconds * 0.8, ease: "sine.inOut" }, 0.4);
    tl.to(this.uniform("amount"), { value: 1, duration: 1.6, ease: "power1.in" }, d.rise.seconds - 1.4);
    await this.clock.play(tl);

    // The Varma family's door.
    const ds = d.doorstep;
    const o = V(...ds.origin);
    g.env.setTimeHours(ds.hour);
    g.env.setWeather(ds.weather);
    this.cut(o.clone().add(V(0, 1.62, -7.5)), o.clone().add(V(0, 1.45, 0)));
    await s.sleep(0.6);
    const walk = gsap.timeline();
    walk.to(this.uniform("amount"), { value: 0, duration: 1.4, ease: "power1.out" }, 0);
    walk.to(g.cine.position, { z: o.z - 1.25, duration: ds.walkSeconds, ease: "power1.inOut" }, 0.2);
    walk.to(g.cine.position, { y: "-=0.05", duration: 0.45, yoyo: true, repeat: Math.max(1, Math.floor(ds.walkSeconds / 0.45) - 1), ease: "sine.inOut" }, 0.2);
    walk.to(g.cine.look, { y: o.y + 1.5, duration: ds.walkSeconds, ease: "sine.inOut" }, 0.2);
    await this.clock.play(walk);
    for (const l of ds.lines) {
      if (!l.speaker) s.signal("ending:knock");
      await this.say(l, "ending_let_go");
    }
    // Cut to black before anyone answers.
    s.ui.clearSubtitles();
    this.uniform("amount").value = 1;
    g.cine.weight = 0;
    await s.sleep(1.5);
    await this.finish("let_go", 1);
  }

  // ── Hold On ───────────────────────────────────────────────────────────────
  /** The hand taken in the culvert: black, silence, his voice, a new day one. */
  async holdOn(): Promise<void> {
    const s = this.game.story;
    if (!this.begin("hold_on")) return;
    await s.sleep(this.data.holdOn.silenceSeconds);
    for (const l of this.data.holdOn.lines) await this.say(l, "ending_hold_on");
    this.pendingHoldOn = true;
    // The wipe hands the stage to the loop's wake-up; the credits follow it.
    this.active = null;
    this.game.guards.devInvisible = false;
    this.game.env.cycleEnabled = true;
    await s.wipe();
  }

  /** After the wake: credits over the cell, the scene showing through. */
  private async holdOnCredits(): Promise<void> {
    const g = this.game;
    const s = g.story;
    this.pendingHoldOn = false;
    // Let the loop's wake play out first (Parth stands up facing the wall).
    for (let i = 0; i < 400 && (loopFeature.runtime?.busy || s.capturing); i++) await s.sleep(0.25);
    await s.sleep(1.2);
    this.active = null;
    if (!this.begin("hold_on")) return;
    await this.finish("hold_on", 0.45);
  }

  // ── Mercy ─────────────────────────────────────────────────────────────────
  async mercy(): Promise<void> {
    const g = this.game;
    const s = g.story;
    const d = this.data.mercy;
    const rt = npcsFeature.runtime;
    if (!this.begin("mercy")) return;
    await this.fade(1, 1.2);
    for (const l of d.pa) await this.say(l, "ending_mercy_pa");
    // "Open the Intake gates": every door in Administration stands open for them.
    for (const door of g.doors) if (door.spec.planId === "admin-ground") door.setState(true, false);
    const route = d.route.map((p) => resolvePlace(p, g.anchors, g.floors, g.chunks)?.position).filter((p): p is Vector3 => !!p);
    const exit = this.adminExit();
    if (rt && route.length && exit) {
      const meera = rt.meera;
      const kabir = rt.kabir;
      kabir.following = false;
      kabir.actor.stop();
      meera.scripted = true;
      const start = route[0];
      const dir = route[1] ? route[1].clone().sub(start).setY(0).normalize() : V(0, 0, 1);
      meera.actor.clearPoses(0);
      meera.actor.place(start.clone().addScaledVector(dir, 1.6), Math.atan2(dir.x, dir.z));
      meera.actor.show(true);
      kabir.actor.clearPoses(0);
      kabir.actor.place(start.clone(), Math.atan2(dir.x, dir.z));
      kabir.actor.show(true);
      // Parth's view: a step behind Kabir, looking past him to Meera.
      const cam = start.clone().addScaledVector(dir, -2.2).setY(start.y + 1.62);
      this.cut(cam, meera.actor.position.clone().setY(start.y + 1.45));
      this.follow = () => {
        const k = kabir.actor.position;
        const m = meera.actor.position;
        const ahead = m.clone().sub(k).setY(0);
        if (ahead.lengthSq() < 0.01) return;
        ahead.normalize();
        const want = k.clone().addScaledVector(ahead, -2.2).setY(k.y + 1.62);
        g.cine.position.lerp(want, 0.06);
        g.cine.look.lerp(m.clone().setY(m.y + 1.45), 0.08);
      };
      void this.fade(0, 1.6);
      const points = [...route.slice(1), exit.door, exit.outside];
      for (const [i, p] of points.entries()) {
        const last = i === points.length - 1;
        // The camera stops at the doorway: they walk out into the rain without him.
        if (last) this.follow = null;
        const kabirTarget = p.clone().addScaledVector(dir, -1.4);
        await Promise.all([
          this.walk(meera.actor, p, d.walkSpeed),
          s.sleep(0.5).then(() => this.walk(kabir.actor, last ? p.clone().add(V(0.9, 0, -0.6)) : kabirTarget, d.walkSpeed)),
        ]);
        if (i === points.length - 2) for (const l of d.exitLines) void this.say(l, "ending_mercy");
      }
      await s.sleep(2.5);
    } else {
      console.warn("[endings] mercy: NPCs or the Administration route missing; skipping the walk-out");
    }
    await this.fade(1, 2.2);
    this.follow = null;
    await this.finish("mercy", 1);
  }

  /** NPC walk with a time limit (doors, a blocked path): if it stalls, they're simply there. */
  private async walk(actor: { walkTo(to: Vector3, speed: number, opensDoors: boolean): Promise<boolean>; place(p: Vector3, yaw: number): void; position: Vector3; stop(): void }, to: Vector3, speed: number): Promise<void> {
    const s = this.game.story;
    const limit = actor.position.distanceTo(to) / Math.max(0.3, speed) + 6;
    const done = await Promise.race([actor.walkTo(to.clone(), speed, true).then(() => true), s.sleep(limit).then(() => false)]);
    if (!done) {
      actor.stop();
      const d = to.clone().sub(actor.position).setY(0);
      actor.place(to.clone(), d.lengthSq() > 0.01 ? Math.atan2(d.x, d.z) : 0);
    }
  }

  /** Administration's public (south) entrance: the doorway and a spot out in the rain. */
  private adminExit(): { door: Vector3; outside: Vector3 } | null {
    const f = this.game.floors.get("admin-ground");
    if (!f) return null;
    let best: { door: Vector3; outside: Vector3 } | null = null;
    for (const d of f.doors) {
      if (d.b !== "OUTSIDE") continue;
      const door = f.toWorld(d.position);
      const n = f.toWorld(d.position.clone().add(d.normal)).sub(door).setY(0).normalize();
      if (!best || door.z > best.door.z) best = { door: door.clone().addScaledVector(n, -0.8), outside: door.clone().addScaledVector(n, this.data.mercy.outsideDistance) };
    }
    return best;
  }

  debugInfo(): Record<string, unknown> {
    const s = this.game.story;
    return {
      active: this.active,
      pendingHoldOn: this.pendingHoldOn,
      mercyReady: this.mercyReady(),
      credits: this.credits.running,
      endings: [...s.state.endings],
      termination: s.hasFlag("termination_tonight"),
    };
  }
}
