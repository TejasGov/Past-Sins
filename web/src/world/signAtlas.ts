import { CanvasTexture, LinearMipmapLinearFilter, SRGBColorSpace } from "three";

/**
 * All painted/stencilled signs share one canvas atlas so every sign in the
 * campus renders in a single merged draw call (Godot used one Label3D each).
 */
export interface SignRect {
  u0: number;
  v0: number;
  u1: number;
  v1: number;
  aspect: number; // width / height in pixels
  lines: number;
}

const SIZE = 4096;
const FONT_PX = 56;
const LINE_PX = Math.round(FONT_PX * 1.2);
const PAD = 6;

export class SignAtlas {
  readonly canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private x = 0;
  private y = 0;
  private rowHeight = 0;
  private cache = new Map<string, SignRect>();
  readonly texture: CanvasTexture;

  constructor() {
    this.canvas = document.createElement("canvas");
    this.canvas.width = SIZE;
    this.canvas.height = SIZE;
    this.ctx = this.canvas.getContext("2d")!;
    this.ctx.fillStyle = "rgba(0,0,0,0)";
    this.ctx.clearRect(0, 0, SIZE, SIZE);
    this.texture = new CanvasTexture(this.canvas);
    this.texture.colorSpace = SRGBColorSpace;
    this.texture.minFilter = LinearMipmapLinearFilter;
    this.texture.anisotropy = 8;
  }

  /** White text; per-sign color comes from vertex colors. */
  add(text: string): SignRect {
    const cached = this.cache.get(text);
    if (cached) return cached;
    const ctx = this.ctx;
    const lines = text.split("\n");
    ctx.font = `600 ${FONT_PX}px Oswald, "Arial Narrow", sans-serif`;
    const width = Math.ceil(Math.max(...lines.map((l) => ctx.measureText(l).width))) + PAD * 2;
    const height = lines.length * LINE_PX + PAD * 2;
    if (this.x + width > SIZE) {
      this.x = 0;
      this.y += this.rowHeight + 2;
      this.rowHeight = 0;
    }
    if (this.y + height > SIZE) {
      console.warn("Sign atlas full; reusing first slot for", text);
      return this.cache.values().next().value!;
    }
    // Dark outline mimics Label3D's outline_size so signs read on any wall.
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.lineJoin = "round";
    lines.forEach((line, i) => {
      const cx = this.x + width / 2;
      const cy = this.y + PAD + LINE_PX * (i + 0.5);
      ctx.lineWidth = 8;
      ctx.strokeStyle = "rgba(10,12,12,0.85)";
      ctx.strokeText(line, cx, cy);
      ctx.fillStyle = "#ffffff";
      ctx.fillText(line, cx, cy);
    });
    const rect: SignRect = {
      u0: this.x / SIZE,
      u1: (this.x + width) / SIZE,
      v0: 1 - (this.y + height) / SIZE,
      v1: 1 - this.y / SIZE,
      aspect: width / height,
      lines: lines.length,
    };
    this.x += width + 2;
    this.rowHeight = Math.max(this.rowHeight, height);
    this.cache.set(text, rect);
    this.texture.needsUpdate = true;
    return rect;
  }

  /** World height of the quad for Godot's font_size 48 × pixel_size. */
  static quadHeight(rect: SignRect, pixelSize: number): number {
    return rect.lines * 48 * pixelSize * 1.2 + (PAD * 2 * 48 * pixelSize) / FONT_PX;
  }
}
