import { Emitter } from "../core/events";
import type { Inventory } from "./inventory";

export type AccessEvents = {
  key_added: string;
  key_removed: string;
  access_unlocked: string;
  inventory_changed: void;
};

/**
 * Port of scripts/systems/access_manager.gd: a key/access-card view over the
 * inventory plus permanently unlocked access IDs for the session.
 */
export class AccessManager {
  readonly events = new Emitter<AccessEvents>();
  private unlocked = new Set<string>();

  constructor(private inventory: Inventory) {
    inventory.events.on("item_added", ({ id }) => {
      const def = inventory.definition(id);
      if (def && (def.category === "KEY" || def.category === "ACCESS_CARD")) {
        this.events.emit("key_added", id);
        this.events.emit("inventory_changed", undefined);
      }
    });
    inventory.events.on("item_removed", ({ id }) => {
      this.events.emit("key_removed", id);
      this.events.emit("inventory_changed", undefined);
    });
  }

  private norm(id: string): string {
    return id.trim().toLowerCase();
  }

  hasKey(id: string): boolean {
    const n = this.norm(id);
    if (!n) return false;
    const def = this.inventory.definition(n);
    return !!def && (def.category === "KEY" || def.category === "ACCESS_CARD");
  }

  addKey(id: string, displayName = "", category: "KEY" | "ACCESS_CARD" = "KEY", devOnly = false): boolean {
    const n = this.norm(id);
    if (!n || this.hasKey(n)) return false;
    const label = displayName.trim() || n.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
    return this.inventory.add({ id: n, displayName: label, category, devOnly }, 1, false);
  }

  removeKey(id: string): boolean {
    return this.hasKey(id) && this.inventory.remove(id);
  }

  unlockAccess(id: string): boolean {
    const n = this.norm(id);
    if (!n || this.unlocked.has(n)) return false;
    this.unlocked.add(n);
    this.events.emit("access_unlocked", n);
    this.events.emit("inventory_changed", undefined);
    return true;
  }

  isAccessUnlocked(id: string): boolean {
    return this.unlocked.has(this.norm(id));
  }

  keys(): string[] {
    return this.inventory.entries().filter((e) => e.def.category === "KEY" || e.def.category === "ACCESS_CARD").map((e) => e.def.id);
  }

  serialize(): string[] {
    return [...this.unlocked];
  }

  restore(ids: string[] | null): void {
    for (const id of ids ?? []) this.unlocked.add(id);
  }

  clearUnlocks(): void {
    this.unlocked.clear();
  }
}
