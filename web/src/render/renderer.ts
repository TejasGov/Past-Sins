import {
  AmbientLight,
  Color,
  FogExp2,
  HalfFloatType,
  HemisphereLight,
  Material,
  NoToneMapping,
  PCFSoftShadowMap,
  PerspectiveCamera,
  PMREMGenerator,
  Scene,
  SRGBColorSpace,
  Vector2,
  Vector3,
  WebGLRenderer,
  type WebGLRenderTarget,
} from "three";
import { CSM } from "three/addons/csm/CSM.js";
import {
  BloomEffect,
  BlendFunction,
  ChromaticAberrationEffect,
  EffectComposer,
  EffectPass,
  KernelSize,
  NoiseEffect,
  RenderPass,
  SMAAEffect,
  SMAAPreset,
  ToneMappingEffect,
  ToneMappingMode,
  VignetteEffect,
} from "postprocessing";
import { N8AOPostPass } from "n8ao";
import { FadeEffect, GradeEffect, UnderwaterEffect } from "./effects";
import { Sky } from "./sky";

export interface QualitySettings {
  pixelRatio: number;
  ao: boolean;
  bloom: boolean;
  shadows: boolean;
}

/**
 * Owns the WebGL2 renderer, the post stack (N8AO → bloom/AgX/grade/vignette/
 * grain → chromatic aberration → SMAA), cascaded sun shadows and the sky.
 */
export class RenderStack {
  readonly renderer: WebGLRenderer;
  readonly scene = new Scene();
  readonly camera: PerspectiveCamera;
  readonly composer: EffectComposer;
  readonly csm: CSM;
  readonly sky = new Sky();
  readonly hemi: HemisphereLight;
  readonly ambient: AmbientLight;
  readonly fog: FogExp2;
  readonly ao: N8AOPostPass;
  readonly bloom: BloomEffect;
  readonly grade = new GradeEffect();
  readonly underwater = new UnderwaterEffect();
  readonly fade = new FadeEffect();
  readonly vignette: VignetteEffect;
  readonly chroma: ChromaticAberrationEffect;
  readonly noise: NoiseEffect;
  private pmrem: PMREMGenerator;
  private envTarget: WebGLRenderTarget | null = null;
  private envScene = new Scene();
  private envSky = new Sky();
  quality: QualitySettings;

  constructor(canvas: HTMLCanvasElement) {
    this.renderer = new WebGLRenderer({
      canvas,
      antialias: false,
      stencil: false,
      depth: true,
      powerPreference: "high-performance",
    });
    this.quality = { pixelRatio: Math.min(window.devicePixelRatio, 1.5), ao: true, bloom: true, shadows: true };
    this.renderer.setPixelRatio(this.quality.pixelRatio);
    this.renderer.setSize(window.innerWidth, window.innerHeight, false);
    this.renderer.outputColorSpace = SRGBColorSpace;
    this.renderer.toneMapping = NoToneMapping;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = PCFSoftShadowMap;
    this.renderer.info.autoReset = false;

    this.camera = new PerspectiveCamera(72, window.innerWidth / window.innerHeight, 0.05, 900);
    this.camera.rotation.order = "YXZ";
    this.scene.add(this.camera);

    this.fog = new FogExp2(0x7c858a, 0.012);
    this.scene.fog = this.fog;
    this.scene.add(this.sky.mesh);
    this.envScene.add(this.envSky.mesh);

    this.hemi = new HemisphereLight(0xb7c6d0, 0x2b2a26, 0.6);
    this.scene.add(this.hemi);
    this.ambient = new AmbientLight(0x9aa6a8, 0.05);
    this.scene.add(this.ambient);

    this.csm = new CSM({
      maxFar: 150,
      cascades: 3,
      mode: "practical",
      parent: this.scene,
      shadowMapSize: 2048,
      lightDirection: new Vector3(-0.6, -1, -0.45).normalize(),
      camera: this.camera,
      lightIntensity: 3,
      lightMargin: 80,
      shadowBias: -0.00025,
    });
    this.csm.fade = true;
    for (const light of this.csm.lights) {
      light.shadow.normalBias = 0.035;
      light.color.set(0xfff1dc);
    }

    this.pmrem = new PMREMGenerator(this.renderer);

    this.composer = new EffectComposer(this.renderer, { frameBufferType: HalfFloatType, multisampling: 0 });
    this.composer.addPass(new RenderPass(this.scene, this.camera));
    const size = this.renderer.getDrawingBufferSize(new Vector2());
    this.ao = new N8AOPostPass(this.scene, this.camera, size.x, size.y);
    this.ao.configuration.aoRadius = 1.4;
    this.ao.configuration.distanceFalloff = 0.45;
    this.ao.configuration.intensity = 2.6;
    this.ao.configuration.aoSamples = 12;
    this.ao.configuration.denoiseSamples = 6;
    this.ao.configuration.denoiseRadius = 10;
    this.ao.configuration.halfRes = true;
    this.ao.configuration.depthAwareUpsampling = true;
    this.ao.configuration.color = new Color(0x050605);
    this.composer.addPass(this.ao);

    this.bloom = new BloomEffect({
      mipmapBlur: true,
      intensity: 0.85,
      luminanceThreshold: 0.82,
      luminanceSmoothing: 0.25,
      radius: 0.72,
    });
    const tone = new ToneMappingEffect({ mode: ToneMappingMode.AGX });
    this.vignette = new VignetteEffect({ offset: 0.32, darkness: 0.62 });
    this.noise = new NoiseEffect({ blendFunction: BlendFunction.SOFT_LIGHT, premultiply: false });
    this.noise.blendMode.opacity.value = 0.32;
    this.composer.addPass(new EffectPass(this.camera, this.underwater, this.bloom, tone, this.grade, this.vignette, this.fade, this.noise));
    this.chroma = new ChromaticAberrationEffect({ offset: new Vector2(0.0006, 0.0004), radialModulation: true, modulationOffset: 0.25 });
    this.composer.addPass(new EffectPass(this.camera, this.chroma));
    this.composer.addPass(new EffectPass(this.camera, new SMAAEffect({ preset: SMAAPreset.HIGH })));
    void KernelSize;

    window.addEventListener("resize", () => this.resize());
    this.resize();
  }

  /** Every lit material goes through here so CSM can inject its cascades. */
  prepareMaterial = (material: Material): void => {
    this.csm.setupMaterial(material);
  };

  resize(): void {
    const w = window.innerWidth;
    const h = window.innerHeight;
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.renderer.setPixelRatio(this.quality.pixelRatio);
    this.renderer.setSize(w, h, false);
    this.composer.setSize(w, h, false);
    this.csm.updateFrustums();
  }

  setPixelRatio(ratio: number): void {
    this.quality.pixelRatio = ratio;
    this.resize();
  }

  /** Regenerates the image-based lighting from the current sky (cheap, ~1 ms). */
  refreshEnvironment(): void {
    const src = this.sky.material.uniforms;
    const dst = this.envSky.material.uniforms;
    for (const key of Object.keys(src)) {
      const v = src[key].value;
      dst[key].value = typeof v === "object" && v && "clone" in v ? v.clone() : v;
    }
    dst.stars.value = 0;
    const next = this.pmrem.fromScene(this.envScene, 0, 0.1, 1000);
    this.envTarget?.dispose();
    this.envTarget = next;
    this.scene.environment = next.texture;
  }

  render(dt: number): void {
    this.renderer.info.reset();
    this.csm.update();
    this.sky.follow(this.camera.position);
    this.composer.render(dt);
  }
}
