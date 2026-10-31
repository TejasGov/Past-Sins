import { MathUtils, PerspectiveCamera, Vector3 } from "three";
import { GUARD_GROUPS, Layer, PLAYER_GROUPS, RAPIER, groups, type Physics } from "../physics/physics";
import type { Input } from "../core/input";
import { Emitter } from "../core/events";
import { CameraMotion } from "./cameraMotion";

/** Values from scripts/player/player.gd (exported defaults). */
export const PLAYER_TUNING = {
  walkSpeed: 4.2,
  sprintSpeed: 7.0,
  crouchSpeed: 2.1,
  jumpVelocity: 5.4,
  acceleration: 18,
  airAcceleration: 5,
  standingHeight: 1.8,
  crouchedHeight: 1.1,
  standingCameraHeight: 0.72,
  crouchedCameraHeight: 0.04,
  colliderTransitionSpeed: 4,
  cameraTransitionSpeed: 3.2,
  clearanceMargin: 0.02,
  mouseSensitivity: 0.0022,
  verticalLookLimit: 85,
  interactionDistance: 3.2,
  radius: 0.35,
  gravity: 18,
};

export type PlayerEvents = {
  movement_state_changed: { sprinting: boolean; crouching: boolean };
  footstep: { position: Vector3; intensity: number };
  landed: { position: Vector3; speed: number };
};

function moveToward(from: number, to: number, delta: number): number {
  return Math.abs(to - from) <= delta ? to : from + Math.sign(to - from) * delta;
}

/** Optional water motor (PlayerSwimming); returns true when it handled movement. */
export interface WaterMotor {
  update(player: Player, dt: number): boolean;
}

/**
 * First-person kinematic controller. `position` is the FEET position; the
 * capsule keeps its base fixed while its height animates between stances.
 */
export class Player {
  readonly t = PLAYER_TUNING;
  readonly events = new Emitter<PlayerEvents>();
  readonly position = new Vector3();
  readonly velocity = new Vector3();
  yaw = 0;
  pitch = 0;
  controlEnabled = true;
  isSprinting = false;
  isCrouching = false;
  grounded = false;
  height = PLAYER_TUNING.standingHeight;
  headY = PLAYER_TUNING.standingCameraHeight;
  restrictedMultiplier = 1;
  noclip = false;
  waterMotor: WaterMotor | null = null;
  inWater = false;
  readonly collider: RAPIER.Collider;
  private controller: RAPIER.KinematicCharacterController;
  private failureLocked = false;
  private stride = 0;
  private airTime = 0;
  private restrictedZones = new Map<string, number>();
  readonly motion = new CameraMotion();

  constructor(private physics: Physics, private input: Input, readonly camera: PerspectiveCamera) {
    const t = this.t;
    const body = physics.world.createRigidBody(RAPIER.RigidBodyDesc.kinematicPositionBased());
    this.collider = physics.world.createCollider(
      RAPIER.ColliderDesc.capsule((t.standingHeight - 2 * t.radius) / 2, t.radius).setCollisionGroups(PLAYER_GROUPS),
      body,
    );
    this.controller = physics.world.createCharacterController(0.02);
    this.controller.enableAutostep(0.32, 0.18, false);
    this.controller.enableSnapToGround(0.35);
    this.controller.setMaxSlopeClimbAngle(MathUtils.degToRad(52));
    this.controller.setMinSlopeSlideAngle(MathUtils.degToRad(40));
    this.controller.setSlideEnabled(true);
    this.controller.setApplyImpulsesToDynamicBodies(false);
  }

  /** Feet position + facing; Godot spawn markers store the capsule centre. */
  teleport(feet: Vector3, yaw?: number, pitch = 0): void {
    this.position.copy(feet);
    this.velocity.set(0, 0, 0);
    if (yaw !== undefined) this.yaw = yaw;
    this.pitch = pitch;
    this.syncCollider();
  }

  get eyePosition(): Vector3 {
    return new Vector3(this.position.x, this.position.y + this.t.standingHeight / 2 + this.headY, this.position.z);
  }

  /** Capsule centre in world space (Godot's CharacterBody3D origin when standing). */
  get center(): Vector3 {
    return new Vector3(this.position.x, this.position.y + this.height / 2, this.position.z);
  }

  setControlEnabled(enabled: boolean): void {
    this.controlEnabled = enabled && !this.failureLocked;
    if (!this.controlEnabled) this.isSprinting = false;
  }

  unlockFailure(): void {
    this.failureLocked = false;
    this.setControlEnabled(true);
  }

  setFailureLocked(): void {
    this.failureLocked = true;
    this.setControlEnabled(false);
  }

  enterRestrictedZone(id: string, multiplier: number): void {
    this.restrictedZones.set(id, Math.max(1, multiplier));
    this.recalculateRestricted();
  }

  exitRestrictedZone(id: string): void {
    this.restrictedZones.delete(id);
    this.recalculateRestricted();
  }

  private recalculateRestricted(): void {
    this.restrictedMultiplier = Math.max(1, ...this.restrictedZones.values());
  }

  private syncCollider(): void {
    this.collider.setTranslation({ x: this.position.x, y: this.position.y + this.height / 2, z: this.position.z });
  }

  look(dt: number): void {
    if (!this.controlEnabled) return;
    const s = this.t.mouseSensitivity;
    this.yaw -= this.input.mouseDX * s;
    this.pitch -= this.input.mouseDY * s;
    const limit = MathUtils.degToRad(this.t.verticalLookLimit);
    this.pitch = MathUtils.clamp(this.pitch, -limit, limit);
    void dt;
  }

  /** Movement vector from WASD in local space (x right, y back). */
  inputVector(): { x: number; y: number } {
    if (!this.controlEnabled) return { x: 0, y: 0 };
    let x = 0;
    let y = 0;
    if (this.input.isDown("KeyA")) x -= 1;
    if (this.input.isDown("KeyD")) x += 1;
    if (this.input.isDown("KeyW")) y -= 1;
    if (this.input.isDown("KeyS")) y += 1;
    const len = Math.hypot(x, y);
    return len > 1 ? { x: x / len, y: y / len } : { x, y };
  }

  /** World-space horizontal direction for a local input vector. */
  worldDirection(v: { x: number; y: number }): Vector3 {
    const c = Math.cos(this.yaw);
    const s = Math.sin(this.yaw);
    return new Vector3(c * v.x + s * v.y, 0, -s * v.x + c * v.y);
  }

  update(dt: number): void {
    const t = this.t;
    this.look(dt);
    const wasSprinting = this.isSprinting;
    const wasCrouching = this.isCrouching;

    if (this.noclip) {
      this.updateNoclip(dt);
      return;
    }

    if (this.waterMotor && this.waterMotor.update(this, dt)) {
      this.inWater = true;
      if (wasSprinting !== this.isSprinting || wasCrouching !== this.isCrouching) {
        this.events.emit("movement_state_changed", { sprinting: this.isSprinting, crouching: this.isCrouching });
      }
      return;
    }
    this.inWater = false;

    if (!this.controlEnabled) {
      this.velocity.x = moveToward(this.velocity.x, 0, t.acceleration * dt);
      this.velocity.z = moveToward(this.velocity.z, 0, t.acceleration * dt);
      this.velocity.y = this.grounded ? -1 : this.velocity.y - t.gravity * dt;
      this.move(dt);
      return;
    }

    const inputVector = this.inputVector();
    const wantsCrouch = this.input.isDown("KeyC") || this.input.isDown("ControlLeft");
    if (wantsCrouch) {
      this.isCrouching = true;
    } else {
      const transitioning = this.height < t.standingHeight - 0.001;
      this.isCrouching = transitioning && !this.canStand();
    }
    const moving = inputVector.x * inputVector.x + inputVector.y * inputVector.y > 0.01;
    this.isSprinting = (this.input.isDown("ShiftLeft") || this.input.isDown("ShiftRight")) && !this.isCrouching && moving;
    this.updateCrouch(dt);
    if (wasSprinting !== this.isSprinting || wasCrouching !== this.isCrouching) {
      this.events.emit("movement_state_changed", { sprinting: this.isSprinting, crouching: this.isCrouching });
    }

    if (!this.grounded) this.velocity.y -= t.gravity * dt;
    else if (this.input.justPressed("Space") && !this.isCrouching) this.velocity.y = t.jumpVelocity;
    else this.velocity.y = -1.0; // keeps snap-to-ground engaged on ramps

    const direction = this.worldDirection(inputVector);
    const speed = this.isCrouching ? t.crouchSpeed : this.isSprinting ? t.sprintSpeed : t.walkSpeed;
    const accel = this.grounded ? t.acceleration : t.airAcceleration;
    this.velocity.x = moveToward(this.velocity.x, direction.x * speed, accel * dt);
    this.velocity.z = moveToward(this.velocity.z, direction.z * speed, accel * dt);
    this.move(dt);
    this.updateFootsteps(dt);
  }

  /** Runs the KCC for the current velocity; updates position/grounded. */
  move(dt: number, filterMask = Layer.STATIC | Layer.DOOR): void {
    const desired = { x: this.velocity.x * dt, y: this.velocity.y * dt, z: this.velocity.z * dt };
    this.controller.computeColliderMovement(this.collider, desired, RAPIER.QueryFilterFlags.EXCLUDE_SENSORS, groups(Layer.PLAYER, filterMask));
    const m = this.controller.computedMovement();
    const wasGrounded = this.grounded;
    this.grounded = this.controller.computedGrounded();
    const fallSpeed = -this.velocity.y;
    this.position.x += m.x;
    this.position.y += m.y;
    this.position.z += m.z;
    // Blocked horizontally → drop velocity on that axis (Godot move_and_slide).
    if (dt > 0) {
      if (Math.abs(m.x) < Math.abs(desired.x) * 0.5) this.velocity.x = m.x / dt;
      if (Math.abs(m.z) < Math.abs(desired.z) * 0.5) this.velocity.z = m.z / dt;
      if (this.velocity.y > 0 && m.y < desired.y * 0.5) this.velocity.y = 0; // head bump
    }
    if (this.grounded && !wasGrounded && this.airTime > 0.25) {
      this.events.emit("landed", { position: this.position.clone(), speed: fallSpeed });
    }
    this.airTime = this.grounded ? 0 : this.airTime + dt;
    this.syncCollider();
  }

  private updateNoclip(dt: number): void {
    const v = this.inputVector();
    const fwd = new Vector3(0, 0, -1).applyAxisAngle(new Vector3(1, 0, 0), this.pitch).applyAxisAngle(new Vector3(0, 1, 0), this.yaw);
    const right = new Vector3(1, 0, 0).applyAxisAngle(new Vector3(0, 1, 0), this.yaw);
    const speed = this.input.isDown("ShiftLeft") ? 22 : 9;
    const delta = fwd.multiplyScalar(-v.y).add(right.multiplyScalar(v.x));
    if (this.input.isDown("Space")) delta.y += 1;
    if (this.input.isDown("KeyC")) delta.y -= 1;
    this.position.addScaledVector(delta, speed * dt);
    this.velocity.set(0, 0, 0);
    this.syncCollider();
  }

  updateCrouch(dt: number): void {
    const t = this.t;
    const target = this.isCrouching ? t.crouchedHeight : t.standingHeight;
    const next = moveToward(this.height, target, dt * t.colliderTransitionSpeed);
    if (next !== this.height) {
      this.height = next;
      this.collider.setHalfHeight((next - 2 * t.radius) / 2);
      this.syncCollider();
    }
    const headTarget = this.isCrouching ? t.crouchedCameraHeight : t.standingCameraHeight;
    this.headY = moveToward(this.headY, headTarget, dt * t.cameraTransitionSpeed);
  }

  /** Godot `_can_stand`: sweep only the extra headroom above the crouched capsule. */
  canStand(): boolean {
    const t = this.t;
    if (this.height >= t.standingHeight - 0.001) return true;
    const r = t.radius - t.clearanceMargin;
    const from = this.position.y + this.height - t.radius;
    const to = this.position.y + t.standingHeight - t.radius;
    const shape = new RAPIER.Ball(r);
    const hit = this.physics.world.castShape(
      { x: this.position.x, y: from, z: this.position.z },
      { x: 0, y: 0, z: 0, w: 1 },
      { x: 0, y: to - from, z: 0 },
      shape,
      0,
      1,
      true,
      RAPIER.QueryFilterFlags.EXCLUDE_SENSORS,
      groups(Layer.PLAYER, Layer.STATIC | Layer.DOOR),
      this.collider,
    );
    return hit === null;
  }

  private updateFootsteps(dt: number): void {
    if (!this.grounded) return;
    const speed = Math.hypot(this.velocity.x, this.velocity.z);
    if (speed < 0.5) return;
    this.stride += speed * dt;
    const strideLength = this.isSprinting ? 2.1 : this.isCrouching ? 1.1 : 1.6;
    if (this.stride >= strideLength) {
      this.stride = 0;
      const intensity = this.isSprinting ? 0.85 : this.isCrouching ? 0.06 : 0.3;
      this.events.emit("footstep", { position: this.position.clone(), intensity });
    }
  }

  /** Applies yaw/pitch + head height + camera motion to the camera. */
  updateCamera(dt: number): void {
    const eye = this.eyePosition;
    this.motion.update(this, dt);
    this.camera.position.copy(eye);
    const c = Math.cos(this.yaw);
    const s = Math.sin(this.yaw);
    const off = this.motion.positionOffset;
    this.camera.position.x += c * off.x + s * off.z;
    this.camera.position.y += off.y;
    this.camera.position.z += -s * off.x + c * off.z;
    this.camera.rotation.set(this.pitch + this.motion.rotationOffset.x, this.yaw + this.motion.rotationOffset.y, this.motion.rotationOffset.z, "YXZ");
  }
}

export { GUARD_GROUPS };
