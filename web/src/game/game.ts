import { Mesh, Raycaster, Vector3 } from "three";
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

export interface GameOptions {
  canvas: HTMLCanvasElement;
  hudRoot: HTMLElement;
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
  readonly env: EnvironmentCycle;
  readonly suspicion = new SuspicionSystem();
  readonly memory = new MemoryManager();
  readonly inventory = new Inventory();
  readonly access: AccessManager;
  readonly noise = new WorldNoiseSystem();
  readonly hud: Hud;
  occluder!: Mesh;
  chunks = new Map<string, ChunkInfo>();
  anchors = new Map<string, Anchor>();
  doorSpecs: DoorSpec[] = [];
  plans: FloorPlan[] = [];
  floors = new Map<string, BuiltFloor>();
  private raycaster = new Raycaster();
  private last = performance.now();
  private frames = 0;
  private fpsTimer = 0;
  fps = 0;
  started = false;
  paused = false;
  stats = { triangles: 0, drawCalls: 0, colliders: 0 };
  private indoorTimer = 0;

  constructor(opts: GameOptions) {
    this.input = new Input(opts.canvas);
    this.render = new RenderStack(opts.canvas);
    this.env = new EnvironmentCycle(6.1);
    this.access = new AccessManager(this.inventory);
    this.hud = new Hud(opts.hudRoot);
  }

  async init(): Promise<void> {
    this.hud.setLoading("INITIALISING PHYSICS");
    this.physics = await Physics.create();
    await document.fonts.load('600 56px "Oswald"').catch(() => undefined);
    this.materials = new MaterialLibrary(this.render.renderer, this.render.prepareMaterial);
    this.hud.setLoading("BUILDING CAMPUS");
    await new Promise((r) => setTimeout(r, 0));
    const builder = new StaticBuilder(this.physics, this.materials, this.render.prepareMaterial);
    this.plans = await loadFloorPlans();
    this.floors = buildCampus(builder, this.plans);
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
    const spawn = this.anchors.get("parth_spawn");
    if (spawn) this.player.teleport(spawn.position, spawn.yaw);
    this.physics.step(1 / 60);

    this.env.events.on("display_changed", (t) => this.hud.setEnvironment(t));
    this.suspicion.events.on("suspicion_changed", () => this.hud.setSuspicion(this.suspicion.value, this.suspicion.state));
    this.suspicion.events.on("suspicion_state_changed", () => this.hud.setSuspicion(this.suspicion.value, this.suspicion.state));
    this.hud.setSuspicion(0, "NORMAL");
    this.hud.setEnvironment(this.env.displayText());

    this.hud.setLoading("LOADING TEXTURES");
    await this.materials.ready;
    this.lighting.update(0, this.render.camera.position);
    this.render.refreshEnvironment();
    // Compile shaders before the first visible frame to avoid hitching.
    this.player.updateCamera(0);
    this.render.renderer.compile(this.render.scene, this.render.camera);
    this.hud.setLoading("");
    this.hud.start.addEventListener("click", () => this.begin());
    document.addEventListener("pointerlockchange", () => {
      if (!this.input.locked && this.started && !this.paused && !this.hud.memoryPlaying) this.pause();
    });
    animeEngine.useDefaultMainLoop = false;
    animeEngine.pauseOnDocumentHidden = false;
    this.schedule();
  }

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

  private loop = (now: number): void => {
    animeEngine.update();
    gsap.ticker.tick();
    const dt = Math.min(0.05, (now - this.last) / 1000);
    this.last = now;
    this.update(dt);
    this.frames++;
    this.fpsTimer += dt;
    if (this.fpsTimer >= 0.5) {
      this.fps = this.frames / this.fpsTimer;
      this.frames = 0;
      this.fpsTimer = 0;
    }
  };

  /**
   * Deterministic stepping for automated play-tests (a hidden browser pane
   * throttles requestAnimationFrame). Simulates `seconds` at 60 Hz and
   * renders only the final frame unless `renderAll` is set.
   */
  step(seconds: number, renderAll = false): Record<string, unknown> {
    const frames = Math.max(1, Math.round(seconds * 60));
    for (let i = 0; i < frames; i++) this.update(1 / 60, renderAll || i === frames - 1);
    return this.debugInfo();
  }

  update(dt: number, draw = true): void {
    const p = this.player;
    if (this.started) {
      p.update(dt);
      this.physics.step(dt);
      this.suspicion.update(dt);
      this.env.update(dt);
    }
    p.updateCamera(dt);
    this.updateIndoor(dt);
    this.updateChunkVisibility();
    this.pool.update(dt, this.render.camera.position);
    this.lighting.update(dt, this.render.camera.position);
    if (draw) this.render.render(dt);
    this.input.endFrame();
  }

  /** Upward ray against the occluder BVH: under a roof → interior ambience. */
  private updateIndoor(dt: number): void {
    this.indoorTimer -= dt;
    if (this.indoorTimer <= 0) {
      this.indoorTimer = 0.1;
      const origin = this.render.camera.position.clone();
      this.raycaster.set(origin, new Vector3(0, 1, 0));
      this.raycaster.far = 40;
      (this.raycaster as Raycaster & { firstHitOnly?: boolean }).firstHitOnly = true;
      const hit = this.raycaster.intersectObject(this.occluder, false).length > 0;
      this.indoorTarget = hit ? 1 : 0;
    }
    this.lighting.indoor += (this.indoorTarget - this.lighting.indoor) * (1 - Math.exp(-dt * 3));
  }
  private indoorTarget = 0;

  /** Interior chunks render only when the camera is near/inside their bounds. */
  private updateChunkVisibility(): void {
    const cam = this.render.camera.position;
    for (const chunk of this.chunks.values()) {
      if (!chunk.interior || chunk.bounds.isEmpty()) continue;
      const d = chunk.bounds.distanceToPoint(cam);
      chunk.group.visible = d < 46;
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
      time: this.env.displayText(),
      indoor: +this.lighting.indoor.toFixed(2),
    };
  }
}
