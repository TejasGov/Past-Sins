import { BufferGeometry, Float32BufferAttribute, LineBasicMaterial, LineSegments, Vector3, type Scene } from "three";
import { gsap } from "gsap";
import { Guard, type GuardWorld } from "./guard";
import { loadCharacter } from "./guardVisual";
import { NavGraph } from "./nav";
import type { Game } from "../game/game";
import type { Door } from "../interact/door";
import { NAV_ANCHOR, type NavExport } from "../world/nav";

/**
 * Owns every guard (CampusPhaseTwoGameplay._spawn_guard_patrol, generalised to
 * the data-driven list in session.json), the shared nav graph and the
 * detention/failure flow.
 */
export class GuardManager {
  readonly guards: Guard[] = [];
  showCones = false;
  devInvisible = false;
  invulnerable = false;
  nav: NavGraph | null = null;
  private world!: GuardWorld;
  private scene: Scene | null = null;
  private navLines: LineSegments | null = null;
  private routeLines: LineSegments | null = null;
  /** Doors a guard opens or closes make noise too; other guards shouldn't investigate it. */
  private quietDoors = false;

  constructor(private game: Game) {}

  async init(scene: Scene): Promise<void> {
    const g = this.game;
    this.scene = scene;
    const asset = await loadCharacter(g.render.prepareMaterial);
    for (const def of g.content.guards) {
      const guard = new Guard(def, g.physics, asset, g.render.prepareMaterial);
      scene.add(guard.root, guard.cone);
      this.guards.push(guard);
    }
    this.buildNav();
    this.world = {
      player: g.player,
      suspicion: g.suspicion,
      segmentBlocked: (a, b) => g.segmentBlocked(a, b),
      visibilityFactor: () => this.visibilityFactor(),
      openDoorNear: (p, d) => this.openDoorNear(p, d),
      onCaught: (guard) => this.onCaught(guard),
      firearmVisible: () => !!g.weapons?.visiblyHeld,
      devInvisible: false,
      nav: this.nav,
      openDoor: (door) => this.openForGuard(door),
    };
    g.noise.events.on("noise_emitted", (e) => {
      if (this.quietDoors) return;
      for (const guard of this.guards) guard.hearNoise(e.position, e.radius, e.source);
    });
  }

  /** Builds the waypoint graph from the static world; on failure guards keep straight-line steering. */
  private buildNav(): void {
    const g = this.game;
    try {
      // Rapier's query structures only include colliders after a step.
      g.physics.step(1 / 60);
      this.nav = NavGraph.build({
        physics: g.physics,
        data: g.anchors.get(NAV_ANCHOR)?.data as NavExport | undefined,
        floors: g.floors,
        doors: g.doors,
        sheltered: (p) => g.isSheltered(new Vector3(p.x, p.y + 1, p.z), 40),
      });
      const s = this.nav.stats;
      console.info(`[nav] ${s.nodes} waypoints, ${s.edges} links (${s.doorEdges} through doors), ${s.components} islands (largest ${s.largest}), ${s.blocked} blocked landing segments dropped, ${s.ms} ms`);
    } catch (err) {
      console.error("[nav] build failed; guards fall back to straight-line steering", err);
      this.nav = null;
    }
  }

  private unseenTimer = 0;

  update(dt: number): void {
    this.world.devInvisible = this.devInvisible;
    let seen = false;
    const cam = this.game.render.camera.position;
    for (const guard of this.guards) {
      guard.update(dt, this.world);
      guard.cone.visible = this.showCones;
      seen ||= guard.canSeePlayer;
      // Skinned meshes can't use bind-pose bounds for culling; cull by range.
      const d = guard.position.distanceTo(cam);
      guard.root.visible = d < 70;
      guard.root.traverse((o) => (o.castShadow = d < 28));
    }
    if (this.routeLines) this.updateRouteLines();
    // ALERT only drops once *no* guard has seen Parth for a while, so hiding
    // works (the Godot version stayed at ALERT until a catch).
    this.unseenTimer = seen ? 0 : this.unseenTimer + dt;
    if (this.unseenTimer > 10 && this.game.suspicion.value >= 100) this.game.suspicion.value = 80;
  }

  /** Outdoors at night the player is harder to make out unless near a light. */
  private visibilityFactor(): number {
    const g = this.game;
    const night = g.env.nightLevel();
    if (night < 0.05) return 1;
    const sheltered = g.isSheltered(g.player.eyePosition, 30);
    if (sheltered) return 1;
    return 1 - 0.45 * night * (1 - g.searchlightExposure());
  }

  /** Stuck fallback: open whatever closed door is right in front of the guard. */
  private openDoorNear(position: Vector3, direction: Vector3): void {
    const probe = position.clone().addScaledVector(direction, 1.0);
    for (const door of this.game.doors) {
      if (door.isOpen || door.isMoving || door.spec.kind === "glass") continue;
      if (door.position.distanceToSquared(probe) > 2.6) continue;
      if (Math.abs(door.position.y - position.y) > 1.5) continue;
      this.openForGuard(door);
    }
  }

  /** Staff carry keys: the door opens (without unlocking it for Parth) and closes behind them. */
  private openForGuard(door: Door): void {
    if (door.isOpen || door.isMoving) return;
    this.quietly(() => door.openForAI());
    this.closeLater(door, 6, 5);
  }

  private closeLater(door: Door, delay: number, tries: number): void {
    gsap.delayedCall(delay, () => {
      this.quietly(() => door.closeForAI());
      // Someone standing in the doorway: try again shortly.
      if (door.isOpen && !door.isMoving && tries > 1) this.closeLater(door, 2, tries - 1);
    });
  }

  private quietly(fn: () => void): void {
    this.quietDoors = true;
    try {
      fn();
    } finally {
      this.quietDoors = false;
    }
  }

  /** Debug overlay (console: `__game.guards.showNav(true)`): the graph plus each guard's current route. */
  showNav(on: boolean): void {
    if (!this.scene || !this.nav) return;
    if (on && !this.navLines) {
      this.navLines = this.nav.debugLines();
      this.routeLines = new LineSegments(new BufferGeometry(), new LineBasicMaterial({ color: 0xff3df2, depthTest: false, toneMapped: false }));
      this.routeLines.renderOrder = 11;
      this.routeLines.frustumCulled = false;
      this.scene.add(this.navLines, this.routeLines);
    } else if (!on && this.navLines) {
      for (const l of [this.navLines, this.routeLines!]) {
        this.scene.remove(l);
        l.geometry.dispose();
      }
      this.navLines = null;
      this.routeLines = null;
    }
  }

  private updateRouteLines(): void {
    const pos: number[] = [];
    for (const guard of this.guards) {
      const pts = NavGraph.pathPoints([...guard.route], guard.position);
      for (let i = 1; i < pts.length; i++) pos.push(pts[i - 1].x, pts[i - 1].y, pts[i - 1].z, pts[i].x, pts[i].y, pts[i].z);
    }
    const geo = this.routeLines!.geometry;
    geo.setAttribute("position", new Float32BufferAttribute(pos, 3));
    geo.computeBoundingSphere();
  }

  private onCaught(_guard: Guard): void {
    const g = this.game;
    if (this.invulnerable) {
      g.suspicion.reset();
      for (const guard of this.guards) guard.reset();
      return;
    }
    if (g.failureInProgress || g.story.capturing) return;
    g.noise.emitNoise(g.player.position, 0, "NONE");
    // Being caught is part of the loop: the story runs the capture → wipe → wake.
    void g.story.capture("caught");
  }

  reset(): void {
    for (const guard of this.guards) guard.reset();
    this.game.weapons?.resetGuards();
  }
}
