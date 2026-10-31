import { Euler, Quaternion, Vector3 } from "three";
import type { Game } from "../../../game/game";
import type { LightsOutDef, WithdrawalDef } from "./data";

/** Smooth pseudo-random drift in [-1, 1]: a few incommensurate sines. */
function drift(t: number, seed: number): number {
  return Math.sin(t * 0.37 + seed) * 0.5 + Math.sin(t * 0.131 + seed * 2.3) * 0.32 + Math.sin(t * 0.83 + seed * 0.7) * 0.18;
}

/**
 * The routine's screen and light treatment, composed each frame from the
 * authored baselines (read once at init) so nothing accumulates:
 * withdrawal (grade saturation / contrast / tint drift, camera sway) and
 * lights out (fixture scale + a grade dim, indoors only). Writes only while
 * an effect is on or easing off, then hands the uniforms back untouched.
 */
export class ScreenLook {
  private readonly baseSaturation: number;
  private readonly baseContrast: number;
  private readonly baseTint: Vector3;
  private readonly baseVignette: number;
  private time = 0;
  private gradeDirty = false;
  private lightsDirty = false;
  private readonly tint = new Vector3();
  private readonly sway = new Quaternion();
  private readonly euler = new Euler(0, 0, 0, "YXZ");

  constructor(private game: Game) {
    const u = game.render.grade.uniforms;
    this.baseSaturation = u.get("saturation")!.value as number;
    this.baseContrast = u.get("contrast")!.value as number;
    this.baseTint = (u.get("tint")!.value as Vector3).clone();
    this.baseVignette = game.render.vignette.darkness;
  }

  /**
   * `w` withdrawal 0..1, `dark` lights out 0..1 (already indoor-weighted).
   * Runs after player.updateCamera, so the sway layers on the posed camera.
   */
  apply(dt: number, w: number, dark: number, wd: WithdrawalDef, lo: LightsOutDef, fixturesDark = dark): void {
    this.time += dt;
    const g = this.game;
    const grade = g.render.grade;
    const t = this.time * wd.grade.speed;
    if (w > 0.001 || dark > 0.001) {
      const sat = this.baseSaturation * (1 - wd.grade.desaturate * w + wd.grade.saturation * w * drift(t, 1.3));
      const con = this.baseContrast * (1 + wd.grade.contrast * w * drift(t, 4.1));
      const k = wd.grade.tint * w;
      const sick = drift(t * 0.8, 7.7);
      const dim = 1 + (lo.grade - 1) * dark;
      grade.set("saturation", Math.max(0, sat));
      grade.set("contrast", con);
      grade.set(
        "tint",
        this.tint.set(
          this.baseTint.x * (1 + k * 0.6 * sick) * dim,
          this.baseTint.y * (1 + k * 0.35 * drift(t, 2.9)) * dim,
          this.baseTint.z * (1 - k * 0.8 * sick) * dim,
        ),
      );
      // Slow pulse at the edges, like a pulse you can feel behind the eyes.
      const beat = Math.pow(0.5 + 0.5 * Math.sin(this.time * 2.2), 6);
      g.render.vignette.darkness = Math.min(1, this.baseVignette + wd.grade.vignette * w * (0.45 + 0.55 * beat));
      this.gradeDirty = true;
    } else if (this.gradeDirty) {
      grade.set("saturation", this.baseSaturation);
      grade.set("contrast", this.baseContrast);
      grade.set("tint", this.baseTint.clone());
      g.render.vignette.darkness = this.baseVignette;
      this.gradeDirty = false;
    }
    // Lights out dims those buildings' fixtures only (point lights and tube panels).
    if (fixturesDark > 0.001) {
      const dim = 1 + (lo.fixtures - 1) * fixturesDark;
      for (const c of lo.chunks) {
        g.pool.chunkDim.set(c, dim);
        g.materials.setChunkFixtureDim(c, dim);
      }
      this.lightsDirty = true;
    } else if (this.lightsDirty) {
      this.clearDims(lo.chunks);
      this.lightsDirty = false;
    }
    // Camera sway: slow drunk roll/pitch/yaw plus a small bob; cinematics own the camera.
    const sw = w * (1 - Math.min(1, g.cine.weight));
    if (sw > 0.001) {
      const s = this.time * wd.sway.speed;
      const deg = Math.PI / 180;
      this.euler.set(wd.sway.pitch * deg * sw * drift(s, 5.2), wd.sway.yaw * deg * sw * drift(s, 8.4), wd.sway.roll * deg * sw * drift(s * 1.2, 0.4));
      this.sway.setFromEuler(this.euler);
      const cam = g.render.camera;
      cam.quaternion.multiply(this.sway);
      cam.position.y += wd.sway.bob * sw * drift(s * 1.7, 3.3);
    }
  }

  /** Back to the authored look immediately (wipe). */
  reset(): void {
    const grade = this.game.render.grade;
    grade.set("saturation", this.baseSaturation);
    grade.set("contrast", this.baseContrast);
    grade.set("tint", this.baseTint.clone());
    this.game.render.vignette.darkness = this.baseVignette;
    this.clearDims([...this.game.pool.chunkDim.keys()]);
    this.gradeDirty = false;
    this.lightsDirty = false;
  }

  private clearDims(chunks: string[]): void {
    for (const c of chunks) {
      this.game.pool.chunkDim.delete(c);
      this.game.materials.setChunkFixtureDim(c, 1);
    }
  }
}
