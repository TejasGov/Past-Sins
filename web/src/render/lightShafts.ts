import { AdditiveBlending, BufferAttribute, BufferGeometry, Color, DoubleSide, Mesh, ShaderMaterial, Vector3 } from "three";

/**
 * Volumetric-looking sun shafts under a glazed roof. Each glazing pane is a
 * prism whose top is the pane and whose sides are sheared along the sun's
 * travel direction in the vertex shader; additive, faded with depth and
 * modulated by drifting dust. One draw call for the whole skylight.
 */
export class LightShafts {
  readonly mesh: Mesh;
  private material: ShaderMaterial;

  constructor(x0: number, z0: number, x1: number, z1: number, topY: number, depth: number, paneX = 2, zSplits = 3) {
    const pos: number[] = [];
    const t: number[] = [];
    const idx: number[] = [];
    const zStep = (z1 - z0) / zSplits;
    for (let x = x0; x < x1 - 0.01; x += paneX) {
      for (let k = 0; k < zSplits; k++) {
        const ax = x + 0.08;
        const bx = x + paneX - 0.08;
        const az = z0 + k * zStep + 0.1;
        const bz = z0 + (k + 1) * zStep - 0.1;
        const base = pos.length / 3;
        const corners = [[ax, az], [bx, az], [bx, bz], [ax, bz]];
        for (const level of [0, 1]) for (const [cx, cz] of corners) {
          pos.push(cx, topY, cz);
          t.push(level);
        }
        // 4 side quads (top ring 0..3, bottom ring 4..7).
        for (let i = 0; i < 4; i++) {
          const j = (i + 1) % 4;
          idx.push(base + i, base + j, base + 4 + j, base + i, base + 4 + j, base + 4 + i);
        }
      }
    }
    const geo = new BufferGeometry();
    geo.setAttribute("position", new BufferAttribute(new Float32Array(pos), 3));
    geo.setAttribute("level", new BufferAttribute(new Float32Array(t), 1));
    geo.setIndex(idx);
    this.material = new ShaderMaterial({
      transparent: true,
      depthWrite: false,
      blending: AdditiveBlending,
      side: DoubleSide,
      uniforms: {
        shear: { value: new Vector3(0, -1, 0) },
        depth: { value: depth },
        strength: { value: 0 },
        color: { value: new Color(1, 0.93, 0.8) },
        time: { value: 0 },
      },
      vertexShader: /* glsl */ `
        attribute float level;
        uniform vec3 shear;
        uniform float depth;
        varying float vT;
        varying vec3 vWorld;
        varying vec3 vNormalish;
        void main() {
          vec3 p = position + shear * (depth * level);
          vT = level;
          vec4 world = modelMatrix * vec4(p, 1.0);
          vWorld = world.xyz;
          gl_Position = projectionMatrix * viewMatrix * world;
        }`,
      fragmentShader: /* glsl */ `
        uniform float strength;
        uniform vec3 color;
        uniform float time;
        varying float vT;
        varying vec3 vWorld;
        void main() {
          float fade = smoothstep(0.0, 0.08, vT) * (1.0 - smoothstep(0.55, 1.0, vT));
          float dust = 0.7 + 0.3 * sin(vWorld.x * 3.1 + time * 0.3) * sin(vWorld.y * 2.3 - time * 0.21) * sin(vWorld.z * 2.7 + time * 0.17);
          float a = strength * fade * dust * 0.11;
          gl_FragColor = vec4(color * a, a);
        }`,
    });
    this.mesh = new Mesh(geo, this.material);
    this.mesh.frustumCulled = false;
    this.mesh.renderOrder = 9;
  }

  /** sunTravel: direction light travels (y < 0). strength 0..1. */
  update(dt: number, sunTravel: Vector3, strength: number, color: Color): void {
    const u = this.material.uniforms;
    u.time.value += dt;
    const down = Math.max(0.15, -sunTravel.y);
    // Per metre of descent the shaft moves horizontally by xz / |y|; shear is
    // normalised so `depth` metres of descent are reached at level = 1.
    u.shear.value.set(sunTravel.x / down, -1, sunTravel.z / down);
    u.strength.value = strength;
    u.color.value.copy(color);
    this.mesh.visible = strength > 0.01;
  }
}
