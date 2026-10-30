import { BoxGeometry, Group, Mesh, MeshBasicMaterial, Object3D, Quaternion, Vector3 } from "three";
import { MeshKit } from "../../../world/builder";
import { markInteractable, type Interactable } from "../../../interact/interactable";
import { resolvePlace } from "../../place";
import type { Game } from "../../../game/game";
import type { StoryDirector } from "../../director";
import type { BuiltFloor } from "../../../world/campus/blueprintFloor";
import type { DoseChoiceDef, DoseDef, LineDef } from "./data";

const V = (x: number, y: number, z: number) => new Vector3(x, y, z);
const hidden = new MeshBasicMaterial({ visible: false });

/** World frame of the dietary window: counter-top centre of the chosen slot, `forward` towards the dining side. */
export interface WindowFrame {
  position: Vector3;
  forward: Vector3;
  along: Vector3;
}

/** Finds the serving hatch on food-ground and the dietary slot along it. */
export function dietaryWindow(floors: Map<string, BuiltFloor>, d: DoseDef["window"]): WindowFrame | null {
  const f = floors.get(d.plan);
  const rec = f?.doors.find((r) => r.kind === "hatch" && ((r.a === d.a && r.b === d.b) || (r.a === d.b && r.b === d.a)));
  const dining = f?.roomCenters.get(d.a);
  if (!f || !rec || !dining) return null;
  const centre = f.toWorld(rec.position.clone());
  const n = f.toWorld(rec.position.clone().add(rec.normal)).sub(centre).setY(0).normalize();
  if (n.dot(dining.clone().sub(centre)) < 0) n.negate();
  const along = V(-n.z, 0, n.x);
  const slotWidth = rec.clearWidth / d.slots;
  const offset = -rec.clearWidth / 2 + slotWidth * (d.slot + 0.5);
  return { position: centre.addScaledVector(along, offset).setY(centre.y + d.counterHeight), forward: n, along };
}

/**
 * The gloved hand through the dietary window, holding out a paper cup with
 * one white pill. Slides in while a dose is on offer, back out once it's
 * been taken or pocketed. E starts the exchange (`onOffer`).
 */
export class DoseStation implements Interactable {
  readonly root = new Group();
  /** Where the camera focuses for the M03 shard. */
  readonly cupFocus = new Object3D();
  private readonly arm = new Group();
  private reach = 0;
  offering = false;
  busy = false;

  constructor(
    game: Game,
    private def: DoseDef,
    private onOffer: () => void,
  ) {
    const kit = new MeshKit(game.materials);
    const up = new Quaternion();
    // Local frame: +z points through the window to the dining side; origin at the counter top.
    const alongZ = new Quaternion().setFromAxisAngle(V(1, 0, 0), Math.PI / 2);
    // Sleeve (pale-green scrubs) reaching through the hatch, glove cuff.
    kit.cylinder(V(0, 0.072, -0.39), 0.04, 0.46, "fabric", 0x8fb3a3, alongZ);
    kit.cylinder(V(0, 0.07, -0.145), 0.043, 0.05, "rubber", 0x7fa6d6, alongZ);
    // Nitrile glove, palm up: fingers towards Parth with the tips curled, thumb along the side.
    const glove = 0x86aedc;
    kit.box(V(0, 0.058, -0.07), V(0.086, 0.026, 0.1), "rubber", glove);
    for (let i = 0; i < 4; i++) {
      const x = -0.027 + i * 0.018;
      const len = i === 0 || i === 3 ? 0.06 : 0.07;
      kit.box(V(x, 0.055, -0.02 + len / 2), V(0.016, 0.017, len), "rubber", glove);
      kit.box(V(x, 0.068, -0.02 + len), V(0.015, 0.022, 0.016), "rubber", glove);
    }
    kit.box(V(-0.056, 0.07, -0.045), V(0.019, 0.02, 0.058), "rubber", glove, new Quaternion().setFromAxisAngle(V(0, 1, 0), -0.45));
    // Paper cup on the palm (darker top disc reads as the inside) with one white pill.
    kit.cylinder(V(0, 0.104, -0.07), 0.027, 0.064, "paper", 0xe9e5d8, up);
    kit.cylinder(V(0, 0.1365, -0.07), 0.025, 0.002, "paper", 0xc9c3b2, up);
    kit.box(V(0.005, 0.1405, -0.072), V(0.012, 0.006, 0.008), "plastic", 0xfafaf6);
    const mesh = kit.build("Routine:dose_hand");
    mesh.castShadow = false;
    this.arm.add(mesh);
    const hit = new Mesh(new BoxGeometry(0.34, 0.3, 0.5), hidden);
    hit.position.set(0, 0.12, -0.1);
    this.arm.add(hit);
    this.cupFocus.position.set(0, 0.0, -0.07);
    this.arm.add(this.cupFocus);
    this.root.add(this.arm);
    this.root.visible = false;
    markInteractable(this.root, this);
  }

  place(at: WindowFrame | null, game: Game): boolean {
    let pos: Vector3;
    let yaw: number;
    if (this.def.at) {
      const p = resolvePlace(this.def.at, game.anchors, game.floors, game.chunks);
      if (!p) return false;
      pos = p.position;
      yaw = p.yaw;
    } else if (at) {
      // Inset a little to the serving side so the cup sits over the counter's middle.
      pos = at.position.clone().addScaledVector(at.forward, 0.05);
      yaw = Math.atan2(at.forward.x, at.forward.z);
    } else return false;
    this.root.position.copy(pos);
    this.root.rotation.y = yaw;
    game.chunkGroup("food").add(this.root);
    game.interaction.register(this);
    return true;
  }

  getInteractionPrompt(): string {
    return this.offering && !this.busy && this.reach > 0.8 ? this.def.prompt : "";
  }

  interact(): void {
    if (this.offering && !this.busy) this.onOffer();
  }

  /** `offering`: a dose is on and this meal's hasn't been handed out yet. */
  update(dt: number): void {
    const target = this.offering ? 1 : 0;
    this.reach += Math.sign(target - this.reach) * Math.min(Math.abs(target - this.reach), dt / 0.7);
    this.root.visible = this.reach > 0.001;
    const e = this.reach * this.reach * (3 - 2 * this.reach);
    this.arm.position.z = -0.55 * (1 - e);
  }
}

/** Plays subtitle lines in order (and the `dialogue` event, for audio). */
export async function sayLines(story: StoryDirector, lines: LineDef[] | undefined, id = "routine"): Promise<void> {
  for (const l of lines ?? []) {
    story.events.emit("dialogue", { id, speaker: l.speaker ?? "", text: l.text, audio: l.audio });
    await story.ui.say(l.speaker ?? "", l.text, l.seconds);
  }
}

/** The exchange at the window: (first breakfast) M03, the offer, Swallow / Pocket it. Resolves with the choice. */
export async function runDose(
  game: Game,
  def: DoseDef,
  station: DoseStation,
  meal: string,
  day: number,
): Promise<"swallow" | "pocket"> {
  const story = game.story;
  const p = game.player;
  const info = { meal, day };
  station.busy = true;
  p.setControlEnabled(false);
  try {
    story.signal("dose_offered", info);
    if (meal === "breakfast" && def.firstShard && !game.memory.hasMemory(def.firstShard)) {
      await story.playShard(def.firstShard, { root: station.cupFocus });
      p.setControlEnabled(false);
    }
    await sayLines(story, def.offerLines);
    const options: { id: "swallow" | "pocket"; c: DoseChoiceDef }[] = [
      { id: "swallow" as const, c: def.swallow },
      { id: "pocket" as const, c: def.pocket },
    ].filter((o) => !o.c.when || story.check(o.c.when));
    const pick = options.length > 1 ? options[await story.ui.choose(options.map((o) => o.c.text), def.choicePrompt)] : options[0] ?? { id: "swallow" as const, c: def.swallow };
    if (pick.id === "swallow") {
      story.setFlag("cycle:dose_taken");
      if (def.swallowEndsWithdrawal && story.hasFlag("cycle:withdrawal")) story.setFlag("cycle:withdrawal", false);
      story.signal("dose_taken", info);
    } else {
      game.inventory.add({ id: def.item.id, displayName: def.item.label, category: "MISSION_ITEM", stackable: true }, 1, false);
      story.setFlag("cycle:dose_pocketed");
      story.setFlag("cycle:withdrawal");
      story.signal("dose_pocketed", info);
    }
    station.offering = false;
    await sayLines(story, pick.c.lines);
    if (pick.c.actions?.length) await story.run(pick.c.actions);
    return pick.id;
  } finally {
    station.busy = false;
    station.offering = false;
    if (!story.capturing) p.setControlEnabled(true);
  }
}
