import "./endings.css";
import type { Input } from "../../../core/input";
import type { EndingsData } from "./data";

function escape(s: string): string {
  return s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]!);
}

/**
 * The credits roll (advanced by game dt, so automation stays exact), then the
 * end card: the ending's name and "[E] WAKE AGAIN". `dim` < 1 lets the scene
 * show through (Hold On rolls over the cell).
 */
export class Credits {
  private root: HTMLElement;
  private roll: HTMLElement;
  private card: HTMLElement;
  private stage: "off" | "roll" | "card" = "off";
  private t = 0;
  private resolve: (() => void) | null = null;

  constructor(parent: HTMLElement) {
    this.root = document.createElement("div");
    this.root.className = "ending-credits";
    this.roll = document.createElement("div");
    this.roll.className = "roll";
    this.card = document.createElement("div");
    this.card.className = "card";
    this.root.append(this.roll, this.card);
    parent.appendChild(this.root);
  }

  get running(): boolean {
    return this.stage !== "off";
  }

  /** Resolves when the player chooses to wake again. */
  play(ending: string, data: EndingsData["credits"], dim: number): Promise<void> {
    this.root.style.setProperty("--dim", String(dim));
    const name = data.names[ending] ?? ending.toUpperCase();
    this.roll.innerHTML =
      `<div class="title">${escape(data.title)}</div><div class="subtitle">${escape(data.subtitle)}</div>` +
      `<div class="ending">${escape(name)}</div>` +
      data.lines.map((l) => (l ? `<div class="line">${escape(l)}</div>` : `<div class="gap"></div>`)).join("");
    this.card.innerHTML = `<div class="end">${escape(data.theEnd)}</div><div class="name">${escape(name)}</div><div class="again">${escape(data.again)}</div>`;
    this.root.classList.add("visible");
    this.root.classList.remove("on-card");
    this.stage = "roll";
    this.t = 0;
    this.seconds = data.seconds;
    return new Promise((resolve) => (this.resolve = resolve));
  }

  private seconds = 30;

  update(dt: number, input: Input): void {
    if (this.stage === "off") return;
    this.t += dt;
    if (this.stage === "roll") {
      const k = Math.min(1, this.t / this.seconds);
      // From below the screen to fully past the top.
      this.roll.style.transform = `translateY(${(1 - k) * 100}vh) translateY(${-k * 100}%)`;
      if (k >= 1 || (this.t > 2.5 && input.justPressed("KeyE"))) {
        this.stage = "card";
        this.t = 0;
        this.root.classList.add("on-card");
      }
    } else if (this.t > 1.2 && input.justPressed("KeyE")) {
      this.stage = "off";
      this.resolve?.();
      this.resolve = null;
    }
  }
}
