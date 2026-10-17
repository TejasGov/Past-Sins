import { BackSide, Color, Mesh, ShaderMaterial, SphereGeometry, Vector3 } from "three";

/**
 * Procedural sky dome replacing Godot's ProceduralSkyMaterial: top/horizon
 * gradient from the environment cycle, sun disc + forward-scatter glow, slow
 * fbm cloud deck (thicker in rain) and stars at night.
 */
export class Sky {
  readonly mesh: Mesh;
  readonly material: ShaderMaterial;

  constructor() {
    this.material = new ShaderMaterial({
      side: BackSide,
      depthWrite: false,
      fog: false,
      uniforms: {
        topColor: { value: new Color(0x5489b2) },
        horizonColor: { value: new Color(0xa9bbc1) },
        groundColor: { value: new Color(0x2a2d2b) },
        sunDir: { value: new Vector3(0.3, 0.8, 0.2).normalize() },
        sunColor: { value: new Color(1, 0.95, 0.88) },
        sunStrength: { value: 1 },
        stars: { value: 0 },
        cloudCover: { value: 0.45 },
        cloudDark: { value: 0 },
        time: { value: 0 },
        fogColor: { value: new Color(0x8c969a) },
        haze: { value: 0.35 },
      },
      vertexShader: /* glsl */ `
        varying vec3 vDir;
        void main() {
          vDir = normalize(position);
          vec4 p = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
          gl_Position = p.xyww;
        }`,
      fragmentShader: /* glsl */ `
        uniform vec3 topColor, horizonColor, groundColor, sunDir, sunColor, fogColor;
        uniform float sunStrength, stars, cloudCover, cloudDark, time, haze;
        varying vec3 vDir;
        float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
        float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
          return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
        float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { v += a * n(p); p = p * 2.03 + 11.3; a *= 0.5; } return v; }
        void main() {
          vec3 d = normalize(vDir);
          float y = d.y;
          vec3 col = mix(horizonColor, topColor, pow(smoothstep(0.0, 0.85, y), 0.65));
          col = mix(col, groundColor, smoothstep(0.0, -0.18, y));
          float mu = max(dot(d, normalize(sunDir)), 0.0);
          float sunUp = smoothstep(-0.12, 0.08, sunDir.y);
          col += sunColor * (pow(mu, 8.0) * 0.25 + pow(mu, 64.0) * 0.6) * sunStrength * sunUp;
          col += sunColor * smoothstep(0.9993, 0.99965, mu) * 18.0 * sunStrength * sunUp;
          if (y > 0.0) {
            vec2 uv = d.xz / (y + 0.12) * 1.3 + vec2(time * 0.004, time * 0.0015);
            float c = fbm(uv);
            float cov = smoothstep(1.0 - cloudCover, 1.0 - cloudCover + 0.35, c) * smoothstep(0.0, 0.25, y);
            vec3 cloudCol = mix(horizonColor * 1.05, topColor * 0.6 + horizonColor * 0.4, 0.4);
            cloudCol = mix(cloudCol, cloudCol * 0.45, cloudDark);
            cloudCol += sunColor * pow(mu, 6.0) * 0.35 * sunStrength;
            col = mix(col, cloudCol, cov * 0.9);
            vec2 sp = d.xz / (y + 0.05) * 90.0;
            float s = step(0.9975, h(floor(sp))) * (0.6 + 0.4 * sin(time * 2.0 + h(floor(sp)) * 40.0));
            col += vec3(s) * stars * (1.0 - cov) * smoothstep(0.05, 0.3, y);
          }
          col = mix(col, fogColor, haze * (1.0 - smoothstep(0.0, 0.32, abs(y))));
          gl_FragColor = vec4(col, 1.0);
          #include <tonemapping_fragment>
          #include <colorspace_fragment>
        }`,
    });
    this.mesh = new Mesh(new SphereGeometry(800, 32, 16), this.material);
    this.mesh.frustumCulled = false;
    this.mesh.renderOrder = -10;
    this.mesh.name = "SkyDome";
  }

  follow(position: Vector3): void {
    this.mesh.position.copy(position);
  }
}
