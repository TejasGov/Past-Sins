import { Box3, MeshStandardMaterial, Vector3, type Object3D } from "three";
import type { StaticBuilder } from "../world/builder";
import type { BuiltFloor } from "../world/campus/blueprintFloor";
import type { DoorSpec } from "../world/types";
import type { MemoryData, Objective, SessionContent, ZoneDef } from "../content/content";
import { V } from "../world/props";
import { AccessCardPickup, KeyPickup, KeypadLocker, MemoryShard } from "../interact/pickups";
import type { Game } from "./game";

interface RackSlot {
  position: Vector3;
  yaw: number;
  entry: { id: string; label: string; short: string };
  scale: number;
  chunk: string;
}

interface Zone {
  def: ZoneDef;
  box: Box3;
  inside: boolean;
}

/**
 * Port of CampusSessionContent + CampusPhaseTwoGameplay: mounts the memory
 * shelf content, key racks, the 2718 locker, restricted zones and the
 * objective chain from session.json — no story text is hard-coded here.
 */
export class Session {
  private slots: RackSlot[] = [];
  private lockerSpots: { def: SessionContent["lockers"][number]; position: Vector3; chunk: string }[] = [];
  readonly shards: MemoryShard[] = [];
  readonly lockers: KeypadLocker[] = [];
  readonly keys: KeyPickup[] = [];
  private zones: Zone[] = [];
  private objectiveIndex = -1;

  constructor(readonly content: SessionContent, readonly memories: Map<string, MemoryData>) {}

  /** Static geometry (racks, hooks, signs) — runs before the builder is finalized. */
  buildStatic(b: StaticBuilder, floors: Map<string, BuiltFloor>, doorSpecs: DoorSpec[]): void {
    for (const rack of this.content.keyRacks) {
      const anchor = b.anchors.get(rack.anchor);
      if (!anchor) continue;
      b.setChunk("cellhouseA", true);
      b.within(anchor.position, anchor.yaw, () => {
        b.box(V(0, 1.45, 0), V(2.5, 1.25, 0.1), { mat: "metal", color: 0x52615a });
        for (const x of [-1.04, 1.04]) {
          b.box(V(x, 0.56, 0), V(0.1, 1.12, 0.1), { mat: "dark", color: 0x343b35 });
          b.box(V(x, 0.04, 0), V(0.42, 0.08, 0.72), { mat: "dark", color: 0x343b35 });
        }
        b.box(V(0, 2.25, -0.0), V(2.45, 0.28, 0.05), { mat: "dark", color: 0x29362d, collide: false });
        b.box(V(0, 2.08, 0), V(0.06, 0.35, 0.06), { mat: "dark", collide: false });
        b.sign(rack.title, V(0, 2.25, 0.035), 0, 0xe7e0c2, 0.0028);
        b.sign("STAFF KEY RACK", V(0, 1.45, -0.06), Math.PI, 0xc9c397, 0.0035);
        rack.keys.forEach((entry, i) => {
          const at = V(-0.8 + i * 0.8, 1.42, 0.14);
          b.box(V(at.x, at.y + 0.44 * 0.72, 0.105), V(0.035, 0.04, 0.17), { mat: "steel", color: 0xa4aaa1, collide: false });
          b.sign(entry.short, V(at.x, at.y - 0.42, 0.06), 0, 0xe8e2c4, 0.0022);
          this.slots.push({ position: b.toWorld(at), yaw: b.worldYaw(0), entry, scale: 0.72, chunk: "cellhouseA" });
        });
      });
    }
    const reg = this.content.cellKeyRegister;
    const floor = reg ? floors.get(reg.plan) : undefined;
    const room = reg && floor ? floor.rooms.get(reg.room) : undefined;
    if (reg && floor && room) {
      const entries = new Map<string, { id: string; label: string; short: string }>();
      for (const d of doorSpecs) {
        const key = d.requiredKey;
        if (!key || key === "cell_master_key") continue;
        if (key.startsWith("cellhouse_a_") || key.startsWith("cell_cellhouse-b")) {
          const short = key.replace("cellhouse_a_", "A ").replace("_key", "").replace("floor", "F").replace("north", "N").replace("south", "S")
            .replace("cell_cellhouse-b-", "B ").replace(/_/g, " ");
          entries.set(key, { id: key, label: `${d.displayName} Key`, short: short.toUpperCase() });
        }
      }
      const ids = [...entries.keys()].sort();
      const center = floor.roomCenters.get(reg.room)!;
      b.setChunk("hq", true);
      for (const side of [-1, 1]) {
        b.within(center.clone().add(V(side * (room.w / 2 - 0.11), 0, 0)), (-side * Math.PI) / 2, () => {
          b.box(V(0, 1.65, 0.04), V(6.3, 2.45, 0.08), { mat: "metal", color: 0x48564d, collide: false });
          b.sign("INDIVIDUAL CELL KEY REGISTER", V(0, 3.0, 0.09), 0, 0xe7e0c2, 0.003);
          for (let slot = 0; slot < 36; slot++) {
            const index = slot + (side < 0 ? 0 : 36);
            if (index >= ids.length) break;
            const at = V(-2.68 + (slot % 9) * 0.67, 0.66 + Math.floor(slot / 9) * 0.62, 0.14);
            b.box(V(at.x, at.y + 0.44 * 0.55, 0.105), V(0.035, 0.04, 0.17), { mat: "steel", color: 0xa4aaa1, collide: false, shadow: false });
            this.slots.push({ position: b.toWorld(at), yaw: b.worldYaw(0), entry: entries.get(ids[index])!, scale: 0.55, chunk: "hq" });
          }
        });
      }
    }
    for (const def of this.content.lockers) {
      const f = floors.get(def.plan);
      const r = f?.rooms.get(def.room);
      const c = f?.roomCenters.get(def.room);
      if (!f || !r || !c) continue;
      const position = c.clone().add(V(def.offset[0], def.offset[1], r.d / 2 - def.fromSouthWall));
      this.lockerSpots.push({ def, position, chunk: "maintenance" });
      b.within(position.clone().add(V(0, 0, 0.05)), 0, () => b.blocker(V(0, 0, 0), V(1.2, 2.2, 0.65), false));
    }
    for (const z of this.content.restrictedZones) {
      let box: Box3 | null = null;
      if (z.center && z.size) box = new Box3().setFromCenterAndSize(V(...z.center), V(...z.size));
      else if (z.plan && z.room) {
        const f = floors.get(z.plan);
        const r = f?.rooms.get(z.room);
        const c = f?.roomCenters.get(z.room);
        if (r && c) box = new Box3().setFromCenterAndSize(c.clone().add(V(0, 2, 0)), V(r.w, 4, r.d));
      }
      if (box) this.zones.push({ def: z, box, inside: false });
    }
  }

  /** Interactables — runs after the static world exists. */
  spawn(game: Game, parentFor: (chunk: string) => Object3D): void {
    const prepare = (m: MeshStandardMaterial) => game.render.prepareMaterial(m);
    const ctx = { materials: game.materials, prepare };
    for (const slot of this.slots) {
      const key = new KeyPickup(ctx, slot.entry.id, slot.entry.label, slot.entry.short, (k) => {
        if (!game.access.addKey(k.keyId, k.displayName)) return false;
        game.hud.showMessage(`${k.displayName.toUpperCase()} ACQUIRED`, 2.0);
        return true;
      }, slot.scale);
      key.root.position.copy(slot.position);
      key.root.rotation.y = slot.yaw;
      if (game.access.hasKey(slot.entry.id)) {
        key.collected = true;
        key.root.visible = false;
      }
      parentFor(slot.chunk).add(key.root);
      game.interaction.register(key);
      this.keys.push(key);
    }
    for (const m of this.content.memories) {
      const anchor = game.anchors.get(m.anchor);
      const data = this.memories.get(m.id);
      if (!anchor || !data) continue;
      const shard = new MemoryShard(prepare, m.id, (s) => game.collectMemory(s, data));
      shard.root.position.copy(anchor.position);
      if (game.memory.hasMemory(m.id)) {
        shard.collected = true;
        shard.root.visible = false;
      }
      parentFor("cellhouseA").add(shard.root);
      game.interaction.register(shard);
      this.shards.push(shard);
    }
    for (const spot of this.lockerSpots) {
      const def = spot.def;
      const locker = new KeypadLocker(
        ctx,
        def.code,
        (clue) => game.memory.knowsClue(clue),
        def.reward.label,
        (card: AccessCardPickup) => {
          const ok = game.inventory.add({ id: def.reward.id, displayName: def.reward.label, category: def.reward.category }, 1, false);
          if (ok) game.hud.showMessage(`${card.label.toUpperCase()} ACQUIRED`, 2.4);
          return ok;
        },
        (ok) => game.hud.showMessage(ok ? "CODE ACCEPTED" : "ACCESS DENIED", 1.2),
      );
      locker.root.position.copy(spot.position);
      parentFor(spot.chunk).add(locker.root);
      game.interaction.register(locker);
      game.interaction.register(locker.card);
      this.lockers.push(locker);
    }
    this.advanceObjectives(game);
  }

  update(dt: number, game: Game): void {
    for (const s of this.shards) s.update(dt);
    const p = game.player.center;
    for (const z of this.zones) {
      const inside = z.box.containsPoint(p);
      if (inside !== z.inside) {
        z.inside = inside;
        if (inside) game.player.enterRestrictedZone(z.def.id, z.def.multiplier);
        else game.player.exitRestrictedZone(z.def.id);
      }
    }
  }

  get zoneBoxes(): { id: string; box: Box3 }[] {
    return this.zones.map((z) => ({ id: z.def.id, box: z.box }));
  }

  private isDone(o: Objective, game: Game): boolean {
    const w = o.doneWhen;
    if (w.never) return false;
    if (w.memory && !game.memory.hasMemory(w.memory)) return false;
    if (w.clue && !game.memory.knowsClue(w.clue)) return false;
    if (w.item && !game.inventory.has(w.item)) return false;
    return true;
  }

  /** A wipe: keys back on their racks and hooks, lockers shut with their cards inside. */
  resetCycle(_game: Game): void {
    for (const k of this.keys) k.reset();
    for (const l of this.lockers) l.reset();
  }

  /** Shows the first unfinished objective; call after any progress event. */
  advanceObjectives(game: Game): void {
    // Story objectives (public/data/story/objectives.json) supersede session.json's chain.
    if (game.story?.hasObjectives) {
      game.story.refreshObjectives();
      return;
    }
    const list = this.content.objectives;
    let index = list.findIndex((o) => !this.isDone(o, game));
    if (index < 0) index = list.length - 1;
    if (index !== this.objectiveIndex) {
      this.objectiveIndex = index;
      const o = list[index];
      if (o) game.hud.setObjective(o.title, o.text);
    }
  }

  get currentObjective(): Objective | undefined {
    return this.content.objectives[this.objectiveIndex];
  }
}
