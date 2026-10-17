import {
  BufferGeometry, DoubleSide, Float32BufferAttribute, Mesh, MeshBasicMaterial, Vector3, type Material, type Object3D,
} from "three";
import { GUARD_GROUPS, Layer, RAPIER, groups, type Physics } from "../physics/physics";
import type { GuardDef } from "../content/content";
import { GuardVisual, type CharacterAsset } from "./guardVisual";
import type { Player } from "../player/player";
import type { SuspicionSystem } from "../systems/suspicion";
import type { Door } from "../interact/door";
import type { NavGraph, NavWaypoint } from "./nav";

export type GuardState = "PATROL" | "WAIT" | "INVESTIGATE" | "SEARCH" | "PURSUE" | "STUNNED";

export interface GuardWorld {
  player: Player;
  suspicion: SuspicionSystem;
  /** True if a static wall or closed solid door blocks the segment. */
  segmentBlocked(from: Vector3, to: Vector3): boolean;
  /** Night + outdoors + unlit → harder to spot (0.55..1). */
  visibilityFactor(): number;
  /** Ask a nearby closed door to open for the guard. */
  openDoorNear(position: Vector3, direction: Vector3): void;
  onCaught(guard: Guard): void;
  firearmVisible(): boolean;
  devInvisible: boolean;
  /** Waypoint graph; null (not built / failed) means straight-line steering only. */
  nav: NavGraph | null;
  /** Open a door on the guard's route; it closes behind them. */
  openDoor(door: Door): void;
}

/** Optional per-guard keys read from session.json alongside GuardDef. */
interface GuardNavDef extends GuardDef {
  /** Seconds a pursuer keeps tracking Parth after losing sight of him (default 3). */
  trackSeconds?: number;
}

function moveToward(from: number, to: number, delta: number): number {
  return Math.abs(to - from) <= delta ? to : from + Math.sign(to - from) * delta;
}

function lerpAngle(a: number, b: number, t: number): number {
  let d = ((b - a + Math.PI) % (Math.PI * 2)) - Math.PI;
  if (d < -Math.PI) d += Math.PI * 2;
  return a + d * t;
}

/**
 * Port of scripts/ai/guard.gd — patrol between points, range → FOV → LOS
 * perception, suspicion accrual scaled by proximity/stance/restricted zones,
 * pursuit at ALERT and a catch check — plus noise investigation and a
 * last-known-position search at SEARCHING (both new). Every move goes through
 * the nav graph (A*, doors opened on the way), so patrols, searches and chases
 * cross storeys and buildings; a straight line is used when it's walkable.
 */
export class Guard {
  readonly position = new Vector3();
  readonly velocity = new Vector3();
  /** Godot convention: forward = (-sin yaw, 0, -cos yaw). */
  yaw = 0;
  state: GuardState = "PATROL";
  canSeePlayer = false;
  private patrolIndex = 0;
  private waitTimer = 0;
  private investigateTarget = new Vector3();
  private investigateTimer = 0;
  private lostTimer = 0;
  private caughtOnce = false;
  private stuckTimer = 0;
  private path: NavWaypoint[] = [];
  private pathIndex = 0;
  private readonly pathGoal = new Vector3();
  private pathAge = 0;
  private pathRetry = 0;
  private lookahead = 0;
  private directCheck = 0;
  private direct = false;
  private giveUp = 0;
  private readonly trackSeconds: number;
  readonly visual: GuardVisual;
  readonly cone: Mesh;
  private coneMat: MeshBasicMaterial;
  private collider: RAPIER.Collider;
  private controller: RAPIER.KinematicCharacterController;
  private grounded = false;
  readonly patrolSpeed: number;
  readonly pursuitSpeed: number;
  readonly waitAtPoint: number;
  readonly viewDistance: number;
  readonly fov: number;
  readonly suspicionPerSecond: number;
  readonly catchDistance = 1.25;
  private readonly patrol: Vector3[];
  private readonly home: Vector3;

  constructor(readonly def: GuardDef, physics: Physics, asset: CharacterAsset | null, prepare: (m: Material) => void) {
    this.patrol = def.patrol.map(([x, y, z]) => new Vector3(x, y, z));
    this.home = this.patrol[0].clone();
    this.patrolSpeed = def.patrolSpeed ?? 2.0;
    this.pursuitSpeed = def.pursuitSpeed ?? 4.8;
    this.waitAtPoint = def.waitAtPoint ?? 1.2;
    this.viewDistance = def.viewDistance ?? 16;
    this.fov = def.fov ?? 78;
    this.suspicionPerSecond = def.suspicionPerSecond ?? 10;
    this.trackSeconds = (def as GuardNavDef).trackSeconds ?? 3;
    const body = physics.world.createRigidBody(RAPIER.RigidBodyDesc.kinematicPositionBased());
    this.collider = physics.world.createCollider(RAPIER.ColliderDesc.capsule(0.58, 0.32).setCollisionGroups(GUARD_GROUPS), body);
    this.controller = physics.world.createCharacterController(0.02);
    this.controller.enableAutostep(0.3, 0.15, false);
    this.controller.enableSnapToGround(0.35);
    this.controller.setMaxSlopeClimbAngle((50 * Math.PI) / 180);
    this.visual = new GuardVisual(asset, prepare);
    this.coneMat = new MeshBasicMaterial({ color: 0x26bf73, transparent: true, opacity: 0.12, depthWrite: false, side: DoubleSide, toneMapped: false });
    this.cone = new Mesh(this.buildCone(), this.coneMat);
    this.cone.visible = false;
    this.cone.renderOrder = 5;
    this.reset();
  }

  get root(): Object3D {
    return this.visual.root;
  }

  get eye(): Vector3 {
    return this.position.clone().add(new Vector3(0, 1.62, 0));
  }

  get forward(): Vector3 {
    return new Vector3(-Math.sin(this.yaw), 0, -Math.cos(this.yaw));
  }

  reset(): void {
    this.collider.setEnabled(true);
    if (this.state === "STUNNED") this.visual.play("idle", 0);
    this.position.copy(this.home);
    this.velocity.set(0, 0, 0);
    this.patrolIndex = this.patrol.length > 1 ? 1 : 0;
    const d = this.patrol[this.patrolIndex].clone().sub(this.position);
    this.yaw = d.lengthSq() > 0.01 ? Math.atan2(-d.x, -d.z) : 0;
    this.state = "PATROL";
    this.caughtOnce = false;
    this.lostTimer = 0;
    this.direct = false;
    this.clearPath();
    this.syncCollider();
    this.syncVisual();
  }

  /** Dev pistol: a downed guard plays a death clip and leaves the AI loop until reset. */
  knockDown(): void {
    this.state = "STUNNED";
    this.velocity.set(0, 0, 0);
    this.collider.setEnabled(false);
    this.visual.play("death_fall_back", 0.15);
  }

  hearNoise(position: Vector3, radius: number, source?: string): void {
    if (this.state === "STUNNED") return;
    const d = position.distanceTo(this.position);
    if (d > radius) return;
    if (this.state === "PURSUE") {
      // Footsteps on the stairs keep a pursuer on the trail out of sight.
      if (source === "player" && Math.abs(position.y - this.position.y) <= 6) this.investigateTarget.copy(position);
      return;
    }
    if (Math.abs(position.y - this.position.y) > 3) return;
    this.investigateTarget.copy(position);
    this.beginSearch("INVESTIGATE", 5);
  }

  private beginSearch(state: "INVESTIGATE" | "SEARCH", seconds: number): void {
    if (this.state !== state) this.clearPath();
    this.state = state;
    this.investigateTimer = seconds;
    this.giveUp = 0;
  }

  private endSearch(): void {
    this.state = "PATROL";
    this.clearPath();
  }

  /** Current route (debug overlay). */
  get route(): readonly NavWaypoint[] {
    return this.path.slice(this.pathIndex);
  }

  private world: GuardWorld | null = null;
  private steerSide = 1;

  /**
   * Feeler steering: if the straight line is blocked at knee/waist height,
   * try progressively wider angles (alternating sides) and take the first
   * clear one. Cheap BVH rays; enough to round benches, tables and corners.
   */
  private steer(dir: Vector3, reach: number, w: GuardWorld): Vector3 {
    const origin = this.position.clone().add(new Vector3(0, 0.45, 0));
    const probe = (d: Vector3) => {
      const side = new Vector3(-d.z, 0, d.x).multiplyScalar(0.3);
      const end = origin.clone().addScaledVector(d, reach + 0.35);
      return !w.segmentBlocked(origin, end) && !w.segmentBlocked(origin.clone().add(side), end.clone().add(side)) && !w.segmentBlocked(origin.clone().sub(side), end.clone().sub(side));
    };
    if (probe(dir)) return dir;
    for (const a of [30, 55, 80, 110]) {
      for (const s of [this.steerSide, -this.steerSide]) {
        const d = dir.clone().applyAxisAngle(new Vector3(0, 1, 0), (s * a * Math.PI) / 180);
        if (probe(d)) {
          this.steerSide = s;
          return d;
        }
      }
    }
    return dir;
  }

  update(dt: number, w: GuardWorld): void {
    this.world = w;
    const p = w.player;
    if (this.state === "STUNNED") {
      this.canSeePlayer = false;
      this.visual.update(dt);
      this.syncVisual();
      return;
    }
    this.canSeePlayer = !w.devInvisible && this.checkVisible(w);
    if (this.canSeePlayer) {
      // A clearly visible firearm is an immediate high-threat identification.
      if (w.firearmVisible()) w.suspicion.addSuspicion(100);
      else w.suspicion.addSuspicion(this.detectionRate(w) * dt);
      this.investigateTarget.copy(p.position);
      this.lostTimer = 0;
    }
    const alert = w.suspicion.state === "ALERT";
    const searching = w.suspicion.state === "SEARCHING";
    if (alert && (this.canSeePlayer || this.position.distanceTo(p.position) < 28)) {
      if (this.state !== "PURSUE") {
        this.clearPath();
        // Joining on the alert call without sight: head for where Parth was reported.
        if (!this.canSeePlayer) {
          this.investigateTarget.copy(p.position);
          this.lostTimer = 0;
        }
      }
      this.state = "PURSUE";
    } else if (this.state === "PURSUE" && !alert) {
      this.beginSearch("SEARCH", 6);
    } else if (searching && this.canSeePlayer && this.state !== "PURSUE") {
      this.beginSearch("SEARCH", 6);
    }

    let speed = 0;
    let running = false;
    switch (this.state) {
      case "PATROL":
      case "WAIT":
        speed = this.updatePatrol(dt, w);
        break;
      case "INVESTIGATE":
      case "SEARCH": {
        speed = this.state === "SEARCH" ? this.patrolSpeed * 1.35 : this.patrolSpeed;
        if (this.navigate(this.investigateTarget, speed, dt, w, 1.6, 2.5)) {
          this.brake(dt);
          this.yaw += Math.sin(performance.now() / 600) * dt * 1.2;
          this.investigateTimer -= dt;
          if (this.investigateTimer <= 0) this.endSearch();
        } else if (this.path.length === 0 || this.stuckTimer > 0.5) {
          // No route (or wedged) for a while: give up and walk back to the patrol.
          if ((this.giveUp += dt) > 10) this.endSearch();
        }
        break;
      }
      case "PURSUE": {
        // Sight, or a few seconds of memory after losing it (running footsteps,
        // the alert call), keeps the target on Parth; then the last known spot.
        if (this.canSeePlayer || this.lostTimer < this.trackSeconds) this.investigateTarget.copy(p.position);
        const target = this.investigateTarget;
        speed = this.pursuitSpeed;
        running = true;
        this.directCheck -= dt;
        if (this.directCheck <= 0) {
          this.directCheck = 0.2;
          this.direct = !w.nav || w.nav.walkable(this.position, target);
        }
        if (this.direct) {
          this.clearPath();
          const flat = target.clone().sub(this.position).setY(0);
          if (flat.length() > 0.9) this.moveToward(flat, speed, dt, w);
          else this.brake(dt);
        } else if (this.navigate(target, speed, dt, w, 0.9, 0.6)) {
          this.brake(dt);
        }
        if (!this.canSeePlayer) this.lostTimer += dt;
        break;
      }
      default:
        this.brake(dt);
    }
    this.applyMovement(dt);

    if (!this.caughtOnce && alert && this.position.distanceTo(p.position) <= this.catchDistance && this.hasLineOfSight(w)) {
      this.caughtOnce = true;
      w.onCaught(this);
    }
    const horizontal = Math.hypot(this.velocity.x, this.velocity.z);
    this.visual.locomote(horizontal, running, alert && this.canSeePlayer && this.position.distanceTo(p.position) < 6);
    this.visual.update(dt);
    this.syncVisual();
    const color = this.canSeePlayer ? 0xf21f14 : alert ? 0xff7a1a : 0x26bf73;
    this.coneMat.color.set(color);
    this.coneMat.opacity = this.canSeePlayer ? 0.18 : 0.1;
  }

  private updatePatrol(dt: number, w: GuardWorld): number {
    if (this.patrol.length < 2) {
      // A post rather than a route: walk back to it after a chase, then hold.
      if (this.navigate(this.home, this.patrolSpeed, dt, w, 0.55, 8)) {
        this.brake(dt);
        return 0;
      }
      return this.patrolSpeed;
    }
    const target = this.patrol[this.patrolIndex];
    const flat = target.clone().sub(this.position);
    const dy = Math.abs(flat.y);
    flat.setY(0);
    if (flat.length() < 0.55 && dy < 1.5) {
      this.velocity.x = 0;
      this.velocity.z = 0;
      this.clearPath();
      this.state = "WAIT";
      this.waitTimer += dt;
      if (this.waitTimer >= this.waitAtPoint) {
        this.waitTimer = 0;
        this.patrolIndex = (this.patrolIndex + 1) % this.patrol.length;
        this.state = "PATROL";
      }
      return 0;
    }
    this.state = "PATROL";
    // Patrol points can sit on different storeys or in different buildings.
    this.navigate(target, this.patrolSpeed, dt, w, 0.4, 8);
    return this.patrolSpeed;
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  private clearPath(): void {
    this.path = [];
    this.pathIndex = 0;
    this.pathRetry = 0;
  }

  /**
   * Walks toward `goal` along the nav graph, replanning when the goal moves,
   * the route ages past `replan` seconds or the guard gets stuck. Without a
   * graph or a route it steers straight at the goal. True once within `arrive`.
   */
  private navigate(goal: Vector3, speed: number, dt: number, w: GuardWorld, arrive: number, replan: number): boolean {
    const off = goal.clone().sub(this.position);
    const dy = Math.abs(off.y);
    off.setY(0);
    if (off.length() < arrive && dy < 1.4) {
      this.clearPath();
      return true;
    }
    const nav = w.nav;
    if (!nav) {
      this.moveToward(off, speed, dt, w);
      return false;
    }
    this.pathAge += dt;
    this.pathRetry -= dt;
    const stale = this.path.length > 0 && this.pathAge > 0.25 && (this.pathGoal.distanceToSquared(goal) > 1 || this.pathAge > replan || this.stuckTimer > 1);
    if (stale || (this.path.length === 0 && this.pathRetry <= 0)) this.plan(goal, nav);
    if (this.path.length === 0) {
      this.moveToward(off, speed, dt, w);
      return false;
    }
    this.followPath(speed, dt, w, nav);
    return false;
  }

  private plan(goal: Vector3, nav: NavGraph): void {
    this.pathGoal.copy(goal);
    this.pathAge = 0;
    const path = nav.findPath(this.position, goal);
    this.path = path ?? [];
    this.pathIndex = 0;
    this.lookahead = 0;
    // An unreachable goal is retried at most once a second.
    if (!path) this.pathRetry = 1;
  }

  private followPath(speed: number, dt: number, w: GuardWorld, nav: NavGraph): void {
    const path = this.path;
    // String pulling: aim at the furthest of the next few waypoints that is
    // straight-line walkable, but never skip a door or a change of storey.
    this.lookahead -= dt;
    if (this.lookahead <= 0) {
      this.lookahead = 0.15;
      let limit = this.pathIndex;
      for (let k = this.pathIndex; k < Math.min(path.length, this.pathIndex + 5); k++) {
        if (path[k].door || Math.abs(path[k].p.y - this.position.y) > 0.5) break;
        limit = k;
      }
      for (let j = limit; j > this.pathIndex; j--) {
        if (nav.walkable(this.position, path[j].p)) {
          this.pathIndex = j;
          break;
        }
      }
    }
    while (this.pathIndex < path.length && this.reached(this.pathIndex)) this.pathIndex++;
    if (this.pathIndex >= path.length) {
      this.clearPath();
      this.brake(dt);
      return;
    }
    // Staff carry keys: open doors on the next legs as the guard closes in.
    for (let k = this.pathIndex; k < Math.min(path.length, this.pathIndex + 2); k++) {
      const door = path[k].door;
      if (door && !door.isOpen && !door.isMoving && door.position.distanceToSquared(this.position) < 9) w.openDoor(door);
    }
    const wp = path[this.pathIndex].p;
    const off = wp.clone().sub(this.position);
    // Feelers are for furniture on the flat; on a flight they'd catch the slab edges.
    const flat = Math.abs(off.y) < 0.3;
    off.setY(0);
    this.moveToward(off, speed, dt, w, flat);
  }

  /** At (or already past, along the next leg) waypoint i on the guard's storey. */
  private reached(i: number): boolean {
    const p = this.path[i].p;
    if (Math.abs(p.y - this.position.y) > 1.3) return false;
    const dx = p.x - this.position.x;
    const dz = p.z - this.position.z;
    const d2 = dx * dx + dz * dz;
    const last = i === this.path.length - 1;
    if (d2 < (last ? 0.12 : 0.36)) return true;
    if (last || d2 > 4) return false;
    const n = this.path[i + 1].p;
    return (this.position.x - p.x) * (n.x - p.x) + (this.position.z - p.z) * (n.z - p.z) > 0;
  }

  private moveToward(offset: Vector3, speed: number, dt: number, w: GuardWorld | null, feelers = true): void {
    if (offset.lengthSq() < 0.001) return;
    let dir = offset.clone().normalize();
    if (this.world && feelers) dir = this.steer(dir, Math.min(1.3, offset.length()), this.world);
    this.velocity.x = moveToward(this.velocity.x, dir.x * speed, dt * 10);
    this.velocity.z = moveToward(this.velocity.z, dir.z * speed, dt * 10);
    this.yaw = lerpAngle(this.yaw, Math.atan2(-dir.x, -dir.z), Math.min(1, dt * 7));
    if (w && this.stuckTimer > 0.4) w.openDoorNear(this.position, dir);
  }

  private brake(dt: number): void {
    this.velocity.x = moveToward(this.velocity.x, 0, dt * 8);
    this.velocity.z = moveToward(this.velocity.z, 0, dt * 8);
  }

  private applyMovement(dt: number): void {
    this.velocity.y = this.grounded ? -1 : this.velocity.y - 18 * dt;
    const desired = { x: this.velocity.x * dt, y: this.velocity.y * dt, z: this.velocity.z * dt };
    this.controller.computeColliderMovement(this.collider, desired, RAPIER.QueryFilterFlags.EXCLUDE_SENSORS, groups(Layer.GUARD, Layer.STATIC | Layer.DOOR | Layer.PLAYER));
    const m = this.controller.computedMovement();
    this.grounded = this.controller.computedGrounded();
    const want = Math.hypot(desired.x, desired.z);
    const got = Math.hypot(m.x, m.z);
    this.stuckTimer = want > 0.001 && got < want * 0.3 ? this.stuckTimer + dt : 0;
    this.position.x += m.x;
    this.position.y += m.y;
    this.position.z += m.z;
    if (this.position.y < -30) this.reset();
    this.syncCollider();
  }

  private syncCollider(): void {
    this.collider.setTranslation({ x: this.position.x, y: this.position.y + 0.92, z: this.position.z });
  }

  private syncVisual(): void {
    this.visual.root.position.copy(this.position);
    // The GLB faces +Z; Godot guards face -Z.
    this.visual.root.rotation.y = this.yaw + Math.PI;
    this.cone.position.copy(this.position);
    this.cone.rotation.y = this.yaw;
  }

  /** Range → field of view → physics ray (guard.gd _check_player_visible). */
  private checkVisible(w: GuardWorld): boolean {
    const p = w.player;
    if (!p.controlEnabled && p.noclip) return false;
    const eye = this.eye;
    const target = this.targetPoint(p);
    const offset = target.clone().sub(eye);
    const distance = offset.length();
    if (distance > this.viewDistance || distance < 0.01) return false;
    const angle = (this.forward.angleTo(offset.clone().setY(offset.y * 0.35).normalize()) * 180) / Math.PI;
    if (angle > this.fov / 2) return false;
    return !w.segmentBlocked(eye, target);
  }

  private hasLineOfSight(w: GuardWorld): boolean {
    return !w.segmentBlocked(this.eye, this.targetPoint(w.player));
  }

  private targetPoint(p: Player): Vector3 {
    return p.position.clone().add(new Vector3(0, p.isCrouching ? 0.75 : 1.35, 0));
  }

  private detectionRate(w: GuardWorld): number {
    const p = w.player;
    const distance = this.position.distanceTo(p.position);
    const proximity = 3.0 + (0.75 - 3.0) * Math.min(1, Math.max(0, distance / this.viewDistance));
    const movement = p.isSprinting ? 1.85 : p.isCrouching ? 0.42 : 1;
    return this.suspicionPerSecond * proximity * movement * p.restrictedMultiplier * w.visibilityFactor();
  }

  private buildCone(): BufferGeometry {
    const half = ((this.fov / 2) * Math.PI) / 180;
    const segs = 18;
    const pos: number[] = [];
    for (let i = 0; i < segs; i++) {
      const a0 = -half + (2 * half * i) / segs;
      const a1 = -half + (2 * half * (i + 1)) / segs;
      pos.push(0, 0.08, 0, Math.sin(a0) * this.viewDistance, 0.08, -Math.cos(a0) * this.viewDistance, Math.sin(a1) * this.viewDistance, 0.08, -Math.cos(a1) * this.viewDistance);
    }
    const g = new BufferGeometry();
    g.setAttribute("position", new Float32BufferAttribute(pos, 3));
    return g;
  }
}
