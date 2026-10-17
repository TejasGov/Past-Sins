import { Vector3 } from "three";
import type { Player } from "./player";

/**
 * Port of scripts/player/camera_motion.gd: walking bob + footfall micro jitter
 * layered on the camera only (never the aim ray). Values are the Godot exports.
 */
export class CameraMotion {
  enabled = true;
  verticalAmplitude = 0.024;
  horizontalAmplitude = 0.013;
  metersPerBobCycle = 2.0;
  sprintMultiplier = 1.45;
  crouchMultiplier = 0.45;
  easeSeconds = 0.22;
  jitterPositionAmplitude = 0.0015;
  jitterRotationDegrees = 0.045;
  jitterFrequency = 17;
  /** 0..1, raised by ADS so precision aiming suppresses motion. */
  precision = 0;
  readonly positionOffset = new Vector3();
  readonly rotationOffset = new Vector3();
  private phase = 0;
  private noiseTime = 0;
  private weight = 0;

  private noise(t: number): number {
    // Smooth 1D value noise in [-1, 1] (stands in for FastNoiseLite simplex).
    const i = Math.floor(t);
    const f = t - i;
    const h = (n: number) => {
      const x = Math.sin(n * 127.1 + 1731 * 0.13) * 43758.5453;
      return (x - Math.floor(x)) * 2 - 1;
    };
    const u = f * f * (3 - 2 * f);
    return h(i) * (1 - u) + h(i + 1) * u;
  }

  update(player: Player, delta: number): void {
    const speed = Math.hypot(player.velocity.x, player.velocity.z);
    const allowed = this.enabled && player.controlEnabled && player.grounded && !player.inWater && !player.noclip;
    const ratio = Math.min(1.8, Math.max(0, speed / Math.max(player.t.walkSpeed, 0.1)));
    const stance = player.isCrouching ? this.crouchMultiplier : player.isSprinting ? this.sprintMultiplier : 1;
    const target = allowed && speed > 0.06 ? ratio * stance * (1 - this.precision) : 0;
    const dt = Math.min(delta, 0.1);
    this.weight += (target - this.weight) * (1 - Math.exp((-3 * dt) / this.easeSeconds));
    if (this.weight < 0.0005) this.weight = 0;
    if (allowed && speed > 0.06) {
      this.phase = (this.phase + (speed * Math.PI * 2 * dt) / this.metersPerBobCycle) % (Math.PI * 4);
      this.noiseTime = (this.noiseTime + dt * this.jitterFrequency) % 10000;
    }
    const jx = this.noise(this.noiseTime);
    const jy = this.noise(this.noiseTime + 53);
    const jz = this.noise(this.noiseTime + 107);
    this.positionOffset
      .set(Math.sin(this.phase * 0.5) * this.horizontalAmplitude, Math.sin(this.phase) * this.verticalAmplitude, 0)
      .add(new Vector3(jx, jy, 0).multiplyScalar(this.jitterPositionAmplitude))
      .multiplyScalar(this.weight);
    const rad = (this.jitterRotationDegrees * Math.PI) / 180;
    this.rotationOffset.set(jy * 0.5, jx * 0.35, jz).multiplyScalar(rad * this.weight);
  }

  reset(): void {
    this.weight = 0;
    this.phase = 0;
    this.noiseTime = 0;
    this.positionOffset.set(0, 0, 0);
    this.rotationOffset.set(0, 0, 0);
  }
}
