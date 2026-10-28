import { Group, Mesh, MeshBasicMaterial, PlaneGeometry, Raycaster, Vector3 } from "three";
import { MeshKit } from "../../../world/builder";
import { wallColorFor } from "../../../world/campus/blueprintFloor";
import type { NpcActor } from "./actor";
import type { NpcRuntime } from "./runtime";
import type { ChairDef, MeeraDef } from "./types";

const V = (x: number, y: number, z: number) => new Vector3(x, y, z);

/**
 * Dr. Meera Varma: a backlit silhouette (lab coat, arms folded) behind the
 * NIDRA B2 observation glass and her voice on the speaker. The chair in
 * Interrogation A (trigger `npcs_chair` → signal `npcs:sit`): sitting down
 * voluntarily plays M14, then the Observation-glass conversation with real
 * choices (dialogue `npcs_observation`; flags and `observation_choice` are
 * set by the data).
 *
 * If the plan's observation window is missing (BUILD_PLAN finding: the
 * nidra-b2 window records sit inside Observation), a false window like the
 * capture cinematic's stands in front of Interrogation A's south wall for the
 * conversation, and she stands behind it.
 */
export class Meera {
  seated = false;
  private light: Mesh;
  private lightMat: MeshBasicMaterial;
  private lightTarget = 0;
  private falseWindow: Group | null = null;
  private realWindow = true;
  private run = 0;
  private savedFade = 0;

  constructor(
    private rt: NpcRuntime,
    readonly actor: NpcActor,
    private def: MeeraDef,
    private chair: ChairDef,
  ) {
    const g = rt.game;
    actor.prompt = () => "";
    this.lightMat = new MeshBasicMaterial({ color: def.backlight.color, fog: false, transparent: true, opacity: 0 });
    this.light = new Mesh(new PlaneGeometry(def.backlight.size[0], def.backlight.size[1]), this.lightMat);
    const at = rt.resolve(def.backlight.at);
    if (at) {
      this.light.position.copy(at.position);
      this.light.rotation.y = at.yaw;
    }
    this.light.visible = false;
    g.render.scene.add(this.light);
    this.realWindow = this.windowOpen();
    if (!this.realWindow) this.buildFalseWindow();
    this.goHome();
  }

  private get story() {
    return this.rt.story;
  }

  /** Is there an opening in Interrogation A's south wall at the window (or only plaster)? */
  private windowOpen(): boolean {
    const g = this.rt.game;
    const floor = g.floors.get(this.def.room.plan);
    const room = floor?.rooms.get(this.def.room.room);
    const c = floor?.roomCenters.get(this.def.room.room);
    if (!room || !c) return false;
    const ray = new Raycaster(c.clone().add(V(0, 1.5, 0)), V(0, 0, 1), 0, room.d / 2 + 1.2);
    (ray as Raycaster & { firstHitOnly?: boolean }).firstHitOnly = true;
    const hit = ray.intersectObject(g.occluder, false)[0];
    return !hit || hit.distance > room.d / 2 + 0.3;
  }

  private buildFalseWindow(): void {
    const g = this.rt.game;
    const floor = g.floors.get(this.def.room.plan);
    const room = floor?.rooms.get(this.def.room.room);
    const c = floor?.roomCenters.get(this.def.room.room);
    if (!room || !c) return;
    const fw = this.chair.falseWindow;
    const south = c.z + room.d / 2 - 0.12;
    const z = south + fw.z;
    const [gw, y0, y1] = fw.glass;
    const width = room.w - 0.06;
    const h = 3.7;
    const t = 0.16;
    const side = (width - gw) / 2;
    const color = wallColorFor(this.def.room.plan);
    const kit = new MeshKit(g.materials);
    kit.box(V(0, y0 / 2, 0), V(width, y0, t), "plaster", color);
    kit.box(V(0, (y1 + h) / 2, 0), V(width, h - y1, t), "plaster", color);
    for (const s of [-1, 1]) kit.box(V(s * (gw / 2 + side / 2), (y0 + y1) / 2, 0), V(side, y1 - y0, t), "plaster", color);
    kit.box(V(0, y0 - 0.03, -0.1), V(gw + 0.12, 0.06, 0.08), "steel", 0x7a827e);
    kit.box(V(0, y1 + 0.03, -0.09), V(gw + 0.12, 0.06, 0.04), "steel", 0x7a827e);
    for (const s of [-1, 1]) kit.box(V(s * (gw / 2 + 0.03), (y0 + y1) / 2, -0.09), V(0.06, y1 - y0, 0.04), "steel", 0x7a827e);
    kit.box(V(1.95, 1.42, -0.1), V(0.34, 0.22, 0.04), "dark", 0x202423);
    for (let i = 0; i < 4; i++) kit.box(V(1.95, 1.35 + i * 0.045, -0.125), V(0.28, 0.012, 0.01), "steel", 0x5d6461);
    kit.box(V(0, (y0 + y1) / 2, 0), V(gw, y1 - y0, 0.03), "glass", 0x4f6766);
    const wall = kit.build("Npcs:observationWindow");
    wall.position.set(c.x, c.y, z);
    const group = new Group();
    group.add(wall);
    group.visible = false;
    g.render.scene.add(group);
    this.falseWindow = group;
    // Backlight on the real wall behind her.
    this.light.position.set(c.x, c.y + 1.6, south - 0.02);
    this.light.rotation.y = Math.PI;
  }

  /** Where she stands (behind whichever glass is in use). */
  private standPlace(): { position: Vector3; yaw: number } | null {
    if (this.realWindow) return this.rt.resolve(this.def.stand);
    const g = this.rt.game;
    const floor = g.floors.get(this.def.room.plan);
    const room = floor?.rooms.get(this.def.room.room);
    const c = floor?.roomCenters.get(this.def.room.room);
    if (!room || !c) return null;
    const [x, , dz] = this.chair.falseWindow.meera;
    const south = c.z + room.d / 2 - 0.12;
    return { position: V(c.x + x, c.y, south + this.chair.falseWindow.z + dz), yaw: Math.PI - 0.5 };
  }

  goHome(): void {
    const at = this.standPlace();
    const a = this.actor;
    if (at) a.place(at.position, at.yaw);
    a.clearPoses(0);
    a.pose("folded", 1, 0);
    a.show(false);
  }

  /** Parth is in Interrogation A. */
  private parthInRoom(): boolean {
    const g = this.rt.game;
    const floor = g.floors.get(this.def.room.plan);
    const room = floor?.rooms.get(this.def.room.room);
    const c = floor?.roomCenters.get(this.def.room.room);
    if (!room || !c) return false;
    const p = g.player.position;
    return Math.abs(p.x - c.x) < room.w / 2 && Math.abs(p.z - c.z) < room.d / 2 && Math.abs(p.y - c.y) < 2.5;
  }

  onSignal(id: string): void {
    if (id === "npcs:sit") void this.sit();
  }

  onCapture(): void {
    // The capture sequence takes the camera; nothing to restore.
    this.run++;
    this.seated = false;
    this.lightTarget = 0;
    if (this.falseWindow) this.falseWindow.visible = false;
  }

  onWipe(): void {
    this.seated = false;
    this.goHome();
  }

  update(dt: number): void {
    const want = this.seated || (this.story.check(this.def.present) && this.parthInRoom() && this.realWindow);
    const a = this.actor;
    if (want && !a.present) {
      const at = this.standPlace();
      if (at) a.place(at.position, at.yaw);
      a.pose("folded", 1, 0);
      a.show(true);
    } else if (!want && a.present && !this.seated) a.show(false);
    if (want) this.lightTarget = Math.max(this.lightTarget, this.seated ? 1 : 0.8);
    else if (!this.seated) this.lightTarget = 0;
    const m = this.lightMat;
    m.opacity += (this.lightTarget - m.opacity) * (1 - Math.exp(-dt * 2.5));
    this.light.visible = m.opacity > 0.01;
    if (a.present) a.lookTargetWeight = this.seated ? 0.8 : 0.3;
    this.tickCine(dt);
  }

  // ── The chair ─────────────────────────────────────────────────────────────
  private cineTween: { from: number; to: number; t: number; seconds: number } | null = null;
  private fadeTween: { from: number; to: number; t: number; seconds: number } | null = null;

  private tickCine(dt: number): void {
    const g = this.rt.game;
    const step = (tw: { from: number; to: number; t: number; seconds: number } | null, set: (v: number) => void) => {
      if (!tw) return null;
      tw.t = Math.min(1, tw.t + dt / tw.seconds);
      const k = tw.t * tw.t * (3 - 2 * tw.t);
      set(tw.from + (tw.to - tw.from) * k);
      return tw.t >= 1 ? null : tw;
    };
    this.cineTween = step(this.cineTween, (v) => (g.cine.weight = v));
    const fade = g.render.fade.uniforms.get("amount")!;
    this.fadeTween = step(this.fadeTween, (v) => (fade.value = v));
  }

  private fade(to: number, seconds: number): Promise<void> {
    const fade = this.rt.game.render.fade.uniforms.get("amount")!;
    this.fadeTween = { from: fade.value as number, to, t: 0, seconds };
    return this.story.sleep(seconds);
  }

  private cine(to: number, seconds: number): Promise<void> {
    this.cineTween = { from: this.rt.game.cine.weight, to, t: 0, seconds };
    return this.story.sleep(seconds);
  }

  /** Seated camera (cine override) at the chair, looking at the glass. */
  private aimSeated(): void {
    const g = this.rt.game;
    const eye = this.rt.resolve(this.chair.eye);
    const look = this.realWindow ? this.rt.resolve(this.chair.look) : null;
    if (!eye) return;
    g.cine.position.copy(eye.position);
    if (look) g.cine.look.copy(look.position);
    else this.actor.bonePoint("mixamorigSpine2", g.cine.look);
  }

  async sit(): Promise<void> {
    const g = this.rt.game;
    if (this.seated || this.rt.talkingTo || this.story.capturing || !g.player.controlEnabled) return;
    const run = ++this.run;
    this.seated = true;
    const pl = g.player;
    pl.setControlEnabled(false);
    this.story.signal("npcs:chair", { beat: "sit" });
    this.savedFade = g.render.fade.uniforms.get("amount")!.value as number;
    await this.fade(1, 0.7);
    if (run !== this.run) return;
    // Parth on the seat facing the glass (the restraint chair faces the far wall, so the shot is the subject's view).
    const eye = this.rt.resolve(this.chair.eye);
    if (eye) {
      pl.teleport(eye.position.clone().setY(eye.position.y - 1.2), eye.yaw);
      pl.setControlEnabled(false);
    }
    if (this.falseWindow) this.falseWindow.visible = true;
    const at = this.standPlace();
    const a = this.actor;
    if (at) a.place(at.position, at.yaw);
    a.show(true);
    a.pose("folded", 1, 0);
    this.lightTarget = 1;
    this.aimSeated();
    g.cine.weight = 1;
    await this.fade(this.savedFade, 1.2);
    if (run !== this.run) return;
    if (this.chair.before) await this.story.run(this.chair.before);
    if (run !== this.run) return;
    // M14: the day he saw her name. collectMemory hands the camera back to Parth's own at the end.
    const head = new Group();
    a.bonePoint("mixamorigHead", head.position);
    head.position.y -= 0.17;
    await this.story.playShard(this.chair.shard, { root: head });
    if (run !== this.run) return;
    pl.setControlEnabled(false);
    this.aimSeated();
    await this.cine(1, 0.8);
    if (run !== this.run) return;
    const talk = { lock: false, steps: [{ dialogue: this.chair.dialogue }] };
    await this.rt.talk(a, talk);
    if (run !== this.run || this.story.capturing) return;
    if (this.chair.after) await this.story.run(this.chair.after);
    if (run !== this.run || this.story.capturing) return;
    await this.stand(run);
  }

  private async stand(run: number): Promise<void> {
    const g = this.rt.game;
    const a = this.actor;
    // She turns from the glass; the light goes.
    const at = this.standPlace();
    if (at) a.targetYaw = at.yaw + Math.PI;
    a.lookTargetWeight = 0;
    this.lightTarget = 0;
    await this.story.sleep(1.6);
    if (run !== this.run) return;
    await this.fade(1, 0.8);
    if (run !== this.run) return;
    g.cine.weight = 0;
    this.seated = false;
    if (this.falseWindow) this.falseWindow.visible = false;
    a.show(false);
    const up = this.rt.resolve(this.chair.standUp);
    if (up) g.player.teleport(up.position, up.yaw);
    await this.fade(this.savedFade, 1.0);
    if (run !== this.run) return;
    this.story.signal("npcs:chair", { beat: "stand" });
    if (!this.story.capturing) g.player.setControlEnabled(true);
  }

  debug(): Record<string, unknown> {
    return { seated: this.seated, realWindow: this.realWindow, present: this.actor.present, light: +this.lightMat.opacity.toFixed(2) };
  }
}
