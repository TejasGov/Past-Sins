import { Color, PointLight, type Scene, Vector3 } from "three";
import type { Fixture } from "../world/builder";

interface Slot {
  light: PointLight;
  fixture: Fixture | null;
  fade: number;
}

/**
 * Godot had one unshadowed omni per storey plus emissive diffusers. Here every
 * fixture (gallery tubes, cell lamps, sodium wall packs) is a candidate, and a
 * fixed pool of point lights is re-assigned to the nearest live fixtures a few
 * times a second, so the forward shader cost stays constant.
 */
export class LightPool {
  private slots: Slot[] = [];
  private timer = 0;
  private time = 0;
  /** 0 = day, 1 = full night (smoothed by the environment cycle). */
  nightLevel = 0;
  /** Day-time level of night-only interior fixtures (they never go fully dark inside). */
  interiorDayLevel = 0.32;
  /** Fixture intensities are authored in Godot-like energy units; this maps them to candela. */
  intensityScale = 7;
  private readonly tmp = new Vector3();

  constructor(scene: Scene, private fixtures: Fixture[], count = 12) {
    for (let i = 0; i < count; i++) {
      const light = new PointLight(0xffffff, 0, 10, 2);
      light.castShadow = false;
      // Always visible: toggling visibility changes the light count and forces
      // every material to recompile. Unused slots just sit at zero intensity.
      light.visible = true;
      scene.add(light);
      this.slots.push({ light, fixture: null, fade: 0 });
    }
  }

  levelOf(f: Fixture): number {
    if (!f.nightOnly) return 1;
    const day = f.chunk === "exterior" ? 0 : this.interiorDayLevel;
    return day + (1 - day) * this.nightLevel;
  }

  private flicker(f: Fixture, i: number): number {
    if (f.flicker <= 0) return 1;
    const t = this.time * 1.0 + i * 13.7;
    const burst = Math.sin(t * 0.7) * Math.sin(t * 1.9 + 1.3);
    if (burst > 0.82) {
      const fast = Math.sin(t * 61) * Math.sin(t * 37);
      return fast > 0.1 ? 1 : 1 - f.flicker * 0.92;
    }
    return 1 - f.flicker * 0.06 * (0.5 + 0.5 * Math.sin(t * 120));
  }

  update(dt: number, camera: Vector3): void {
    this.time += dt;
    this.timer -= dt;
    if (this.timer <= 0) {
      this.timer = 0.15;
      this.reassign(camera);
    }
    this.slots.forEach((slot, i) => {
      const f = slot.fixture;
      if (!f) {
        slot.light.intensity = 0;
        return;
      }
      slot.fade = Math.min(1, slot.fade + dt / 0.35);
      const intensity = f.intensity * this.intensityScale * this.levelOf(f) * slot.fade * this.flicker(f, i);
      slot.light.intensity = intensity;
    });
  }

  private reassign(camera: Vector3): void {
    const scored: { f: Fixture; s: number }[] = [];
    for (const f of this.fixtures) {
      if (this.levelOf(f) < 0.02) continue;
      const d = this.tmp.copy(f.position).sub(camera);
      const dy = Math.abs(d.y);
      const dist = d.length();
      if (dist > f.range + 18) continue;
      // Prefer the current storey: fixtures on other tiers count as further away.
      scored.push({ f, s: dist + (dy > 3.2 ? dy * 2.5 : 0) });
    }
    scored.sort((a, c) => a.s - c.s);
    const chosen = new Set(scored.slice(0, this.slots.length).map((x) => x.f));
    const free: Slot[] = [];
    for (const slot of this.slots) {
      if (slot.fixture && chosen.has(slot.fixture)) chosen.delete(slot.fixture);
      else free.push(slot);
    }
    for (const f of chosen) {
      const slot = free.shift();
      if (!slot) break;
      slot.fixture = f;
      slot.fade = 0;
      slot.light.position.copy(f.position);
      slot.light.color = new Color(f.color);
      slot.light.distance = f.range;
    }
    for (const slot of free) slot.fixture = null;
  }
}
