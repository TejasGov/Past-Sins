import type { Place } from "../../types";

export interface Line {
  speaker: string;
  text: string;
  seconds?: number;
  audio?: string;
}

export interface EndingsData {
  act3: { weather: "RAINY" | "NORMAL"; monsoonMessage?: string; terminationHour: number; terminationLines: Line[] };
  pistol: { at: Place; prompt: string; message: string };
  letGo: {
    surfaceSeconds: number;
    rise: { seconds: number; height: number; back: number; look: [number, number, number] };
    town: { center: [number, number, number] };
    doorstep: { origin: [number, number, number]; hour: number; weather: "RAINY" | "NORMAL"; walkSeconds: number; lines: Line[] };
  };
  holdOn: { silenceSeconds: number; lines: Line[] };
  mercy: { pa: Line[]; walkSpeed: number; route: Place[]; exitLines: Line[]; outsideDistance: number };
  credits: {
    title: string;
    subtitle: string;
    names: Record<string, string>;
    lines: string[];
    theEnd: string;
    again: string;
    seconds: number;
  };
}

const DEFAULTS: EndingsData = {
  act3: { weather: "RAINY", terminationHour: 2, terminationLines: [] },
  pistol: { at: { plan: "hq-1", room: "chief" }, prompt: "[E] Take the pistol", message: "" },
  letGo: {
    surfaceSeconds: 2,
    rise: { seconds: 10, height: 24, back: 14, look: [36, 6, 245] },
    town: { center: [36, 0, 240] },
    doorstep: { origin: [-200, 0, 160], hour: 7.3, weather: "NORMAL", walkSeconds: 6, lines: [] },
  },
  holdOn: { silenceSeconds: 2.5, lines: [] },
  mercy: { pa: [], walkSpeed: 1.3, route: [], exitLines: [], outsideDistance: 9 },
  credits: { title: "BLACKSITE", subtitle: "GHOST EXIT", names: {}, lines: [], theEnd: "THE END", again: "[E] WAKE AGAIN", seconds: 30 },
};

/** Fills anything missing in endings.json with the defaults above. */
export function readEndings(raw: unknown): EndingsData {
  const d = (raw ?? {}) as Partial<EndingsData>;
  return {
    act3: { ...DEFAULTS.act3, ...d.act3 },
    pistol: { ...DEFAULTS.pistol, ...d.pistol },
    letGo: {
      ...DEFAULTS.letGo,
      ...d.letGo,
      rise: { ...DEFAULTS.letGo.rise, ...d.letGo?.rise },
      town: { ...DEFAULTS.letGo.town, ...d.letGo?.town },
      doorstep: { ...DEFAULTS.letGo.doorstep, ...d.letGo?.doorstep },
    },
    holdOn: { ...DEFAULTS.holdOn, ...d.holdOn },
    mercy: { ...DEFAULTS.mercy, ...d.mercy },
    credits: { ...DEFAULTS.credits, ...d.credits },
  };
}
