import { Group, Mesh, Object3D, Quaternion, Raycaster, Vector3, Matrix4 } from "three";
import { engine as animeEngine } from "animejs";
import { gsap } from "gsap";
import { Input } from "../core/input";
import { Physics } from "../physics/physics";
import { RenderStack } from "../render/renderer";
import { MaterialLibrary } from "../render/materials";
import { LightPool } from "../render/lightPool";
import { WorldLighting } from "../render/worldLighting";
import { StaticBuilder, type ChunkInfo } from "../world/builder";
import { buildCampus } from "../world/campus/campus";
import { PropLibrary } from "../world/models";
import { buildOuterGrass } from "../world/campus/ground";
import { loadFloorPlans, type FloorPlan } from "../world/campus/plans";
import type { BuiltFloor } from "../world/campus/blueprintFloor";
import { Player } from "../player/player";
import { EnvironmentCycle } from "../systems/environment";
import { SuspicionSystem } from "../systems/suspicion";
import { MemoryManager } from "../systems/memory";
import { Inventory } from "../systems/inventory";
import { AccessManager } from "../systems/access";
import { WorldNoiseSystem } from "../systems/noise";
import { Hud } from "../ui/hud";
import type { Anchor, DoorSpec } from "../world/types";
import { InteractionSystem } from "../interact/interactable";
import { Door, ReaderLeds } from "../interact/door";
import { loadSession, type MemoryData, type SessionContent } from "../content/content";
import { Session } from "./session";
import { GuardManager } from "../ai/guards";
import { SwimMotor, SwimmingPool } from "../world/pool";
import { DustMotes, Rain } from "../render/weather";
import { Searchlights } from "../render/searchlights";
import { LightShafts } from "../render/lightShafts";
import { Minimap } from "../ui/minimap";
import { DevMode } from "../ui/devMenu";
import { PistolController } from "../weapons/pistol";
import { StoryDirector, loadStoryData } from "../story/director";

export interface GameOptions {
  canvas: HTMLCanvasElement;
  hudRoot: HTMLElement;
}

/** Camera override used by cinematics; GSAP tweens `weight` and the targets. */
interface Cinematic {
  weight: number;
  position: Vector3;
  look: Vector3;
}

/**
 * Top-level orchestrator (Godot: PrisonCampusPrototype + autoloads). Owns the
 * render stack, physics, static world and every gameplay system.
 */
export class Game {
  readonly input: Input;
  readonly render: RenderStack;
  physics!: Physics;
  materials!: MaterialLibrary;
  player!: Player;
  pool!: LightPool;
  lighting!: WorldLighting;
  env!: EnvironmentCycle;
  readonly suspicion = new SuspicionSystem();
  readonly memory = new MemoryManager();
  readonly inventory = new Inventory();
  readonly access: AccessManager;
  readonly noise = new WorldNoiseSystem();
  readonly hud: Hud;
  interaction!: InteractionSystem;
  readonly guards = new GuardManager(this);
  pools: SwimmingPool[] = [];
  swim!: SwimMotor;
  rain = new Rain();
  dust = new DustMotes();
  searchlights!: Searchlights;
  shafts: LightShafts | null = null;
  minimap!: Minimap;
  dev!: DevMode;
  weapons: PistolController | null = null;
  private exposureTimer = 0;
  session!: Session;
  content!: SessionContent;
  /** The "Again" story runtime (cycle/wall/flags, triggers, dialogue, capture → wipe). */
  story!: StoryDirector;
  occluder!: Mesh;
  /** Closed solid door leaves; tested in addition to the static BVH. */
  readonly dynamicOccluders = new Set<Object3D>();
  doors: Door[] = [];
  chunks = new Map<string, ChunkInfo>();
  anchors = new Map<string, Anchor>();
  doorSpecs: DoorSpec[] = [];
  plans: FloorPlan[] = [];
  floors = new Map<string, BuiltFloor>();
  readonly cine: Cinematic = { weight: 0, position: new Vector3(), look: new Vector3() };
  private raycaster = new Raycaster();
  private last = performance.now();
  private frames = 0;
  private fpsTimer = 0;
  fps = 0;
  started = false;
  paused = false;
  stats = { triangles: 0, drawCalls: 0, colliders: 0 };
  private indoorTimer = 0;
  private indoorTarget = 0;
  /** Systems added by later milestones register per-frame updates here. */
  readonly updaters: ((dt: number) => void)[] = [];
  failureInProgress = false;

  constructor(opts: GameOptions) {
    this.input = new Input(opts.canvas);
    this.render = new RenderStack(opts.canvas);
    this.access = new AccessManager(this.inventory);
    this.hud = new Hud(opts.hudRoot);
  }

  async init(): Promise<void> {
    this.hud.setLoading("INITIALISING PHYSICS");
    const [physics, plans, loaded, storyData, props] = await Promise.all([
      Physics.create(),
      loadFloorPlans(),
      loadSession(),
      loadStoryData(),
      PropLibrary.load(this.render.prepareMaterial),
    ]);
    this.physics = physics;
    this.plans = plans;
    this.content = loaded.session;
    this.story = new StoryDirector(this, storyData);
    // Cycle state, the wall and recovered memories survive wipes and reloads.
    this.story.loadSave();
    this.env = new EnvironmentCycle(this.content.startHour);
    this.env.dayLengthSeconds = this.content.dayLengthSeconds;
    await document.fonts.load('600 56px "Oswald"').catch(() => undefined);
    this.materials = new MaterialLibrary(this.render.renderer, this.render.prepareMaterial);
    this.hud.setLoading("BUILDING CAMPUS");
    await new Promise((r) => setTimeout(r, 0));
    const builder = new StaticBuilder(this.physics, this.materials, this.render.prepareMaterial, props);
    this.floors = buildCampus(builder, this.plans);
    this.session = new Session(this.content, loaded.memories);
    this.session.buildStatic(builder, this.floors, builder.doors);
    this.story.buildStatic(builder, this.floors);
    buildOuterGrass(builder);
    const world = builder.finalize();
    this.render.scene.add(world.root);
    this.occluder = world.occluder;
    this.chunks = builder.chunks;
    this.anchors = builder.anchors;
    this.doorSpecs = builder.doors;
    this.stats = { triangles: world.triangles, drawCalls: world.drawCalls, colliders: builder.colliderCount };
    this.pool = new LightPool(this.render.scene, builder.fixtures, 12);
    this.lighting = new WorldLighting(this.render, this.env, this.pool, this.materials);

    this.player = new Player(this.physics, this.input, this.render.camera);
    const poolAnchor = this.anchors.get("pool");
    if (poolAnchor) {
      const d = poolAnchor.data as { sizeX: number; sizeZ: number; depth: number; surfaceY: number };
      const pool = new SwimmingPool(poolAnchor.position, d.sizeX, d.sizeZ, d.depth, d.surfaceY);
      this.render.scene.add(pool.mesh);
      this.pools.push(pool);
    }
    this.swim = new SwimMotor(this.pools, this.input);
    this.player.waterMotor = this.swim;
    this.swim.events.on("swimming_state_changed", (s) => this.hud.setSwimming(s, this.swim.water?.ceiling ?? false));
    this.render.scene.add(this.rain.mesh, this.dust.points);
    this.searchlights = new Searchlights(this.render.scene, this.anchors);
    const sky = this.anchors.get("cellhouse_a_skylight");
    if (sky) {
      const d = sky.data as { x0: number; z0: number; x1: number; z1: number; top: number; depth: number };
      const o = sky.position;
      this.shafts = new LightShafts(o.x + d.x0, o.z + d.z0, o.x + d.x1, o.z + d.z1, o.y + d.top, d.depth);
      this.render.scene.add(this.shafts.mesh);
    }
    this.minimap = new Minimap(this.hud.root, this.plans);
    this.weapons = new PistolController(this, this.render.camera, this.render.scene);
    this.dev = new DevMode(this);
    this.interaction = new InteractionSystem(this.occluder);
    this.spawnDoors();
    this.session.spawn(this, (chunk) => this.chunkGroup(chunk));
    this.respawnPlayer();
    this.hud.setLoading("LOADING GUARDS");
    await this.guards.init(this.render.scene);
    this.updaters.push((dt) => this.guards.update(dt));
    this.hud.setLoading("WAKING");
    await this.story.init();
    this.updaters.push((dt) => this.story.update(dt));
    this.physics.step(1 / 60);
    this.bindEvents();

    this.hud.setLoading("LOADING TEXTURES");
    await this.materials.ready;
    this.lighting.update(0, this.render.camera.position);
    this.render.refreshEnvironment();
    this.player.updateCamera(0);
    this.render.renderer.compile(this.render.scene, this.render.camera);
    this.hud.setLoading("");
    this.hud.start.addEventListener("click", () => this.begin());
    document.addEventListener("pointerlockchange", () => {
      if (!this.input.locked && this.started && !this.paused && !this.hud.memoryPlaying && !this.input.suppressPause) this.pause();
    });
    animeEngine.useDefaultMainLoop = false;
    animeEngine.pauseOnDocumentHidden = false;
    this.schedule();
  }

  chunkGroup(name: string): Group {
    return this.chunks.get(name)?.group ?? this.chunks.get("exterior")!.group;
  }

  private spawnDoors(): void {
    const leds = new ReaderLeds(this.doorSpecs.length);
    this.render.scene.add(leds.mesh);
    const ctx = {
      leds,
      physics: this.physics,
      materials: this.materials,
      access: this.access,
      message: (t: string, d?: number) => this.hud.showMessage(t, d),
      occluders: this.dynamicOccluders,
      onNoise: (p: Vector3, i: number) => this.noise.emitNoise(p, i, "DOOR", "door"),
    };
    for (const spec of this.doorSpecs) {
      const door = new Door(spec, ctx);
      this.chunkGroup(spec.chunk).add(door.root);
      this.interaction.register(door);
      this.doors.push(door);
    }
  }

  respawnPlayer(): void {
    const spawn = this.anchors.get(this.content.player.spawnAnchor);
    if (spawn) this.player.teleport(spawn.position, spawn.yaw);
  }

  private bindEvents(): void {
    this.env.events.on("display_changed", (t) => this.hud.setEnvironment(t));
    const sus = () => this.hud.setSuspicion(this.suspicion.value, this.suspicion.state);
    this.suspicion.events.on("suspicion_changed", sus);
    this.suspicion.events.on("suspicion_state_changed", sus);
    this.hud.setSuspicion(0, "NORMAL");
    this.hud.setEnvironment(this.env.displayText());
    this.inventory.events.on("inventory_changed", () => {
      this.hud.setInventory(this.inventory.entries().map((e) => e.def.displayName.toUpperCase()));
      this.session.advanceObjectives(this);
    });
    this.inventory.events.on("feedback_requested", (m) => this.hud.showMessage(m));
    this.memory.events.on("memory_collected", () => this.session.advanceObjectives(this));
    this.player.events.on("footstep", ({ position, intensity }) => this.noise.emitNoise(position, intensity, "CONCRETE", "player"));
    this.player.events.on("landed", ({ position, speed }) => this.noise.emitNoise(position, Math.min(1, speed / 8), "CONCRETE", "player"));
  }

  // ── Loop ───────────────────────────────────────────────────────────────────
  /**
   * rAF when visible; a timer watchdog keeps the game (and the anime.js/GSAP
   * tweens it drives) running when the page is backgrounded or the preview
   * pane is hidden.
   */
  private rafId = 0;
  private timerId = 0;
  private schedule(): void {
    const run = (now: number) => {
      cancelAnimationFrame(this.rafId);
      clearTimeout(this.timerId);
      this.loop(now);
      this.schedule();
    };
    this.rafId = requestAnimationFrame(run);
    this.timerId = window.setTimeout(() => run(performance.now()), 40);
  }

  begin(): void {
    this.input.requestLock();
    if (!this.started) {
      this.started = true;
      this.hud.hideStart();
    } else if (this.paused) {
      this.paused = false;
      this.hud.hideStart();
    }
  }

  pause(): void {
    // Keyboard keeps working without pointer lock; only the overlay appears.
    this.paused = true;
    this.hud.showStartPaused();
  }

  /**
   * Adaptive render scale: keeps 60 fps by trimming the pixel ratio when the
   * smoothed frame time exceeds budget, and restoring it when there's room.
   */
  private frameAvg = 16;
  private scaleTimer = 0;
  adaptiveResolution = true;
  private adaptResolution(frameMs: number, dt: number): void {
    if (!this.adaptiveResolution || document.hidden) return;
    this.frameAvg += (frameMs - this.frameAvg) * 0.05;
    this.scaleTimer -= dt;
    if (this.scaleTimer > 0) return;
    const q = this.render.quality;
    const max = Math.min(window.devicePixelRatio, 1.5);
    if (this.frameAvg > 18.5 && q.pixelRatio > 0.7) {
      this.render.setPixelRatio(Math.max(0.7, q.pixelRatio - 0.1));
      this.scaleTimer = 1.5;
    } else if (this.frameAvg < 13 && q.pixelRatio < max) {
      this.render.setPixelRatio(Math.min(max, q.pixelRatio + 0.05));
      this.scaleTimer = 3;
    }
  }

  private loop = (now: number): void => {
    animeEngine.update();
    gsap.ticker.tick();
    const frameMs = now - this.last;
    const dt = Math.max(0, Math.min(0.05, frameMs / 1000));
    if (this.started && !this.paused) this.adaptResolution(frameMs, dt);
    this.last = now;
    this.update(dt);
    this.frames++;
    this.fpsTimer += dt;
    if (this.fpsTimer >= 0.5) {
      this.fps = this.frames / this.fpsTimer;
      this.frames = 0;
      this.fpsTimer = 0;
      this.hud.fps.textContent = this.showFps ? `${Math.round(this.fps)} FPS · ${this.render.renderer.info.render.calls} calls` : "";
    }
  };
  showFps = new URLSearchParams(location.search).has("fps");

  /**
   * Deterministic stepping for automated play-tests (a hidden browser pane
   * throttles requestAnimationFrame). Simulates `seconds` at 60 Hz and
   * renders only the final frame unless `renderAll` is set.
   */
  step(seconds: number, renderAll = false): Record<string, unknown> {
    const frames = Math.max(1, Math.round(seconds * 60));
    for (let i = 0; i < frames; i++) {
      gsap.ticker.tick();
      this.update(1 / 60, renderAll || i === frames - 1);
    }
    return this.debugInfo();
  }

  /**
   * Like step(), but yields between frames so promise-driven story logic
   * (dialogue, capture → wipe, action chains) advances exactly as in play.
   * Automation: `await __game.stepAsync(3)`.
   */
  async stepAsync(seconds: number, renderAll = false): Promise<Record<string, unknown>> {
    const frames = Math.max(1, Math.round(seconds * 60));
    for (let i = 0; i < frames; i++) {
      gsap.ticker.tick();
      this.update(1 / 60, renderAll || i === frames - 1);
      await Promise.resolve();
    }
    return this.debugInfo();
  }

  update(dt: number, draw = true): void {
    const p = this.player;
    if (this.started) {
      // Unlocked, the cursor is needed for choice buttons and documents, so they freeze the view.
      if (!this.input.locked && this.story.ui.blocking) {
        this.input.mouseDX = 0;
        this.input.mouseDY = 0;
      }
      p.update(dt);
      // Pose the camera before anything aims through it (interaction, firing).
      p.updateCamera(dt);
      this.applyCinematic();
      this.physics.step(dt);
      this.suspicion.update(dt);
      this.env.update(dt);
      this.interaction.update(this.render.camera, p);
      this.hud.setPrompt(this.interaction.prompt);
      if (this.input.justPressed("KeyE")) {
        if (this.hud.memoryPlaying) this.hud.requestSkip();
        else if (this.interaction.current && p.controlEnabled && !this.story.ui.blocking) this.interaction.current.interact(p);
      }
      this.session.update(dt, this);
      for (const u of this.updaters) u(dt);
      if (this.input.justPressed("KeyM")) this.minimap.toggle();
      this.weapons?.update(dt);
      this.updateSearchlightExposure(dt);
    }
    for (const pool of this.pools) pool.update(dt);
    if (!this.started) {
      p.updateCamera(dt);
      this.applyCinematic();
    }
    this.updateIndoor(dt);
    this.updateChunkVisibility();
    const cam = this.render.camera.position;
    this.pool.update(dt, cam);
    this.lighting.update(dt, cam);
    this.swim.updateCamera(cam, dt);
    this.render.underwater.uniforms.get("time")!.value += dt;
    this.render.underwater.uniforms.get("immersion")!.value = this.swim.immersion;
    this.lighting.overrideFogDensity = this.swim.immersion > 0.001 ? this.swim.fogDensity * this.swim.immersion + 0.02 : null;
    if (this.swim.immersion > 0.001) this.render.fog.color.lerp(this.swim.fogColor, this.swim.immersion);
    const night = this.env.nightLevel();
    // The control-room radio (Act III) kills the towers' beams for good.
    this.searchlights.enabled = !this.story?.hasFlag("searchlights_off");
    this.searchlights.update(dt, night);
    if (this.shafts) {
      const sun = this.env.sunTravelDirection();
      const sample = this.env.skySample();
      const elevation = Math.min(1, Math.max(0, (-sun.y - 0.12) / 0.3));
      const visible = this.chunks.get("cellhouseA")?.group.visible ?? false;
      this.shafts.update(dt, sun, visible ? sample.daylight * elevation * (this.env.weather === "RAINY" ? 0.12 : 1) : 0, this.env.sunColor());
    }
    this.rain.update(dt, cam, (this.env.weather === "RAINY" ? 1 : 0) * (1 - this.lighting.indoor), night);
    this.dust.update(dt, cam, 0.35 + this.lighting.indoor * 0.9);
    this.minimap.update(
      dt,
      this.player.position,
      this.player.yaw,
      this.doors.map((d) => ({ x: d.position.x, z: d.position.z, y: d.position.y, locked: d.isLocked, open: d.isOpen })),
      this.guards.guards.map((gd) => ({ x: gd.position.x, z: gd.position.z, y: gd.position.y, alert: gd.state === "PURSUE" })),
      this.guards.showCones,
    );
    if (draw) this.render.render(dt);
    this.input.endFrame();
  }

  private applyCinematic(): void {
    const w = this.cine.weight;
    if (w <= 0.0001) return;
    const cam = this.render.camera;
    const m = new Matrix4().lookAt(this.cine.position, this.cine.look, new Vector3(0, 1, 0));
    const q = new Quaternion().setFromRotationMatrix(m);
    cam.position.lerp(this.cine.position, w);
    cam.quaternion.slerp(q, w);
  }

  // ── Memory reconstruction (MemoryShard.interact + HUD sequence) ────────────
  /**
   * Any focus object works (a shard, a story prop, a point in front of the
   * camera); `onDone` fires when control returns to the player.
   */
  collectMemory(shard: { root: Object3D; dissolve?: () => void }, data: MemoryData, onDone?: () => void): void {
    const record = { id: data.id, title: data.title, transcript: data.transcript, clue: data.practical_clue ?? "" };
    if (!this.memory.collectMemory(record)) {
      shard.root.visible = false;
      onDone?.();
      return;
    }
    const p = this.player;
    p.setControlEnabled(false);
    const shardPos = shard.root.getWorldPosition(new Vector3()).add(new Vector3(0, 0.17, 0));
    const cam = this.render.camera.position.clone();
    const toShard = shardPos.clone().sub(cam);
    this.cine.position.copy(cam).addScaledVector(toShard, 0.35);
    this.cine.look.copy(shardPos);
    const fade = this.render.fade.uniforms;
    const chroma = this.render.chroma;
    const tl = gsap.timeline();
    tl.to(this.cine, { weight: 1, duration: 1.1, ease: "power2.inOut" })
      .add(() => shard.dissolve?.(), 0.6)
      .to(fade.get("desaturate")!, { value: 0.85, duration: 0.9, ease: "power1.in" }, 0.4)
      .to(fade.get("amount")!, { value: 0.55, duration: 0.9, ease: "power2.in" }, 0.6)
      .to(chroma.offset, { x: 0.006, y: 0.004, duration: 0.25, yoyo: true, repeat: 3, ease: "sine.inOut" }, 0.6);
    tl.add(() => {
      void this.hud
        .playMemorySequence({ id: data.id, title: data.title, transcript: data.transcript, clue: data.practical_clue, tag: data.tag })
        .then(() => {
          gsap.timeline({
            onComplete: () => {
              p.setControlEnabled(true);
              onDone?.();
            },
          })
            .to(fade.get("amount")!, { value: 0, duration: 0.8, ease: "power2.out" }, 0)
            .to(fade.get("desaturate")!, { value: 0, duration: 1.2 }, 0)
            .to(this.cine, { weight: 0, duration: 1.0, ease: "power2.inOut" }, 0.1);
          this.session.advanceObjectives(this);
        });
    }, 1.2);
  }

  /** Tower sentries notice anyone caught in a beam for more than a moment. */
  private updateSearchlightExposure(dt: number): void {
    this.exposureTimer -= dt;
    if (this.exposureTimer <= 0) {
      this.exposureTimer = 0.2;
      this.searchlightLevel = this.guards.devInvisible ? 0 : this.searchlights.exposure(this.player.eyePosition, (a, b) => this.segmentBlocked(a, b));
    }
    if (this.searchlightLevel > 0.05) this.suspicion.addSuspicion(14 * this.searchlightLevel * dt);
  }

  /** 0..1: how strongly a searchlight beam currently covers the player. */
  searchlightExposure(): number {
    return this.searchlightLevel;
  }
  searchlightLevel = 0;

  /** CampusPhaseTwoGameplay._reload_level, in place: back to the cell, state kept. */
  detentionReset(): void {
    this.suspicion.reset();
    this.guards.reset();
    for (const door of this.doors) door.reset();
    this.respawnPlayer();
    this.player.unlockFailure();
    this.hud.hideDetained();
    this.failureInProgress = false;
  }

  // ── Environment helpers ────────────────────────────────────────────────────
  /** Upward ray against the occluder BVH: under a roof → interior ambience. */
  private updateIndoor(dt: number): void {
    this.indoorTimer -= dt;
    if (this.indoorTimer <= 0) {
      this.indoorTimer = 0.1;
      this.indoorTarget = this.isSheltered(this.render.camera.position) ? 1 : 0;
    }
    this.lighting.indoor += (this.indoorTarget - this.lighting.indoor) * (1 - Math.exp(-dt * 3));
  }

  isSheltered(point: Vector3, far = 40): boolean {
    this.raycaster.set(point, new Vector3(0, 1, 0));
    this.raycaster.far = far;
    (this.raycaster as Raycaster & { firstHitOnly?: boolean }).firstHitOnly = true;
    return this.raycaster.intersectObject(this.occluder, false).length > 0;
  }

  /** First static or door hit along a segment (guard LOS, etc.). */
  segmentBlocked(from: Vector3, to: Vector3): boolean {
    const dir = to.clone().sub(from);
    const dist = dir.length();
    if (dist < 1e-4) return false;
    this.raycaster.set(from, dir.divideScalar(dist));
    this.raycaster.far = dist;
    (this.raycaster as Raycaster & { firstHitOnly?: boolean }).firstHitOnly = true;
    if (this.raycaster.intersectObject(this.occluder, false).length > 0) return true;
    (this.raycaster as Raycaster & { firstHitOnly?: boolean }).firstHitOnly = false;
    for (const o of this.dynamicOccluders) {
      if (this.raycaster.intersectObject(o, true).length > 0) return true;
    }
    return false;
  }

  /**
   * Interior culling: inside a building only that building's interior is
   * drawn (walls hide the rest); outdoors, interiors within 28 m stay visible
   * so open doorways show their rooms.
   */
  private updateChunkVisibility(): void {
    const cam = this.render.camera.position;
    let inside: ChunkInfo | null = null;
    for (const chunk of this.chunks.values()) {
      if (chunk.interior && !chunk.bounds.isEmpty() && chunk.bounds.distanceToPoint(cam) < 0.5 && this.lighting.indoor > 0.5) {
        inside = chunk;
        break;
      }
    }
    for (const chunk of this.chunks.values()) {
      if (!chunk.interior || chunk.bounds.isEmpty()) continue;
      const base = (name: string) => name.split("_")[0];
      chunk.group.visible = inside
        ? base(chunk.name) === base(inside.name) || chunk.bounds.distanceToPoint(cam) < 2
        : chunk.bounds.distanceToPoint(cam) < 28;
    }
  }

  // ── Debug / automation ─────────────────────────────────────────────────────
  debugInfo(): Record<string, unknown> {
    const info = this.render.renderer.info;
    return {
      fps: Math.round(this.fps),
      calls: info.render.calls,
      triangles: info.render.triangles,
      staticTriangles: this.stats.triangles,
      staticDrawCalls: this.stats.drawCalls,
      colliders: this.stats.colliders,
      player: this.player.position.toArray().map((v) => +v.toFixed(2)),
      yaw: +this.player.yaw.toFixed(3),
      pitch: +this.player.pitch.toFixed(3),
      grounded: this.player.grounded,
      crouching: this.player.isCrouching,
      height: +this.player.height.toFixed(2),
      prompt: this.interaction?.prompt,
      suspicion: `${this.suspicion.value.toFixed(1)} ${this.suspicion.state}`,
      time: this.env.displayText(),
      indoor: +this.lighting.indoor.toFixed(2),
      inventory: this.inventory.entries().map((e) => e.def.id),
      story: this.story?.debugInfo(),
    };
  }

  /** Points the camera at a world position (automation helper). */
  lookAt(target: Vector3): void {
    const eye = this.player.eyePosition;
    const d = target.clone().sub(eye);
    this.player.yaw = Math.atan2(-d.x, -d.z);
    this.player.pitch = Math.atan2(d.y, Math.hypot(d.x, d.z));
  }
}
