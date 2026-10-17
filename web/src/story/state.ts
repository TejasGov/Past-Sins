import type { WallEntry } from "./types";

const SAVE_KEY = "blacksite.ghostexit.save.v1";

export interface SaveData {
  cycle: number;
  act: number;
  flags: string[];
  wall: WallEntry[];
  codes: string[];
  stash: string[];
  endings: string[];
  vars?: Record<string, number>;
  memories: unknown;
}

/**
 * What survives a wipe (the outline's "the wall is the save file"): cycle
 * count, act, story flags, the N03 wall, learned codes, the cistern stash and
 * endings seen. Memories are kept by MemoryManager and saved alongside.
 * Inventory, keys, position and time are per-cycle and never saved, so a page
 * reload is simply another wake-up in N03.
 */
export class StoryState {
  cycle = 41;
  act = 1;
  readonly flags = new Set<string>();
  readonly wall: WallEntry[] = [];
  readonly codes = new Set<string>();
  readonly stash = new Set<string>();
  readonly endings = new Set<string>();
  /** Persistent numeric counters (visit counts, …); `cycle:` names are cleared by the wipe. */
  readonly vars = new Map<string, number>();

  serialize(memories: unknown): SaveData {
    return {
      cycle: this.cycle,
      act: this.act,
      flags: [...this.flags],
      wall: this.wall.slice(),
      codes: [...this.codes],
      stash: [...this.stash],
      endings: [...this.endings],
      vars: Object.fromEntries(this.vars),
      memories,
    };
  }

  restore(d: Partial<SaveData>): void {
    this.cycle = d.cycle ?? 41;
    this.act = d.act ?? 1;
    this.flags.clear();
    for (const f of d.flags ?? []) this.flags.add(f);
    this.wall.length = 0;
    this.wall.push(...(d.wall ?? []));
    this.codes.clear();
    for (const c of d.codes ?? []) this.codes.add(c);
    this.stash.clear();
    for (const s of d.stash ?? []) this.stash.add(s);
    this.endings.clear();
    for (const e of d.endings ?? []) this.endings.add(e);
    this.vars.clear();
    for (const [k, v] of Object.entries(d.vars ?? {})) this.vars.set(k, v);
  }

  static load(): Partial<SaveData> | null {
    try {
      if (new URLSearchParams(location.search).has("fresh")) {
        localStorage.removeItem(SAVE_KEY);
        return null;
      }
      const raw = localStorage.getItem(SAVE_KEY);
      return raw ? (JSON.parse(raw) as Partial<SaveData>) : null;
    } catch {
      return null;
    }
  }

  static write(data: SaveData): void {
    try {
      localStorage.setItem(SAVE_KEY, JSON.stringify(data));
    } catch {
      // Private mode / storage blocked: the run just won't persist across reloads.
    }
  }

  static clear(): void {
    try {
      localStorage.removeItem(SAVE_KEY);
    } catch {
      // ignore
    }
  }
}
