import { Color, Mesh, PlaneGeometry, ShaderMaterial, Vector3, DoubleSide, UniformsLib, UniformsUtils } from "three";
import type { Player, WaterMotor } from "../player/player";
import type { Input } from "../core/input";
import { Emitter } from "../core/events";

/**
 * Pool water (port of shaders/pool_water.gdshader, upgraded with fresnel,
 * scrolling ripple normals and fog) + PlayerSwimming's water motor.
 */
export class SwimmingPool {
  readonly mesh: Mesh;
  readonly material: ShaderMaterial;
  readonly surfaceY: number;

  constructor(readonly center: Vector3, readonly sizeX: number, readonly sizeZ: number, readonly depth: number, surfaceOffset: number) {
    this.surfaceY = center.y + surfaceOffset;
    this.material = new ShaderMaterial({
      transparent: true,
      depthWrite: false,
      side: DoubleSide,
      fog: true,
      uniforms: UniformsUtils.merge([
        UniformsLib.fog,
        {
          time: { value: 0 },
          deep: { value: new Color(0x0b3a44) },
          shallow: { value: new Color(0x2e8f9c) },
          sky: { value: new Color(0x9fb4bd) },
          sunDir: { value: new Vector3(0.3, 0.8, 0.2) },
          sunColor: { value: new Color(1, 0.95, 0.85) },
          sunStrength: { value: 1 },
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
    this.mesh.name = "PoolWater";
  }

  containsHorizontal(p: Vector3): boolean {
    return Math.abs(p.x - this.center.x) < this.sizeX / 2 && Math.abs(p.z - this.center.z) < this.sizeZ / 2;
  }

  update(dt: number): void {
    this.material.uniforms.time.value += dt;
  }
}

export type SwimEvents = { swimming_state_changed: boolean };

function moveToward(from: number, to: number, delta: number): number {
  return Math.abs(to - from) <= delta ? to : from + Math.sign(to - from) * delta;
}

/** Port of scripts/player/player_swimming.gd. */
export class SwimMotor implements WaterMotor {
  readonly events = new Emitter<SwimEvents>();
  swimSpeed = 2.7;
  verticalSpeed = 2.2;
  waterAcceleration = 5;
  water: SwimmingPool | null = null;
  underwater = false;
  immersion = 0;

  constructor(private pools: SwimmingPool[], private input: Input) {}

  update(player: Player, dt: number): boolean {
    const was = this.water !== null;
    this.water = null;
    for (const pool of this.pools) {
      if (!pool.containsHorizontal(player.position)) continue;
      const y = player.center.y;
      if (y > pool.center.y - pool.depth - 0.2 && y < pool.surfaceY + 0.35) {
        this.water = pool;
        break;
      }
    }
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
    else {
      // Stable buoyancy: eyes just above the surface. No drowning.
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
    for (const pool of this.pools) {
      if (!pool.containsHorizontal(camera)) continue;
      const threshold = pool.surfaceY + (this.underwater ? 0.025 : -0.025);
      submerged = camera.y < threshold && camera.y > pool.center.y - pool.depth;
      if (submerged) break;
    }
    this.underwater = submerged;
    this.immersion = moveToward(this.immersion, submerged ? 1 : 0, dt * 4);
  }
}
