import { Emitter } from "../core/events";

export type ItemCategory = "FIREARM" | "MELEE" | "EQUIPMENT" | "KEY" | "ACCESS_CARD" | "MISSION_ITEM" | "AMMO";

export interface ItemDefinition {
  id: string;
  displayName: string;
  category: ItemCategory;
  stackable?: boolean;
  maxStack?: number;
  devOnly?: boolean;
}

export type InventoryEvents = {
  inventory_changed: void;
  item_added: { id: string; quantity: number };
  item_removed: { id: string; quantity: number };
  feedback_requested: string;
};

const FIREARM_SLOTS = 2;

/**
 * Port of InventoryComponent + InventoryManager: two firearm slots, one melee
 * slot, and unique/stackable records for everything else.
 */
export class Inventory {
  readonly events = new Emitter<InventoryEvents>();
  private firearms: (ItemDefinition | null)[] = new Array(FIREARM_SLOTS).fill(null);
  private melee: ItemDefinition | null = null;
  private items = new Map<string, { def: ItemDefinition; count: number }>();

  private norm(id: string): string {
    return id.trim().toLowerCase();
  }

  rejection(def: ItemDefinition, quantity = 1): string {
    if (!def.id.trim() || !def.displayName.trim() || quantity <= 0) return "INVALID ITEM";
    const id = this.norm(def.id);
    if (def.category === "FIREARM") {
      if (!this.firearms.includes(null)) return "FIREARM SLOTS FULL";
      if (this.has(id)) return "ITEM ALREADY OWNED";
    } else if (def.category === "MELEE") {
      if (this.melee) return "MELEE SLOT FULL";
    } else {
      const count = this.count(id);
      if (count > 0 && !def.stackable) return "ITEM ALREADY OWNED";
      if (def.maxStack && count + quantity > def.maxStack) return "ITEM STACK FULL";
    }
    return "";
  }

  add(def: ItemDefinition, quantity = 1, feedback = true): boolean {
    const reason = this.rejection(def, quantity);
    if (reason) {
      if (feedback) this.events.emit("feedback_requested", reason);
      return false;
    }
    const id = this.norm(def.id);
    if (def.category === "FIREARM") this.firearms[this.firearms.indexOf(null)] = def;
    else if (def.category === "MELEE") this.melee = def;
    else this.items.set(id, { def, count: this.count(id) + quantity });
    this.events.emit("item_added", { id, quantity });
    this.events.emit("inventory_changed", undefined);
    if (feedback) this.events.emit("feedback_requested", "ITEM ACQUIRED");
    return true;
  }

  remove(rawId: string, quantity = 1): boolean {
    const id = this.norm(rawId);
    const slot = this.firearms.findIndex((f) => f && this.norm(f.id) === id);
    if (slot >= 0) this.firearms[slot] = null;
    else if (this.melee && this.norm(this.melee.id) === id) this.melee = null;
    else {
      const entry = this.items.get(id);
      if (!entry) return false;
      entry.count -= quantity;
      if (entry.count <= 0) this.items.delete(id);
    }
    this.events.emit("item_removed", { id, quantity });
    this.events.emit("inventory_changed", undefined);
    return true;
  }

  has(rawId: string): boolean {
    return this.count(rawId) > 0;
  }

  count(rawId: string): number {
    const id = this.norm(rawId);
    if (this.firearms.some((f) => f && this.norm(f.id) === id)) return 1;
    if (this.melee && this.norm(this.melee.id) === id) return 1;
    return this.items.get(id)?.count ?? 0;
  }

  definition(rawId: string): ItemDefinition | undefined {
    const id = this.norm(rawId);
    return this.firearms.find((f) => f && this.norm(f.id) === id) ?? (this.melee && this.norm(this.melee.id) === id ? this.melee : undefined) ?? this.items.get(id)?.def ?? undefined;
  }

  firearmSlot(index: number): ItemDefinition | null {
    return this.firearms[index] ?? null;
  }

  entries(): { def: ItemDefinition; count: number }[] {
    const out: { def: ItemDefinition; count: number }[] = [];
    for (const f of this.firearms) if (f) out.push({ def: f, count: 1 });
    if (this.melee) out.push({ def: this.melee, count: 1 });
    for (const e of this.items.values()) out.push({ def: e.def, count: e.count });
    return out;
  }

  clearAll(): void {
    this.firearms.fill(null);
    this.melee = null;
    this.items.clear();
    this.events.emit("inventory_changed", undefined);
  }

  clearDevOnly(): void {
    for (const e of this.entries()) if (e.def.devOnly) this.remove(e.def.id, e.count);
  }

  serialize(): unknown {
    return this.entries().filter((e) => !e.def.devOnly).map((e) => ({ ...e.def, count: e.count }));
  }

  restore(list: (ItemDefinition & { count: number })[] | null): void {
    for (const e of list ?? []) this.add(e, e.count, false);
  }
}
