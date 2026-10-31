import {
  Box3,
  BufferGeometry,
  Color,
  Float32BufferAttribute,
  DoubleSide,
  Group,
  InstancedMesh,
  Material,
  Matrix4,
  Mesh,
  MeshBasicMaterial,
  MeshStandardMaterial,
  Quaternion,
  Uint32BufferAttribute,
  Vector3,
} from "three";
import { computeBoundsTree } from "three-mesh-bvh";
import type { Physics } from "../physics/physics";
import { type MaterialKey, type MaterialLibrary, vertexColorFor, applyGrime } from "../render/materials";
import type { PropId, PropLibrary } from "./models";
import { SignAtlas } from "./signAtlas";
import type { Anchor, DoorSpec } from "./types";
import { NAV_ANCHOR, type NavExport } from "./nav";

export interface BoxOpts {
  mat?: MaterialKey;
  color?: number;
  /** Rapier collider (default true). */
  collide?: boolean;
  /** Included in the BVH used for line-of-sight / interaction blocking (default = collide). */
  occlude?: boolean;
  shadow?: boolean;
  /** Extra yaw on top of the current frame (radians). */
  yaw?: number;
  /** Full local rotation (overrides yaw). */
  quat?: Quaternion;
}

export interface PropOpts {
  /** Extra yaw on top of the current frame (radians). */
  yaw?: number;
  /** Tilt about the prop's own X then Z axes, e.g. a chair knocked onto its front. */
  pitch?: number;
  roll?: number;
  scale?: number | Vector3;
  /** Rapier box from the model's bounds (default false). */
  collide?: boolean;
  /** Include that box in the line-of-sight BVH (default false). */
  occlude?: boolean;
  shadow?: boolean;
  /** Replace the model's own glow with the game's diffuser (follows night switching and lights-out), or "off" for a dead tube. */
  glow?: "night" | "always" | "off";
}

interface PropInstance {
  id: PropId;
  matrix: Matrix4;
  chunk: string;
  glow?: "night" | "always" | "off";
  shadow: boolean;
}

export interface Fixture {
  position: Vector3;
  color: Color;
  intensity: number;
  range: number;
  /** Cellblock fixtures only light at night (Godot: automatic_night_light). */
  nightOnly: boolean;
  /** 0 = steady, otherwise flicker strength. */
  flicker: number;
  chunk: string;
}

interface Bucket {
  pos: number[];
  nor: number[];
  uv: number[];
  col: number[];
  idx: number[];
}

export interface ChunkInfo {
  name: string;
  interior: boolean;
  bounds: Box3;
  group: Group;
}

interface Frame {
  origin: Vector3;
  yaw: number;
}

const UP = new Vector3(0, 1, 0);
const _X = new Vector3(1, 0, 0);
const _Z = new Vector3(0, 0, 1);
const FACES: { n: [number, number, number]; u: [number, number, number]; v: [number, number, number] }[] = [
  { n: [1, 0, 0], u: [0, 0, -1], v: [0, 1, 0] },
  { n: [-1, 0, 0], u: [0, 0, 1], v: [0, 1, 0] },
  { n: [0, 1, 0], u: [1, 0, 0], v: [0, 0, -1] },
  { n: [0, -1, 0], u: [1, 0, 0], v: [0, 0, 1] },
  { n: [0, 0, 1], u: [1, 0, 0], v: [0, 1, 0] },
  { n: [0, 0, -1], u: [-1, 0, 0], v: [0, 1, 0] },
];

const _a = new Vector3();
const _b = new Vector3();
const _c = new Vector3();
const _n = new Vector3();
const _q = new Quaternion();
const _col = new Color();

function newBucket(): Bucket {
  return { pos: [], nor: [], uv: [], col: [], idx: [] };
}

/**
 * Port of Godot's greybox_factory + campus_furniture_batcher: every static box
 * is appended straight into a per-(chunk, material, shadow) vertex bucket, gets
 * a Rapier cuboid if it collides, and goes into a BVH proxy for raycasts.
 * Coordinates are local to a frame stack (push/pop), mirroring Godot node
 * hierarchies such as a rotated cell module inside a building.
 */
export class StaticBuilder {
  private frames: Frame[] = [{ origin: new Vector3(), yaw: 0 }];
  private buckets = new Map<string, Bucket>();
  private occPos: number[] = [];
  private occIdx: number[] = [];
  readonly fixtures: Fixture[] = [];
  readonly doors: DoorSpec[] = [];
  readonly anchors = new Map<string, Anchor>();
  readonly chunks = new Map<string, ChunkInfo>();
  /** Footprints the outer (beyond-the-wall) grass leaves out, e.g. the reservoir basin. */
  readonly terrainCutouts: { x: number; z: number; w: number; d: number }[] = [];
  /** Guard navigation data recorded alongside the geometry (see world/nav.ts). */
  readonly nav: NavExport = { paths: [], regions: [] };
  private chunk!: ChunkInfo;
  readonly atlas = new SignAtlas();
  private signMaterial: MeshStandardMaterial;
  private propInstances: PropInstance[] = [];
  colliderCount = 0;

  constructor(private physics: Physics, private materials: MaterialLibrary, prepare: (m: Material) => void, readonly props: PropLibrary) {
    this.signMaterial = new MeshStandardMaterial({
      map: this.atlas.texture,
      emissiveMap: this.atlas.texture,
      emissive: new Color(0xffffff),
      emissiveIntensity: 0.16,
      vertexColors: true,
      transparent: true,
      alphaTest: 0.35,
      roughness: 0.85,
      depthWrite: false,
      polygonOffset: true,
      polygonOffsetFactor: -2,
    });
    prepare(this.signMaterial);
    applyGrime(this.signMaterial, 0, false);
    this.setChunk("campus", false);
    this.anchors.set(NAV_ANCHOR, { position: new Vector3(), yaw: 0, data: this.nav as unknown as Record<string, unknown> });
  }

  setChunk(name: string, interior: boolean): void {
    let info = this.chunks.get(name);
    if (!info) {
      const group = new Group();
      group.name = `chunk:${name}`;
      info = { name, interior, bounds: new Box3(), group };
      this.chunks.set(name, info);
    }
    this.chunk = info;
  }

  get chunkName(): string {
    return this.chunk.name;
  }

  // ── Frame stack ────────────────────────────────────────────────────────────
  get frame(): Frame {
    return this.frames[this.frames.length - 1];
  }

  toWorld(local: Vector3, out = new Vector3()): Vector3 {
    const f = this.frame;
    const c = Math.cos(f.yaw);
    const s = Math.sin(f.yaw);
    return out.set(f.origin.x + c * local.x + s * local.z, f.origin.y + local.y, f.origin.z - s * local.x + c * local.z);
  }

  /** Direction (no translation) from the current frame into world space. */
  dirToWorld(local: Vector3, out = new Vector3()): Vector3 {
    const yaw = this.frame.yaw;
    const c = Math.cos(yaw);
    const s = Math.sin(yaw);
    return out.set(c * local.x + s * local.z, local.y, -s * local.x + c * local.z);
  }

  worldYaw(localYaw = 0): number {
    return this.frame.yaw + localYaw;
  }

  push(origin: Vector3, yaw = 0): void {
    this.frames.push({ origin: this.toWorld(origin), yaw: this.frame.yaw + yaw });
  }

  pop(): void {
    if (this.frames.length > 1) this.frames.pop();
  }

  within(origin: Vector3, yaw: number, fn: () => void): void {
    this.push(origin, yaw);
    try {
      fn();
    } finally {
      this.pop();
    }
  }

  /** Records a door/gate at a local position/yaw (converted to world space). */
  door(spec: Omit<DoorSpec, "position" | "yaw" | "chunk"> & { position: Vector3; yaw: number }): DoorSpec {
    const world: DoorSpec = { ...spec, position: this.toWorld(spec.position), yaw: this.worldYaw(spec.yaw), chunk: this.chunk.name };
    this.doors.push(world);
    if (spec.kind !== "door") {
      // Static key reader beside the opening; its LED is an instanced light.
      this.within(spec.position, spec.yaw, () => {
        this.box(new Vector3(spec.width / 2 + 0.12, 1.25, 0.12), new Vector3(0.18, 0.28, 0.12), { mat: "hazard", color: 0xd8b448, collide: false, shadow: false });
        this.box(new Vector3(spec.width / 2 + 0.12, 1.25, 0.185), new Vector3(0.14, 0.22, 0.02), { mat: "dark", color: 0x1f2422, collide: false, shadow: false });
      });
    }
    return world;
  }

  anchor(name: string, local: Vector3, yaw = 0, data?: Record<string, unknown>): Anchor {
    const a: Anchor = { position: this.toWorld(local), yaw: this.worldYaw(yaw), data };
    this.anchors.set(name, a);
    return a;
  }

  /** Nav export hook: a walkable polyline in local space (stair flights, landings). */
  navPath(points: Vector3[], tag = "path"): void {
    this.nav.paths.push({ points: points.map((p) => this.toWorld(p)), tag });
  }

  /** Nav export hook: a walkable floor rectangle (local x/z at local height y), sampled into a guard grid. */
  navRegion(x0: number, z0: number, x1: number, z1: number, y: number, opts: { spacing: number; align?: [number, number]; exterior?: boolean; tag?: string }): void {
    this.nav.regions.push({
      origin: this.toWorld(new Vector3()),
      yaw: this.worldYaw(0),
      x0, z0, x1, z1, y,
      spacing: opts.spacing,
      align: opts.align ?? [0, 0],
      exterior: opts.exterior ?? false,
      tag: opts.tag ?? "region",
    });
  }

  // ── Primitives ─────────────────────────────────────────────────────────────
  /** Exterior statics are split into 80 m cells so frustum culling (main view and each CSM cascade) can reject most of the campus. */
  private cellChunk(chunk: ChunkInfo, at?: Vector3): ChunkInfo {
    if (chunk.interior || !at) return chunk;
    const name = `${chunk.name}@${Math.floor(at.x / 80)},${Math.floor(at.z / 80)}`;
    let cell = this.chunks.get(name);
    if (!cell) {
      const group = new Group();
      group.name = `chunk:${name}`;
      cell = { name, interior: false, bounds: new Box3(), group };
      this.chunks.set(name, cell);
    }
    return cell;
  }

  private bucket(mat: MaterialKey, shadow: boolean, chunk = this.chunk, at?: Vector3): Bucket {
    chunk = this.cellChunk(chunk, at);
    const key = `${chunk.name}|${mat}|${shadow ? 1 : 0}`;
    let b = this.buckets.get(key);
    if (!b) {
      b = newBucket();
      this.buckets.set(key, b);
    }
    return b;
  }

  box(center: Vector3, size: Vector3, opts: BoxOpts = {}): void {
    const mat = opts.mat ?? "concrete";
    const collide = opts.collide ?? true;
    const occlude = opts.occlude ?? collide;
    const shadow = opts.shadow ?? !mat.startsWith("emissive");
    const worldCenter = this.toWorld(center);
    const q = new Quaternion().setFromAxisAngle(UP, this.frame.yaw);
    if (opts.quat) q.multiply(opts.quat);
    else if (opts.yaw) q.multiply(_q.setFromAxisAngle(UP, opts.yaw));
    const half = _c.copy(size).multiplyScalar(0.5).clone();
    const color = vertexColorFor(mat, opts.color ?? 0x9a9a92);
    appendBox(this.bucket(mat, shadow, this.chunk, worldCenter), worldCenter, half, q, color);
    this.expandBounds(worldCenter, half);
    if (collide) {
      this.physics.addStaticBoxQuat(worldCenter, half, q);
      this.colliderCount++;
    }
    if (occlude) appendBoxOccluder(this.occPos, this.occIdx, worldCenter, half, q);
  }

  /** Invisible collision (and optionally LOS) blocker; yaw or a full local rotation. */
  blocker(center: Vector3, size: Vector3, occlude = false, rotation: number | Quaternion = 0): void {
    const worldCenter = this.toWorld(center);
    const q = new Quaternion().setFromAxisAngle(UP, this.frame.yaw);
    if (typeof rotation === "number") q.multiply(_q.setFromAxisAngle(UP, rotation));
    else q.multiply(rotation);
    const half = size.clone().multiplyScalar(0.5);
    this.physics.addStaticBoxQuat(worldCenter, half, q);
    this.colliderCount++;
    if (occlude) appendBoxOccluder(this.occPos, this.occIdx, worldCenter, half, q);
  }

  cylinder(center: Vector3, radius: number, height: number, opts: BoxOpts = {}): void {
    const mat = opts.mat ?? "metal";
    const worldCenter = this.toWorld(center);
    const q = new Quaternion().setFromAxisAngle(UP, this.frame.yaw);
    if (opts.quat) q.multiply(opts.quat);
    const color = vertexColorFor(mat, opts.color ?? 0x8a8f8a);
    appendCylinder(this.bucket(mat, opts.shadow ?? true, this.chunk, worldCenter), worldCenter, radius, height, q, color, radius > 0.25 ? 16 : 10);
    this.expandBounds(worldCenter, new Vector3(radius, height / 2, radius));
    if (opts.collide ?? false) {
      this.physics.addStaticBoxQuat(worldCenter, new Vector3(radius * 0.85, height / 2, radius * 0.85), q);
      this.colliderCount++;
    }
  }

  /** Places a Poly Haven model (origin at floor contact, facing +Z) in the current frame. */
  prop(id: PropId, local: Vector3, opts: PropOpts = {}): void {
    const at = this.toWorld(local);
    const yaw = this.frame.yaw + (opts.yaw ?? 0);
    const q = new Quaternion().setFromAxisAngle(UP, yaw);
    if (opts.pitch) q.multiply(_q.setFromAxisAngle(_X, opts.pitch));
    if (opts.roll) q.multiply(_q.setFromAxisAngle(_Z, opts.roll));
    const s = typeof opts.scale === "number" ? new Vector3(opts.scale, opts.scale, opts.scale) : (opts.scale ?? new Vector3(1, 1, 1));
    const chunk = this.cellChunk(this.chunk, at);
    this.propInstances.push({ id, matrix: new Matrix4().compose(at, q, s), chunk: chunk.name, glow: opts.glow, shadow: opts.shadow ?? true });
    const size = this.props.size(id).clone().multiply(s);
    const half = size.clone().multiplyScalar(0.5);
    const centre = at.clone().add(new Vector3(0, half.y, 0));
    const r = Math.max(half.x, half.z);
    chunk.bounds.expandByPoint(_b.set(centre.x - r, at.y, centre.z - r));
    chunk.bounds.expandByPoint(_b.set(centre.x + r, at.y + size.y, centre.z + r));
    if (opts.collide) {
      this.physics.addStaticBoxQuat(centre, half, q);
      this.colliderCount++;
    }
    if (opts.occlude) appendBoxOccluder(this.occPos, this.occIdx, centre, half, q);
  }

  /** Godot greybox_factory.bar_between: an oriented square bar from a to b. */
  bar(start: Vector3, end: Vector3, thickness: number, opts: BoxOpts = {}): void {
    const length = start.distanceTo(end);
    if (length < 0.001) return;
    const quat = basisQuat(start, end);
    const mid = start.clone().add(end).multiplyScalar(0.5);
    this.box(mid, new Vector3(thickness, thickness, length), { collide: false, ...opts, quat });
  }

  /** Two rails + posts every ≤3 m and a single invisible 1.1 m collision fence. */
  railing(start: Vector3, end: Vector3, color = 0x3d4541, mat: MaterialKey = "metal"): void {
    const up = (v: Vector3, h: number) => v.clone().add(new Vector3(0, h, 0));
    this.bar(up(start, 1.05), up(end, 1.05), 0.07, { mat, color, collide: false });
    this.bar(up(start, 0.55), up(end, 0.55), 0.05, { mat, color, collide: false });
    const length = start.distanceTo(end);
    const posts = Math.max(2, Math.ceil(length / 3) + 1);
    for (let i = 0; i < posts; i++) {
      const p = start.clone().lerp(end, i / (posts - 1));
      this.box(up(p, 0.525), new Vector3(0.07, 1.05, 0.07), { mat, color, collide: false, shadow: true });
    }
    if (length > 0.05) {
      const mid = start.clone().add(end).multiplyScalar(0.5);
      this.blocker(up(mid, 0.55), new Vector3(0.1, 1.1, length), false, basisQuat(start, end));
    }
  }

  /** Convex ramp collider from local-space points (stair flights). */
  ramp(points: Vector3[]): void {
    this.physics.addStaticConvex(points.map((p) => this.toWorld(p)));
    this.colliderCount++;
  }

  /** Painted sign: a quad facing local +Z, Godot Label3D-sized. */
  sign(text: string, center: Vector3, yaw: number, color = 0xb8c8ca, pixelSize = 0.006): void {
    const rect = this.atlas.add(text);
    const h = SignAtlas.quadHeight(rect, pixelSize);
    const w = h * rect.aspect;
    const q = new Quaternion().setFromAxisAngle(UP, this.frame.yaw + yaw);
    const c = this.toWorld(center);
    const b = this.bucket("__sign" as MaterialKey, false, this.chunk, c);
    const base = b.pos.length / 3;
    const corners = [
      [-w / 2, -h / 2, rect.u0, rect.v0],
      [w / 2, -h / 2, rect.u1, rect.v0],
      [w / 2, h / 2, rect.u1, rect.v1],
      [-w / 2, h / 2, rect.u0, rect.v1],
    ];
    _n.set(0, 0, 1).applyQuaternion(q);
    _col.set(color);
    for (const [x, y, u, v] of corners) {
      _a.set(x, y, 0.012).applyQuaternion(q).add(c);
      b.pos.push(_a.x, _a.y, _a.z);
      b.nor.push(_n.x, _n.y, _n.z);
      b.uv.push(u, v);
      b.col.push(_col.r, _col.g, _col.b);
    }
    b.idx.push(base, base + 1, base + 2, base, base + 2, base + 3);
  }

  /** Ceiling fluorescent: batten model(s) whose tubes use the game's diffuser + a light-pool candidate. */
  fixture(center: Vector3, size: Vector3, opts: { nightOnly: boolean; color?: number; intensity?: number; range?: number; flicker?: number; backplate?: boolean; broken?: boolean }): void {
    const batten = this.props.size("mounted_fluorescent_lights");
    const alongX = size.x >= size.z;
    const length = alongX ? size.x : size.z;
    const width = alongX ? size.z : size.x;
    const tubes = width >= 0.15 ? 2 : 1;
    const glow = opts.broken ? "off" : opts.nightOnly ? "night" : "always";
    for (let i = 0; i < tubes; i++) {
      const across = tubes === 1 ? 0 : (i - 0.5) * Math.min(width - batten.z, 0.12);
      const at = center.clone().add(alongX ? new Vector3(0, size.y / 2 - batten.y, across) : new Vector3(across, size.y / 2 - batten.y, 0));
      this.prop("mounted_fluorescent_lights", at, { yaw: alongX ? 0 : Math.PI / 2, scale: new Vector3(length / batten.x, 1, 1), glow, shadow: false });
    }
    // A dead tube casts no light: it leaves a dark pocket.
    if (opts.broken) return;
    this.fixtures.push({
      position: this.toWorld(center.clone().add(new Vector3(0, -0.25, 0))),
      color: new Color(opts.color ?? 0xffdca0),
      intensity: opts.intensity ?? 6,
      range: opts.range ?? 11,
      nightOnly: opts.nightOnly,
      flicker: opts.flicker ?? 0,
      chunk: this.chunk.name,
    });
  }

  /** Light-pool candidate without a visual (e.g. cell wall lamp built separately). */
  lightPoint(local: Vector3, color: number, intensity: number, range: number, nightOnly: boolean, flicker = 0): void {
    this.fixtures.push({ position: this.toWorld(local), color: new Color(color), intensity, range, nightOnly, flicker, chunk: this.chunk.name });
  }

  private expandBounds(center: Vector3, half: Vector3): void {
    const r = Math.max(half.x, half.z);
    this.chunk.bounds.expandByPoint(_b.set(center.x - r, center.y - half.y, center.z - r));
    this.chunk.bounds.expandByPoint(_b.set(center.x + r, center.y + half.y, center.z + r));
  }

  // ── Output ─────────────────────────────────────────────────────────────────
  finalize(): { root: Group; occluder: Mesh; triangles: number; drawCalls: number } {
    const root = new Group();
    root.name = "StaticWorld";
    let triangles = 0;
    let drawCalls = 0;
    for (const [key, b] of this.buckets) {
      if (b.idx.length === 0) continue;
      const [chunkName, matKey, shadow] = key.split("|");
      const geo = new BufferGeometry();
      geo.setAttribute("position", new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute("normal", new Float32BufferAttribute(b.nor, 3));
      geo.setAttribute("uv", new Float32BufferAttribute(b.uv, 2));
      geo.setAttribute("color", new Float32BufferAttribute(b.col, 3));
      geo.setIndex(new Uint32BufferAttribute(b.idx, 1));
      geo.computeBoundingSphere();
      geo.computeBoundingBox();
      const interior = this.chunks.get(chunkName)?.interior ?? false;
      const material =
        matKey === "__sign"
          ? this.signMaterial
          : matKey === "emissive_night" && interior
            ? this.materials.nightFor(chunkName)
            : this.materials.get(matKey as MaterialKey);
      const mesh = new Mesh(geo, material);
      mesh.name = key;
      // Interior batches sit under roofs; only Cellhouse A (skylight) needs them in the sun's shadow passes.
      const chunk = this.chunks.get(chunkName)!;
      mesh.castShadow = shadow === "1" && (!chunk.interior || chunkName === "cellhouseA");
      mesh.receiveShadow = !(material instanceof MeshBasicMaterial);
      mesh.matrixAutoUpdate = false;
      mesh.updateMatrix();
      if (matKey === "glass" || matKey === "__sign") mesh.renderOrder = 2;
      this.chunks.get(chunkName)!.group.add(mesh);
      triangles += b.idx.length / 3;
      drawCalls++;
    }
    const props = this.finalizeProps();
    triangles += props.triangles;
    drawCalls += props.drawCalls;
    for (const chunk of this.chunks.values()) root.add(chunk.group);
    const occGeo = new BufferGeometry();
    occGeo.setAttribute("position", new Float32BufferAttribute(this.occPos, 3));
    occGeo.setIndex(new Uint32BufferAttribute(this.occIdx, 1));
    computeBoundsTree.call(occGeo);
    const occluder = new Mesh(occGeo, new MeshBasicMaterial({ visible: false, side: DoubleSide }));
    occluder.name = "OccluderBVH";
    occluder.updateMatrixWorld(true);
    this.buckets.clear();
    return { root, occluder, triangles, drawCalls };
  }

  /** One InstancedMesh per (chunk, model, glow, shadow) and model part. */
  private finalizeProps(): { triangles: number; drawCalls: number } {
    const groups = new Map<string, PropInstance[]>();
    for (const p of this.propInstances) {
      const key = `${p.chunk}|${p.id}|${p.glow ?? ""}|${p.shadow ? 1 : 0}`;
      let list = groups.get(key);
      if (!list) groups.set(key, (list = []));
      list.push(p);
    }
    let triangles = 0;
    let drawCalls = 0;
    const tinted = new Map<BufferGeometry, BufferGeometry>();
    for (const [key, list] of groups) {
      const { chunk: chunkName, id, glow, shadow } = list[0];
      const chunk = this.chunks.get(chunkName)!;
      for (const part of this.props.get(id)) {
        let material: Material = part.material;
        let geometry = part.geometry;
        const replaced = !!glow && part.glowPart;
        if (glow === "night" && !part.glowPart && part.material.emissiveMap) material = this.materials.nightEmissive(part.material);
        if (replaced && glow === "off") material = this.materials.get("plastic");
        else if (replaced) {
          material = glow === "always" ? this.materials.get("emissive_always") : chunk.interior ? this.materials.nightFor(chunkName) : this.materials.get("emissive_night");
          // The diffusers are vertex-coloured; give the tube geometry a white colour attribute.
          if (material.vertexColors && !geometry.getAttribute("color")) {
            let white = tinted.get(geometry);
            if (!white) {
              white = geometry.clone();
              white.setAttribute("color", new Float32BufferAttribute(new Float32Array(geometry.getAttribute("position").count * 3).fill(1), 3));
              tinted.set(geometry, white);
            }
            geometry = white;
          }
        }
        const mesh = new InstancedMesh(geometry, material, list.length);
        list.forEach((p, i) => mesh.setMatrixAt(i, p.matrix));
        mesh.instanceMatrix.needsUpdate = true;
        mesh.computeBoundingSphere();
        mesh.computeBoundingBox();
        mesh.name = `prop:${key}`;
        mesh.castShadow = shadow && !replaced && (!chunk.interior || chunkName === "cellhouseA");
        mesh.receiveShadow = !(material instanceof MeshBasicMaterial);
        mesh.matrixAutoUpdate = false;
        mesh.updateMatrix();
        chunk.group.add(mesh);
        const tris = (geometry.index ? geometry.index.count : geometry.getAttribute("position").count) / 3;
        triangles += tris * list.length;
        drawCalls++;
      }
    }
    this.propInstances = [];
    return { triangles, drawCalls };
  }
}

// ── Geometry helpers ─────────────────────────────────────────────────────────
/** Godot bar_between basis: local +Z along start→end, +X horizontal. */
function basisQuat(start: Vector3, end: Vector3): Quaternion {
  const forward = end.clone().sub(start).normalize();
  let right = new Vector3().crossVectors(UP, forward);
  if (right.lengthSq() < 0.001) right = new Vector3(1, 0, 0);
  else right.normalize();
  const up = new Vector3().crossVectors(forward, right).normalize();
  return new Quaternion().setFromRotationMatrix(new Matrix4().makeBasis(right, up, forward));
}

function worldUV(p: Vector3, n: Vector3): [number, number] {
  if (Math.abs(n.y) > 0.5) return [p.x, -p.z];
  const len = Math.hypot(n.z, n.x) || 1;
  return [(p.x * n.z - p.z * n.x) / len, p.y];
}

export function appendBox(b: Bucket, center: Vector3, half: Vector3, q: Quaternion, color: Color): void {
  const h = [half.x, half.y, half.z];
  for (const face of FACES) {
    const base = b.pos.length / 3;
    const ni = face.n.findIndex((v) => v !== 0);
    const ui = face.u.findIndex((v) => v !== 0);
    const vi = face.v.findIndex((v) => v !== 0);
    _n.set(face.n[0], face.n[1], face.n[2]).applyQuaternion(q);
    for (const [su, sv] of [[-1, -1], [1, -1], [1, 1], [-1, 1]]) {
      const local = [0, 0, 0];
      local[ni] += face.n[ni] * h[ni];
      local[ui] += face.u[ui] * su * h[ui];
      local[vi] += face.v[vi] * sv * h[vi];
      _a.set(local[0], local[1], local[2]).applyQuaternion(q).add(center);
      b.pos.push(_a.x, _a.y, _a.z);
      b.nor.push(_n.x, _n.y, _n.z);
      const [u, v] = worldUV(_a, _n);
      b.uv.push(u, v);
      b.col.push(color.r, color.g, color.b);
    }
    b.idx.push(base, base + 1, base + 2, base, base + 2, base + 3);
  }
}

function appendBoxOccluder(pos: number[], idx: number[], center: Vector3, half: Vector3, q: Quaternion): void {
  const base = pos.length / 3;
  for (let i = 0; i < 8; i++) {
    _a.set(i & 1 ? half.x : -half.x, i & 2 ? half.y : -half.y, i & 4 ? half.z : -half.z).applyQuaternion(q).add(center);
    pos.push(_a.x, _a.y, _a.z);
  }
  const quads = [
    [0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5],
  ];
  for (const [a, b2, c, d] of quads) idx.push(base + a, base + b2, base + c, base + a, base + c, base + d);
}

function appendCylinder(b: Bucket, center: Vector3, radius: number, height: number, q: Quaternion, color: Color, segments: number): void {
  const hy = height / 2;
  const ring = (y: number) => {
    const out: number[] = [];
    for (let i = 0; i <= segments; i++) {
      const a = (i / segments) * Math.PI * 2;
      const base = b.pos.length / 3;
      _n.set(Math.sin(a), 0, Math.cos(a)).applyQuaternion(q);
      _a.set(Math.sin(a) * radius, y, Math.cos(a) * radius).applyQuaternion(q).add(center);
      b.pos.push(_a.x, _a.y, _a.z);
      b.nor.push(_n.x, _n.y, _n.z);
      b.uv.push((i / segments) * Math.PI * 2 * radius, y);
      b.col.push(color.r, color.g, color.b);
      out.push(base);
    }
    return out;
  };
  const bottom = ring(-hy);
  const top = ring(hy);
  for (let i = 0; i < segments; i++) b.idx.push(bottom[i], bottom[i + 1], top[i + 1], bottom[i], top[i + 1], top[i]);
  for (const [y, sign] of [[hy, 1], [-hy, -1]] as const) {
    _n.set(0, sign, 0).applyQuaternion(q);
    const centerIndex = b.pos.length / 3;
    _a.set(0, y, 0).applyQuaternion(q).add(center);
    b.pos.push(_a.x, _a.y, _a.z);
    b.nor.push(_n.x, _n.y, _n.z);
    b.uv.push(0, 0);
    b.col.push(color.r, color.g, color.b);
    const first = b.pos.length / 3;
    for (let i = 0; i <= segments; i++) {
      const a = (i / segments) * Math.PI * 2;
      _a.set(Math.sin(a) * radius, y, Math.cos(a) * radius).applyQuaternion(q).add(center);
      b.pos.push(_a.x, _a.y, _a.z);
      b.nor.push(_n.x, _n.y, _n.z);
      b.uv.push(Math.sin(a) * radius, Math.cos(a) * radius);
      b.col.push(color.r, color.g, color.b);
    }
    for (let i = 0; i < segments; i++) {
      if (sign > 0) b.idx.push(centerIndex, first + i, first + i + 1);
      else b.idx.push(centerIndex, first + i + 1, first + i);
    }
  }
}

/**
 * Small geometry kit for dynamic objects (door leaves, pickups): boxes and
 * cylinders appended per material into one BufferGeometry with draw groups,
 * so each moving object costs one mesh.
 */
export class MeshKit {
  private buckets = new Map<MaterialKey, Bucket>();

  constructor(private materials: MaterialLibrary) {}

  private bucket(mat: MaterialKey): Bucket {
    let b = this.buckets.get(mat);
    if (!b) this.buckets.set(mat, (b = newBucket()));
    return b;
  }

  box(center: Vector3, size: Vector3, mat: MaterialKey, color = 0x9a9a92, quat?: Quaternion): this {
    appendBox(this.bucket(mat), center, size.clone().multiplyScalar(0.5), quat ?? new Quaternion(), vertexColorFor(mat, color));
    return this;
  }

  cylinder(center: Vector3, radius: number, height: number, mat: MaterialKey, color = 0x8a8f8a, quat?: Quaternion): this {
    appendCylinder(this.bucket(mat), center, radius, height, quat ?? new Quaternion(), vertexColorFor(mat, color), 12);
    return this;
  }

  build(name = "kit"): Mesh {
    const pos: number[] = [];
    const nor: number[] = [];
    const uv: number[] = [];
    const col: number[] = [];
    const idx: number[] = [];
    const geo = new BufferGeometry();
    const mats: Material[] = [];
    for (const [mat, b] of this.buckets) {
      const base = pos.length / 3;
      const start = idx.length;
      pos.push(...b.pos);
      nor.push(...b.nor);
      uv.push(...b.uv);
      col.push(...b.col);
      for (const i of b.idx) idx.push(i + base);
      geo.addGroup(start, b.idx.length, mats.length);
      mats.push(this.materials.get(mat));
    }
    geo.setAttribute("position", new Float32BufferAttribute(pos, 3));
    geo.setAttribute("normal", new Float32BufferAttribute(nor, 3));
    geo.setAttribute("uv", new Float32BufferAttribute(uv, 2));
    geo.setAttribute("color", new Float32BufferAttribute(col, 3));
    geo.setIndex(idx);
    geo.computeBoundingSphere();
    geo.computeBoundingBox();
    const mesh = new Mesh(geo, mats);
    mesh.name = name;
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    return mesh;
  }
}
