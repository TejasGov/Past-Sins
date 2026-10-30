import { BoxGeometry, Group, Mesh, MeshBasicMaterial, MeshStandardMaterial, type Material } from "three";
import { markInteractable, type Interactable } from "../../../interact/interactable";
import type { NpcActor } from "./actor";
import { tumbler } from "./props";
import type { NpcRuntime, Placed } from "./runtime";
import type { BhosleDef } from "./types";

type State = "home" | "round" | "lunch_out" | "away" | "lunch_back";

const inHours = (h: number, [a, b]: [number, number]) => (a <= b ? h >= a && h < b : h >= a || h < b);

/** The chai Bhosle leaves inside N03's gate (in Act III with his card under it). */
class GateChai implements Interactable {
  readonly root = new Group();
  card = false;
  private drunk = false;
  private busy = false;
  private cardMesh: Mesh;

  constructor(
    private rt: NpcRuntime,
    private def: BhosleDef,
  ) {
    const steel = new MeshStandardMaterial({ color: 0xd0d4cf, roughness: 0.3, metalness: 0.65 });
    rt.game.render.prepareMaterial(steel as Material);
    this.root.add(tumbler(steel));
    this.cardMesh = new Mesh(new BoxGeometry(0.086, 0.002, 0.054), new MeshStandardMaterial({ color: 0xd9dcd2, roughness: 0.5 }));
    rt.game.render.prepareMaterial(this.cardMesh.material as Material);
    this.cardMesh.position.set(0.02, 0.001, 0.035);
    this.cardMesh.rotation.y = 0.4;
    this.root.add(this.cardMesh);
    const hit = new Mesh(new BoxGeometry(0.45, 0.4, 0.45), new MeshBasicMaterial({ visible: false }));
    hit.position.y = 0.15;
    this.root.add(hit);
    markInteractable(this.root, this);
    this.root.visible = false;
  }

  set(at: Placed | null, card: boolean): void {
    this.root.visible = !!at;
    if (at) {
      this.root.position.copy(at.position);
      this.root.rotation.y = at.yaw;
    }
    this.card = card;
    this.cardMesh.visible = card;
    this.drunk = false;
  }

  private get cardReady(): boolean {
    return this.card && this.rt.story.check(this.def.chai.cardWhen);
  }

  getInteractionPrompt(): string {
    if (!this.root.visible || this.busy) return "";
    if (this.cardReady) return this.def.chai.cardPrompt;
    return this.drunk ? "" : this.def.chai.prompt;
  }

  interact(): void {
    if (this.busy || !this.getInteractionPrompt()) return;
    const card = this.cardReady;
    this.busy = true;
    const actions = card ? this.def.chai.cardActions : this.def.chai.actions;
    if (card) {
      this.card = false;
      this.cardMesh.visible = false;
    } else this.drunk = true;
    void this.rt.story.run(actions).finally(() => (this.busy = false));
  }
}

/**
 * Constable Bhosle (tier-3 guard quarter): chai at N03 on every count with
 * the same line, away over lunch, and in Act III his card under the tumbler
 * at lock-in. Not an AI guard: he never sees or detains Parth.
 */
export class Bhosle {
  state: State = "home";
  readonly chai: GateChai;
  private morningKey = "";
  private lockinKey = "";
  private run = 0;

  constructor(
    private rt: NpcRuntime,
    readonly actor: NpcActor,
    private def: BhosleDef,
  ) {
    this.chai = new GateChai(rt, def);
    rt.game.chunkGroup("cellhouseA").add(this.chai.root);
    rt.game.interaction.register(this.chai);
    actor.prompt = () => (this.state === "home" && this.rt.canTalk() && this.rt.pickTalk(def) ? (def.prompt ?? rt.data.talkPrompt) : "");
    actor.onInteract = () => {
      const t = this.rt.pickTalk(def);
      if (t) void this.rt.talk(actor, t).then(() => this.settle());
    };
    const home = rt.resolve(def.home);
    if (home && def.homePose?.includes("sit")) rt.addStool(home);
    rt.behaviours.set("bhosle_morning", () => this.startRound("morning"));
    rt.behaviours.set("bhosle_lockin", () => this.startRound("lockin"));
    this.goHome();
  }

  private get story() {
    return this.rt.story;
  }

  private dayKey(): string {
    return `${this.story.state.cycle}:${this.rt.game.env.dayNumber}`;
  }

  private nightKey(): string {
    return `${this.dayKey()}:${this.story.getVar("loop:night_restarts")}`;
  }

  /** At the desk in the guard quarter. */
  goHome(): void {
    this.run++;
    const home = this.rt.resolve(this.def.home);
    const a = this.actor;
    if (home) a.place(home.position, home.yaw);
    a.show(true);
    a.clearPoses(0);
    if (this.def.homePose) for (const p of this.def.homePose.split(",")) a.pose(p.trim(), 1, 0);
    this.prop(false);
    this.state = "home";
  }

  private settle(): void {
    const a = this.actor;
    a.lookTargetWeight = 0;
    const home = this.rt.resolve(this.def.home);
    if (home && this.state === "home") a.targetYaw = home.yaw;
  }

  private prop(on: boolean): void {
    const t = this.actor.props.get("tumbler");
    if (t) t.visible = on;
  }

  onSignal(id: string, _data?: Record<string, unknown>): void {
    if (id === "routine:count") void this.startRound("morning");
    else if (id === "routine:lunch") void this.startLunch();
    else if (id === "routine:lockin" && this.story.state.act >= this.def.lockin.act) void this.startRound("lockin");
    else if (id === "loop:night_restart") {
      // The night starts again at 19:00: back at his desk, and the lock-in chai comes round again.
      this.goHome();
      this.chai.set(null, false);
      if (this.story.state.act >= this.def.lockin.act) void this.story.sleep(4).then(() => this.startRound("lockin"));
    }
  }

  onWipe(): void {
    this.goHome();
    this.chai.set(null, false);
    this.morningKey = "";
    this.lockinKey = "";
  }

  /** The chai round: walk to N03's gate, wait for Parth, say the line, leave the tumbler, walk back. */
  async startRound(kind: "morning" | "lockin"): Promise<void> {
    if (kind === "morning") {
      if (this.morningKey === this.dayKey()) return;
      this.morningKey = this.dayKey();
    } else {
      if (this.lockinKey === this.nightKey()) return;
      this.lockinKey = this.nightKey();
    }
    if (this.state !== "home") this.goHome();
    const run = ++this.run;
    const a = this.actor;
    const gate = this.rt.resolve(this.def.gate);
    if (!gate) return;
    this.state = "round";
    this.story.signal("npcs:bhosle", { beat: `${kind}_start` });
    a.clearPoses(0.5);
    await this.story.sleep(0.8);
    if (run !== this.run) return;
    this.prop(true);
    a.pose("carry", 1, 0.5);
    a.pose("stoop", 1, 0.5);
    await a.walkTo(gate.position, this.def.walkSpeed, true);
    if (run !== this.run) return;
    a.targetYaw = gate.yaw;
    const line = kind === "morning" ? this.def.morning.line : this.def.lockin.line;
    const g = this.rt.game;
    // Wait for Parth at the bars (in control, close, nobody else talking).
    while (run === this.run) {
      const near = g.player.position.distanceTo(gate.position) < this.def.morning.hearDistance;
      if (near && g.player.controlEnabled && !this.story.ui.speaking && !this.story.capturing && !g.hud.memoryPlaying) break;
      if (kind === "morning" && g.env.timeHours >= this.def.morning.giveUpHour) break;
      await this.story.sleep(0.25);
    }
    if (run !== this.run) return;
    const heard = g.player.position.distanceTo(gate.position) < this.def.morning.hearDistance;
    if (heard) {
      a.lookTargetWeight = 1;
      a.talking = true;
      this.story.events.emit("dialogue", { id: `npcs_bhosle_${kind}`, speaker: line.speaker, text: line.text });
      await this.story.ui.say(line.speaker, line.text, line.seconds);
      a.talking = false;
      if (run !== this.run) return;
      if (kind === "morning") this.story.addVar(this.def.morning.counter);
    }
    // The tumbler goes in through the bars.
    a.pose("carry", 0, 0.4);
    await this.story.sleep(0.5);
    if (run !== this.run) return;
    this.prop(false);
    this.chai.set(this.rt.resolve(this.def.tumblerAt), kind === "lockin");
    this.story.signal("npcs:bhosle", { beat: kind === "morning" ? "chai" : "card", heard });
    const after = kind === "morning" ? this.def.morning.after : this.def.lockin.after;
    if (heard && after) await this.story.run(after);
    if (run !== this.run) return;
    await this.story.sleep(1.2);
    a.lookTargetWeight = 0;
    await this.walkHome(run);
  }

  private async walkHome(run: number): Promise<void> {
    const home = this.rt.resolve(this.def.home);
    if (!home) return;
    const a = this.actor;
    a.pose("stoop", 1, 0.5);
    // Stop short of the chair, then sit.
    const ok = await a.walkTo(home.position, this.def.walkSpeed, true);
    if (run !== this.run || !ok) return;
    this.goHome();
  }

  /** 12:30: leaves the guard quarter (tier 3 is unwatched until 13:00). */
  async startLunch(): Promise<void> {
    if (this.state !== "home") return;
    const away = this.rt.resolve(this.def.lunchAway);
    if (!away) return;
    const run = ++this.run;
    const a = this.actor;
    this.state = "lunch_out";
    this.story.signal("npcs:bhosle", { beat: "lunch_out" });
    a.clearPoses(0.6);
    await this.story.sleep(0.8);
    if (run !== this.run) return;
    a.pose("stoop", 1, 0.5);
    await a.walkTo(away.position, this.def.walkSpeed, true);
    if (run !== this.run) return;
    a.show(false);
    this.state = "away";
  }

  private async endLunch(): Promise<void> {
    const away = this.rt.resolve(this.def.lunchAway);
    if (!away) return this.goHome();
    const run = ++this.run;
    const a = this.actor;
    a.place(away.position, away.yaw);
    a.show(true);
    this.state = "lunch_back";
    this.story.signal("npcs:bhosle", { beat: "lunch_back" });
    await this.walkHome(run);
  }

  update(_dt: number): void {
    const h = this.rt.game.env.timeHours;
    if (this.state === "home") {
      // Without the routine feature's signals (or after a reload mid-window) the clock decides.
      if (inHours(h, this.def.lunchHours)) void this.startLunch();
      else if (inHours(h, this.def.morning.fallbackHours) && this.morningKey !== this.dayKey()) void this.startRound("morning");
    } else if ((this.state === "away" || this.state === "lunch_out") && h >= this.def.lunchHours[1] && h < this.def.lunchHours[1] + 2) {
      void this.endLunch();
    }
  }

  debug(): Record<string, unknown> {
    return { state: this.state, chai: this.chai.root.visible, card: this.chai.card, mornings: this.story.getVar(this.def.morning.counter) };
  }
}
