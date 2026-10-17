import type { Vector3 } from "three";
import { Emitter } from "../core/events";

export interface NoiseEvent {
  position: Vector3;
  /** 0..1, normalized loudness. */
  intensity: number;
  surface: string;
  /** World radius at which a guard hears it (intensity × base radius). */
  radius: number;
  source?: string;
}

export interface WeaponNoiseEvent {
  origin: Vector3;
  weaponId: string;
  suppressed: boolean;
  baseRadius: number;
  effectiveRadius: number;
}

export type NoiseEvents = {
  noise_emitted: NoiseEvent;
  weapon_noise_emitted: WeaponNoiseEvent;
};

/** Port of scripts/systems/world_noise_system.gd. */
export class WorldNoiseSystem {
  readonly events = new Emitter<NoiseEvents>();
  /** Radius in metres of an intensity-1 noise. */
  baseRadius = 18;

  emitNoise(position: Vector3, intensity: number, surface = "CONCRETE", source?: string): void {
    const i = Math.min(1, Math.max(0, intensity));
    this.events.emit("noise_emitted", { position: position.clone(), intensity: i, surface, radius: i * this.baseRadius, source });
  }

  emitWeaponNoise(origin: Vector3, weaponId: string, baseRadius: number, effectiveRadius: number, suppressed: boolean): void {
    const base = Math.max(1, baseRadius);
    const radius = Math.min(base, Math.max(0, effectiveRadius));
    this.events.emit("weapon_noise_emitted", { origin: origin.clone(), weaponId, suppressed, baseRadius: base, effectiveRadius: radius });
    this.events.emit("noise_emitted", { position: origin.clone(), intensity: radius / base, surface: "WEAPON", radius, source: weaponId });
  }
}
