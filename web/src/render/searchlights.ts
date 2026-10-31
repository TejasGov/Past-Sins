import {
  AdditiveBlending, Color, ConeGeometry, DoubleSide, Group, Mesh, MeshBasicMaterial, CylinderGeometry, Object3D, ShaderMaterial, SpotLight, Vector3, type Scene,
} from "three";
import type { Anchor } from "../world/types";

interface Beam {
  name: string;
  pivot: Group;
  head: Group;
  lens: Mesh;
  baseYaw: number;
  pitch: number;
  phase: number;
  light: SpotLight | null;
  cone: Mesh | null;
}

const RANGE = 46;
const HALF_ANGLE = (13 * Math.PI) / 180;

/**
 * Watchtower searchlights (watchtower.gd). All eight lenses glow after dark;
 * only the three designated towers own real shadowed SpotLights, now with a
 * slow sweep and an additive volumetric-looking cone.
 */
export class Searchlights {
  readonly root = new Group();
  private beams: Beam[] = [];
  private t = 0;
  level = 0;
  /** False = the towers are dark (beams, lights and exposure off). */
  enabled = true;
  private lensMat = new MeshBasicMaterial({ color: new Color(0xfff0c8) });

  constructor(scene: Scene, anchors: Map<string, Anchor>) {
    scene.add(this.root);
    const coneMat = new ShaderMaterial({
      transparent: true,
      depthWrite: false,
      blending: AdditiveBlending,
      side: DoubleSide,
      uniforms: { level: { value: 0 }, color: { value: new Color(0xffe0a8) }, time: { value: 0 } },
      vertexShader: /* glsl */ `
        varying float vAlong;
        varying vec3 vN;
        varying vec3 vView;
        varying vec3 vWorld;
        void main() {
          vAlong = 0.5 - position.y / ${RANGE.toFixed(1)};
          vec4 world = modelMatrix * vec4(position, 1.0);
          vWorld = world.xyz;
          vN = normalize(mat3(modelMatrix) * normal);
          vView = normalize(cameraPosition - world.xyz);
          gl_Position = projectionMatrix * viewMatrix * world;
        }`,
      fragmentShader: /* glsl */ `
        uniform float level;
        uniform vec3 color;
        uniform float time;
        varying float vAlong;
        varying vec3 vN;
        varying vec3 vView;
        varying vec3 vWorld;
        float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
        void main() {
          float facing = pow(abs(dot(normalize(vN), normalize(vView))), 1.6);
          float fall = pow(1.0 - clamp(vAlong, 0.0, 1.0), 1.7) * smoothstep(0.0, 0.04, vAlong);
          float dust = 0.85 + 0.15 * sin(vWorld.x * 0.7 + vWorld.y * 1.3 + time * 0.6) * sin(vWorld.z * 0.9 - time * 0.4);
          float a = facing * fall * dust * level * 0.16;
          gl_FragColor = vec4(color * a, a);
        }`,
    });
    for (const [key, anchor] of anchors) {
      if (!key.startsWith("tower:")) continue;
      const data = anchor.data as { light: boolean; pitch: number; name: string };
      const pivot = new Group();
      pivot.position.copy(anchor.position);
      const head = new Group();
      pivot.add(head);
      const housing = new Mesh(new CylinderGeometry(0.24, 0.3, 0.55, 14), new MeshBasicMaterial({ color: 0x1c201e }));
      housing.rotation.x = Math.PI / 2;
      head.add(housing);
      const lens = new Mesh(new CylinderGeometry(0.2, 0.2, 0.03, 16), this.lensMat);
      lens.rotation.x = Math.PI / 2;
      lens.position.z = 0.29;
      head.add(lens);
      let light: SpotLight | null = null;
      let cone: Mesh | null = null;
      if (data.light) {
        light = new SpotLight(0xffe1ac, 0, RANGE + 6, HALF_ANGLE, 0.45, 1.2);
        light.position.set(0, 0, 0.35);
        light.castShadow = true;
        light.shadow.mapSize.set(1024, 1024);
        light.shadow.bias = -0.0004;
        light.shadow.normalBias = 0.05;
        light.shadow.camera.near = 0.5;
        light.shadow.camera.far = RANGE + 6;
        const target = new Object3D();
        target.position.set(0, 0, 10);
        head.add(target);
        light.target = target;
        head.add(light);
        const radius = Math.tan(HALF_ANGLE) * RANGE;
        const geo = new ConeGeometry(radius, RANGE, 28, 1, true);
        cone = new Mesh(geo, coneMat);
        cone.rotation.x = -Math.PI / 2;
        cone.position.z = RANGE / 2 + 0.3;
        cone.renderOrder = 8;
        cone.frustumCulled = false;
        head.add(cone);
      }
      this.root.add(pivot);
      this.beams.push({ name: data.name, pivot, head, lens, baseYaw: anchor.yaw, pitch: (data.pitch * Math.PI) / 180, phase: Math.random() * 10, light, cone });
    }
    this.coneMaterial = coneMat;
  }
  private coneMaterial: ShaderMaterial;

  /** level: 0 day … 1 night. */
  update(dt: number, level: number): void {
    if (!this.enabled) level = 0;
    this.t += dt;
    this.level = level;
    this.coneMaterial.uniforms.level.value = level;
    this.coneMaterial.uniforms.time.value = this.t;
    this.lensMat.color.setScalar(0.05 + level * 3.5).multiply(new Color(1, 0.94, 0.78));
    for (const b of this.beams) {
      const sweep = Math.sin(this.t * 0.42 + b.phase) * 0.45 + Math.sin(this.t * 0.17 + b.phase * 2) * 0.15;
      b.pivot.rotation.y = b.baseYaw + sweep;
      // The lens faces local +Z; depress it by the configured pitch.
      b.head.rotation.x = b.pitch + Math.sin(this.t * 0.23 + b.phase) * 0.08;
      if (b.light) {
        b.light.intensity = level * 900;
        b.light.shadow.autoUpdate = level > 0.02;
        if (b.cone) b.cone.visible = level > 0.02;
      }
    }
  }

  /** 0..1 exposure of a point to any live beam (cone test, no occlusion). */
  exposure(point: Vector3, blocked: (a: Vector3, b: Vector3) => boolean): number {
    if (this.level < 0.05) return 0;
    let best = 0;
    const origin = new Vector3();
    const dir = new Vector3();
    for (const b of this.beams) {
      if (!b.light) continue;
      b.light.getWorldPosition(origin);
      b.head.getWorldDirection(dir);
      const to = point.clone().sub(origin);
      const d = to.length();
      if (d > RANGE + 4) continue;
      const angle = dir.angleTo(to.normalize());
      if (angle > HALF_ANGLE) continue;
      if (blocked(origin, point)) continue;
      best = Math.max(best, (1 - angle / HALF_ANGLE) * this.level);
    }
    return best;
  }
}
