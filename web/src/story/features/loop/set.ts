import {
  CapsuleGeometry, Group, LatheGeometry, Mesh, MeshBasicMaterial, PlaneGeometry, SphereGeometry, Vector2, Vector3, type Material,
} from "three";
import { MeshKit } from "../../../world/builder";
import { wallColorFor } from "../../../world/campus/blueprintFloor";
import { GuardVisual, loadCharacter, type CharacterAsset } from "../../../ai/guardVisual";
import type { Game } from "../../../game/game";

const V = (x: number, y: number, z: number) => new Vector3(x, y, z);

/** A woman in a lab coat, as a flat black shape (only ever seen backlit through glass). Faces −z; origin at her feet. */
function silhouette(): Group {
  const g = new Group();
  const ink = new MeshBasicMaterial({ color: 0x030405, fog: false });
  const coat = new LatheGeometry(
    [
      [0.001, 0.52], [0.27, 0.54], [0.23, 0.78], [0.2, 0.95], [0.165, 1.06], [0.19, 1.24], [0.215, 1.36], [0.2, 1.42], [0.075, 1.47], [0.056, 1.56], [0.001, 1.57],
    ].map(([r, y]) => new Vector2(r, y)),
    18,
  );
  const body = new Mesh(coat, ink);
  body.scale.z = 0.62;
  g.add(body);
  for (const x of [-0.09, 0.09]) {
    const leg = new Mesh(new CapsuleGeometry(0.055, 0.5, 4, 8), ink);
    leg.position.set(x, 0.3, 0);
    g.add(leg);
  }
  const head = new Mesh(new SphereGeometry(0.1, 16, 12), ink);
  head.scale.set(0.86, 1.12, 0.96);
  head.position.y = 1.67;
  const bun = new Mesh(new SphereGeometry(0.058, 12, 8), ink);
  bun.position.set(0.01, 1.7, 0.1);
  g.add(head, bun);
  // Left arm hangs; the right is folded across her, holding something (the tape remote).
  const arm = (x: number, rz: number, rx: number, y: number, z: number) => {
    const a = new Mesh(new CapsuleGeometry(0.045, 0.5, 4, 8), ink);
    a.position.set(x, y, z);
    a.rotation.set(rx, 0, rz);
    g.add(a);
  };
  arm(-0.25, -0.12, 0, 1.1, 0);
  arm(0.24, 0.1, 0, 1.24, 0);
  arm(0.12, 1.25, 0, 1.06, -0.12);
  return g;
}

/**
 * Cinematic-only set pieces, hidden outside the capture sequence:
 * the observation window in NIDRA B2 Interrogation A (with Meera's silhouette
 * behind the glass) and two escort guards for the HQ lift shot.
 *
 * The window is built as a false wall 1.3 m in front of Interrogation A's
 * south wall: the plan's observation windows are misplaced (they stand inside
 * the Observation room after the floor-plan compaction), and this keeps the
 * shot right either way.
 */
export class CaptureSet {
  readonly window = new Group();
  readonly escorts: GuardVisual[] = [];
  readonly escortGroup = new Group();
  /** Camera marks for the chair shot (world). */
  readonly chair = { eye: V(0, 0, 0), push: V(0, 0, 0), look: V(0, 0, 0) };
  /** Camera marks for the lift-vestibule shot (world). */
  readonly lift = { from: V(0, 0, 0), to: V(0, 0, 0), look: V(0, 0, 0), dir: V(1, 0, 0) };
  ok = false;
  private asset: CharacterAsset | null = null;

  constructor(private game: Game) {
    this.window.visible = false;
    this.escortGroup.visible = false;
    game.render.scene.add(this.window, this.escortGroup);
    this.buildWindow();
    this.placeLift();
    void loadCharacter((m: Material) => game.render.prepareMaterial(m)).then((asset) => {
      this.asset = asset;
      for (let i = 0; i < 2; i++) {
        const v = new GuardVisual(asset, (m: Material) => game.render.prepareMaterial(m));
        this.escorts.push(v);
        this.escortGroup.add(v.root);
      }
    });
  }

  get escortsReady(): boolean {
    return this.escorts.length === 2 && !!this.asset;
  }

  private buildWindow(): void {
    const g = this.game;
    const floor = g.floors.get("nidra-b2");
    const room = floor?.rooms.get("interrogationa");
    const center = floor?.roomCenters.get("interrogationa");
    if (!floor || !room || !center) return;
    // Interrogation A's south wall (towards Observation) is at +z in world space.
    const south = center.z + room.d / 2 - 0.12;
    const wallZ = south - 1.3;
    const glass = { w: 3, y0: 0.96, y1: 2.08 };
    const h = 3.7;
    const width = room.w - 0.06;
    const kit = new MeshKit(g.materials);
    const color = wallColorFor("nidra-b2");
    const t = 0.16;
    const side = (width - glass.w) / 2;
    kit.box(V(0, glass.y0 / 2, 0), V(width, glass.y0, t), "plaster", color);
    kit.box(V(0, (glass.y1 + h) / 2, 0), V(width, h - glass.y1, t), "plaster", color);
    for (const s of [-1, 1]) kit.box(V(s * (glass.w / 2 + side / 2), (glass.y0 + glass.y1) / 2, 0), V(side, glass.y1 - glass.y0, t), "plaster", color);
    // Steel frame, sill, the speaker grille under it.
    kit.box(V(0, glass.y0 - 0.03, -0.1), V(glass.w + 0.12, 0.06, 0.08), "steel", 0x7a827e);
    kit.box(V(0, glass.y1 + 0.03, -0.09), V(glass.w + 0.12, 0.06, 0.04), "steel", 0x7a827e);
    for (const s of [-1, 1]) kit.box(V(s * (glass.w / 2 + 0.03), (glass.y0 + glass.y1) / 2, -0.09), V(0.06, glass.y1 - glass.y0, 0.04), "steel", 0x7a827e);
    kit.box(V(1.95, 1.42, -0.1), V(0.34, 0.22, 0.04), "dark", 0x202423);
    for (let i = 0; i < 4; i++) kit.box(V(1.95, 1.35 + i * 0.045, -0.125), V(0.28, 0.012, 0.01), "steel", 0x5d6461);
    kit.box(V(0, (glass.y0 + glass.y1) / 2, 0), V(glass.w, glass.y1 - glass.y0, 0.03), "glass", 0x4f6766);
    // Behind the glass: desk edge with two monitors (backs to us), a bright wall.
    kit.box(V(-0.6, 0.74, 0.45), V(2.2, 0.05, 0.6), "metal", 0x2b302e);
    for (const x of [-1.2, -0.25]) kit.box(V(x, 1.0, 0.42), V(0.5, 0.34, 0.06), "dark", 0x111414);
    const wall = kit.build("CaptureSet:window");
    wall.position.set(center.x, center.y, wallZ);
    // Built facing −z (towards the chair); our local −z already points into the room.
    this.window.add(wall);
    const light = new Mesh(new PlaneGeometry(3.8, 2.6), new MeshBasicMaterial({ color: 0xb9cbd2, fog: false }));
    light.position.set(center.x, center.y + 1.6, south - 0.02);
    light.rotation.y = Math.PI;
    const woman = silhouette();
    woman.position.set(center.x + 0.25, center.y, wallZ + 0.78);
    woman.rotation.y = Math.PI;
    this.window.add(light, woman);
    // The chair faces the glass from across the table.
    this.chair.eye.set(center.x, center.y + 1.22, center.z + 0.15);
    this.chair.push.set(center.x + 0.05, center.y + 1.2, center.z + 0.6);
    this.chair.look.set(center.x + 0.2, center.y + 1.52, wallZ + 0.8);
    this.ok = true;
  }

  private placeLift(): void {
    const floor = this.game.floors.get("hq-0");
    const lobby = floor?.roomCenters.get("liftlobby");
    const door = floor?.doors.find((d) => d.a === "lift" && d.b === "liftlobby");
    if (!floor || !lobby || !door) return;
    const doorW = floor.toWorld(door.position);
    const dir = doorW.clone().sub(lobby).setY(0).normalize();
    this.lift.dir.copy(dir);
    this.lift.from.copy(lobby).addScaledVector(dir, -1.6).setY(lobby.y + 1.45);
    this.lift.to.copy(doorW).addScaledVector(dir, -1.15).setY(lobby.y + 1.4);
    this.lift.look.copy(doorW).setY(lobby.y + 0.55);
  }

  /** Escorts flank the camera, a little ahead, walking towards the lift. */
  poseEscorts(eye: Vector3, dt: number): void {
    const d = this.lift.dir;
    const side = V(-d.z, 0, d.x);
    this.escorts.forEach((v, i) => {
      const s = i === 0 ? 1 : -1;
      v.root.position.copy(eye).addScaledVector(d, 0.95).addScaledVector(side, s * 0.62);
      v.root.position.y = eye.y - 1.4 - 0.05;
      v.root.rotation.y = Math.atan2(d.x, d.z);
      v.locomote(0.75, false, false);
      v.update(dt);
    });
  }
}
