import { Color, MathUtils, Vector3 } from "three";
import type { EnvironmentCycle } from "../systems/environment";
import type { RenderStack } from "./renderer";
import type { LightPool } from "./lightPool";
import { sharedUniforms, type MaterialLibrary } from "./materials";

const RAIN_TOP = new Color(0x313a43);
const RAIN_HORIZON = new Color(0x56616a);
const MOON = new Color(0x8ea8d8);
const INDOOR_FOG = new Color(0x1a1d1c);
const DUSK_TEAL = new Color(0x3c5560);

/**
 * Applies the environment cycle to the renderer every frame: sun/moon through
 * the CSM cascades, sky gradient, hemisphere ambient, fog, wetness and the
 * night level of fixtures. `indoor` (0..1) fades towards interior ambience.
 */
export class WorldLighting {
  indoor = 0;
  wetness = 0;
  private envTimer = 0;
  private lastEnvHour = -10;
  private lastEnvWeather = "";
  overrideFogDensity: number | null = null;

  constructor(private render: RenderStack, private cycle: EnvironmentCycle, private pool: LightPool, private materials: MaterialLibrary) {}

  update(dt: number, camera: Vector3): void {
    const c = this.cycle;
    const r = this.render;
    const s = c.skySample();
    const rainy = c.weather === "RAINY";
    const top = s.top.clone();
    const horizon = s.horizon.clone();
    if (rainy) {
      // Overcast greys only apply by day; at night the cloud deck just goes black.
      const lit = 0.12 + 0.88 * s.daylight;
      top.lerp(RAIN_TOP.clone().multiplyScalar(lit), 0.62);
      horizon.lerp(RAIN_HORIZON.clone().multiplyScalar(lit), 0.68);
    }
    // Cold teal-grey cast through dusk and dawn.
    const dusk = MathUtils.clamp(1 - Math.abs(s.daylight - 0.25) / 0.25, 0, 1);
    horizon.lerp(DUSK_TEAL, dusk * 0.35);

    const sunDir = c.sunTravelDirection();
    const daylight = s.daylight;
    const sunUp = MathUtils.smoothstep(-sunDir.y, -0.05, 0.12);
    const sunIntensity = 3.4 * daylight * (rainy ? 0.42 : 1) * sunUp;
    const moonIntensity = 0.14 * (1 - MathUtils.smoothstep(daylight, 0.04, 0.25)) * (rainy ? 0.35 : 1);
    const useMoon = moonIntensity > sunIntensity;
    const dir = useMoon ? new Vector3(0.35, -0.82, 0.45).normalize() : sunDir;
    r.csm.lightDirection.copy(dir);
    const sunColor = useMoon ? MOON : c.sunColor();
    for (const light of r.csm.lights) {
      light.intensity = useMoon ? moonIntensity : sunIntensity;
      light.color.copy(sunColor);
      light.castShadow = r.quality.shadows;
    }

    const sky = r.sky.material.uniforms;
    sky.topColor.value.copy(top);
    sky.horizonColor.value.copy(horizon);
    sky.groundColor.value.copy(top).multiplyScalar(0.28);
    sky.sunDir.value.copy(sunDir).negate();
    sky.sunColor.value.copy(c.sunColor());
    sky.sunStrength.value = MathUtils.clamp(daylight * 1.2, 0, 1) * (rainy ? 0.15 : 1);
    sky.stars.value = MathUtils.clamp(1 - daylight * 6, 0, 1) * (rainy ? 0.1 : 1);
    sky.cloudCover.value = rainy ? 0.92 : 0.42;
    sky.cloudDark.value = rainy ? 0.75 : 0.15;
    sky.time.value += dt;
    sky.fogColor.value.copy(horizon);
    sky.haze.value = rainy ? 0.75 : 0.4;

    const indoor = this.indoor;
    const ambientSky = horizon.clone().lerp(new Color(0xcad1d2), 0.22);
    const outdoorAmbient = MathUtils.lerp(0.025, 0.42, daylight) * (rainy ? 0.95 : 1);
    r.hemi.color.copy(ambientSky);
    r.hemi.groundColor.copy(new Color(0x2a2824)).lerp(ambientSky, 0.15);
    r.hemi.intensity = MathUtils.lerp(outdoorAmbient, outdoorAmbient * 0.25 + 0.03, indoor);
    r.ambient.intensity = MathUtils.lerp(0.015, 0.05, indoor);
    r.scene.environmentIntensity = MathUtils.lerp(MathUtils.lerp(0.04, 0.5, daylight), 0.12, indoor);

    const fogOut = horizon.clone().multiplyScalar((rainy ? 0.85 : 0.95) * (0.35 + 0.65 * daylight));
    r.fog.color.copy(fogOut).lerp(INDOOR_FOG.clone().lerp(fogOut, 0.15), indoor);
    // Heavy haze at dawn/dusk/night and in rain; clearer at midday.
    const outDensity = rainy ? 0.024 : 0.0055 + (1 - daylight) * 0.009 + dusk * 0.006;
    r.fog.density = this.overrideFogDensity ?? MathUtils.lerp(outDensity, 0.012, indoor);

    const night = c.nightLevel();
    this.pool.nightLevel = night;
    this.materials.setNightLevel(MathUtils.lerp(this.pool.interiorDayLevel, 1, night));

    const targetWet = rainy ? 1 : 0;
    this.wetness = MathUtils.lerp(this.wetness, targetWet, 1 - Math.exp(-dt / (rainy ? 25 : 90)));
    sharedUniforms.uWetness.value = this.wetness;
    sharedUniforms.uTime.value += dt;

    // Simple scene-adaptive exposure (feeds AgX via toneMappingExposure).
    const outdoorExposure = MathUtils.lerp(1.15, 0.82, daylight);
    const targetExposure = MathUtils.lerp(outdoorExposure, 0.95, indoor);
    r.renderer.toneMappingExposure += (targetExposure - r.renderer.toneMappingExposure) * (1 - Math.exp(-dt * 2));
    r.grade.set("exposureLift", 0.002 * (1 - daylight));
    void camera;

    this.envTimer -= dt;
    if (this.envTimer <= 0 && (Math.abs(c.timeHours - this.lastEnvHour) > 0.35 || c.weather !== this.lastEnvWeather)) {
      this.envTimer = 2;
      this.lastEnvHour = c.timeHours;
      this.lastEnvWeather = c.weather;
      r.refreshEnvironment();
    }
  }
}
