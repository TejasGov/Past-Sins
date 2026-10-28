import { AdditiveBlending, Box3, BufferAttribute, BufferGeometry, Points, PointsMaterial, Vector3 } from "three";
import type { Game } from "../../../game/game";
import type { KeypadLocker } from "../../../interact/pickups";
import type { StoryDirector } from "../../director";
import { resolvePlace } from "../../place";
import type { Condition } from "../../types";
import type { ContentData, LiftStop } from "./data";
import { buildPropModel } from "./models";
import { MonitorWall } from "./monitors";

interface FadeTween {
  from: number;
  to: number;
  t: number;
  duration: number;
  resolve: () => void;
}

interface Stream {
  points: Points;
  when: Condition;
  top: number;
  speeds: Float32Array;
}

const DROPS = 140;

/**
 * Runtime half of W5: custom meshes on story props, the restricted lift
 * ride (`signal lift_ride {to}`), flags that track where Parth is or what is
 * open (the 2718 locker, NIDRA B2, Maintenance B1), shower water and the
 * surveillance wall. Everything the player reads comes from content.json and
 * the story data files.
 */
export class ContentRuntime {
  private story: StoryDirector;
  private locker: KeypadLocker | null = null;
  private regions: { flag: string; box: Box3; when?: Condition }[] = [];
  private regionTimer = 0;
  private fade: FadeTween | null = null;
  private rideToken = 0;
  riding = false;
  private streams: Stream[] = [];
  private checkTimer = 0;
  private monitors: MonitorWall | null = null;
  private monitorsVisible = false;
  private conesOwned = false;

  constructor(
    private game: Game,
    private data: ContentData,
  ) {
    const g = game;
    this.story = g.story;
    for (const [id, def] of Object.entries(data.models ?? {})) {
      const prop = this.story.props.find((p) => p.def.id === id);
      if (prop) prop.root.add(buildPropModel(def, g.materials));
      else console.warn(`[content] model for unknown trigger "${id}"`);
    }
    if (data.locker) this.locker = g.session.lockers.find((l) => l.code === data.locker!.code) ?? null;
    for (const r of data.regions ?? []) {
      const box = planBox(g, r.plan);
      if (box) this.regions.push({ flag: r.flag, box, when: r.when });
      else console.warn(`[content] region "${r.flag}": plan ${r.plan} not found`);
    }
    for (const w of data.water ?? []) {
      const place = resolvePlace(w.at, g.anchors, g.floors, g.chunks);
      if (!place) {
        console.warn("[content] shower water: place not found", w.at);
        continue;
      }
      this.streams.push(this.buildStream(place.position, w.top ?? 2.0, w.when, place.chunk));
    }
    const m = data.monitors;
    if (m) {
      const place = resolvePlace(m.at, g.anchors, g.floors, g.chunks);
      if (place) {
        this.monitors = new MonitorWall(m, place.position, place.yaw);
        g.chunkGroup(place.chunk).add(this.monitors.mesh);
      } else console.warn("[content] monitor wall: place not found", m.at);
    }
    this.story.events.on("signal", ({ id, data: d }) => {
      if (id === "lift_ride") void this.ride(String(d?.to ?? ""));
    });
    // A capture (or wipe) mid-ride hands the screen to the capture sequence.
    this.story.events.on("capture", () => this.cancelRide());
    this.story.events.on("wipe", () => this.cancelRide());
  }

  update(dt: number): void {
    const s = this.story;
    const p = this.game.player;
    if (this.locker && this.data.locker && this.locker.isOpen !== s.hasFlag(this.data.locker.flag)) s.setFlag(this.data.locker.flag, this.locker.isOpen);
    this.regionTimer -= dt;
    if (this.regionTimer <= 0) {
      this.regionTimer = 0.25;
      if (!s.capturing && p.controlEnabled) {
        for (const r of this.regions) {
          if (!s.hasFlag(r.flag) && r.box.containsPoint(p.position) && (!r.when || s.check(r.when))) s.setFlag(r.flag);
        }
      }
    }
    this.updateFade(dt);
    // Data conditions for the water and the monitor wall: twice a second is plenty.
    this.checkTimer -= dt;
    const recheck = this.checkTimer <= 0;
    if (recheck) this.checkTimer = 0.5;
    this.updateStreams(dt, recheck);
    if (this.monitors) {
      if (recheck) this.monitorsVisible = s.check(this.data.monitors!.when);
      const near = this.monitors.mesh.position.distanceToSquared(this.game.render.camera.position) < 16 * 16;
      this.monitors.update(dt, this.monitorsVisible, near);
    }
    const gaps = this.data.patrolGaps;
    if (gaps) {
      const on = s.hasFlag(gaps.flag);
      if (on && !this.game.guards.showCones) {
        this.game.guards.showCones = true;
        this.conesOwned = true;
      } else if (!on && this.conesOwned) {
        this.game.guards.showCones = false;
        this.conesOwned = false;
      }
    }
  }

  onWipe(): void {
    this.cancelRide();
  }

  // ── The restricted lift ────────────────────────────────────────────────────
  /** Fade to black, ride, arrive at the other lobby (data: content.json `lift`). */
  async ride(to: string): Promise<void> {
    const g = this.game;
    const lift = this.data.lift;
    const stop: LiftStop | undefined = lift?.stops[to];
    if (!lift || !stop || this.riding || this.story.capturing) {
      if (lift && !stop) console.warn(`[content] lift_ride: no stop "${to}"`);
      return;
    }
    const place = resolvePlace(stop.at, g.anchors, g.floors, g.chunks);
    if (!place) {
      console.warn(`[content] lift stop "${to}": place not found`);
      return;
    }
    const token = ++this.rideToken;
    this.riding = true;
    g.player.setControlEnabled(false);
    await this.fadeTo(1, lift.fadeOut);
    if (token !== this.rideToken) return;
    g.player.teleport(place.position.clone().add(new Vector3(0, 0.05, 0)), place.yaw);
    const lines = (async () => {
      for (const l of stop.lines ?? []) {
        if (l.onceFlag && this.story.hasFlag(l.onceFlag)) continue;
        if (l.onceFlag) this.story.setFlag(l.onceFlag);
        await this.story.ui.say(l.speaker ?? "", l.text, l.seconds);
      }
    })();
    await Promise.all([lines, this.story.sleep(lift.hold)]);
    if (token !== this.rideToken) return;
    if (stop.flag) this.story.setFlag(stop.flag);
    this.story.signal("lift_arrived", { at: to });
    await this.fadeTo(0, lift.fadeIn);
    if (token !== this.rideToken) return;
    this.riding = false;
    g.player.setControlEnabled(true);
  }

  private cancelRide(): void {
    if (!this.riding) return;
    this.rideToken++;
    this.riding = false;
    this.fade?.resolve();
    this.fade = null;
    this.game.render.fade.uniforms.get("amount")!.value = 0;
  }

  private fadeTo(to: number, duration: number): Promise<void> {
    this.fade?.resolve();
    const from = this.game.render.fade.uniforms.get("amount")!.value as number;
    return new Promise((resolve) => {
      this.fade = { from, to, t: 0, duration: Math.max(0.01, duration), resolve };
    });
  }

  private updateFade(dt: number): void {
    const f = this.fade;
    if (!f) return;
    f.t = Math.min(f.duration, f.t + dt);
    const k = f.t / f.duration;
    const e = k * k * (3 - 2 * k);
    this.game.render.fade.uniforms.get("amount")!.value = f.from + (f.to - f.from) * e;
    if (f.t >= f.duration) {
      this.fade = null;
      f.resolve();
    }
  }

  // ── Shower water ───────────────────────────────────────────────────────────
  private buildStream(at: Vector3, top: number, when: Condition, chunk: string): Stream {
    const pos = new Float32Array(DROPS * 3);
    const speeds = new Float32Array(DROPS);
    for (let i = 0; i < DROPS; i++) {
      const a = Math.random() * Math.PI * 2;
      const r = Math.random() * 0.09;
      pos[i * 3] = Math.cos(a) * r;
      pos[i * 3 + 1] = Math.random() * top;
      pos[i * 3 + 2] = Math.sin(a) * r;
      speeds[i] = 4.5 + Math.random() * 1.5;
    }
    const geo = new BufferGeometry();
    geo.setAttribute("position", new BufferAttribute(pos, 3));
    const points = new Points(
      geo,
      new PointsMaterial({ color: 0xbfd9e2, size: 0.025, transparent: true, opacity: 0.55, depthWrite: false, blending: AdditiveBlending }),
    );
    points.position.copy(at);
    points.frustumCulled = false;
    points.visible = false;
    points.name = "ContentShowerWater";
    this.game.chunkGroup(chunk).add(points);
    return { points, when, top, speeds };
  }

  private updateStreams(dt: number, recheck: boolean): void {
    for (const s of this.streams) {
      if (recheck) s.points.visible = this.story.check(s.when);
      if (!s.points.visible) continue;
      const attr = s.points.geometry.getAttribute("position") as BufferAttribute;
      const a = attr.array as Float32Array;
      for (let i = 0; i < DROPS; i++) {
        a[i * 3 + 1] -= s.speeds[i] * dt;
        if (a[i * 3 + 1] < 0) a[i * 3 + 1] += s.top;
      }
      attr.needsUpdate = true;
    }
  }
}

/** World box of a floor plan's rooms, floor to ceiling. */
function planBox(g: Game, planId: string): Box3 | null {
  const floor = g.floors.get(planId);
  if (!floor) return null;
  const box = new Box3();
  for (const [id, c] of floor.roomCenters) {
    const r = floor.rooms.get(id);
    if (!r) continue;
    box.expandByPoint(new Vector3(c.x - r.w / 2, c.y - 0.6, c.z - r.d / 2));
    box.expandByPoint(new Vector3(c.x + r.w / 2, c.y + floor.storyHeight - 0.3, c.z + r.d / 2));
  }
  return box.isEmpty() ? null : box;
}
