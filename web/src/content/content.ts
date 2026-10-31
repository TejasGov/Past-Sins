/** Data-driven session content (public/data/content/session.json). */
export interface KeyEntry {
  id: string;
  label: string;
  short: string;
}

export interface Objective {
  id: string;
  title: string;
  text: string;
  doneWhen: { memory?: string; clue?: string; item?: string; never?: boolean };
}

export interface GuardDef {
  id: string;
  name: string;
  patrol: [number, number, number][];
  patrolSpeed?: number;
  pursuitSpeed?: number;
  viewDistance?: number;
  fov?: number;
  waitAtPoint?: number;
  suspicionPerSecond?: number;
}

export interface ZoneDef {
  id: string;
  center?: [number, number, number];
  size?: [number, number, number];
  plan?: string;
  room?: string;
  multiplier: number;
  type: string;
}

export interface SessionContent {
  startHour: number;
  dayLengthSeconds: number;
  player: { spawnAnchor: string };
  memories: { id: string; source: string; anchor: string }[];
  keyRacks: { anchor: string; title: string; keys: KeyEntry[] }[];
  cellKeyRegister?: { plan: string; room: string };
  lockers: {
    id: string;
    plan: string;
    room: string;
    offset: [number, number];
    fromSouthWall: number;
    code: string;
    reward: { id: string; label: string; category: "ACCESS_CARD" | "KEY" | "MISSION_ITEM" };
  }[];
  objectives: Objective[];
  guards: GuardDef[];
  restrictedZones: ZoneDef[];
}

export interface MemoryData {
  id: string;
  title: string;
  transcript: string;
  practical_clue?: string;
  tag?: string;
}

export async function loadJSON<T>(url: string): Promise<T> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to load ${url}: ${res.status}`);
  return (await res.json()) as T;
}

export async function loadSession(): Promise<{ session: SessionContent; memories: Map<string, MemoryData> }> {
  const session = await loadJSON<SessionContent>("data/content/session.json");
  const memories = new Map<string, MemoryData>();
  await Promise.all(
    session.memories.map(async (m) => {
      const data = await loadJSON<MemoryData>(m.source);
      memories.set(m.id, data);
    }),
  );
  return { session, memories };
}
