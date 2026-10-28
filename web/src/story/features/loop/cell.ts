import {
  BoxGeometry, CanvasTexture, Color, Group, Mesh, MeshBasicMaterial, MeshStandardMaterial, PlaneGeometry, SRGBColorSpace, Vector3,
} from "three";
import { markInteractable, type Interactable } from "../../../interact/interactable";
import { PARTH_SPAWN_LOCAL, PARTH_SPAWN_YAW } from "../../../world/campus/cell";
import type { Game } from "../../../game/game";
import type { WallEntry } from "../../types";

/**
 * N03 in its own frame (world/campus/cell.ts, prisonCell: +X is the barred
 * front, X spans 5.7 m, Z 5.0 m, origin on the floor). Derived from the
 * `parth_spawn` anchor so the cell can move without touching this file.
 */
export class CellFrame {
  readonly origin: Vector3;
  readonly yaw: number;

  constructor(spawn: { position: Vector3; yaw: number }) {
    this.yaw = spawn.yaw - PARTH_SPAWN_YAW;
    this.origin = spawn.position.clone().sub(this.dir(PARTH_SPAWN_LOCAL));
  }

  /** Local → world direction (no translation). */
  dir(local: Vector3, out = new Vector3()): Vector3 {
    const c = Math.cos(this.yaw);
    const s = Math.sin(this.yaw);
    return out.set(c * local.x + s * local.z, local.y, -s * local.x + c * local.z);
  }

  toWorld(x: number, y: number, z: number): Vector3 {
    return this.dir(new Vector3(x, y, z)).add(this.origin);
  }

  /** Player yaw that looks along a local direction (player forward = (−sin yaw, −cos yaw)). */
  facing(localX: number, localZ: number): number {
    const d = this.dir(new Vector3(localX, 0, localZ));
    return Math.atan2(-d.x, -d.z);
  }
}

// Cell geometry this file decorates (keep in step with prisonCell).
const REAR_FACE = -2.75;
// The rendered concrete face sits a few centimetres proud of the nominal box face.
const WALL_X = REAR_FACE + 0.085;
/** The writable rear wall above the bunk: local z span and height. */
const WALL = { z0: 2.38, z1: -2.38, y0: 0.8, y1: 3.42 };
/** Under the bunk, between its two wall brackets. */
const TALLY = { z0: -0.4, z1: -1.6, y0: 0.04, y1: 0.3 };
/** The privacy wall hides the rear wall behind the toilet below this height (local z > 0.41). */
const NOOK = { z: 0.41, y: 1.62 };

/** Deterministic jitter so the scratches don't crawl when the wall is redrawn. */
function rng(seed: number): () => number {
  let s = seed >>> 0 || 1;
  return () => {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

function hash(text: string): number {
  let h = 2166136261;
  for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619);
  return h >>> 0;
}

const SCRATCH = "rgba(222, 218, 204, ";
const GOUGE = "rgba(28, 26, 22, ";
const HAND = '"Bradley Hand", "Segoe Print", "Comic Sans MS", cursive';

/** Hand-gouged text: per-glyph jitter, drawn twice slightly offset. Returns the advance width. */
function scratchText(ctx: CanvasRenderingContext2D, text: string, x: number, y: number, size: number, alpha: number, seed: number): number {
  const r = rng(seed);
  ctx.font = `600 ${size}px ${HAND}`;
  let cx = x;
  for (const ch of text) {
    const w = ctx.measureText(ch).width;
    if (ch !== " ") {
      const jx = (r() - 0.5) * size * 0.06;
      const jy = (r() - 0.5) * size * 0.08;
      const rot = (r() - 0.5) * 0.12;
      // A dark lip under the gouge, then the pale scratch twice, slightly apart.
      for (const [dx, dy, color] of [
        [size * 0.035, size * 0.045, `${GOUGE}${alpha * 0.5})`],
        [0, 0, `${SCRATCH}${alpha * 0.9})`],
        [1.2, 0.8, `${SCRATCH}${alpha * 0.45})`],
      ] as const) {
        ctx.save();
        ctx.translate(cx + jx + dx, y + jy + dy);
        ctx.rotate(rot);
        ctx.fillStyle = color;
        ctx.fillText(ch, 0, 0);
        ctx.restore();
      }
    }
    cx += w * 0.98;
  }
  return cx - x;
}

function wrap(ctx: CanvasRenderingContext2D, text: string, size: number, width: number): string[] {
  ctx.font = `600 ${size}px ${HAND}`;
  const lines: string[] = [];
  let line = "";
  for (const word of text.split(/\s+/)) {
    const next = line ? `${line} ${word}` : word;
    if (line && ctx.measureText(next).width > width) {
      lines.push(line);
      line = word;
    } else line = next;
  }
  if (line) lines.push(line);
  return lines;
}

function scratchMaterial(texture: CanvasTexture, prepare: (m: MeshStandardMaterial) => void): MeshStandardMaterial {
  const m = new MeshStandardMaterial({
    map: texture,
    emissiveMap: texture,
    emissive: new Color(0xffffff),
    emissiveIntensity: 0.1,
    transparent: true,
    alphaTest: 0.04,
    roughness: 0.95,
    depthWrite: false,
    polygonOffset: true,
    polygonOffsetFactor: -2,
  });
  prepare(m);
  return m;
}

export interface WallContent {
  entries: WallEntry[];
  codes: string[];
  faded: string[];
  entryFormat: (e: WallEntry) => string;
  cycleFormat: (e: WallEntry) => string;
  codeFormat: (code: string) => string;
}

/**
 * The tally under the bunk (one scratch per past cycle, in fives) and the rear
 * wall where every recovered fragment is scratched (runtime canvas textures).
 */
export class CellMarks {
  readonly group = new Group();
  private tallyCanvas = document.createElement("canvas");
  private wallCanvas = document.createElement("canvas");
  private tallyTex: CanvasTexture;
  private wallTex: CanvasTexture;
  private tallyCount = -1;
  private wallKey = "";

  constructor(
    private frame: CellFrame,
    prepare: (m: MeshStandardMaterial) => void,
  ) {
    this.tallyCanvas.width = 1024;
    this.tallyCanvas.height = 256;
    this.wallCanvas.width = 2048;
    this.wallCanvas.height = Math.round((2048 * (WALL.y1 - WALL.y0)) / (WALL.z0 - WALL.z1));
    this.tallyTex = new CanvasTexture(this.tallyCanvas);
    this.wallTex = new CanvasTexture(this.wallCanvas);
    for (const t of [this.tallyTex, this.wallTex]) {
      t.colorSpace = SRGBColorSpace;
      t.anisotropy = 4;
    }
    this.group.add(this.plane(TALLY, this.tallyTex, prepare, "N03 tally"), this.plane(WALL, this.wallTex, prepare, "N03 wall"));
  }

  /** A plane on the rear wall's inner face; canvas left = local +z (the viewer's left facing the wall). */
  private plane(r: { z0: number; z1: number; y0: number; y1: number }, tex: CanvasTexture, prepare: (m: MeshStandardMaterial) => void, name: string): Mesh {
    const mesh = new Mesh(new PlaneGeometry(r.z0 - r.z1, r.y1 - r.y0), scratchMaterial(tex, prepare));
    mesh.name = name;
    mesh.position.copy(this.frame.toWorld(WALL_X, (r.y0 + r.y1) / 2, (r.z0 + r.z1) / 2));
    mesh.rotation.y = this.frame.yaw + Math.PI / 2;
    mesh.renderOrder = 2;
    return mesh;
  }

  /** World point at the tally's centre (for the wake camera). */
  tallyPoint(): Vector3 {
    return this.frame.toWorld(REAR_FACE, (TALLY.y0 + TALLY.y1) / 2, (TALLY.z0 + TALLY.z1) / 2);
  }

  setTally(count: number): void {
    if (count === this.tallyCount) return;
    this.tallyCount = count;
    const c = this.tallyCanvas;
    const ctx = c.getContext("2d")!;
    ctx.clearRect(0, 0, c.width, c.height);
    const groups = Math.ceil(count / 5);
    const perRow = Math.max(5, Math.ceil(groups / Math.max(1, Math.ceil(groups / 5))));
    const rows = Math.max(1, Math.ceil(groups / perRow));
    const rowH = c.height / rows;
    const groupW = c.width / perRow;
    const r = rng(41);
    ctx.lineCap = "round";
    for (let i = 0; i < count; i++) {
      const g = Math.floor(i / 5);
      const k = i % 5;
      const gx = (g % perRow) * groupW + groupW * 0.14;
      const gy = Math.floor(g / perRow) * rowH;
      const top = gy + rowH * (0.14 + r() * 0.06);
      const bottom = gy + rowH * (0.86 - r() * 0.06);
      // The newest mark is fresher (paler, deeper).
      const fresh = i === count - 1 ? 1 : 0.78;
      let a: [number, number];
      let b: [number, number];
      if (k < 4) {
        const x = gx + k * groupW * 0.17 + (r() - 0.5) * 4;
        a = [x + (r() - 0.5) * 6, top];
        b = [x + (r() - 0.5) * 6, bottom];
      } else {
        a = [gx - groupW * 0.06, bottom - rowH * 0.1];
        b = [gx + groupW * 0.62, top + rowH * 0.1];
      }
      const width = Math.max(4, rowH * 0.06);
      for (const [off, color] of [
        [width * 0.7, `${GOUGE}0.55)`],
        [0, `${SCRATCH}${fresh})`],
      ] as const) {
        ctx.strokeStyle = color;
        ctx.lineWidth = width;
        ctx.beginPath();
        ctx.moveTo(a[0] + off, a[1] + off);
        ctx.lineTo(b[0] + off, b[1] + off);
        ctx.stroke();
      }
    }
    this.tallyTex.needsUpdate = true;
  }

  setWall(w: WallContent): void {
    const key = JSON.stringify([w.entries.map((e) => [e.id, e.text, e.cycle]), w.codes, w.faded]);
    if (key === this.wallKey) return;
    this.wallKey = key;
    const c = this.wallCanvas;
    const ctx = c.getContext("2d")!;
    ctx.clearRect(0, 0, c.width, c.height);
    ctx.textBaseline = "alphabetic";
    const pxPerM = c.width / (WALL.z0 - WALL.z1);
    // Canvas-space rectangle hidden behind the toilet's privacy wall.
    const nookRight = (WALL.z0 - NOOK.z) * pxPerM;
    const nookTop = (WALL.y1 - NOOK.y) * pxPerM;

    // Older layers, half scraped away.
    w.faded.forEach((text, i) => {
      const r = rng(hash(text) + i);
      const size = 46 + r() * 30;
      const x = 80 + r() * (c.width - 520);
      let y = 120 + r() * (c.height - 200);
      if (x < nookRight && y > nookTop - 20) y = nookTop - 40 - r() * 200;
      const width = scratchText(ctx, text, x, y, size, 0.2, hash(text));
      if (r() < 0.5) {
        ctx.strokeStyle = `${SCRATCH}0.18)`;
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.moveTo(x - 10, y - size * 0.35);
        ctx.lineTo(x + width + 10, y - size * 0.2);
        ctx.stroke();
      }
    });

    // Codes: big, deep, top right (the first thing a thumb finds).
    let codeY = 150;
    for (const code of w.codes) {
      const text = w.codeFormat(code);
      ctx.font = `600 120px ${HAND}`;
      const width = ctx.measureText(text).width;
      scratchText(ctx, text, c.width - width - 90, codeY, 120, 1, hash(code));
      codeY += 140;
    }

    // Entries flow in columns, oldest first, skipping the hidden nook and the codes.
    const colW = (c.width - 160) / 3;
    const size = 54;
    const lineH = size * 1.15;
    let col = 0;
    let y = 110;
    const colX = (i: number) => 80 + i * colW;
    const bottomFor = (i: number) => (colX(i) < nookRight ? nookTop - 30 : c.height - 40);
    const topFor = (i: number) => (i === 2 && w.codes.length ? codeY + 10 : 110);
    y = topFor(0);
    for (const e of w.entries) {
      const lines = wrap(ctx, w.entryFormat(e), size, colW - 70);
      const height = lines.length * lineH + 36;
      while (col < 3 && y + height > bottomFor(col)) {
        col++;
        y = topFor(col);
      }
      if (col >= 3) break;
      const r = rng(hash(e.id));
      const x = colX(col) + r() * 24;
      lines.forEach((line, i) => scratchText(ctx, line, x, y + i * lineH + size, size, 0.95, hash(e.id) + i));
      scratchText(ctx, w.cycleFormat(e), x + 4, y + lines.length * lineH + size + 4, 30, 0.6, hash(e.id) ^ 7);
      y += height + 24 + r() * 16;
    }
    this.wallTex.needsUpdate = true;
  }
}

/** An E target over a region of the cell, with no visible mesh of its own. */
export class CellHotspot implements Interactable {
  readonly root = new Group();

  constructor(
    frame: CellFrame,
    center: [number, number, number],
    size: [number, number, number],
    private prompt: () => string,
    private onUse: () => void,
  ) {
    const hit = new Mesh(new BoxGeometry(size[0], size[1], size[2]), new MeshBasicMaterial({ visible: false }));
    this.root.add(hit);
    this.root.position.copy(frame.toWorld(...center));
    this.root.rotation.y = frame.yaw;
    markInteractable(this.root, this);
  }

  getInteractionPrompt(): string {
    return this.prompt();
  }

  interact(): void {
    if (this.prompt()) this.onUse();
  }
}

/** Hotspots: the wall above the bunk, and the toilet cistern (stash). */
export const HOTSPOTS = {
  wall: { center: [REAR_FACE + 0.08, 1.75, -1.0] as [number, number, number], size: [0.14, 1.7, 2.6] as [number, number, number] },
  cistern: { center: [-2.4, 0.78, 2.04] as [number, number, number], size: [0.62, 0.62, 0.42] as [number, number, number] },
};

/** Camera marks for the wake sequence (cell-local). */
export const CELL_SHOTS = {
  lying: { eye: [-2.2, 0.98, -1.5], look: [-0.9, 3.1, -0.7] },
  sitting: { eye: [-1.8, 1.32, -0.8], look: [0.6, 1.25, -0.2] },
  tally: { eye: [-1.0, 0.3, -1.0], look: [REAR_FACE, 0.15, -1.0] },
} as const;

export function standingPose(game: Game, frame: CellFrame): { feet: Vector3; yaw: number } {
  const spawn = game.anchors.get("parth_spawn")!;
  return { feet: spawn.position.clone(), yaw: frame.facing(-1, -0.12) };
}
