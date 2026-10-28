import { Vector3 } from "three";
import type { NpcActor } from "./actor";
import type { NpcRuntime } from "./runtime";
import type { MotherDef } from "./types";

type State = "gone" | "arriving" | "seated" | "leaving";

/**
 * Parth's mother: Admin visitation, public side of a booth, on day 3 of a
 * cycle between 10:00 and 11:00 (`routine:visitation` brings her in; the
 * clock alone seats her after a reload). She talks; he never recognises her.
 */
export class Mother {
  state: State = "gone";
  private run = 0;
  private photoOut = false;

  constructor(
    private rt: NpcRuntime,
    readonly actor: NpcActor,
    private def: MotherDef,
  ) {
    actor.prompt = () => (this.state === "seated" && this.rt.canTalk() && this.rt.pickTalk(def) ? (def.prompt ?? rt.data.talkPrompt) : "");
    actor.onInteract = () => {
      const t = this.rt.pickTalk(def);
      if (t) void this.rt.talk(actor, t).then(() => this.settle());
    };
    rt.behaviours.set("mother_photo_up", () => this.photo(true));
    rt.behaviours.set("mother_photo_down", () => this.photo(false));
    this.photoProp(false);
    actor.show(false);
  }

  private get story() {
    return this.rt.story;
  }

  /** It is visiting hour on visiting day. */
  get visiting(): boolean {
    const env = this.rt.game.env;
    const [a, b] = this.def.visit.hours;
    return env.dayNumber === this.def.visit.day && env.timeHours >= a && env.timeHours < b;
  }

  private photoProp(on: boolean): void {
    const p = this.actor.props.get("photo");
    if (p) p.visible = on;
  }

  /** The photo against the glass (hand flat on it), or back in her lap. */
  private async photo(up: boolean): Promise<void> {
    const a = this.actor;
    this.photoOut = up;
    this.photoProp(up);
    a.pose("lap", up ? 0 : 1, 0.6);
    a.pose("palm", up ? 1 : 0, 0.8);
    a.pose("lean", up ? 1 : 0, 0.8);
    this.story.signal("npcs:visitation", { beat: up ? "photo" : "photo_down" });
    await this.story.sleep(0.9);
  }

  private sit(): void {
    const seat = this.rt.resolve(this.def.seat);
    const a = this.actor;
    if (seat) a.place(seat.position, seat.yaw);
    a.show(true);
    a.clearPoses(0);
    a.pose("sit", 1, 0);
    a.pose("lap", 1, 0);
    this.photoProp(false);
    this.state = "seated";
  }

  private settle(): void {
    const a = this.actor;
    a.lookTargetWeight = 0.5;
    if (this.photoOut) void this.photo(false);
    const seat = this.rt.resolve(this.def.seat);
    if (seat) a.targetYaw = seat.yaw;
  }

  /** Walks in from the visitor hall and sits down at her booth. */
  async arrive(): Promise<void> {
    if (this.state !== "gone") return;
    const seat = this.rt.resolve(this.def.seat);
    const door = this.rt.resolve(this.def.entrance);
    if (!seat || !door) return;
    const run = ++this.run;
    const a = this.actor;
    this.state = "arriving";
    a.place(door.position, door.yaw);
    a.show(true);
    a.clearPoses(0);
    a.pose("stoop", 1, 0);
    this.story.signal("npcs:visitation", { beat: "arrive" });
    // Up to the stool behind it, then down.
    const behind = seat.position.clone().add(new Vector3(Math.sin(seat.yaw), 0, Math.cos(seat.yaw)).multiplyScalar(-0.55));
    await a.walkTo(behind, 1.1, true);
    if (run !== this.run) return;
    a.targetYaw = seat.yaw;
    await this.story.sleep(0.6);
    if (run !== this.run) return;
    this.sit();
  }

  /** 11:00: she stands and goes. */
  async leave(): Promise<void> {
    if (this.state !== "seated" && this.state !== "arriving") return;
    if (this.rt.talkingTo === this.actor) return;
    const door = this.rt.resolve(this.def.entrance);
    const run = ++this.run;
    const a = this.actor;
    this.state = "leaving";
    this.story.signal("npcs:visitation", { beat: "leave" });
    a.clearPoses(0.8);
    a.pose("stoop", 1, 0.8);
    await this.story.sleep(1.0);
    if (run !== this.run) return;
    if (door) await a.walkTo(door.position, 1.1, true);
    if (run !== this.run) return;
    a.show(false);
    this.state = "gone";
  }

  onSignal(id: string): void {
    if (id === "routine:visitation") void this.arrive();
  }

  onWipe(): void {
    this.run++;
    this.actor.show(false);
    this.state = "gone";
  }

  update(_dt: number): void {
    if (this.visiting) {
      // Reloaded (or the clock was set) during the hour: she is already there.
      if (this.state === "gone") {
        if (this.rt.game.env.timeHours - this.def.visit.hours[0] < 0.05) void this.arrive();
        else this.sit();
      }
    } else if (this.state === "seated" || this.state === "arriving") void this.leave();
  }

  debug(): Record<string, unknown> {
    return { state: this.state, visiting: this.visiting };
  }
}
