import { Color, Euler, MathUtils, Vector3 } from "three";
import { Emitter } from "../core/events";

export type Phase = "MORNING" | "DAY" | "EVENING" | "NIGHT";
export type Weather = "NORMAL" | "RAINY";

export type EnvironmentEvents = {
  display_changed: string;
  phase_changed: Phase;
  weather_changed: Weather;
  new_day_started: { day: number; weather: Weather };
  lights_changed: boolean;
};

interface Anchor {
  hour: number;
  daylight: number;
  top: Color;
  horizon: Color;
}

const ANCHORS: Anchor[] = [
  { hour: 0, daylight: 0.015, top: new Color(0x050814), horizon: new Color(0x111827) },
  { hour: 5, daylight: 0.06, top: new Color(0x151d31), horizon: new Color(0x55453f) },
  { hour: 8, daylight: 0.72, top: new Color(0x6f91aa), horizon: new Color(0xd2a17c) },
  { hour: 12, daylight: 1.0, top: new Color(0x5489b2), horizon: new Color(0xa9bbc1) },
  { hour: 17, daylight: 0.76, top: new Color(0x58728d), horizon: new Color(0xbd9274) },
  { hour: 20, daylight: 0.07, top: new Color(0x171b2d), horizon: new Color(0x57423d) },
  { hour: 24, daylight: 0.015, top: new Color(0x050814), horizon: new Color(0x111827) },
];

export interface SkySample {
  daylight: number;
  top: Color;
  horizon: Color;
}

/**
 * Port of campus_environment_cycle.gd: 24 h clock (12 real minutes per day),
 * four phases, automatic lights on at 18:30 / off at 07:00 and a daily rain
 * roll (25 %, or 10 % after a rainy day). Rendering is applied by WorldLighting.
 */
export class EnvironmentCycle {
  readonly events = new Emitter<EnvironmentEvents>();
  cycleEnabled = true;
  dayLengthSeconds = 720;
  lightsOnHour = 18.5;
  lightsOffHour = 7.0;
  normalDayRainChance = 0.25;
  afterRainChance = 0.1;
  timeHours = 7;
  dayNumber = 1;
  weather: Weather = "NORMAL";
  previousDayWasRainy = false;
  private phase: Phase = "MORNING";
  private lightsActive = false;
  private displayTimer = 0;
  private lastDisplay = "";

  constructor(startHour: number, private random: () => number = Math.random) {
    this.timeHours = startHour;
    this.phase = this.phaseFor(startHour);
    this.lightsActive = this.isDark();
    this.rollWeather(this.random());
  }

  update(dt: number): void {
    if (this.cycleEnabled) this.advanceHours((dt * 24) / Math.max(this.dayLengthSeconds, 1));
    const next = this.phaseFor(this.timeHours);
    if (next !== this.phase) {
      this.phase = next;
      this.events.emit("phase_changed", next);
    }
    const dark = this.isDark();
    if (dark !== this.lightsActive) {
      this.lightsActive = dark;
      this.events.emit("lights_changed", dark);
    }
    this.displayTimer -= dt;
    if (this.displayTimer <= 0) {
      this.displayTimer = 0.25;
      const text = this.displayText();
      if (text !== this.lastDisplay) {
        this.lastDisplay = text;
        this.events.emit("display_changed", text);
      }
    }
  }

  setTimeHours(value: number): void {
    this.timeHours = ((value % 24) + 24) % 24;
  }

  setWeather(weather: Weather): void {
    if (weather === this.weather) return;
    this.weather = weather;
    this.events.emit("weather_changed", weather);
  }

  get currentPhase(): Phase {
    return this.phaseFor(this.timeHours);
  }

  isDark(): boolean {
    return this.timeHours >= this.lightsOnHour || this.timeHours < this.lightsOffHour;
  }

  /** Smoothed 0..1 automatic-light level (short ramps instead of a hard switch). */
  nightLevel(): number {
    const t = this.timeHours;
    if (t >= this.lightsOnHour) return MathUtils.smoothstep(t, this.lightsOnHour, this.lightsOnHour + 0.15);
    if (t < this.lightsOffHour) return 1 - MathUtils.smoothstep(t, this.lightsOffHour - 0.15, this.lightsOffHour);
    return 0;
  }

  displayText(): string {
    const hour = Math.floor(this.timeHours);
    const minute = Math.floor((this.timeHours - hour) * 60);
    const pad = (n: number) => String(n).padStart(2, "0");
    return `DAY ${pad(this.dayNumber)}  ·  ${pad(hour)}:${pad(minute)}  ·  ${this.currentPhase}  ·  ${this.weather}`;
  }

  dailyRainChance(): number {
    return this.previousDayWasRainy ? this.afterRainChance : this.normalDayRainChance;
  }

  debugBeginNewDay(roll: number): void {
    this.beginNewDay(MathUtils.clamp(roll, 0, 1));
  }

  advanceHours(hours: number): void {
    this.timeHours += hours;
    while (this.timeHours >= 24) {
      this.timeHours -= 24;
      this.beginNewDay(this.random());
    }
  }

  private beginNewDay(roll: number): void {
    this.previousDayWasRainy = this.weather === "RAINY";
    this.dayNumber += 1;
    this.rollWeather(roll);
    this.events.emit("new_day_started", { day: this.dayNumber, weather: this.weather });
  }

  private rollWeather(roll: number): void {
    this.setWeather(roll < this.dailyRainChance() ? "RAINY" : "NORMAL");
  }

  private phaseFor(hour: number): Phase {
    if (hour >= 5 && hour < 9) return "MORNING";
    if (hour >= 9 && hour < 17) return "DAY";
    if (hour >= 17 && hour < 20) return "EVENING";
    return "NIGHT";
  }

  skySample(hour = this.timeHours): SkySample {
    for (let i = 0; i < ANCHORS.length - 1; i++) {
      const a = ANCHORS[i];
      const b = ANCHORS[i + 1];
      if (hour <= b.hour) {
        const w = MathUtils.smoothstep(hour, a.hour, b.hour);
        return {
          daylight: MathUtils.lerp(a.daylight, b.daylight, w),
          top: a.top.clone().lerp(b.top, w),
          horizon: a.horizon.clone().lerp(b.horizon, w),
        };
      }
    }
    const last = ANCHORS[ANCHORS.length - 1];
    return { daylight: last.daylight, top: last.top.clone(), horizon: last.horizon.clone() };
  }

  sunColor(): Color {
    const p = this.currentPhase;
    if (p === "MORNING") return new Color(0xffd6aa);
    if (p === "EVENING") return new Color(0xffc18f);
    return new Color(0xeef3f4);
  }

  /** Direction the sunlight travels (Godot sun rotation: pitch -8→-172°, yaw -35 + 4·h). */
  sunTravelDirection(): Vector3 {
    const progress = MathUtils.clamp((this.timeHours - 6) / 12, 0, 1);
    const pitch = MathUtils.degToRad(MathUtils.lerp(-8, -172, progress));
    const yaw = MathUtils.degToRad(-35 + this.timeHours * 4);
    return new Vector3(0, 0, -1).applyEuler(new Euler(pitch, yaw, 0, "YXZ")).normalize();
  }
}
