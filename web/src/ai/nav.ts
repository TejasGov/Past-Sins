import { BufferGeometry, Float32BufferAttribute, LineBasicMaterial, LineSegments, Vector3 } from "three";
import { Layer, RAPIER, groups, type Physics } from "../physics/physics";
import type { Door } from "../interact/door";
import type { BuiltFloor } from "../world/campus/blueprintFloor";
import type { NavExport, NavRegion } from "../world/nav";

/** A point on a guard path; `door` is the door crossed on the way to it. */
export interface NavWaypoint {
  p: Vector3;
  door: Door | null;
}

interface NavEdge {
  to: number;
  cost: number;
  door: Door | null;
}

interface NavNode {
  p: Vector3;
  edges: NavEdge[];
  /** Auto-link reach in metres (0 = explicit links only). */
  reach: number;
  /** Nodes of one structure (a grid, a room, a stair) are linked explicitly; auto-link skips them. */
  group: number;
  dead: boolean;
}

interface EdgeHit {
  a: number;
  b: number;
  /** Closest point on the edge. */
  q: Vector3;
  door: Door | null;
}

export interface NavSources {
  physics: Physics;
  data: NavExport | undefined;
  floors: Map<string, BuiltFloor>;
  doors: Door[];
  /** True when the point is under a roof (exterior grids skip interiors). */
  sheltered: (p: Vector3) => boolean;
}

// Validation capsule: guard-sized, lifted clear of the floor so stair treads
// and the KCC's 0.3 m autostep don't count as obstacles.
const LIFT = 1.0;
const HALF = 0.4;
const RADIUS = 0.28;
/** Largest height change auto-linked or walked straight (anything more is a stair). */
const MAX_STEP_Y = 0.45;
const REACH = 2.6;
const EXTERIOR_REACH = 7;
const CELL = 4;
const STATIC_ONLY = groups(0xffff, Layer.STATIC);
const FLAGS = RAPIER.QueryFilterFlags.EXCLUDE_SENSORS;
const UP = new Vector3(0, 1, 0);
const NO_ROOM = new Set(["stair", "lift", "void"]);

/** Rapier queries against static geometry only (doors open, so they never block a link). */
class Probe {
  private readonly capsule = new RAPIER.Capsule(HALF, RADIUS);
  private readonly rot = { x: 0, y: 0, z: 0, w: 1 };
  private readonly down = new RAPIER.Ray({ x: 0, y: 0, z: 0 }, { x: 0, y: -1, z: 0 });
  private readonly los = new RAPIER.Ray({ x: 0, y: 0, z: 0 }, { x: 0, y: 0, z: 1 });

  constructor(private readonly world: RAPIER.World) {}

  /** Floor height under (x, z), searched from y + above down to y - below. */
  floor(x: number, y: number, z: number, above = 0.5, below = 0.6): number | null {
    this.down.origin = { x, y: y + above, z };
    const hit = this.world.castRay(this.down, above + below, true, FLAGS, STATIC_ONLY);
    return hit ? y + above - hit.timeOfImpact : null;
  }

  /** A guard can stand at p. */
  fits(p: Vector3): boolean {
    return this.world.intersectionWithShape({ x: p.x, y: p.y + LIFT, z: p.z }, this.rot, this.capsule, FLAGS, STATIC_ONLY) === null;
  }

  /** A guard can walk the straight line a → b without touching walls, rails or furniture. */
  sweep(a: Vector3, b: Vector3): boolean {
    const vel = { x: b.x - a.x, y: b.y - a.y, z: b.z - a.z };
    return this.world.castShape({ x: a.x, y: a.y + LIFT, z: a.z }, this.rot, vel, this.capsule, 0, 1, true, FLAGS, STATIC_ONLY) === null;
  }

  /** Floor under every half metre of a → b near the straight line: no voids or drops. */
  grounded(a: Vector3, b: Vector3): boolean {
    const n = Math.floor(Math.hypot(b.x - a.x, b.z - a.z) / 0.5);
    for (let i = 1; i <= n; i++) {
      const t = i / (n + 1);
      const y = a.y + (b.y - a.y) * t;
      if (this.floor(a.x + (b.x - a.x) * t, y, a.z + (b.z - a.z) * t) === null) return false;
    }
    return true;
  }

  /** Clear chest-height ray (attaching an off-graph point to the graph). */
  ray(a: Vector3, b: Vector3): boolean {
    this.los.origin = { x: a.x, y: a.y + 0.9, z: a.z };
    this.los.dir = { x: b.x - a.x, y: b.y - a.y, z: b.z - a.z };
    return this.world.castRay(this.los, 1, true, FLAGS, STATIC_ONLY) === null;
  }
}

function key(ix: number, iz: number): number {
  return (ix + 4096) * 8192 + (iz + 4096);
}

/** Min-heap of node ids keyed by f-score. */
class Heap {
  private ids: number[] = [];
  private fs: number[] = [];
  get size(): number {
    return this.ids.length;
  }
  clear(): void {
    this.ids.length = 0;
    this.fs.length = 0;
  }
  push(id: number, f: number): void {
    const ids = this.ids;
    const fs = this.fs;
    let i = ids.length;
    ids.push(id);
    fs.push(f);
    while (i > 0) {
      const p = (i - 1) >> 1;
      if (fs[p] <= f) break;
      ids[i] = ids[p];
      fs[i] = fs[p];
      i = p;
    }
    ids[i] = id;
    fs[i] = f;
  }
  peekF(): number {
    return this.fs[0];
  }
  pop(): number {
    const ids = this.ids;
    const fs = this.fs;
    const top = ids[0];
    const lastId = ids.pop()!;
    const lastF = fs.pop()!;
    const n = ids.length;
    if (n > 0) {
      let i = 0;
      for (;;) {
        const l = 2 * i + 1;
        if (l >= n) break;
        const r = l + 1;
        const c = r < n && fs[r] < fs[l] ? r : l;
        if (fs[c] >= lastF) break;
        ids[i] = ids[c];
        fs[i] = fs[c];
        i = c;
      }
      ids[i] = lastId;
      fs[i] = lastF;
    }
    return top;
  }
}

/**
 * Guard waypoint graph built from what the world builder already knows:
 * walkable grids for open-plan areas and the outdoors (navRegion hooks), every
 * floor-plan room, stair flights / switchback landings (navPath hooks), and a
 * crossing through every door, gate and open threshold. All links are checked
 * with a guard-sized capsule sweep and floor probes against the Rapier world,
 * so railings, voids and furniture are respected. A* over it gives PURSUE /
 * SEARCH / patrol routes across storeys and between buildings.
 */
export class NavGraph {
  readonly nodes: NavNode[] = [];
  private readonly hash = new Map<number, number[]>();
  private readonly doorHash = new Map<number, Door[]>();
  private readonly probe: Probe;
  private groupCount = 0;
  private component = new Int32Array(0);
  /** `blocked`: recorded landing segments dropped because a guard can't walk them (e.g. headroom). */
  readonly stats = { nodes: 0, edges: 0, doorEdges: 0, components: 0, largest: 0, blocked: 0, ms: 0 };
  // A* scratch, reused between queries.
  private g = new Float64Array(0);
  private parent = new Int32Array(0);
  private via: (Door | null)[] = [];
  private seen = new Uint32Array(0);
  private closed = new Uint32Array(0);
  private gen = 0;
  private heap = new Heap();

  private constructor(physics: Physics, doors: Door[]) {
    this.probe = new Probe(physics.world);
    for (const d of doors) {
      const k = key(Math.floor(d.position.x / CELL), Math.floor(d.position.z / CELL));
      let list = this.doorHash.get(k);
      if (!list) this.doorHash.set(k, (list = []));
      list.push(d);
    }
  }

  static build(src: NavSources): NavGraph {
    const t0 = performance.now();
    const nav = new NavGraph(src.physics, src.doors);
    for (const r of src.data?.regions ?? []) nav.addRegion(r, src.sheltered);
    for (const floor of src.floors.values()) nav.addFloor(floor, src.sheltered);
    for (const path of src.data?.paths ?? []) nav.addPath(path.points, path.tag);
    for (const door of src.doors) {
      const s = door.spec;
      nav.addCrossing(s.position, new Vector3(Math.sin(s.yaw), 0, Math.cos(s.yaw)), 1.8, 1.0, door, src.sheltered);
    }
    nav.weld();
    nav.autoLink();
    nav.tagDoors();
    nav.finish();
    nav.stats.ms = Math.round(performance.now() - t0);
    return nav;
  }

  // ── Construction ──────────────────────────────────────────────────────────
  private addNode(p: Vector3, reach: number, group: number): number {
    const id = this.nodes.length;
    this.nodes.push({ p, edges: [], reach, group, dead: false });
    const k = key(Math.floor(p.x / CELL), Math.floor(p.z / CELL));
    let list = this.hash.get(k);
    if (!list) this.hash.set(k, (list = []));
    list.push(id);
    return id;
  }

  private linked(a: number, b: number): NavEdge | undefined {
    return this.nodes[a].edges.find((e) => e.to === b);
  }

  private link(a: number, b: number, door: Door | null = null, cost?: number): void {
    if (a === b || a < 0 || b < 0 || this.linked(a, b)) return;
    const c = cost ?? this.nodes[a].p.distanceTo(this.nodes[b].p) + (door ? 0.5 : 0);
    this.nodes[a].edges.push({ to: b, cost: c, door });
    this.nodes[b].edges.push({ to: a, cost: c, door });
  }

  /** Validated link: small height change, clear capsule sweep, floor all the way (optional). */
  private tryLink(a: number, b: number, ground: boolean): boolean {
    const A = this.nodes[a].p;
    const B = this.nodes[b].p;
    if (Math.abs(A.y - B.y) > MAX_STEP_Y) return false;
    if (!this.probe.sweep(A, B)) return false;
    if (ground && !this.probe.grounded(A, B)) return false;
    this.link(a, b);
    return true;
  }

  /** Floor-snapped node position, or null if there's no floor near `y` or no room to stand. */
  private stand(x: number, y: number, z: number, tolerance = 0.35, needFit = true): Vector3 | null {
    const f = this.probe.floor(x, y, z, 0.6, 0.6);
    if (f === null || Math.abs(f - y) > tolerance) return null;
    const p = new Vector3(x, f, z);
    return !needFit || this.probe.fits(p) ? p : null;
  }

  /** Grid over a navRegion; 8-neighbour links need a clear sweep and floor underneath. */
  private addRegion(r: NavRegion, sheltered: (p: Vector3) => boolean): void {
    const axis = (lo: number, hi: number, align: number) => {
      const out: number[] = [];
      for (let v = align + Math.ceil((lo - align) / r.spacing - 1e-6) * r.spacing; v <= hi + 1e-6; v += r.spacing) out.push(v);
      return out;
    };
    const xs = axis(r.x0, r.x1, r.align[0]);
    const zs = axis(r.z0, r.z1, r.align[1]);
    const c = Math.cos(r.yaw);
    const s = Math.sin(r.yaw);
    const group = this.groupCount++;
    const grid = new Int32Array(xs.length * zs.length).fill(-1);
    for (let i = 0; i < xs.length; i++) {
      for (let j = 0; j < zs.length; j++) {
        const wx = r.origin.x + c * xs[i] + s * zs[j];
        const wz = r.origin.z - s * xs[i] + c * zs[j];
        const p = this.stand(wx, r.origin.y + r.y, wz);
        if (!p || (r.exterior && sheltered(p))) continue;
        grid[i * zs.length + j] = this.addNode(p, r.exterior ? EXTERIOR_REACH : REACH, group);
      }
    }
    for (let i = 0; i < xs.length; i++) {
      for (let j = 0; j < zs.length; j++) {
        const a = grid[i * zs.length + j];
        if (a < 0) continue;
        for (const [di, dj] of [[1, 0], [0, 1], [1, 1], [1, -1]]) {
          const ii = i + di;
          const jj = j + dj;
          if (ii >= xs.length || jj < 0 || jj >= zs.length) continue;
          const b = grid[ii * zs.length + jj];
          if (b >= 0) this.tryLink(a, b, true);
        }
      }
    }
  }

  /** Floor plan: a small grid per room (rooms are convex, walls only open at thresholds). */
  private addFloor(floor: BuiltFloor, sheltered: (p: Vector3) => boolean): void {
    const inset = 0.55;
    for (const r of floor.plan.rooms) {
      if (NO_ROOM.has(r.type)) continue;
      const nx = Math.max(1, Math.round((r.w - 2 * inset) / 2.4) + 1);
      const nz = Math.max(1, Math.round((r.d - 2 * inset) / 2.4) + 1);
      const at = (lo: number, size: number, n: number, i: number) => (n === 1 ? lo + size / 2 : lo + inset + ((size - 2 * inset) * i) / (n - 1));
      const group = this.groupCount++;
      const grid = new Int32Array(nx * nz).fill(-1);
      for (let i = 0; i < nx; i++) {
        for (let j = 0; j < nz; j++) {
          const w = floor.toWorld(floor.point(at(r.x, r.w, nx, i), at(r.y, r.d, nz, j)));
          const p = this.stand(w.x, w.y, w.z);
          if (p) grid[i * nz + j] = this.addNode(p, 0, group);
        }
      }
      for (let i = 0; i < nx; i++) {
        for (let j = 0; j < nz; j++) {
          const a = grid[i * nz + j];
          if (a < 0) continue;
          for (const [di, dj] of [[1, 0], [0, 1], [1, 1], [1, -1]]) {
            const ii = i + di;
            const jj = j + dj;
            if (ii >= nx || jj < 0 || jj >= nz) continue;
            const b = grid[ii * nz + jj];
            if (b >= 0) this.tryLink(a, b, false);
          }
        }
      }
    }
    // Doorless thresholds (stair rooms, open archways). Leafed doors come from the Door list.
    for (const d of floor.doors) {
      if (d.kind !== "open") continue;
      const c = floor.toWorld(d.position);
      const n = floor.toWorld(d.position.clone().add(d.normal)).sub(c);
      this.addCrossing(c, n, 1.0, 0.45, null, sheltered);
    }
  }

  /**
   * A crossing through an opening: near + far nodes on each side of the plane
   * through `center` (normal `n`). Missing floor drops a node; the outermost
   * node on each side auto-links to whatever is around it.
   */
  private addCrossing(center: Vector3, n: Vector3, far: number, near: number, door: Door | null, sheltered: (p: Vector3) => boolean): void {
    const side = (sign: number): number[] => {
      const ids: number[] = [];
      for (const [d, isFar] of [[near, false], [far, true]] as const) {
        const x = center.x + n.x * d * sign;
        const z = center.z + n.z * d * sign;
        const p = this.stand(x, center.y, z, 0.35, isFar);
        if (!p) break;
        ids.push(this.addNode(p, 0, group));
      }
      if (ids.length) {
        const outer = this.nodes[ids[ids.length - 1]];
        outer.reach = sheltered(outer.p) ? REACH : EXTERIOR_REACH;
      }
      return ids;
    };
    const group = this.groupCount++;
    const a = side(-1);
    const b = side(1);
    if (!a.length || !b.length) {
      for (const id of [...a, ...b]) this.kill(id);
      return;
    }
    this.link(a[1] ?? -1, a[0]);
    this.link(a[0], b[0], door);
    this.link(b[0], b[1] ?? -1);
  }

  /** Recorded polyline (stairs, landings): densified to ≤ 3 m, linked in order. */
  private addPath(points: Vector3[], tag: string): void {
    const stair = tag === "stair";
    const group = this.groupCount++;
    let prev = -1;
    for (let i = 0; i < points.length; i++) {
      const p = points[i];
      if (prev >= 0) {
        const from = this.nodes[prev].p.clone();
        const steps = Math.max(1, Math.ceil(from.distanceTo(p) / 3));
        for (let k = 1; k <= steps; k++) {
          const q = from.clone().lerp(p, k / steps);
          const end = k === steps;
          const id = this.addNode(q, stair && !(end && i === points.length - 1) ? 0 : REACH, group);
          // Flights are trusted (the sweep would graze the treads); landings must be clear,
          // e.g. a continuing stair's next mid landing leaves too little headroom below it.
          if (stair || this.probe.sweep(this.nodes[prev].p, q)) this.link(prev, id);
          else this.stats.blocked++;
          prev = id;
        }
      } else {
        prev = this.addNode(p.clone(), REACH, group);
      }
    }
  }

  private kill(id: number): void {
    const n = this.nodes[id];
    for (const e of n.edges) {
      const other = this.nodes[e.to];
      other.edges = other.edges.filter((x) => x.to !== id);
    }
    n.edges = [];
    n.dead = true;
    const k = key(Math.floor(n.p.x / CELL), Math.floor(n.p.z / CELL));
    const list = this.hash.get(k);
    if (list) this.hash.set(k, list.filter((x) => x !== id));
  }

  /** Node ids within horizontal radius r of p. */
  private near(p: Vector3, r: number, out: number[] = []): number[] {
    out.length = 0;
    const x0 = Math.floor((p.x - r) / CELL);
    const x1 = Math.floor((p.x + r) / CELL);
    const z0 = Math.floor((p.z - r) / CELL);
    const z1 = Math.floor((p.z + r) / CELL);
    const r2 = r * r;
    for (let ix = x0; ix <= x1; ix++) {
      for (let iz = z0; iz <= z1; iz++) {
        const list = this.hash.get(key(ix, iz));
        if (!list) continue;
        for (const id of list) {
          const q = this.nodes[id].p;
          const dx = q.x - p.x;
          const dz = q.z - p.z;
          if (dx * dx + dz * dz <= r2) out.push(id);
        }
      }
    }
    return out;
  }

  /** Merges coincident nodes from different sources (stair ends meeting thresholds, etc.). */
  private weld(): void {
    const scratch: number[] = [];
    for (let i = 0; i < this.nodes.length; i++) {
      const a = this.nodes[i];
      if (a.dead) continue;
      for (const j of this.near(a.p, 0.3, scratch).slice()) {
        if (j <= i) continue;
        const b = this.nodes[j];
        if (b.dead || Math.abs(b.p.y - a.p.y) > 0.3 || b.group === a.group) continue;
        const edges = b.edges.slice();
        this.kill(j);
        for (const e of edges) this.link(i, e.to, e.door);
        a.reach = Math.max(a.reach, b.reach);
      }
    }
  }

  /** Joins structures: every reaching node links to nearby nodes of other structures it can walk to. */
  private autoLink(): void {
    const scratch: number[] = [];
    for (let i = 0; i < this.nodes.length; i++) {
      const a = this.nodes[i];
      if (a.dead) continue;
      for (const j of this.near(a.p, EXTERIOR_REACH, scratch)) {
        if (j <= i) continue;
        const b = this.nodes[j];
        if (b.dead || b.group === a.group) continue;
        const reach = Math.max(a.reach, b.reach);
        if (reach === 0 || a.p.distanceTo(b.p) > reach || this.linked(i, j)) continue;
        this.tryLink(i, j, true);
      }
    }
  }

  private doorsNear(a: Vector3, b: Vector3, out: Door[] = []): Door[] {
    out.length = 0;
    const x0 = Math.floor((Math.min(a.x, b.x) - 4) / CELL);
    const x1 = Math.floor((Math.max(a.x, b.x) + 4) / CELL);
    const z0 = Math.floor((Math.min(a.z, b.z) - 4) / CELL);
    const z1 = Math.floor((Math.max(a.z, b.z) + 4) / CELL);
    for (let ix = x0; ix <= x1; ix++) for (let iz = z0; iz <= z1; iz++) out.push(...(this.doorHash.get(key(ix, iz)) ?? []));
    return out;
  }

  /** Does a → b pass through the door's opening? */
  private static crosses(door: Door, a: Vector3, b: Vector3): boolean {
    const s = door.spec;
    const nx = Math.sin(s.yaw);
    const nz = Math.cos(s.yaw);
    const da = (a.x - s.position.x) * nx + (a.z - s.position.z) * nz;
    const db = (b.x - s.position.x) * nx + (b.z - s.position.z) * nz;
    if (da * db > 0 || da === db) return false;
    const k = da / (da - db);
    const px = a.x + (b.x - a.x) * k - s.position.x;
    const py = a.y + (b.y - a.y) * k - s.position.y;
    const pz = a.z + (b.z - a.z) * k - s.position.z;
    const lateral = Math.abs(px * nz - pz * nx);
    return lateral <= s.width / 2 + 0.4 && py > -1 && py < s.height;
  }

  /** Any link that passes through a door opening remembers the door (guards open it on the way). */
  private tagDoors(): void {
    const scratch: Door[] = [];
    for (let i = 0; i < this.nodes.length; i++) {
      const a = this.nodes[i];
      for (const e of a.edges) {
        if (e.to < i || e.door) continue;
        const b = this.nodes[e.to];
        for (const d of this.doorsNear(a.p, b.p, scratch)) {
          if (!NavGraph.crosses(d, a.p, b.p)) continue;
          e.door = d;
          const back = b.edges.find((x) => x.to === i);
          if (back) back.door = d;
          break;
        }
      }
    }
  }

  private finish(): void {
    const n = this.nodes.length;
    this.g = new Float64Array(n);
    this.parent = new Int32Array(n);
    this.via = new Array(n).fill(null);
    this.seen = new Uint32Array(n);
    this.closed = new Uint32Array(n);
    this.component = new Int32Array(n).fill(-1);
    let components = 0;
    let largest = 0;
    const stack: number[] = [];
    for (let i = 0; i < n; i++) {
      const node = this.nodes[i];
      if (node.dead) continue;
      this.stats.nodes++;
      for (const e of node.edges) {
        if (e.to > i) {
          this.stats.edges++;
          if (e.door) this.stats.doorEdges++;
        }
      }
      if (this.component[i] >= 0 || node.edges.length === 0) continue;
      let size = 0;
      stack.push(i);
      this.component[i] = components;
      while (stack.length) {
        const u = stack.pop()!;
        size++;
        for (const e of this.nodes[u].edges) {
          if (this.component[e.to] < 0) {
            this.component[e.to] = components;
            stack.push(e.to);
          }
        }
      }
      largest = Math.max(largest, size);
      components++;
    }
    this.stats.components = components;
    this.stats.largest = largest;
  }

  /** Island id of the node nearest to p (diagnostics); -1 if off-graph. */
  islandAt(p: Vector3): number {
    const hit = this.locate(p);
    return hit ? this.component[hit.a] : -1;
  }

  // ── Queries ───────────────────────────────────────────────────────────────
  /** Nearest edge a point at `p` (feet) can reach in a straight line. */
  locate(p: Vector3): EdgeHit | null {
    const cands: { a: number; b: number; q: Vector3; score: number; door: Door | null }[] = [];
    for (const id of this.near(p, 6.5)) {
      const A = this.nodes[id].p;
      for (const e of this.nodes[id].edges) {
        if (e.to < id && this.nodes[e.to].p.distanceToSquared(p) < 42.25) continue; // seen from the other end
        const B = this.nodes[e.to].p;
        const abx = B.x - A.x;
        const abz = B.z - A.z;
        const len2 = abx * abx + abz * abz;
        const t = len2 < 1e-6 ? 0 : Math.min(1, Math.max(0, ((p.x - A.x) * abx + (p.z - A.z) * abz) / len2));
        const q = A.clone().lerp(B, t);
        const dy = p.y - q.y;
        if (dy < -1.0 || dy > 1.2) continue;
        const score = Math.hypot(p.x - q.x, p.z - q.z) + 2 * Math.abs(dy);
        if (score < 7) cands.push({ a: id, b: e.to, q, score, door: e.door });
      }
    }
    cands.sort((x, y) => x.score - y.score);
    for (let i = 0; i < Math.min(8, cands.length); i++) {
      const c = cands[i];
      if (c.score < 0.05 || this.probe.ray(p, c.q)) return c;
    }
    return null;
  }

  /** A* from `from` to `to` (feet positions). Null if either is off-graph or they're disconnected. */
  findPath(from: Vector3, to: Vector3): NavWaypoint[] | null {
    const s = this.locate(from);
    const t = this.locate(to);
    if (!s || !t) return null;
    if (this.component[s.a] !== this.component[t.a]) return null;
    const goal = to.clone();
    const tail = (u: number) => this.nodes[u].p.distanceTo(t.q) + t.q.distanceTo(goal);
    const sameEdge = (s.a === t.a && s.b === t.b) || (s.a === t.b && s.b === t.a);
    const out: NavWaypoint[] = [];
    if (!sameEdge) {
      const gen = ++this.gen;
      const heap = this.heap;
      heap.clear();
      const h = (u: number) => this.nodes[u].p.distanceTo(goal);
      for (const end of [s.a, s.b]) {
        const g0 = from.distanceTo(s.q) + s.q.distanceTo(this.nodes[end].p);
        if (this.seen[end] === gen && this.g[end] <= g0) continue;
        this.seen[end] = gen;
        this.g[end] = g0;
        this.parent[end] = -1;
        this.via[end] = s.door;
        heap.push(end, g0 + h(end));
      }
      let best = Infinity;
      let bestEnd = -1;
      while (heap.size) {
        if (heap.peekF() >= best) break;
        const u = heap.pop();
        if (this.closed[u] === gen) continue;
        this.closed[u] = gen;
        if (u === t.a || u === t.b) {
          const total = this.g[u] + tail(u);
          if (total < best) {
            best = total;
            bestEnd = u;
          }
        }
        for (const e of this.nodes[u].edges) {
          const v = e.to;
          if (this.closed[v] === gen) continue;
          const ng = this.g[u] + e.cost;
          if (this.seen[v] === gen && ng >= this.g[v]) continue;
          this.seen[v] = gen;
          this.g[v] = ng;
          this.parent[v] = u;
          this.via[v] = e.door;
          heap.push(v, ng + h(v));
        }
      }
      if (bestEnd < 0) return null;
      for (let u = bestEnd; u >= 0; u = this.parent[u]) out.push({ p: this.nodes[u].p, door: this.via[u] });
      out.reverse();
    }
    out.push({ p: t.q, door: t.door }, { p: goal, door: null });
    // Drop near-duplicates (the attach point often sits on a node).
    const path: NavWaypoint[] = [];
    for (const w of out) {
      const last = path[path.length - 1];
      if (last && last.p.distanceToSquared(w.p) < 0.09) {
        last.door ??= w.door;
        continue;
      }
      path.push(w);
    }
    return path;
  }

  /** A guard can walk straight from a to b right now (same level, clear, floored, no closed door). */
  walkable(a: Vector3, b: Vector3): boolean {
    if (Math.abs(a.y - b.y) > 0.5) return false;
    if (!this.probe.sweep(a, b) || !this.probe.grounded(a, b)) return false;
    for (const d of this.doorsNear(a, b)) if (!d.isOpen && NavGraph.crosses(d, a, b)) return false;
    return true;
  }

  /** Debug overlay: links in cyan, door crossings in orange. */
  debugLines(): LineSegments {
    const plain: number[] = [];
    const doors: number[] = [];
    for (let i = 0; i < this.nodes.length; i++) {
      const a = this.nodes[i].p;
      for (const e of this.nodes[i].edges) {
        if (e.to < i) continue;
        const b = this.nodes[e.to].p;
        (e.door ? doors : plain).push(a.x, a.y + 0.12, a.z, b.x, b.y + 0.12, b.z);
      }
    }
    const pos = [...plain, ...doors];
    const col: number[] = [];
    for (let i = 0; i < plain.length / 3; i++) col.push(0.2, 0.85, 1);
    for (let i = 0; i < doors.length / 3; i++) col.push(1, 0.55, 0.1);
    const g = new BufferGeometry();
    g.setAttribute("position", new Float32BufferAttribute(pos, 3));
    g.setAttribute("color", new Float32BufferAttribute(col, 3));
    const lines = new LineSegments(g, new LineBasicMaterial({ vertexColors: true, transparent: true, opacity: 0.85, toneMapped: false }));
    lines.renderOrder = 10;
    lines.frustumCulled = false;
    lines.name = "NavDebug";
    return lines;
  }

  /** Path as a polyline for the debug overlay. */
  static pathPoints(path: NavWaypoint[], from: Vector3): Vector3[] {
    return [from.clone(), ...path.map((w) => w.p.clone())].map((p) => p.add(UP.clone().multiplyScalar(0.2)));
  }
}
