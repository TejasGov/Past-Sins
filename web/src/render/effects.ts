import { Effect, BlendFunction } from "postprocessing";
import { Uniform, Vector3 } from "three";

/**
 * Port of shaders/screen_grade.gdshader, minus its 9-tap bloom (postprocessing's
 * mip-mapped bloom replaces it): contrast with a soft shadow floor, saturation,
 * institutional grey-green tint, plus a cold-shadow / warm-highlight split tone.
 * Runs after AgX tone mapping, in linear [0,1].
 */
export class GradeEffect extends Effect {
  constructor() {
    super(
      "GradeEffect",
      /* glsl */ `
      uniform float contrast;
      uniform float shadowDetail;
      uniform float saturation;
      uniform vec3 tint;
      uniform vec3 shadowTone;
      uniform vec3 highlightTone;
      uniform float splitStrength;
      uniform float exposureLift;
      void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {
        vec3 c = inputColor.rgb;
        vec3 g = pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
        g = max(g * shadowDetail, mix(vec3(0.5), g, contrast));
        c = pow(max(g, vec3(0.0)), vec3(2.2));
        float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
        c = mix(vec3(l), c, saturation);
        float sh = 1.0 - smoothstep(0.0, 0.35, l);
        float hi = smoothstep(0.35, 0.9, l);
        c *= mix(vec3(1.0), shadowTone, sh * splitStrength);
        c *= mix(vec3(1.0), highlightTone, hi * splitStrength);
        c = c * tint + exposureLift;
        outputColor = vec4(c, inputColor.a);
      }`,
      {
        blendFunction: BlendFunction.NORMAL,
        uniforms: new Map<string, Uniform>([
          ["contrast", new Uniform(1.08)],
          ["shadowDetail", new Uniform(0.86)],
          ["saturation", new Uniform(0.82)],
          ["tint", new Uniform(new Vector3(0.96, 1.0, 0.98))],
          ["shadowTone", new Uniform(new Vector3(0.86, 0.98, 1.06))],
          ["highlightTone", new Uniform(new Vector3(1.05, 1.0, 0.92))],
          ["splitStrength", new Uniform(0.8)],
          ["exposureLift", new Uniform(0.0)],
        ]),
      },
    );
  }

  set(name: string, value: number | Vector3): void {
    const u = this.uniforms.get(name);
    if (u) u.value = value;
  }
}

/**
 * Port of shaders/underwater_overlay.gdshader: edge-weighted teal tint with a
 * moving caustic band, driven by `immersion` (0 dry → 1 submerged).
 */
export class UnderwaterEffect extends Effect {
  constructor() {
    super(
      "UnderwaterEffect",
      /* glsl */ `
      uniform float immersion;
      uniform float time;
      void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {
        if (immersion <= 0.001) { outputColor = inputColor; return; }
        float edge = smoothstep(0.2, 0.75, length(uv - vec2(0.5)));
        float band = sin(uv.x * 19.0 + uv.y * 7.0 + time * 1.5) * 0.5 + 0.5;
        vec3 water = vec3(0.012, 0.11 + band * 0.02, 0.14);
        float l = dot(inputColor.rgb, vec3(0.2126, 0.7152, 0.0722));
        vec3 absorbed = vec3(l * 0.35, l * 0.85, l * 0.95) * vec3(0.55, 0.95, 1.0);
        vec3 c = mix(inputColor.rgb, absorbed + water, immersion * 0.75);
        c = mix(c, water * 0.6, immersion * (0.16 + edge * 0.35));
        outputColor = vec4(c, inputColor.a);
      }`,
      {
        uniforms: new Map<string, Uniform>([
          ["immersion", new Uniform(0)],
          ["time", new Uniform(0)],
        ]),
      },
    );
  }
}

/** Full-screen fade used by the detention overlay and memory cinematics. */
export class FadeEffect extends Effect {
  constructor() {
    super(
      "FadeEffect",
      /* glsl */ `
      uniform float amount;
      uniform vec3 color;
      uniform float desaturate;
      void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {
        float l = dot(inputColor.rgb, vec3(0.2126, 0.7152, 0.0722));
        vec3 c = mix(inputColor.rgb, vec3(l), desaturate);
        outputColor = vec4(mix(c, color, amount), inputColor.a);
      }`,
      {
        uniforms: new Map<string, Uniform>([
          ["amount", new Uniform(0)],
          ["color", new Uniform(new Vector3(0, 0, 0))],
          ["desaturate", new Uniform(0)],
        ]),
      },
    );
  }
}
