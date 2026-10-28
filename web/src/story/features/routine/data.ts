import type { Action, Condition, Place } from "../../types";

/** One subtitle line (data/story/features/routine.json). */
export interface LineDef {
  speaker?: string;
  text: string;
  seconds?: number;
  audio?: string;
}

/**
 * A routine beat on the 12-real-minute clock. `at`/`until` are clock hours;
 * `until` < `at` wraps past midnight (lights out 21:00 → 06:00). `day` limits
 * the beat to one day of the cycle (visitation: day 3).
 */
export interface BeatDef {
  id: string;
  at: number;
  until: number;
  day?: number;
  label: string;
  /** Second half of the HUD line while the beat is on ("DOSE · DIETARY WINDOW"). */
  hint?: string;
  /** PA / officer lines when the beat starts. */
  lines?: LineDef[];
  /** Extra story actions when the beat starts (data hook for other workstreams). */
  actions?: Action[];
  /** Merged into the `routine:<id>` signal data. */
  signalData?: Record<string, unknown>;
  /** The dietary window offers the pill during this beat. */
  dose?: boolean;
  /** Beat only fires/shows while this holds. */
  when?: Condition;
}

/** Inside-N03 test: a box in the anchor's frame (x right, z forward of the anchor's yaw). */
export interface CellDef {
  anchor: string;
  min: [number, number, number];
  max: [number, number, number];
  /** Door persistentId of the cell gate. */
  gate: string;
}

export interface MissedDef {
  message: string;
  /** HUD hint for the rest of the beat. */
  hint?: string;
  lines?: LineDef[];
  /** Suspicion added, then held at least this high for `holdSeconds`. */
  suspicion: number;
  holdSeconds: number;
  /** Guard ids (session.json) sent to investigate the cell. */
  alertGuards: string[];
  flag: string;
}

export interface CountDef {
  /** Clock hour Parth must be in N03 by (the officer's walk past the bars). */
  checkAt: number;
  /** Excused (e.g. waking in the infirmary after a Jagran cycle: `cycle:loop_infirmary`). */
  excuseWhen?: Condition;
  presentLines?: LineDef[];
  missed: MissedDef;
  /** Unlock and open N03's gate once the count is done. */
  openGate: boolean;
}

export interface LockinDef {
  /** Parth has until this hour to be back in N03 before he's missing. */
  graceUntil: number;
  /** Seconds after Parth steps in before the gate rolls shut. */
  closeDelay: number;
  /** Lock the gate behind him (false: closed only). */
  lock: boolean;
  /** Leave it unlocked tonight while this holds (e.g. Act III, Bhosle's slowness). */
  leaveUnlockedWhen?: Condition;
  /** Key that opens the locked gate from inside (a trusty's cell-block key). "" = only the master key. */
  gateKey: string;
  lockedMessage: string;
  /** HUD hint once he's locked in. */
  lockedHint?: string;
  lockedLines?: LineDef[];
  missed: MissedDef;
}

export interface LightsOutDef {
  /** Fixture intensity multiplier (LightPool.intensityScale) at full lights out. */
  fixtures: number;
  /** Extra screen-grade dimming (tint) for emissive panels the fixture scale can't reach. */
  grade: number;
  /** Seconds to dim / restore. */
  rampSeconds: number;
  /** Interior chunks that go dark (base names: "cellhouseA" also covers "cellhouseA_cells"). */
  chunks: string[];
  message: string;
}

export interface SleepDef {
  at: Place;
  /** Hit-box size in the place's frame. */
  size: [number, number, number];
  prompt: string;
  when?: Condition;
  /** Clock hour to wake at (next morning). */
  wakeHour: number;
  fadeSeconds: number;
  lines?: LineDef[];
  wakeLines?: LineDef[];
}

export interface DoseChoiceDef {
  text: string;
  when?: Condition;
  lines?: LineDef[];
  actions?: Action[];
}

export interface DoseDef {
  /** The serving hatch on food-ground (dining ↔ serving), split into `slots` windows. */
  window: { plan: string; a: string; b: string; slots: number; slot: number; counterHeight: number; sign: string };
  /** Place override for the hand/cup (otherwise derived from the hatch). */
  at?: Place;
  prompt: string;
  /** HUD hint once this meal's dose has been handed out. */
  servedHint?: string;
  /** Shard played the first time the cup is offered at breakfast. */
  firstShard: string;
  offerLines?: LineDef[];
  choicePrompt: string;
  swallow: DoseChoiceDef;
  pocket: DoseChoiceDef;
  /** Inventory item for the pocketed pill. */
  item: { id: string; label: string };
  /** Swallowing a later dose clears today's withdrawal. */
  swallowEndsWithdrawal: boolean;
}

export interface WithdrawalDef {
  /** Seconds for the effects to build after pocketing (and to fade after a swallowed dose). */
  onsetSeconds: number;
  recoverSeconds: number;
  suspicionMultiplier: number;
  /** Drift amplitudes (fractions of the authored grade) and the vignette pulse added at full withdrawal. */
  grade: { saturation: number; desaturate: number; contrast: number; tint: number; vignette: number; speed: number };
  sway: { roll: number; pitch: number; yaw: number; bob: number; speed: number };
  onsetLines?: LineDef[];
}

export interface HudDef {
  /** Format for the current beat: {label} {hint} {time}. */
  now: string;
  nowNoHint: string;
  /** Format for the next beat. */
  next: string;
  separator: string;
  idle: string;
  /** Shown instead of the hint while Parth must get back to N03 (count / lock-in). */
  toCell: string;
}

export interface RoutineData {
  beats: BeatDef[];
  hud: HudDef;
  cell: CellDef;
  count: CountDef;
  lockin: LockinDef;
  lightsOut: LightsOutDef;
  sleep: SleepDef;
  dose: DoseDef;
  withdrawal: WithdrawalDef;
}
