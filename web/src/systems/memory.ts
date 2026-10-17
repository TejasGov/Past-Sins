import { Emitter } from "../core/events";

export interface MemoryRecord {
  id: string;
  title: string;
  transcript: string;
  clue: string;
}

export type MemoryEvents = {
  memory_collected: MemoryRecord;
  clue_learned: string;
};

/**
 * Port of scripts/systems/memory_manager.gd. Collected memories and learned
 * clues persist for the browser session (sessionStorage) so a detention
 * reload keeps them, exactly like the Godot autoload surviving reload.
 */
export class MemoryManager {
  readonly events = new Emitter<MemoryEvents>();
  private collected = new Map<string, MemoryRecord>();
  private clues = new Map<string, string>();

  collectMemory(record: MemoryRecord): boolean {
    if (this.collected.has(record.id)) return false;
    this.collected.set(record.id, record);
    if (record.clue) {
      this.clues.set(record.clue, record.id);
      this.events.emit("clue_learned", record.clue);
    }
    this.events.emit("memory_collected", record);
    return true;
  }

  hasMemory(id: string): boolean {
    return this.collected.has(id);
  }

  knowsClue(clue: string): boolean {
    return this.clues.has(clue);
  }

  getMemory(id: string): MemoryRecord | undefined {
    return this.collected.get(id);
  }

  all(): MemoryRecord[] {
    return [...this.collected.values()];
  }

  serialize(): unknown {
    return { memories: this.all() };
  }

  restore(data: { memories?: MemoryRecord[] } | null): void {
    for (const m of data?.memories ?? []) {
      this.collected.set(m.id, m);
      if (m.clue) this.clues.set(m.clue, m.id);
    }
  }

  clear(): void {
    this.collected.clear();
    this.clues.clear();
  }
}
