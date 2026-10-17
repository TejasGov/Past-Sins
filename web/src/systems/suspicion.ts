import { Emitter } from "../core/events";

export type SuspicionState = "NORMAL" | "WATCHING" | "SUSPICIOUS" | "SEARCHING" | "ALERT";

export type SuspicionEvents = {
  suspicion_changed: number;
  suspicion_state_changed: SuspicionState;
  alert_triggered: void;
};

/** Port of scripts/systems/suspicion_system.gd (autoload singleton). */
export class SuspicionSystem {
  readonly events = new Emitter<SuspicionEvents>();
  decayPerSecond = 4.5;
  decayDelay = 0.65;
  private _value = 0;
  state: SuspicionState = "NORMAL";
  private secondsSinceGain = 99;

  get value(): number {
    return this._value;
  }

  set value(v: number) {
    this.setValue(v);
  }

  update(dt: number): void {
    this.secondsSinceGain += dt;
    if (this.secondsSinceGain >= this.decayDelay && this._value > 0 && this._value < 100) {
      this.setValue(this._value - this.decayPerSecond * dt);
    }
  }

  addSuspicion(amount: number): void {
    if (!Number.isFinite(amount) || amount <= 0 || this._value >= 100) return;
    this.secondsSinceGain = 0;
    this.setValue(this._value + amount);
  }

  reduceSuspicion(amount: number): void {
    if (Number.isFinite(amount) && amount > 0) this.setValue(this._value - amount);
  }

  reset(): void {
    this.secondsSinceGain = 99;
    this.setValue(0);
  }

  static stateFor(amount: number): SuspicionState {
    if (amount >= 100) return "ALERT";
    if (amount >= 75) return "SEARCHING";
    if (amount >= 50) return "SUSPICIOUS";
    if (amount >= 25) return "WATCHING";
    return "NORMAL";
  }

  private setValue(next: number): void {
    if (!Number.isFinite(next)) return;
    const previousState = this.state;
    const previous = this._value;
    this._value = Math.min(100, Math.max(0, next));
    this.state = SuspicionSystem.stateFor(this._value);
    if (Math.abs(previous - this._value) > 1e-6) this.events.emit("suspicion_changed", this._value);
    if (this.state !== previousState) {
      this.events.emit("suspicion_state_changed", this.state);
      if (this.state === "ALERT") this.events.emit("alert_triggered", undefined);
    }
  }
}
