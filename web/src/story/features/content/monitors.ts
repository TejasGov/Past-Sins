import { CanvasTexture, Mesh, MeshBasicMaterial, PlaneGeometry, SRGBColorSpace, Vector3 } from "three";
import type { ContentData } from "./data";

type MonitorDef = NonNullable<ContentData["monitors"]>;

const CELL_W = 128;
const CELL_H = 80;

/**
 * M12 "Forty": the HQ surveillance wall replays Parth's earlier cycles. A
 * canvas over the furnished screens, one grainy feed per screen, cycling
 * through every recorded cycle; the routes from the highlighted cycles are
 * marked. Redrawn at a few frames per second, only while Parth is near.
 */
export class MonitorWall {
  readonly mesh: Mesh;
  private canvas = document.createElement("canvas");
  private ctx: CanvasRenderingContext2D;
  private texture: CanvasTexture;
  private time = 0;
  private acc = 1;

  constructor(private def: MonitorDef, origin: Vector3, yaw: number) {
    this.canvas.width = def.cols * CELL_W;
    this.canvas.height = def.rows * CELL_H;
    this.ctx = this.canvas.getContext("2d")!;
    this.texture = new CanvasTexture(this.canvas);
    this.texture.colorSpace = SRGBColorSpace;
    const [sx, sy] = def.spacing;
    const material = new MeshBasicMaterial({ map: this.texture, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -2 });
    this.mesh = new Mesh(new PlaneGeometry(def.cols * sx, def.rows * sy), material);
    this.mesh.name = "ContentMonitorWall";
    const c = Math.cos(yaw);
    const s = Math.sin(yaw);
    const up = ((def.rows - 1) * sy) / 2;
    this.mesh.position.set(origin.x + s * 0.004, origin.y + up, origin.z + c * 0.004);
    this.mesh.rotation.y = yaw;
    this.mesh.visible = false;
  }

  update(dt: number, visible: boolean, near: boolean): void {
    this.mesh.visible = visible;
    if (!visible || !near) return;
    this.time += dt;
    this.acc += dt;
    if (this.acc < 1 / 6) return;
    this.acc = 0;
    this.draw();
    this.texture.needsUpdate = true;
  }

  private draw(): void {
    const { ctx, def } = this;
    const [sx, sy] = def.spacing;
    const sw = Math.round((def.screen[0] / sx) * CELL_W);
    const sh = Math.round((def.screen[1] / sy) * CELL_H);
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    const screens = def.cols * def.rows;
    // Every few seconds the wall moves on to the next set of cycles.
    const page = Math.floor(this.time / 7);
    for (let r = 0; r < def.rows; r++) {
      for (let c = 0; c < def.cols; c++) {
        const i = r * def.cols + c;
        const cycle = ((page * screens + i * 7) % def.cycles) + 1;
        const x = c * CELL_W + (CELL_W - sw) / 2;
        // Canvas rows run top-down; the bottom screen row is r = 0.
        const y = (def.rows - 1 - r) * CELL_H + (CELL_H - sh) / 2;
        this.feed(x, y, sw, sh, cycle, i);
      }
    }
  }

  private feed(x: number, y: number, w: number, h: number, cycle: number, seed: number): void {
    const { ctx, def } = this;
    const route = def.highlight.includes(cycle);
    const t = this.time + seed * 1.7;
    ctx.save();
    ctx.beginPath();
    ctx.rect(x, y, w, h);
    ctx.clip();
    const g = 26 + Math.round(Math.sin(t * 3 + seed) * 4);
    ctx.fillStyle = `rgb(${g - 6},${g + 4},${g})`;
    ctx.fillRect(x, y, w, h);
    // A corridor, a fence line or a pool edge, in two greys.
    ctx.strokeStyle = "rgba(150,170,160,0.35)";
    ctx.lineWidth = 1;
    const kind = cycle % 3;
    ctx.beginPath();
    if (kind === 0) {
      const vx = x + w * 0.5;
      const vy = y + h * 0.38;
      for (const [ex, ey] of [[x, y + h], [x + w, y + h], [x, y], [x + w, y]]) {
        ctx.moveTo(vx, vy);
        ctx.lineTo(ex, ey);
      }
    } else if (kind === 1) {
      for (let k = 0; k < 7; k++) {
        ctx.moveTo(x + (k * w) / 6, y + h * 0.25);
        ctx.lineTo(x + (k * w) / 6, y + h * 0.75);
      }
      ctx.moveTo(x, y + h * 0.3);
      ctx.lineTo(x + w, y + h * 0.3);
    } else {
      ctx.moveTo(x, y + h * 0.62);
      ctx.lineTo(x + w, y + h * 0.55);
      ctx.fillStyle = "rgba(90,140,150,0.25)";
      ctx.fillRect(x, y + h * 0.62, w, h * 0.38);
    }
    ctx.stroke();
    // The same grey figure, somewhere else every time.
    const walk = (Math.sin(t * 0.35) * 0.5 + 0.5) * (w - 16);
    const fy = y + h * (kind === 1 ? 0.5 : 0.58);
    ctx.fillStyle = "rgba(205,215,205,0.85)";
    ctx.fillRect(x + 6 + walk, fy, 5, 13);
    ctx.fillRect(x + 6.5 + walk, fy - 5, 4, 4);
    if (cycle % 5 === 0) {
      ctx.fillStyle = "rgba(25,30,28,0.9)";
      ctx.fillRect(x + 14 + walk, fy - 2, 6, 15);
    }
    // Grain and roll.
    ctx.fillStyle = "rgba(255,255,255,0.07)";
    for (let k = 0; k < 40; k++) ctx.fillRect(x + Math.random() * w, y + Math.random() * h, 1, 1);
    const roll = y + ((t * 18) % h);
    ctx.fillStyle = "rgba(255,255,255,0.05)";
    ctx.fillRect(x, roll, w, 3);
    // Labels.
    ctx.font = "9px monospace";
    ctx.fillStyle = route ? "rgba(255,196,92,0.95)" : "rgba(200,214,206,0.8)";
    ctx.fillText(def.labels.cycle.replace("{n}", String(cycle).padStart(2, "0")), x + 4, y + 11);
    if (route) ctx.fillText(def.labels.route, x + 4, y + h - 4);
    if (Math.floor(t * 1.5) % 2 === 0) {
      ctx.fillStyle = "rgba(230,60,50,0.9)";
      ctx.fillText(def.labels.rec, x + w - 24, y + 11);
    }
    ctx.restore();
  }
}
