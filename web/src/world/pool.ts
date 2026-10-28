import { Color, Mesh, PlaneGeometry, ShaderMaterial, Vector3, DoubleSide, UniformsLib, UniformsUtils } from "three";
import type { Player, WaterMotor } from "../player/player";
import type { Input } from "../core/input";
import { Emitter } from "../core/events";

/** PlayerSwimming tuning (shared with level layout: the culvert spaces its air pockets in seconds of swimming). */
export const SWIM_TUNING = { swimSpeed: 2.7, verticalSpeed: 2.2, acceleration: 5 };

/** Default underwater fog (the pool's chlorinated cyan). */
const POOL_FOG = { color: 0x286374, scale: 0.35, density: 0.11 };

export interface WaterOptions {
  /** Flooded to the top of the box (culverts): no surface to float up to, neutral buoyancy. */
  ceiling?: boolean;
  /** Draw the surface plane (default: true unless `ceiling`). */
  surface?: boolean;
  /** Free-form id for story code ("pool", "culvert:tube", "culvert:pocket:0", "reservoir"…). */
  tag?: string;
  colors?: { deep?: number; shallow?: number; sky?: number };
  /** Underwater fog while the camera is in this volume (`color` before `scale`, density at full immersion). */
  fog?: { color: number; scale?: number; density: number };
  /** Open to the sky (default true); underground water never shows the sun's glint. */
  sunlit?: boolean;
}

/**
 * A body of water: an axis-aligned box whose top is the surface (port of
 * shaders/pool_water.gdshader, upgraded with fresnel, scrolling ripple normals
 * and fog). The pool is one; the culvert adds ceilinged tubes, air pockets and
 * a reservoir. `center.y` is the reference (deck) height; the bottom is
 * `center.y - depth`.
 */
export class SwimmingPool {
  readonly mesh: Mesh;
  readonly material: ShaderMaterial;
  readonly surfaceY: number;
  readonly bottomY: number;
  readonly ceiling: boolean;
  readonly tag: string;
  readonly fog: { color: Color; density: number };
  readonly sunlit: boolean;

  /** Water filling the box `min`..`max` (surface at `max.y`). */
  static box(min: Vector3, max: Vector3, opts: WaterOptions = {}): SwimmingPool {
    const center = new Vector3((min.x + max.x) / 2, max.y, (min.z + max.z) / 2);
    return new SwimmingPool(center, max.x - min.x, max.z - min.z, max.y - min.y, 0, opts);
  }

  constructor(readonly center: Vector3, readonly sizeX: number, readonly sizeZ: number, readonly depth: number, surfaceOffset: number, opts: WaterOptions = {}) {
    this.surfaceY = center.y + surfaceOffset;
    this.bottomY = center.y - depth;
    this.ceiling = opts.ceiling ?? false;
    this.tag = opts.tag ?? "pool";
    this.sunlit = opts.sunlit ?? true;
    const fog = opts.fog ?? POOL_FOG;
    this.fog = { color: new Color(fog.color).multiplyScalar(fog.scale ?? 1), density: fog.density };
    const colors = opts.colors ?? {};
    this.material = new ShaderMaterial({
      transparent: true,
      depthWrite: false,
      side: DoubleSide,
      fog: true,
      uniforms: UniformsUtils.merge([
        UniformsLib.fog,
        {
          time: { value: 0 },
          deep: { value: new Color(colors.deep ?? 0x0b3a44) },
          shallow: { value: new Color(colors.shallow ?? 0x2e8f9c) },
          sky: { value: new Color(colors.sky ?? 0x9fb4bd) },
          sunDir: { value: new Vector3(0.3, 0.8, 0.2) },
          sunColor: { value: new Color(1, 0.95, 0.85) },
          sunStrength: { value: this.sunlit ? 1 : 0 },
        },
      ]),
      vertexShader: /* glsl */ `
        #include <common>
        #include <fog_pars_vertex>
        varying vec3 vWorld;
        varying vec2 vUv;
        void main() {
          vUv = uv;
          vec4 world = modelMatrix * vec4(position, 1.0);
          vWorld = world.xyz;
          vec4 mvPosition = viewMatrix * world;
          gl_Position = projectionMatrix * mvPosition;
          #include <fog_vertex>
        }`,
      fragmentShader: /* glsl */ `
        #include <common>
        #include <fog_pars_fragment>
        uniform float time;
        uniform vec3 deep, shallow, sky, sunDir, sunColor;
        uniform float sunStrength;
        varying vec3 vWorld;
        varying vec2 vUv;
        vec2 wave(vec2 p, float t) {
          return vec2(sin(p.x * 1.7 + t * 1.3) + sin(p.y * 2.3 - t * 0.9 + p.x * 0.6), cos(p.y * 1.9 + t * 1.1) + cos(p.x * 2.6 + t * 0.7 - p.y * 0.4));
        }
        void main() {
          vec2 p = vWorld.xz;
          vec2 w = wave(p * 1.6, time) * 0.06 + wave(p * 4.1 + 3.0, time * 1.7) * 0.025;
          vec3 n = normalize(vec3(w.x, 1.0, w.y));
          vec3 v = normalize(cameraPosition - vWorld);
          bool below = cameraPosition.y < vWorld.y;
          if (below) n = -n;
          float fres = pow(1.0 - max(dot(n, v), 0.0), 4.0);
          float ripple = sin(vUv.x * 140.0 + time * 1.3) * sin(vUv.y * 90.0 - time);
          vec3 base = mix(deep, shallow, 0.55 + ripple * 0.05);
          vec3 refl = sky * (0.6 + 0.4 * sunStrength);
          vec3 h = normalize(normalize(sunDir) + v);
          float spec = pow(max(dot(n, h), 0.0), 220.0) * sunStrength * 6.0;
          vec3 col = mix(base, refl, below ? 0.15 : fres * 0.85) + sunColor * spec;
          float alpha = below ? 0.65 : mix(0.55, 0.92, fres);
          gl_FragColor = vec4(col, alpha);
          #include <fog_fragment>
        }`,
    });
    this.mesh = new Mesh(new PlaneGeometry(sizeX, sizeZ, 1, 1), this.material);
    this.mesh.rotation.x = -Math.PI / 2;
    this.mesh.position.set(center.x, this.surfaceY, center.z);
    this.mesh.renderOrder = 3;
    this.mesh.name = `Water:${this.tag}`;
    this.mesh.visible = opts.surface ?? !this.ceiling;
  }

  containsHorizontal(p: Vector3): boolean {
    return Math.abs(p.x - this.center.x) < this.sizeX / 2 && Math.abs(p.z - this.center.z) < this.sizeZ / 2;
  }

  /** Inside the box, with margins below the bottom and above the surface. */
  contains(p: Vector3, below = 0.2, above = 0.35): boolean {
    return this.containsHorizontal(p) && p.y > this.bottomY - below && p.y < this.surfaceY + above;
  }

  update(dt: number): void {
    this.material.uniforms.time.value += dt;
  }

  /** Glint strength from the sky (0 at night); ignored for underground water. */
  setSun(strength: number): void {
    if (this.sunlit) this.material.uniforms.sunStrength.value = strength;
  }
}

/** Any body of water the swim motor knows about. */
export type WaterVolume = SwimmingPool;

export type SwimEvents = { swimming_state_changed: boolean };

function moveToward(from: number, to: number, delta: number): number {
  return Math.abs(to - from) <= delta ? to : from + Math.sign(to - from) * delta;
}

/**
 * Port of scripts/player/player_swimming.gd, generalised to several volumes:
 * where boxes overlap (a culvert tube and the air pocket above it) the one
 * with the highest surface wins. Open water floats Parth to the surface;
 * ceilinged water is neutral (he stays where he stops).
 */
export class SwimMotor implements WaterMotor {
  readonly events = new Emitter<SwimEvents>();
  swimSpeed = SWIM_TUNING.swimSpeed;
  verticalSpeed = SWIM_TUNING.verticalSpeed;
  waterAcceleration = SWIM_TUNING.acceleration;
  /** Volume holding the player's capsule centre (null on land). */
  water: SwimmingPool | null = null;
  /** Volume the camera is in (submerged) or just above (breathing at its surface). */
  cameraWater: SwimmingPool | null = null;
  underwater = false;
  immersion = 0;
  /** Underwater fog for the renderer (blend towards it by `immersion`). */
  readonly fogColor = new Color(POOL_FOG.color).multiplyScalar(POOL_FOG.scale);
  fogDensity = POOL_FOG.density;

  constructor(private pools: SwimmingPool[], private input: Input) {}

  /** Highest-surface volume containing `p` (margins as in `SwimmingPool.contains`). */
  volumeAt(p: Vector3, below = 0.2, above = 0.35): SwimmingPool | null {
    let best: SwimmingPool | null = null;
    for (const pool of this.pools) {
      if (pool.contains(p, below, above) && (!best || pool.surfaceY > best.surfaceY)) best = pool;
    }
    return best;
  }

  update(player: Player, dt: number): boolean {
    const was = this.water !== null;
    this.water = this.volumeAt(player.center);
    if (was !== (this.water !== null)) this.events.emit("swimming_state_changed", this.water !== null);
    if (!this.water) return false;
    const water = this.water;
    player.isSprinting = false;
    player.isCrouching = !player.canStand();
    player.updateCrouch(dt);
    const v = player.inputVector();
    const dir = player.worldDirection(v);
    player.velocity.x = moveToward(player.velocity.x, dir.x * this.swimSpeed, this.waterAcceleration * dt);
    player.velocity.z = moveToward(player.velocity.z, dir.z * this.swimSpeed, this.waterAcceleration * dt);
    let targetY = 0;
    if (player.controlEnabled && this.input.isDown("KeyC")) targetY = -this.verticalSpeed;
    else if (player.controlEnabled && this.input.isDown("Space")) targetY = this.verticalSpeed;
    else if (!water.ceiling) {
      // Stable buoyancy: eyes just above the surface. Breath is the story's business (features/water).
      const floatY = water.surfaceY - player.t.standingCameraHeight + 0.16;
      targetY = Math.max(-this.verticalSpeed, Math.min(this.verticalSpeed, (floatY - player.center.y) * 3));
    }
    player.velocity.y = moveToward(player.velocity.y, targetY, this.waterAcceleration * dt);
    if (player.grounded && !this.input.isDown("KeyC")) player.velocity.y = Math.max(0, player.velocity.y);
    player.move(dt);
    return true;
  }

  /** Camera immersion for the underwater overlay/fog (PlayerSwimming._process). */
  updateCamera(camera: Vector3, dt: number): void {
    let submerged = false;
    let at: SwimmingPool | null = null;
    for (const pool of this.pools) {
      if (!pool.containsHorizontal(camera) || camera.y <= pool.bottomY) continue;
      const threshold = pool.surfaceY + (this.underwater ? 0.025 : -0.025);
      if (camera.y < threshold) {
        submerged = true;
        at = pool;
        break;
      }
      if (camera.y < pool.surfaceY + 1.2 && (!at || pool.surfaceY > at.surfaceY)) at = pool;
    }
    this.underwater = submerged;
    this.cameraWater = at;
    this.immersion = moveToward(this.immersion, submerged ? 1 : 0, dt * 4);
    if (submerged && at) {
      this.fogColor.lerp(at.fog.color, Math.min(1, dt * 6));
      this.fogDensity += (at.fog.density - this.fogDensity) * Math.min(1, dt * 6);
    }
  }
}
