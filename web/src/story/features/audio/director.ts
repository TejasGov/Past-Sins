import { Raycaster, Vector3 } from "three";
import type { Game } from "../../../game/game";
import { AudioEngine } from "../../../audio/engine";
import { Ambience, type AmbienceInput } from "../../../audio/ambience";
import { CuePlayer, type CueHost } from "../../../audio/cues";
import { VoicePlayer } from "../../../audio/voice";
import * as S from "../../../audio/synth";
import type { AudioData } from "./data";

const MUTE_STORE = "blacksite.ghostexit.audio.muted.v1";
const UP = new Vector3(0, 1, 0);
const rnd = (a: number, b: number) => a + Math.random() * (b - a);
const smooth = (a: number, b: number, x: number) => {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
  return t * t * (3 - 2 * t);
};

/**
 * Wires the game's existing events to the audio engine: player/noise/swim/
 * suspicion events become one-shots, story events and signals become data
 * cues, and every frame the ambience, reverb space, underwater filter,
 * heartbeat and klaxon follow the world state.
 */
export class AudioDirector implements CueHost {
  readonly engine: AudioEngine;
  readonly cues: CuePlayer;
  readonly voices: VoicePlayer;
  ambience: Ambience | null = null;
  readonly input: AmbienceInput = { indoor: 0, rain: 0, atrium: 0, night: 0, tubes: 1, immersion: 0, level: 1, searchlights: 0 };
  private drone: { gain: GainNode; filter: BiquadFilterNode } | null = null;
  private ray = new Raycaster();
  private fwd = new Vector3();
  private up = new Vector3();
  private spaceTimer = 0;
  ceiling = 40;
  /** Share of a 5-ray probe around the camera that sees a hall-height ceiling. */
  openness = 0;
  chunk = "exterior";
  /** Audio's own indoor factor: the game's roof ray, but any building interior counts (the atrium skylight is open). */
  indoor = 0;
  private rain = 0;
  private hall = 0;
  private klaxonUntil = 0;
  private klaxonNext = 0;
  private beatNext = 0;
  tension = 0;
  bpm = 0;
  private underFor = 0;
  private wasUnder = false;
  private ducks: { amount: number; start: number; hold: number; release: number }[] = [];
  private scenes = new Map<string, number>();
  private guardSteps = new Map<object, { x: number; z: number; stride: number }>();
  private nextClank = 0;
  private nextThunder = 0;
  private lastSuspicion = "NORMAL";

  constructor(
    readonly game: Game,
    readonly data: AudioData,
  ) {
    const e = (this.engine = new AudioEngine({ ...data.mix }));
    this.cues = new CuePlayer(e, data.cues, data.motif, this);
    this.voices = new VoicePlayer(e, data.voices);
    try {
      e.muted = localStorage.getItem(MUTE_STORE) === "1";
    } catch {
      /* storage blocked: default unmuted */
    }
    e.onReady(() => this.build());
    e.armUnlock();
    this.bind();
  }

  private build(): void {
    const e = this.engine;
    const amb = (this.ambience = new Ambience(e, this.data.ambience));
    for (const [key, a] of this.game.anchors) if (key.startsWith("tower:")) amb.addTower(a.position);
    // Low tension drone under the heartbeat.
    const ctx = e.ctx!;
    const gain = ctx.createGain();
    gain.gain.value = 0;
    const filter = ctx.createBiquadFilter();
    filter.type = "lowpass";
    filter.frequency.value = 90;
    for (const [f, det] of [[41.2, 0], [41.2, 11], [61.7, -6]]) {
      const o = ctx.createOscillator();
      o.type = "sawtooth";
      o.frequency.value = f;
      o.detune.value = det;
      o.connect(filter);
      o.start();
    }
    filter.connect(gain).connect(e.bus.music);
    this.drone = { gain, filter };
    this.nextClank = e.now + rnd(...this.data.clanks.every);
    this.nextThunder = e.now + rnd(...this.data.rain.thunderEvery);
  }

  // ── Event wiring ──────────────────────────────────────────────────────────
  private bind(): void {
    const g = this.game;
    const e = this.engine;
    const live = () => !!e.ctx;
    g.player.events.on("footstep", ({ position, intensity }) => {
      if (live()) S.footstep(e, this.surfaceAt(position, this.indoor > 0.5), intensity, {}, this.data.footsteps.gain);
    });
    g.player.events.on("landed", ({ position, speed }) => {
      if (live()) S.landing(e, this.surfaceAt(position, this.indoor > 0.5), speed / 9);
    });
    g.noise.events.on("noise_emitted", (n) => {
      if (!live() || n.source !== "door") return;
      const door = this.doorAt(n.position);
      const pos = n.position.clone().add(new Vector3(0, 1.3, 0));
      S.door(e, door?.spec.kind ?? "door", door?.isOpen ?? true, { position: pos, occluded: this.blocked(pos), reverb: 0.2 });
    });
    g.noise.events.on("weapon_noise_emitted", (w) => {
      if (live()) S.pistol(e, w.suppressed);
    });
    let lastSwimCue = -10;
    g.swim.events.on("swimming_state_changed", (inWater) => {
      // Bobbing at the waterline toggles the state; don't splash every time.
      if (e.now - lastSwimCue < 1.5) return;
      lastSwimCue = e.now;
      this.cues.play([inWater ? "swim:enter" : "swim:exit"]);
    });
    g.suspicion.events.on("suspicion_state_changed", (s) => {
      if (s !== this.lastSuspicion) this.cues.play([`suspicion:${s}`]);
      this.lastSuspicion = s;
    });
    g.env.events.on("weather_changed", (w) => this.cues.play([`weather:${w}`]));

    const st = g.story.events;
    st.on("shard", ({ id }) => this.cues.play([`shard:${id}`, "shard"]));
    st.on("capture", ({ reason }) => this.cues.play([`capture:${reason}`, "capture"], { reason }));
    st.on("wipe", ({ cycle }) => {
      this.klaxon(false);
      this.scenes.clear();
      this.cues.play(["wipe"], { cycle });
    });
    st.on("act", ({ act }) => this.cues.play([`act:${act}`, "act"], { act }));
    st.on("ending", ({ id }) => this.cues.play([`ending:${id}`, "ending"], { id }));
    st.on("signal", ({ id, data }) => {
      const names: string[] = [];
      for (const v of Object.values(data ?? {})) if (["string", "number", "boolean"].includes(typeof v)) names.push(`signal:${id}:${v}`);
      names.push(`signal:${id}`);
      this.cues.play(names, data);
    });
    st.on("dialogue", ({ audio }) => {
      if (!audio) return;
      void this.voices.play(audio);
      this.cues.play([`dialogue:${audio}`]);
    });
  }

  // ── CueHost ───────────────────────────────────────────────────────────────
  klaxon(on: boolean): void {
    if (!on) {
      this.klaxonUntil = 0;
      return;
    }
    const now = this.engine.now;
    if (this.klaxonUntil <= now) this.klaxonNext = now + 0.05;
    this.klaxonUntil = now + this.data.klaxon.maxSeconds;
  }

  duck(amount: number, seconds: number, release: number): void {
    this.ducks.push({ amount, start: this.engine.now, hold: seconds, release });
  }

  scene(name: string, on: boolean, seconds?: number): void {
    if (on) this.scenes.set(name, seconds ? this.engine.now + seconds : Infinity);
    else this.scenes.delete(name);
  }

  voice(id: string): void {
    void this.voices.play(id);
  }

  private sceneOn(name: string): boolean {
    const until = this.scenes.get(name);
    if (until === undefined) return false;
    if (until < this.engine.now) {
      this.scenes.delete(name);
      return false;
    }
    return true;
  }

  // ── Mix controls ──────────────────────────────────────────────────────────
  toggleMute(): void {
    const on = !this.engine.muted;
    this.engine.setMuted(on);
    try {
      localStorage.setItem(MUTE_STORE, on ? "1" : "0");
    } catch {
      /* not persisted */
    }
    this.game.hud.showMessage(on ? this.data.messages.muted : this.data.messages.unmuted, 1.4);
  }

  // ── Per frame ─────────────────────────────────────────────────────────────
  update(dt: number): void {
    const g = this.game;
    const e = this.engine;
    if (g.input.justPressed(this.data.muteKey)) this.toggleMute();
    e.setPaused(g.paused);
    const amb = this.ambience;
    if (!e.ctx || !amb || e.paused) return;
    const now = e.now;
    const cam = g.render.camera;
    cam.getWorldDirection(this.fwd);
    this.up.copy(UP).applyQuaternion(cam.quaternion);
    e.setListener(cam.position, this.fwd, this.up);

    // The space: ceiling height decides room vs hall reverb.
    this.spaceTimer -= dt;
    if (this.spaceTimer <= 0) {
      this.spaceTimer = 0.25;
      this.chunk = this.chunkAt(cam.position);
      this.probeSpace(cam.position);
    }
    const indoorTarget = this.chunk !== "exterior" ? 1 : g.lighting.indoor;
    this.indoor += (indoorTarget - this.indoor) * Math.min(1, dt * 3);
    const indoor = this.indoor;
    const H = this.data.hall;
    const hallTarget = indoor > 0.5 ? this.openness : 0;
    this.hall += (hallTarget - this.hall) * Math.min(1, dt * 2);
    e.roomSend.gain.setTargetAtTime(indoor * (1 - this.hall) * H.roomReverb + (1 - indoor) * H.outdoorReverb, now, 0.2);
    e.hallSend.gain.setTargetAtTime(indoor * this.hall * H.hallReverb, now, 0.2);

    const rainTarget = g.env.weather === "RAINY" ? 1 : 0;
    this.rain += (rainTarget - this.rain) * Math.min(1, dt * this.data.rain.fade);

    // Ducking: memories, captures, cue ducks, silence scenes.
    let level = 1;
    if (g.hud.memoryPlaying) level *= this.data.ducking.memory;
    if (g.story.capturing) level *= this.data.ducking.capture;
    this.ducks = this.ducks.filter((d) => now < d.start + d.hold + d.release);
    for (const d of this.ducks) {
      const t = now - d.start;
      const k = t < d.hold ? 1 : 1 - (t - d.hold) / d.release;
      level *= 1 - d.amount * k;
    }
    if (this.sceneOn("silence")) level = 0;
    const immersion = Math.max(g.swim.immersion, this.sceneOn("water") ? 1 : 0);

    const s = this.input;
    s.indoor = indoor;
    s.rain = this.rain;
    s.atrium = this.hall;
    s.night = g.env.nightLevel();
    s.tubes = g.story.hasFlag("cycle:lights_out") ? 0.15 : 1;
    s.immersion = immersion;
    s.level = level;
    s.searchlights = g.story.hasFlag("searchlights_off") ? 0 : g.searchlights.level;
    amb.update(dt, s);

    // Underwater: everything in the world goes dull and close.
    const U = this.data.underwater;
    const cutoff = 20000 * Math.pow(U.cutoff / 20000, Math.pow(immersion, 0.7));
    e.world.frequency.setTargetAtTime(cutoff, now, 0.05);
    e.worldLevel.gain.setTargetAtTime(1 - U.dip * immersion, now, 0.08);
    this.updateSwim(dt);
    this.updateTension(dt, now);
    this.updateKlaxon(now);
    this.updateRandom(dt, now);
    this.updateGuards();
  }

  private updateSwim(dt: number): void {
    const sw = this.game.swim;
    if (sw.underwater) this.underFor += dt;
    if (sw.underwater && !this.wasUnder) this.cues.play(["swim:dive"]);
    if (!sw.underwater && this.wasUnder) this.cues.play([this.underFor > 3 ? "swim:surface" : "swim:bob"], { seconds: this.underFor });
    if (!sw.underwater) this.underFor = 0;
    this.wasUnder = sw.underwater;
  }

  private updateTension(dt: number, now: number): void {
    const T = this.data.tension;
    const sus = this.game.suspicion;
    let target = smooth(T.from, 100, sus.value);
    if (sus.state === "ALERT") target = Math.max(target, 0.9);
    target = Math.max(target, Math.min(1, this.underFor / 18) * T.breathHold);
    if (this.game.story.capturing) target *= 0.3;
    this.tension += (target - this.tension) * Math.min(1, dt * (target > this.tension ? 2 : 0.5));
    const k = this.tension;
    this.bpm = T.bpm[0] + (T.bpm[1] - T.bpm[0]) * k;
    if (this.drone) {
      this.drone.gain.gain.setTargetAtTime(T.drone * k * k, now, 0.3);
      this.drone.filter.frequency.setTargetAtTime(90 + 800 * k, now, 0.3);
    }
    if (k < 0.03) {
      this.beatNext = 0;
      return;
    }
    if (this.beatNext < now) this.beatNext = now + 0.05;
    if (this.beatNext < now + 0.15) {
      const interval = 60 / this.bpm;
      S.heartbeat(this.engine, this.beatNext, T.heartbeat * Math.pow(k, 0.8), interval);
      this.beatNext += interval;
    }
  }

  private updateKlaxon(now: number): void {
    const K = this.data.klaxon;
    if (now >= this.klaxonUntil) return;
    if (this.klaxonNext < now) this.klaxonNext = now + 0.02;
    if (this.klaxonNext < now + 0.2) {
      S.klaxon(this.engine, this.klaxonNext, K.gain, K.period);
      this.klaxonNext += K.period;
    }
  }

  private updateRandom(dt: number, now: number): void {
    const e = this.engine;
    const cam = this.game.render.camera.position;
    const s = this.input;
    const R = this.data.rain;
    if (s.level < 0.05) return;
    const out = 1 - s.indoor;
    const around = (r: number, dy = 0) => new Vector3(cam.x + rnd(-r, r), cam.y + dy, cam.z + rnd(-r, r));
    if (Math.random() < R.drops * s.rain * out * dt) S.raindrop(e, { position: around(4, -1.4) }, s.level);
    if (Math.random() < R.roofDrips * s.rain * s.indoor * dt) S.drip(e, { position: around(7, rnd(-1, 1)), reverb: 0.4 }, 0.6 * s.level);
    if (s.rain > 0.6 && now > this.nextThunder) {
      this.nextThunder = now + rnd(...R.thunderEvery);
      S.thunder(e, R.thunder * (1 - 0.5 * s.indoor) * s.level);
    }
    const C = this.data.clanks;
    if (now > this.nextClank) {
      this.nextClank = now + rnd(...C.every);
      // Chunk families: "cellhouseA_cells" belongs to "cellhouseA" (as in Game.updateChunkVisibility).
      if (this.hall > 0.5 && C.chunks.includes(this.chunk.split("_")[0])) {
        const a = Math.random() * Math.PI * 2;
        const r = rnd(10, 20);
        S.clank(e, { position: new Vector3(cam.x + Math.cos(a) * r, cam.y + rnd(-4, 5), cam.z + Math.sin(a) * r), refDistance: 4 }, C.gain * s.level);
      }
    }
  }

  /** Guards' boots: positional, occluded through walls (a stealth cue). */
  private updateGuards(): void {
    const F = this.data.footsteps;
    const cam = this.game.render.camera.position;
    for (const gd of this.game.guards.guards) {
      const p = gd.position;
      let st = this.guardSteps.get(gd);
      if (!st) {
        st = { x: p.x, z: p.z, stride: 0 };
        this.guardSteps.set(gd, st);
      }
      const d = Math.hypot(p.x - st.x, p.z - st.z);
      st.x = p.x;
      st.z = p.z;
      if (d > 1.5) continue; // teleported / reset
      st.stride += d;
      const pursuing = gd.state === "PURSUE";
      if (st.stride < F.guardStride * (pursuing ? 1.3 : 1)) continue;
      st.stride = 0;
      const dist = p.distanceTo(cam);
      if (dist > F.guardRange) continue;
      const pos = p.clone().add(new Vector3(0, 0.1, 0));
      const head = p.clone().add(new Vector3(0, 1.4, 0));
      const indoor = this.game.isSheltered(head, 30);
      S.footstep(this.engine, this.surfaceAt(p, indoor), pursuing ? 0.85 : 0.45, { position: pos, occluded: this.blocked(head), refDistance: 2.5 }, F.guardGain);
    }
  }

  // ── World queries ─────────────────────────────────────────────────────────
  surfaceAt(p: Vector3, indoor: boolean): S.Surface {
    if (this.game.swim.water && p.distanceToSquared(this.game.player.position) < 0.01) return "water";
    const chunk = this.chunkAt(new Vector3(p.x, p.y + 0.5, p.z));
    for (const r of this.data.surfaces) {
      if (r.chunk && r.chunk !== chunk) continue;
      if (r.minY !== undefined && p.y < r.minY) continue;
      if (r.maxY !== undefined && p.y > r.maxY) continue;
      return r.surface;
    }
    if (indoor) return "concrete";
    return this.rain > 0.4 ? "wet" : this.data.outdoor;
  }

  /** Smallest interior chunk containing the point, else "exterior". */
  chunkAt(p: Vector3): string {
    let best = "exterior";
    let vol = Infinity;
    for (const c of this.game.chunks.values()) {
      if (!c.interior || c.bounds.isEmpty() || !c.bounds.containsPoint(p)) continue;
      const s = c.bounds.max.clone().sub(c.bounds.min);
      const v = s.x * s.y * s.z;
      if (v < vol) {
        vol = v;
        best = c.name;
      }
    }
    return best;
  }

  /** Ceiling height straight up and 3 m around: big open volumes read as a hall. */
  private probeSpace(p: Vector3): void {
    const H = this.data.hall;
    this.ceiling = this.ceilingAbove(p);
    let open = smooth(H.from, H.to, this.ceiling);
    const q = new Vector3();
    for (const [dx, dz] of [[3, 0], [-3, 0], [0, 3], [0, -3]]) {
      q.set(p.x + dx, p.y, p.z + dz);
      if (this.game.segmentBlocked(p, q)) continue;
      open += smooth(H.from, H.to, this.ceilingAbove(q));
    }
    this.openness = open / 5;
  }

  ceilingAbove(p: Vector3): number {
    this.ray.set(p, UP);
    this.ray.far = 40;
    (this.ray as Raycaster & { firstHitOnly?: boolean }).firstHitOnly = true;
    const hit = this.ray.intersectObject(this.game.occluder, false)[0];
    return hit ? hit.distance : 40;
  }

  private blocked(pos: Vector3): boolean {
    return this.game.segmentBlocked(this.game.render.camera.position, pos);
  }

  private doorAt(p: Vector3) {
    let best = null;
    let bestD = 2.5;
    for (const d of this.game.doors) {
      const dist = d.root.position.distanceTo(p);
      if (dist < bestD) {
        bestD = dist;
        best = d;
      }
    }
    return best;
  }

  debugInfo(): Record<string, unknown> {
    const e = this.engine;
    const r2 = (v: number) => +v.toFixed(3);
    return {
      state: e.ctx?.state ?? "locked",
      muted: e.muted,
      paused: e.paused,
      time: r2(e.now),
      active: e.active,
      played: e.played,
      towers: this.ambience?.towerCount ?? 0,
      input: Object.fromEntries(Object.entries(this.input).map(([k, v]) => [k, r2(v)])),
      ambience: Object.fromEntries(Object.entries(this.ambience?.targets ?? {}).map(([k, v]) => [k, r2(v)])),
      worldCutoff: e.ctx ? Math.round(e.world.frequency.value) : null,
      roomSend: e.ctx ? r2(e.roomSend.gain.value) : null,
      hallSend: e.ctx ? r2(e.hallSend.gain.value) : null,
      ceiling: r2(this.ceiling),
      openness: r2(this.openness),
      chunk: this.chunk,
      tension: r2(this.tension),
      bpm: Math.round(this.bpm),
      drone: this.drone ? r2(this.drone.gain.gain.value) : null,
      klaxon: this.klaxonUntil > e.now,
      scenes: [...this.scenes.keys()],
      cues: this.cues.log.slice(-10),
      voices: this.voices.log.slice(-6),
      levels: e.ctx ? e.levels() : null,
    };
  }
}
