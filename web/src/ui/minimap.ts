import type { Vector3 } from "three";
import { compactPlan, type FloorPlan } from "../world/campus/plans";
import { BUILDINGS } from "../world/campus/buildings";

interface MapContext {
  title: string;
  plan: FloorPlan | null;
  origin: { x: number; z: number; w: number; d: number };
  elevation: number;
}

interface Marker {
  x: number;
  z: number;
  y: number;
  locked: boolean;
  open: boolean;
}

const BUILDING_FOOTPRINTS = [
  { name: "CELLHOUSE A", x: -50, z: 0, w: 44, d: 34, plans: ["cellhouse-a-1", "cellhouse-a-2", "cellhouse-a-3"] },
  ...BUILDINGS.map((b) => ({ name: b.name.toUpperCase(), x: b.position.x, z: b.position.z, w: b.shell.width, d: b.shell.depth, plans: b.plans })),
];

/**
 * Port of scripts/ui/minimap.gd: campus overview outdoors; inside a building
 * it switches to the occupied storey's room plan (from floor_plans.json),
 * including B1/B2, with live door markers filtered to that floor. M toggles.
 */
export class Minimap {
  readonly el: HTMLElement;
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private caption: HTMLElement;
  private plans = new Map<string, FloorPlan>();
  visible = true;
  private timer = 0;
  current: MapContext | null = null;

  constructor(parent: HTMLElement, plans: FloorPlan[]) {
    this.el = document.createElement("div");
    this.el.className = "minimap";
    this.canvas = document.createElement("canvas");
    this.canvas.width = 460;
    this.canvas.height = 460;
    this.canvas.style.width = "100%";
    this.canvas.style.height = "100%";
    this.el.appendChild(this.canvas);
    this.caption = document.createElement("div");
    this.caption.className = "caption";
    this.el.appendChild(this.caption);
    parent.appendChild(this.el);
    this.ctx = this.canvas.getContext("2d")!;
    for (const p of plans) this.plans.set(p.id, p.id.startsWith("cellhouse-a") ? p : compactPlan(p));
  }

  toggle(): void {
    this.visible = !this.visible;
    this.el.style.display = this.visible ? "block" : "none";
  }

  private contextFor(p: Vector3): MapContext | null {
    for (const b of BUILDING_FOOTPRINTS) {
      if (Math.abs(p.x - b.x) > b.w / 2 || Math.abs(p.z - b.z) > b.d / 2) continue;
      let best: FloorPlan | null = null;
      for (const id of b.plans) {
        const plan = this.plans.get(id);
        if (plan && plan.elevation <= p.y + 0.6 && (!best || plan.elevation > best.elevation)) best = plan;
      }
      if (!best) return null;
      return { title: `${b.name} · ${best.level.toUpperCase()}`, plan: best, origin: { x: b.x - best.width / 2, z: b.z - best.depth / 2, w: best.width, d: best.depth }, elevation: best.elevation };
    }
    return null;
  }

  update(dt: number, player: Vector3, yaw: number, markers: Marker[], guards: { x: number; z: number; y: number; alert: boolean }[], showGuards: boolean): void {
    this.timer -= dt;
    if (this.timer > 0 || !this.visible) return;
    this.timer = 0.08;
    const ctx = this.ctx;
    const W = this.canvas.width;
    ctx.clearRect(0, 0, W, W);
    this.current = this.contextFor(player);
    const c = this.current;
    let toScreen: (x: number, z: number) => [number, number];
    if (c && c.plan) {
      const scale = (W - 40) / Math.max(c.origin.w, c.origin.d);
      const ox = (W - c.origin.w * scale) / 2;
      const oz = (W - c.origin.d * scale) / 2;
      toScreen = (x, z) => [ox + (x - c.origin.x) * scale, oz + (z - c.origin.z) * scale];
      for (const r of c.plan.rooms) {
        const [x0, y0] = toScreen(c.origin.x + r.x, c.origin.z + r.y);
        const fill = r.type === "stair" ? "rgba(227,199,122,0.18)" : r.type === "void" || r.type === "open" ? "rgba(140,160,150,0.06)" : r.type === "corridor" ? "rgba(160,175,168,0.13)" : r.type === "cell" ? "rgba(120,130,125,0.16)" : r.type === "secure" ? "rgba(220,90,80,0.14)" : "rgba(170,185,178,0.2)";
        ctx.fillStyle = fill;
        ctx.fillRect(x0, y0, r.w * scale, r.d * scale);
        ctx.strokeStyle = "rgba(217,223,210,0.5)";
        ctx.lineWidth = 1.5;
        ctx.strokeRect(x0, y0, r.w * scale, r.d * scale);
        if (r.w * r.d > 40 && r.type !== "cell") {
          ctx.fillStyle = "rgba(217,223,210,0.55)";
          ctx.font = "500 15px 'IBM Plex Mono', monospace";
          ctx.textAlign = "center";
          ctx.fillText(r.label.split("\n")[0].slice(0, 18), x0 + (r.w * scale) / 2, y0 + (r.d * scale) / 2 + 5);
        }
      }
      this.caption.textContent = c.title;
    } else {
      // Campus overview: 156 × 188 m compound.
      const scale = (W - 20) / 188;
      toScreen = (x, z) => [W / 2 + x * scale, W / 2 + z * scale];
      ctx.fillStyle = "rgba(90,105,80,0.25)";
      const [px0, pz0] = toScreen(-78, -94);
      ctx.fillRect(px0, pz0, 156 * scale, 188 * scale);
      ctx.fillStyle = "rgba(60,62,60,0.8)";
      for (const [x, z, w, d] of [[0, -88, 150, 6], [0, 88, 150, 6], [-72, 0, 6, 176], [72, 0, 6, 176], [0, -31, 140, 5], [0, 31, 140, 5], [0, -61, 5, 54], [5, 45.5, 5, 27]]) {
        const [sx, sz] = toScreen(x - w / 2, z - d / 2);
        ctx.fillRect(sx, sz, w * scale, d * scale);
      }
      ctx.strokeStyle = "rgba(217,223,210,0.35)";
      const [yx, yz] = toScreen(-26, -27);
      ctx.strokeRect(yx, yz, 52 * scale, 54 * scale);
      ctx.fillStyle = "rgba(60,150,170,0.6)";
      const [qx, qz] = toScreen(-24, 37.5);
      ctx.fillRect(qx, qz, 20 * scale, 10 * scale);
      for (const b of BUILDING_FOOTPRINTS) {
        const [bx, bz] = toScreen(b.x - b.w / 2, b.z - b.d / 2);
        ctx.fillStyle = "rgba(150,160,155,0.32)";
        ctx.fillRect(bx, bz, b.w * scale, b.d * scale);
        ctx.strokeStyle = "rgba(217,223,210,0.6)";
        ctx.strokeRect(bx, bz, b.w * scale, b.d * scale);
        ctx.fillStyle = "rgba(217,223,210,0.7)";
        ctx.font = "500 13px 'IBM Plex Mono', monospace";
        ctx.textAlign = "center";
        ctx.fillText(b.name.split(" ")[0], bx + (b.w * scale) / 2, bz + (b.d * scale) / 2 + 4);
      }
      ctx.strokeStyle = "rgba(217,223,210,0.5)";
      ctx.lineWidth = 2;
      ctx.strokeRect(px0, pz0, 156 * scale, 188 * scale);
      this.caption.textContent = "CAMPUS";
    }
    const floorY = c ? c.elevation : 0;
    for (const m of markers) {
      if (c && Math.abs(m.y - floorY) > 1.5) continue;
      if (!c && m.y > 1) continue;
      const [x, z] = toScreen(m.x, m.z);
      if (x < 0 || z < 0 || x > W || z > W) continue;
      ctx.fillStyle = m.locked ? "rgba(236,87,59,0.85)" : m.open ? "rgba(112,220,149,0.9)" : "rgba(227,199,122,0.85)";
      ctx.fillRect(x - 3, z - 3, 6, 6);
    }
    if (showGuards) {
      for (const g of guards) {
        if (c && Math.abs(g.y - floorY) > 2) continue;
        const [x, z] = toScreen(g.x, g.z);
        ctx.fillStyle = g.alert ? "#ff3b30" : "#e7d678";
        ctx.beginPath();
        ctx.arc(x, z, 5, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    const [sx, sz] = toScreen(player.x, player.z);
    ctx.save();
    ctx.translate(sx, sz);
    ctx.rotate(-yaw);
    ctx.fillStyle = "#e3c77a";
    ctx.beginPath();
    ctx.moveTo(0, -12);
    ctx.lineTo(8, 9);
    ctx.lineTo(0, 4);
    ctx.lineTo(-8, 9);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }
}
