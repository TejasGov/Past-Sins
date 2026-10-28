import { Object3D, Vector3, type Material } from "three";
import { loadCharacter, type CharacterAsset } from "../../../ai/guardVisual";
import type { Game } from "../../../game/game";
import { chunkAt, resolvePlace } from "../../place";
import type { DocumentDef } from "../../types";
import { NpcActor } from "./actor";
import { POSES } from "./pose";
import { stool } from "./props";
import { NpcDialogue } from "./script";
import { Bhosle } from "./bhosle";
import { Kabir } from "./kabir";
import { Mother } from "./mother";
import { Meera } from "./meera";
import type { NpcDef, NpcPlace, NpcsData, Step, TalkDef } from "./types";

export interface Placed {
  position: Vector3;
  yaw: number;
}

/** A named behaviour a talk step (`{ "do": … }`) or signal `npcs:do {do}` can start. */
export type Behaviour = () => Promise<void> | void;

/**
 * W4 runtime: owns the four story NPCs (Bhosle, Kabir, Parth's mother,
 * Meera), runs their talks (data: features/npcs.json + dialogue/npcs.json)
 * and reacts to routine signals. Dev/automation handle:
 * `__game.story.features.find(f => f.id === "npcs").runtime`.
 */
export class NpcRuntime {
  readonly dialogue: NpcDialogue;
  readonly actors = new Map<string, NpcActor>();
  readonly behaviours = new Map<string, Behaviour>();
  /** Pose table (dev: tweak live from the console). */
  readonly poses = POSES;
  bhosle!: Bhosle;
  kabir!: Kabir;
  mother!: Mother;
  meera!: Meera;
  /** The talk in progress (one at a time). */
  talkingTo: NpcActor | null = null;
  private abortTalk = false;
  private ownsControl = false;
  private ready = false;
  private docs = new Map<string, DocumentDef>();

  constructor(
    readonly game: Game,
    readonly data: NpcsData,
  ) {
    this.dialogue = new NpcDialogue(game.story, data.tokens ?? {});
    for (const d of data.documents ?? []) this.docs.set(d.id, d);
  }

  get story() {
    return this.game.story;
  }

  async init(): Promise<void> {
    const g = this.game;
    const prepare = (m: Material) => g.render.prepareMaterial(m);
    const asset = await loadCharacter(prepare);
    if (!asset) {
      console.warn("[npcs] guard.glb unavailable: no NPCs");
      return;
    }
    const make = (id: string, def: NpcDef) => this.makeActor(id, def, asset, prepare);
    this.bhosle = new Bhosle(this, make("bhosle", this.data.bhosle), this.data.bhosle);
    this.kabir = new Kabir(this, make("kabir", this.data.kabir), this.data.kabir);
    this.mother = new Mother(this, make("mother", this.data.mother), this.data.mother);
    this.meera = new Meera(this, make("meera", this.data.meera), this.data.meera, this.data.chair);
    const story = this.story;
    story.events.on("signal", ({ id, data }) => {
      if (id === "npcs:do" && typeof data?.do === "string") void this.behave(data.do);
      this.bhosle.onSignal(id, data);
      this.kabir.onSignal(id, data);
      this.mother.onSignal(id);
      this.meera.onSignal(id);
    });
    story.events.on("capture", () => {
      if (this.talkingTo) this.abortTalk = true;
      this.kabir.onCapture();
      this.meera.onCapture();
    });
    this.ready = true;
  }

  private makeActor(id: string, def: NpcDef, asset: CharacterAsset, prepare: (m: Material) => void): NpcActor {
    const g = this.game;
    const actor = new NpcActor(
      id,
      asset,
      def.look,
      {
        nav: () => g.guards.nav,
        prepare,
        lookTarget: () => g.player.eyePosition,
      },
      def.hit,
    );
    g.render.scene.add(actor.root);
    g.interaction.register(actor);
    this.actors.set(id, actor);
    return actor;
  }

  update(dt: number): void {
    if (!this.ready) return;
    const cam = this.game.render.camera.position;
    this.tick(dt);
    this.bhosle.update(dt);
    this.kabir.update(dt);
    this.mother.update(dt);
    this.meera.update(dt);
    for (const a of this.actors.values()) a.update(dt, cam, this.data.drawDistance ?? 45);
  }

  onWipe(): void {
    if (!this.ready) return;
    this.bhosle.onWipe();
    this.kabir.onWipe();
    this.mother.onWipe();
    this.meera.onWipe();
  }

  /** A stool under a seated NPC: `at` is the actor's spot (the seat sits a little behind it). */
  addStool(at: Placed, back = 0.12): Object3D {
    const st = stool((m) => this.game.render.prepareMaterial(m));
    st.position.copy(at.position).add(new Vector3(-Math.sin(at.yaw) * back, 0, -Math.cos(at.yaw) * back));
    st.rotation.y = at.yaw;
    this.game.chunkGroup(chunkAt(st.position, this.game.chunks)).add(st);
    return st;
  }

  // ── Places ────────────────────────────────────────────────────────────────
  resolve(p: NpcPlace): Placed | null {
    const g = this.game;
    if ("door" in p) {
      const door = g.doors.find((d) => d.spec.persistentId === p.door);
      if (!door) {
        console.warn(`[npcs] no door "${p.door}"`);
        return null;
      }
      const [x, y, z] = p.offset ?? [0, 0, 0];
      const a = door.spec.yaw;
      const c = Math.cos(a);
      const s = Math.sin(a);
      const pos = door.spec.position;
      return { position: new Vector3(pos.x + c * x + s * z, pos.y + y, pos.z - s * x + c * z), yaw: a + (p.yaw ?? 0) };
    }
    const r = resolvePlace(p, g.anchors, g.floors);
    if (!r) console.warn("[npcs] place not found", p);
    return r ? { position: r.position, yaw: r.yaw } : null;
  }

  // ── Talks ─────────────────────────────────────────────────────────────────
  /** First talk entry whose `when` holds. */
  pickTalk(def: NpcDef): TalkDef | null {
    return def.talk.find((t) => !t.when || this.story.check(t.when)) ?? null;
  }

  canTalk(): boolean {
    const g = this.game;
    return !this.talkingTo && !this.story.capturing && g.player.controlEnabled && !this.story.ui.blocking && !g.hud.memoryPlaying;
  }

  /** Runs a talk with `actor` (lock = freeze Parth facing the speaker). */
  async talk(actor: NpcActor, talk: TalkDef): Promise<void> {
    if (this.talkingTo) return;
    const g = this.game;
    this.talkingTo = actor;
    this.abortTalk = false;
    actor.lookTargetWeight = 1;
    // Seated talkers turn their head, not their body (the stool doesn't swivel).
    if (!actor.hasPose("sit")) actor.faceTo(g.player.position);
    if (talk.lock && g.player.controlEnabled) {
      this.ownsControl = true;
      g.player.setControlEnabled(false);
      this.turnParthTo(actor.bonePoint("mixamorigHead"));
    }
    try {
      await this.steps(talk.steps, actor);
    } catch (err) {
      console.error("[npcs] talk", err);
    } finally {
      this.endTalk();
    }
  }

  private endTalk(): void {
    const g = this.game;
    this.talkingTo = null;
    if (this.ownsControl) {
      this.ownsControl = false;
      if (!this.story.capturing && !g.failureInProgress) g.player.setControlEnabled(true);
    }
    this.abortTalk = false;
  }

  get aborted(): boolean {
    return this.abortTalk || this.story.capturing;
  }

  async steps(list: Step[], actor: NpcActor | null): Promise<void> {
    for (const s of list) {
      if (this.aborted) return;
      await this.step(s, actor);
    }
  }

  private async step(s: Step, actor: NpcActor | null): Promise<void> {
    const story = this.story;
    if ("dialogue" in s) {
      const def = this.data.dialogue?.find((d) => d.id === s.dialogue) ?? story.data.dialogue.get(s.dialogue);
      if (!def) return console.warn(`[npcs] no dialogue "${s.dialogue}"`);
      await this.dialogue.run(def, {
        speaking: (speaker, on) => this.speaking(speaker, on),
        aborted: () => this.aborted,
      });
    } else if ("run" in s) await story.run(s.run);
    else if ("shard" in s) await story.playShard(s.shard, this.focus(s.focus, actor));
    else if ("document" in s) {
      const d = this.docs.get(s.document) ?? story.data.documents.get(s.document);
      if (d) await story.ui.showDocument(d);
      else console.warn(`[npcs] no document "${s.document}"`);
    } else if ("pose" in s) (s.actor ? this.actors.get(s.actor) : actor)?.pose(s.pose, s.weight ?? 1);
    else if ("do" in s) await this.behave(s.do);
    else if ("wait" in s) await story.sleep(s.wait);
    else if ("if" in s) await this.steps(story.check(s.if) ? s.then : (s.else ?? []), actor);
  }

  async behave(name: string): Promise<void> {
    const b = this.behaviours.get(name);
    if (!b) return console.warn(`[npcs] no behaviour "${name}"`);
    await b();
  }

  private speaking(speaker: string, on: boolean): void {
    for (const [id, a] of this.actors) {
      const def = (this.data as unknown as Record<string, NpcDef>)[id];
      if (def?.speaker === speaker) a.talking = on;
    }
  }

  /** Focus for a shard's camera push: an actor's head/hand/prop, else ahead. */
  private focus(spec: string | undefined, actor: NpcActor | null): { root: Object3D } | undefined {
    if (!spec || !actor) return undefined;
    const [who, what] = spec.includes(":") ? spec.split(":") : [actor.id, spec];
    const a = this.actors.get(who) ?? actor;
    const o = new Object3D();
    const prop = a.props.get(what);
    if (prop) prop.getWorldPosition(o.position);
    else a.bonePoint(what === "hand" ? "mixamorigRightHand" : "mixamorigHead", o.position);
    o.position.y -= 0.17; // collectMemory aims 0.17 m above the focus root
    return { root: o };
  }

  /** Smoothly turns the camera to a world point (Parth looks at whoever is talking). */
  turnParthTo(p: Vector3, seconds = 0.5): void {
    const pl = this.game.player;
    const d = p.clone().sub(pl.eyePosition);
    const yaw = Math.atan2(-d.x, -d.z);
    const pitch = Math.atan2(d.y, Math.hypot(d.x, d.z));
    const y0 = pl.yaw;
    const p0 = pl.pitch;
    let dy = yaw - y0;
    dy = Math.atan2(Math.sin(dy), Math.cos(dy));
    let t = 0;
    const tick = (dt: number) => {
      t = Math.min(1, t + dt / seconds);
      const k = t * t * (3 - 2 * t);
      pl.yaw = y0 + dy * k;
      pl.pitch = p0 + (pitch - p0) * k;
      return t >= 1;
    };
    this.tweens.push(tick);
  }

  private tweens: ((dt: number) => boolean)[] = [];

  tick(dt: number): void {
    for (let i = this.tweens.length - 1; i >= 0; i--) if (this.tweens[i](dt)) this.tweens.splice(i, 1);
  }

  debugInfo(): Record<string, unknown> {
    return {
      talking: this.talkingTo?.id ?? null,
      actors: [...this.actors.values()].map((a) => a.debug()),
      bhosle: this.bhosle?.debug(),
      kabir: this.kabir?.debug(),
      mother: this.mother?.debug(),
      meera: this.meera?.debug(),
    };
  }
}
