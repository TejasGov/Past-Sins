import { Box3, Object3D, Vector3 } from "three";
import { Emitter } from "../core/events";
import { loadJSON, type MemoryData } from "../content/content";
import type { Game } from "../game/game";
import type { StaticBuilder } from "../world/builder";
import type { BuiltFloor } from "../world/campus/blueprintFloor";
import type { ItemCategory } from "../systems/inventory";
import { StoryState } from "./state";
import { StoryUI } from "./ui";
import { runDialogue } from "./dialogue";
import { resolvePlace } from "./place";
import { TriggerProp, TriggerZone } from "./triggers";
import { FEATURES } from "./features";
import type {
  Action, Condition, DialogueDef, DocumentDef, ObjectiveDef, StoryEvents, StoryFeature, StoryIndex, TriggerDef,
} from "./types";

export interface StoryData {
  index: StoryIndex & { acts?: Record<string, { title: string; sub?: string }> };
  triggers: TriggerDef[];
  documents: Map<string, DocumentDef>;
  dialogue: Map<string, DialogueDef>;
  objectives: ObjectiveDef[];
  features: Map<string, unknown>;
}

/** Loads public/data/story/index.json and every file it lists (missing files are logged and skipped). */
export async function loadStoryData(): Promise<StoryData> {
  const empty: StoryIndex = { triggers: [], documents: [], dialogue: [], objectives: [], features: {} };
  const index = await loadJSON<StoryData["index"]>("data/story/index.json").catch((err) => {
    console.error("[story] index.json", err);
    return empty;
  });
  const lists = async <T>(files: string[]) =>
    (await Promise.all(files.map((f) => loadJSON<T[]>(f).catch((err) => (console.error(`[story] ${f}`, err), [] as T[]))))).flat();
  const [triggers, documents, dialogue, objectives] = await Promise.all([
    lists<TriggerDef>(index.triggers ?? []),
    lists<DocumentDef>(index.documents ?? []),
    lists<DialogueDef>(index.dialogue ?? []),
    lists<ObjectiveDef>(index.objectives ?? []),
  ]);
  const features = new Map<string, unknown>();
  await Promise.all(
    Object.entries(index.features ?? {}).map(async ([id, file]) => {
      features.set(id, await loadJSON<unknown>(file).catch((err) => (console.error(`[story] ${file}`, err), null)));
    }),
  );
  return {
    index,
    triggers,
    documents: new Map(documents.map((d) => [d.id, d])),
    dialogue: new Map(dialogue.map((d) => [d.id, d])),
    objectives,
    features,
  };
}

type Focus = { root: Object3D; dissolve?: () => void };

/**
 * The "Again" story runtime: cycle state that survives wipes (and reloads),
 * flags, conditions, data-driven actions/triggers/documents/dialogue,
 * objectives, and the capture → wipe → wake loop. Features (one per
 * workstream, src/story/features/) plug in through the hooks below; see
 * docs/story/BUILD_PLAN.md for the vocabulary.
 */
export class StoryDirector {
  readonly state = new StoryState();
  readonly events = new Emitter<StoryEvents>();
  readonly ui: StoryUI;
  readonly features: StoryFeature[] = FEATURES;
  readonly props: TriggerProp[] = [];
  readonly zones: TriggerZone[] = [];
  /**
   * Replaces the default DETAINED fade. Return "wipe" to continue into the
   * standard wipe, or "handled" if the handler did its own reset (Act III
   * night restart, endings).
   */
  captureHandler: ((reason: string) => Promise<"wipe" | "handled">) | null = null;
  /** Show the default "CYCLE n" banner after a wipe (the loop feature may present its own). */
  wipeBanner = true;
  capturing = false;
  private timers: { t: number; resolve: () => void }[] = [];
  private objectiveId = "";
  private objectiveTimer = 0;
  private dirty = false;
  private saveTimer = 0;
  private uiLock = false;
  private shardCache = new Map<string, MemoryData>();

  constructor(
    readonly game: Game,
    readonly data: StoryData,
  ) {
    this.ui = new StoryUI(game.hud.root);
  }

  featureData(id: string): unknown {
    return this.data.features.get(id) ?? null;
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  /** Restores the cycle state and memories; call before pickups are spawned. */
  loadSave(): void {
    const d = StoryState.load();
    if (!d) return;
    this.state.restore(d);
    this.game.memory.restore((d.memories as { memories?: [] } | null) ?? null);
  }

  save(): void {
    StoryState.write(this.state.serialize(this.game.memory.serialize()));
    this.dirty = false;
  }

  /** Dev: wipe the save and start again at cycle 41. */
  resetSave(): void {
    StoryState.clear();
    location.search = "?fresh";
  }

  private markDirty(): void {
    this.dirty = true;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  buildStatic(b: StaticBuilder, floors: Map<string, BuiltFloor>): void {
    for (const f of this.features) {
      try {
        f.buildStatic?.(b, floors, this.featureData(f.id));
      } catch (err) {
        console.error(`[story] ${f.id}.buildStatic`, err);
      }
    }
  }

  async init(): Promise<void> {
    const g = this.game;
    g.memory.events.on("memory_collected", (r) => {
      this.addWall(r.id, r.title);
      this.events.emit("shard", { id: r.id });
      this.markDirty();
      this.refreshObjectives();
    });
    g.memory.events.on("clue_learned", (c) => {
      this.state.codes.add(c);
      this.markDirty();
    });
    g.inventory.events.on("inventory_changed", () => this.refreshObjectives());
    for (const m of g.memory.all()) this.addWall(m.id, m.title);
    await this.prefetchShards();
    this.spawnTriggers();
    for (const f of this.features) {
      try {
        await f.init?.({ game: g, data: this.featureData(f.id) });
      } catch (err) {
        console.error(`[story] ${f.id}.init`, err);
      }
    }
    this.refreshObjectives();
  }

  update(dt: number): void {
    const g = this.game;
    this.ui.update(dt, g.input);
    // Documents and choices own the keyboard: freeze Parth while one is open.
    if (this.ui.blocking && !this.uiLock && g.player.controlEnabled) {
      this.uiLock = true;
      g.player.setControlEnabled(false);
    } else if (!this.ui.blocking && this.uiLock) {
      this.uiLock = false;
      g.player.setControlEnabled(true);
    }
    for (let i = this.timers.length - 1; i >= 0; i--) {
      const t = this.timers[i];
      t.t -= dt;
      if (t.t <= 0) {
        this.timers.splice(i, 1);
        t.resolve();
      }
    }
    for (const p of this.props) p.update(dt, this.triggerAvailable(p.def));
    if (!this.capturing && g.player.controlEnabled) {
      const c = g.player.center;
      for (const z of this.zones) {
        const inside = z.box.containsPoint(c);
        if (inside && !z.inside && this.triggerAvailable(z.def)) void this.fireTrigger(z.def);
        z.inside = inside;
      }
    }
    for (const f of this.features) f.update?.(dt);
    this.objectiveTimer -= dt;
    if (this.objectiveTimer <= 0) {
      this.objectiveTimer = 1;
      this.refreshObjectives();
    }
    this.saveTimer -= dt;
    if (this.dirty && this.saveTimer <= 0) {
      this.saveTimer = 1;
      this.save();
    }
  }

  /** Game-time delay (advances with `update`, so automation via __game.step stays exact). */
  sleep(seconds: number): Promise<void> {
    return new Promise((resolve) => this.timers.push({ t: seconds, resolve }));
  }

  // ── Flags, wall, acts ─────────────────────────────────────────────────────
  hasFlag(flag: string): boolean {
    return this.state.flags.has(flag);
  }

  setFlag(flag: string, on = true): void {
    if (this.state.flags.has(flag) === on) return;
    if (on) this.state.flags.add(flag);
    else this.state.flags.delete(flag);
    this.events.emit("flag", { flag, on });
    this.markDirty();
    this.refreshObjectives();
  }

  addWall(id: string, text: string): void {
    if (this.state.wall.some((w) => w.id === id)) return;
    const entry = { id, text, cycle: this.state.cycle };
    this.state.wall.push(entry);
    this.events.emit("wall", entry);
    this.markDirty();
  }

  setAct(act: number): void {
    if (this.state.act === act) return;
    this.state.act = act;
    this.events.emit("act", { act });
    const t = this.data.index.acts?.[String(act)];
    if (t) void this.ui.banner(t.title, t.sub ?? "", 4);
    this.save();
    this.refreshObjectives();
  }

  getVar(name: string): number {
    return this.state.vars.get(name) ?? 0;
  }

  setVar(name: string, value: number): void {
    this.state.vars.set(name, value);
    this.markDirty();
    this.refreshObjectives();
  }

  addVar(name: string, by = 1): number {
    const v = this.getVar(name) + by;
    this.setVar(name, v);
    return v;
  }

  signal(id: string, data?: Record<string, unknown>): void {
    this.events.emit("signal", { id, data });
  }

  // ── Conditions & actions ──────────────────────────────────────────────────
  check(c: Condition): boolean {
    const g = this.game;
    const s = this.state;
    if (c.all && !c.all.every((x) => this.check(x))) return false;
    if (c.any && !c.any.some((x) => this.check(x))) return false;
    if (c.not && this.check(c.not)) return false;
    if (c.flag !== undefined && !s.flags.has(c.flag)) return false;
    if (c.shard !== undefined && !g.memory.hasMemory(c.shard)) return false;
    if (c.item !== undefined && !g.inventory.has(c.item)) return false;
    if (c.code !== undefined && !s.codes.has(c.code) && !g.memory.knowsClue(c.code)) return false;
    if (c.act !== undefined && s.act !== c.act) return false;
    if (c.actAtLeast !== undefined && s.act < c.actAtLeast) return false;
    if (c.cycleAtLeast !== undefined && s.cycle < c.cycleAtLeast) return false;
    if (c.hours) {
      const h = g.env.timeHours;
      const [a, b] = c.hours;
      if (!(a <= b ? h >= a && h < b : h >= a || h < b)) return false;
    }
    if (c.day !== undefined && g.env.dayNumber !== c.day) return false;
    if (c.count) {
      const v = this.getVar(c.count.name);
      if (c.count.atLeast !== undefined && v < c.count.atLeast) return false;
      if (c.count.below !== undefined && v >= c.count.below) return false;
    }
    return true;
  }

  async run(actions: Action[], focus?: Focus): Promise<void> {
    for (const a of actions) await this.runOne(a, focus);
  }

  private async runOne(a: Action, focus?: Focus): Promise<void> {
    const g = this.game;
    if ("setFlag" in a) this.setFlag(a.setFlag, true);
    else if ("clearFlag" in a) this.setFlag(a.clearFlag, false);
    else if ("shard" in a) await this.playShard(a.shard, focus);
    else if ("wall" in a) this.addWall(a.wall, a.text);
    else if ("give" in a) {
      const cat = a.give.category ?? "MISSION_ITEM";
      const ok =
        cat === "KEY" || cat === "ACCESS_CARD"
          ? g.access.addKey(a.give.id, a.give.label, cat)
          : g.inventory.add({ id: a.give.id, displayName: a.give.label, category: cat as ItemCategory }, 1, false);
      if (ok) g.hud.showMessage(`${a.give.label.toUpperCase()} ACQUIRED`, 2);
    } else if ("take" in a) g.inventory.remove(a.take);
    else if ("add" in a) this.addVar(a.add, a.by ?? 1);
    else if ("learnCode" in a) {
      this.state.codes.add(a.learnCode);
      this.markDirty();
    } else if ("message" in a) g.hud.showMessage(a.message, a.seconds ?? 2);
    else if ("say" in a) {
      this.events.emit("dialogue", { id: "", speaker: a.speaker ?? "", text: a.say });
      await this.ui.say(a.speaker ?? "", a.say, a.seconds);
    } else if ("dialogue" in a) {
      const d = this.data.dialogue.get(a.dialogue);
      if (d) await runDialogue(d, this);
      else console.warn(`[story] no dialogue "${a.dialogue}"`);
    } else if ("document" in a) {
      const d = this.data.documents.get(a.document);
      if (d) await this.ui.showDocument(d);
      else console.warn(`[story] no document "${a.document}"`);
    } else if ("act" in a) this.setAct(a.act);
    else if ("objective" in a) this.setFlag(`objective:${a.objective}`);
    else if ("wait" in a) await this.sleep(a.wait);
    else if ("signal" in a) this.signal(a.signal, a.data);
    else if ("capture" in a) void this.capture(a.capture);
  }

  /** Plays a memory shard (data/memories/<id>.json) with the reconstruction sequence. */
  async playShard(id: string, focus?: Focus): Promise<void> {
    const g = this.game;
    if (g.memory.hasMemory(id)) return;
    let data = this.shardCache.get(id);
    if (!data) {
      data = (await loadJSON<MemoryData>(`data/memories/${id}.json`).catch(() => null)) ?? undefined;
      if (!data) {
        console.error(`[story] missing data/memories/${id}.json`);
        return;
      }
      this.shardCache.set(id, data);
    }
    const target = focus ?? this.pointAhead();
    await new Promise<void>((resolve) => g.collectMemory(target, data!, resolve));
  }

  /** Loads every shard the data references up front, so playing one never waits on the network. */
  private async prefetchShards(): Promise<void> {
    const ids = new Set<string>();
    const scan = (actions?: Action[]) => actions?.forEach((a) => "shard" in a && ids.add(a.shard));
    for (const t of this.data.triggers) scan(t.actions);
    for (const d of this.data.dialogue.values()) {
      for (const n of d.nodes) {
        if ("speaker" in n) scan(n.actions);
        else if ("choice" in n) n.choice.forEach((c) => scan(c.actions));
      }
    }
    const extra = this.data.index.shards ?? [];
    for (const id of extra) ids.add(id);
    await Promise.all(
      [...ids].map(async (id) => {
        const data = await loadJSON<MemoryData>(`data/memories/${id}.json`).catch(() => null);
        if (data) this.shardCache.set(id, data);
        else console.error(`[story] missing data/memories/${id}.json`);
      }),
    );
  }

  private pointAhead(): Focus {
    const cam = this.game.render.camera;
    const o = new Object3D();
    o.position.copy(cam.getWorldPosition(new Vector3()).add(cam.getWorldDirection(new Vector3()).multiplyScalar(1.2)));
    return { root: o };
  }

  // ── Triggers ──────────────────────────────────────────────────────────────
  private spawnTriggers(): void {
    const g = this.game;
    for (const def of this.data.triggers) {
      const place = resolvePlace(def.at, g.anchors, g.floors, g.chunks);
      if (!place) {
        console.warn(`[story] trigger "${def.id}": place not found`, def.at);
        continue;
      }
      if (def.kind === "zone") {
        const [hx, hy, hz] = def.size ?? [1.5, 1.5, 1.5];
        const c = place.position.clone().add(new Vector3(0, hy, 0));
        this.zones.push(new TriggerZone(def, new Box3(c.clone().sub(new Vector3(hx, hy, hz)), c.clone().add(new Vector3(hx, hy, hz)))));
        continue;
      }
      const prop = new TriggerProp(
        def,
        g.materials,
        (m) => g.render.prepareMaterial(m),
        () => this.triggerAvailable(def),
        (p) => this.fireTrigger(p.def, p.shard ?? { root: p.root }),
      );
      prop.root.position.copy(place.position);
      prop.root.rotation.y = place.yaw;
      g.chunkGroup(place.chunk).add(prop.root);
      g.interaction.register(prop);
      this.props.push(prop);
    }
  }

  triggerAvailable(def: TriggerDef): boolean {
    if ((def.once ?? true) && this.state.flags.has(`trigger:${def.id}`)) return false;
    return !def.when || this.check(def.when);
  }

  async fireTrigger(def: TriggerDef, focus?: Focus): Promise<void> {
    if (def.once ?? true) this.setFlag(`trigger:${def.id}`);
    await this.run(def.actions, focus);
  }

  // ── Objectives ────────────────────────────────────────────────────────────
  get hasObjectives(): boolean {
    return this.data.objectives.length > 0;
  }

  /** Shows the first objective whose `when` holds and `done` doesn't. */
  refreshObjectives(): void {
    if (!this.hasObjectives) return;
    const o = this.data.objectives.find((x) => (!x.when || this.check(x.when)) && !this.check(x.done));
    if (!o || o.id === this.objectiveId) return;
    this.objectiveId = o.id;
    this.game.hud.setObjective(o.title, o.text);
  }

  // ── Capture → wipe → wake ─────────────────────────────────────────────────
  /** Parth is caught (or gives himself up): capture sequence, then a wipe unless the handler took over. */
  async capture(reason = "caught"): Promise<void> {
    if (this.capturing) return;
    const g = this.game;
    this.capturing = true;
    g.failureInProgress = true;
    g.player.setFailureLocked();
    this.ui.clearSubtitles();
    this.events.emit("capture", { reason });
    try {
      let next: "wipe" | "handled" = "wipe";
      if (this.captureHandler) next = await this.captureHandler(reason);
      else {
        void g.hud.showDetained();
        await this.sleep(2.6);
      }
      if (next === "wipe") await this.wipe();
    } finally {
      this.capturing = false;
    }
  }

  /**
   * The wipe: cycle + 1; inventory, keys, cards and unlocks go (keys back on
   * their racks, the locker card back in its locker), the clock returns to
   * 06:00 on day one, guards/doors reset, Parth wakes in N03. Memories, codes,
   * flags and the wall stay.
   */
  async wipe(): Promise<void> {
    const g = this.game;
    this.state.cycle++;
    this.ui.clearSubtitles();
    g.inventory.clearAll();
    g.access.clearUnlocks();
    g.session.resetCycle(g);
    g.env.setTimeHours(6);
    g.env.dayNumber = 1;
    g.detentionReset();
    for (const f of this.features) {
      try {
        f.onWipe?.(this.state.cycle);
      } catch (err) {
        console.error(`[story] ${f.id}.onWipe`, err);
      }
    }
    // "cycle:"-prefixed flags last one cycle (today's dose, Jagran, Bhosle's card…); onWipe
    // hooks above still see the ending cycle's values.
    for (const f of [...this.state.flags]) if (f.startsWith("cycle:")) this.setFlag(f, false);
    for (const k of [...this.state.vars.keys()]) if (k.startsWith("cycle:")) this.state.vars.delete(k);
    this.save();
    this.events.emit("wipe", { cycle: this.state.cycle });
    this.refreshObjectives();
    if (this.wipeBanner) void this.ui.banner(`CYCLE ${this.state.cycle}`, "06:00 · DAY ONE", 3.4);
  }

  debugInfo(): Record<string, unknown> {
    return {
      cycle: this.state.cycle,
      act: this.state.act,
      objective: this.objectiveId,
      flags: [...this.state.flags].filter((f) => !f.startsWith("trigger:")),
      vars: Object.fromEntries(this.state.vars),
      wall: this.state.wall.length,
    };
  }
}
