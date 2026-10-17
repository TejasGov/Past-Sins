import {
  AdditiveBlending, BufferAttribute, BufferGeometry, Color, LineSegments, Points, ShaderMaterial, Vector3,
} from "three";

/**
 * Camera-local rain volume (Godot used one 650-particle GPUParticles3D box).
 * Streaks are animated entirely in the vertex shader and wrap around the
 * camera, so the CPU cost is a few uniforms per frame.
 */
export class Rain {
  readonly mesh: LineSegments;
  private material: ShaderMaterial;
  /** 0..1 intensity (eased by the weather) × shelter. */
  amount = 0;
  private shown = 0;

  constructor(count = 2600) {
    const pos = new Float32Array(count * 6);
    const seed = new Float32Array(count * 2 * 4);
    for (let i = 0; i < count; i++) {
      const x = Math.random();
      const y = Math.random();
      const z = Math.random();
      const s = Math.random();
      for (let k = 0; k < 2; k++) {
        pos.set([0, k, 0], (i * 2 + k) * 3);
        seed.set([x, y, z, s], (i * 2 + k) * 4);
      }
    }
    const geo = new BufferGeometry();
    geo.setAttribute("position", new BufferAttribute(pos, 3));
    geo.setAttribute("seed", new BufferAttribute(seed, 4));
    this.material = new ShaderMaterial({
      transparent: true,
      depthWrite: false,
      blending: AdditiveBlending,
      uniforms: {
        time: { value: 0 },
        center: { value: new Vector3() },
        amount: { value: 0 },
        color: { value: new Color(0xa9b8c2) },
        wind: { value: new Vector3(0.9, 0, 0.35) },
      },
      vertexShader: /* glsl */ `
        attribute vec4 seed;
        uniform float time;
        uniform vec3 center;
        uniform vec3 wind;
        uniform float amount;
        varying float vA;
        void main() {
          float size = 22.0;
          float height = 16.0;
          float speed = 11.0 + seed.w * 5.0;
          float fall = height - mod(seed.y * height + time * speed, height);
          vec2 fixedXZ = seed.xz * size + wind.xz * (fall / speed);
          vec2 rel = mod(fixedXZ - center.xz + size * 0.5, size) - size * 0.5;
          vec3 world = vec3(center.x + rel.x, center.y - 6.0 + fall, center.z + rel.y);
          vec3 streak = normalize(vec3(-wind.x, -speed, -wind.z)) * (0.28 + seed.w * 0.25);
          world += position.y * streak;
          float d = length(world.xz - center.xz);
          vA = amount * (1.0 - smoothstep(6.0, 11.0, d)) * step(seed.w, amount * 1.05) * mix(0.25, 0.55, position.y);
          gl_Position = projectionMatrix * viewMatrix * vec4(world, 1.0);
        }`,
      fragmentShader: /* glsl */ `
        uniform vec3 color;
        varying float vA;
        void main() { if (vA < 0.01) discard; gl_FragColor = vec4(color * vA, vA); }`,
    });
    this.mesh = new LineSegments(geo, this.material);
    this.mesh.frustumCulled = false;
    this.mesh.renderOrder = 6;
  }

  update(dt: number, camera: Vector3, target: number, nightLevel: number): void {
    this.shown += (target - this.shown) * (1 - Math.exp(-dt * 1.5));
    const u = this.material.uniforms;
    u.time.value += dt;
    u.center.value.copy(camera);
    u.amount.value = this.shown;
    u.color.value.setRGB(0.66 - nightLevel * 0.3, 0.72 - nightLevel * 0.3, 0.78 - nightLevel * 0.28);
    this.mesh.visible = this.shown > 0.01;
  }
}

/** Drifting dust motes around the camera; they read in light shafts and lamp pools. */
export class DustMotes {
  readonly points: Points;
  private material: ShaderMaterial;

  constructor(count = 900) {
    const pos = new Float32Array(count * 3);
    for (let i = 0; i < count; i++) pos.set([Math.random(), Math.random(), Math.random()], i * 3);
    const geo = new BufferGeometry();
    geo.setAttribute("position", new BufferAttribute(pos, 3));
    this.material = new ShaderMaterial({
      transparent: true,
      depthWrite: false,
      blending: AdditiveBlending,
      uniforms: { time: { value: 0 }, center: { value: new Vector3() }, strength: { value: 1 }, tint: { value: new Color(1, 0.92, 0.8) } },
      vertexShader: /* glsl */ `
        uniform float time;
        uniform vec3 center;
        varying float vA;
        void main() {
          float size = 9.0;
          vec3 p = position * size;
          p += vec3(sin(time * 0.11 + position.y * 40.0), sin(time * 0.07 + position.x * 30.0) * 0.6 - time * 0.02, cos(time * 0.09 + position.z * 35.0)) * 0.6;
          vec3 world = center + mod(p - center + vec3(size * 0.5), size) - vec3(size * 0.5);
          vec4 mv = viewMatrix * vec4(world, 1.0);
          float d = length(world - center);
          vA = (1.0 - smoothstep(2.0, 4.4, d)) * smoothstep(0.3, 1.0, d);
          gl_PointSize = clamp(42.0 / -mv.z, 1.0, 5.0);
          gl_Position = projectionMatrix * mv;
        }`,
      fragmentShader: /* glsl */ `
        uniform float strength;
        uniform vec3 tint;
        varying float vA;
        void main() {
          vec2 c = gl_PointCoord - 0.5;
          float a = smoothstep(0.5, 0.0, length(c)) * vA * strength * 0.22;
          if (a < 0.004) discard;
          gl_FragColor = vec4(tint * a, a);
        }`,
    });
    this.points = new Points(geo, this.material);
    this.points.frustumCulled = false;
    this.points.renderOrder = 7;
  }

  update(dt: number, camera: Vector3, strength: number): void {
    this.material.uniforms.time.value += dt;
    this.material.uniforms.center.value.copy(camera);
    this.material.uniforms.strength.value = strength;
  }
}
