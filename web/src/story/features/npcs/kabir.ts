import { Vector3 } from "three";
import type { Door } from "../../../interact/door";
import type { NpcActor } from "./actor";
import type { NpcRuntime } from "./runtime";
import type { KabirDef } from "./types";

/**
 * Kabir (S-03), Cellhouse B Special Room A, behind the glass door. Remembers
 * every cycle and counts Parth's visits (one per cycle). With the cell
 * master key Parth can let him out (`kabir_freed`); then he follows Parth
 * along the guard nav graph, waits at closed doors, and keeps up through the
 * restricted lift. A capture puts him back in his room.
 */
export class Kabir {
  following = false;
  private repath = 0;
  private lastParth = new Vector3();
  private goal = new Vector3();
  private leaving = false;

  constructor(
    private rt: NpcRuntime,
    readonly actor: NpcActor,
    private def: KabirDef,
  ) {
    actor.prompt = () => (this.rt.canTalk() && !this.leaving && this.rt.pickTalk(def) ? (def.prompt ?? rt.data.talkPrompt) : "");
    actor.onInteract = () => void this.talk();
    rt.behaviours.set("kabir_free", () => this.free());
    this.goHome();
    // Kabir was let out before a reload: he waits by his door.
    if (rt.story.hasFlag(def.freedFlag) && rt.story.hasFlag(def.followFlag)) void this.free(true);
  }

  private get story() {
    return this.rt.story;
  }

  get door(): Door | undefined {
    return this.rt.game.doors.find((d) => d.spec.persistentId === this.def.door);
  }

  goHome(): void {
    const at = this.rt.resolve(this.def.stand);
    const a = this.actor;
    if (at) a.place(at.position, at.yaw);
    a.show(true);
    a.clearPoses(0);
    a.lookTargetWeight = 0;
    this.following = false;
    this.leaving = false;
  }

  private async talk(): Promise<void> {
    // One visit per cycle: "This is the forty-first time you've asked me that."
    if (!this.story.hasFlag(this.def.seenFlag)) {
      this.story.setFlag(this.def.seenFlag);
      this.story.addVar(this.def.visits);
    }
    const t = this.rt.pickTalk(this.def);
    if (!t) return;
    const a = this.actor;
    if (!this.following) a.pose("lean", 1, 0.8);
    await this.rt.talk(a, t);
    a.pose("lean", 0, 0.8);
    if (!this.following && !this.leaving) {
      const at = this.rt.resolve(this.def.stand);
      if (at) a.targetYaw = at.yaw;
      a.lookTargetWeight = 0.4;
    }
  }

  /** The master key turns: glass door open, Kabir out, following. */
  async free(restore = false): Promise<void> {
    if (this.following || this.leaving) return;
    const door = this.door;
    this.leaving = true;
    if (!restore) {
      this.story.setFlag(this.def.freedFlag);
      this.story.signal("npcs:kabir_freed");
    }
    this.story.setFlag(this.def.followFlag);
    if (door && !door.isOpen) door.setState(true, false);
    const a = this.actor;
    a.clearPoses(0.5);
    if (door) {
      const out = door.position.clone().add(new Vector3(Math.sin(door.spec.yaw), 0, Math.cos(door.spec.yaw)).multiplyScalar(-1.4));
      // The door's leaf normal points into the corridor or the room depending on the plan: pick the side Parth is on.
      const other = door.position.clone().add(new Vector3(Math.sin(door.spec.yaw), 0, Math.cos(door.spec.yaw)).multiplyScalar(1.4));
      const p = this.rt.game.player.position;
      const target = out.distanceToSquared(p) < other.distanceToSquared(p) ? out : other;
      await a.walkTo(target, this.def.follow.walk, false);
    }
    this.leaving = false;
    this.following = true;
    this.repath = 0;
  }

  onSignal(id: string, _data?: Record<string, unknown>): void {
    void id;
  }

  /** Caught with Parth: back to Special Room A. */
  onCapture(): void {
    if (!this.following && !this.leaving) return;
    this.story.setFlag(this.def.freedFlag, false);
    this.story.setFlag(this.def.followFlag, false);
    // Doors reset with the detention/wipe reset; he is put back once the capture is over.
    this.actor.show(false);
    void this.waitCaptureOver();
  }

  private async waitCaptureOver(): Promise<void> {
    while (this.story.capturing) await this.story.sleep(0.5);
    this.goHome();
  }

  onWipe(): void {
    this.goHome();
  }

  update(dt: number): void {
    if (!this.following) return;
    const g = this.rt.game;
    const a = this.actor;
    const parth = g.player.position;
    // Parth jumped (the lift ride, a fade): Kabir comes along, a step behind him.
    if (parth.distanceTo(this.lastParth) > 12 && !this.story.capturing) {
      const back = new Vector3(Math.sin(g.player.yaw), 0, Math.cos(g.player.yaw)).multiplyScalar(1.4);
      a.place(parth.clone().add(back), g.player.yaw + Math.PI);
    }
    this.lastParth.copy(parth);
    const d = a.position.distanceTo(parth);
    a.lookTargetWeight = d < 6 ? 0.6 : 0;
    this.repath -= dt;
    if (d < this.def.follow.near) {
      if (a.walking) a.stop();
      a.faceTo(parth);
      return;
    }
    if (this.repath > 0 && a.walking && this.goal.distanceTo(parth) < 1.5) return;
    this.repath = this.def.follow.repath;
    this.goal.copy(parth);
    const speed = d > this.def.follow.far ? this.def.follow.run : this.def.follow.walk;
    void a.walkTo(parth.clone(), speed, false);
  }

  debug(): Record<string, unknown> {
    return {
      following: this.following,
      visits: this.story.getVar(this.def.visits),
      freed: this.story.hasFlag(this.def.freedFlag),
      door: this.door ? { open: this.door.isOpen, locked: this.door.isLocked } : null,
    };
  }
}
