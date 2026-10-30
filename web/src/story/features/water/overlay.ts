import "./water.css";
import type { Breath } from "./breath";

function el(tag: string, cls: string, html = ""): HTMLElement {
  const e = document.createElement(tag);
  e.className = cls;
  if (html) e.innerHTML = html;
  return e;
}

function escape(s: string): string {
  return s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]!);
}

/**
 * Water HUD: the 2·7·1·8 breath meter, the black-water vignette, choking,
 * full-screen fades and the hand's let-go / hold-on prompt. The vignettes sit
 * under the HUD, the meter under the memory overlay, fades and the prompt just
 * under story subtitles.
 */
export class WaterOverlay {
  private dark = el("div", "water-dark");
  private choke = el("div", "water-choke");
  private meter = el("div", "water-meter");
  private black = el("div", "water-black");
  private hand = el("div", "water-hand");
  private segs: { root: HTMLElement; fill: HTMLElement }[] = [];
  private secondsEl: HTMLElement;
  private handFills: HTMLElement[] = [];
  private shown = false;
  private choking = false;
  /** 0..1 full-screen black (driven by the runtime's tweens). */
  blackAmount = 0;
  /** 0..1 black-water vignette target. */
  darkTarget = 0;
  private darkValue = 0;

  constructor(root: HTMLElement, breath: Breath, labels: string[], caption: string) {
    root.insertBefore(this.choke, root.firstChild);
    root.insertBefore(this.dark, root.firstChild);
    root.insertBefore(this.meter, root.querySelector(".overlay.memory"));
    const subs = root.querySelector(".story-subs");
    root.insertBefore(this.black, subs);
    root.insertBefore(this.hand, subs);
    const cap = el("div", "caption");
    cap.appendChild(el("span", "left", escape(caption)));
    this.secondsEl = el("span", "right");
    cap.appendChild(this.secondsEl);
    this.meter.appendChild(cap);
    const row = el("div", "segs");
    breath.segments.forEach((s, i) => {
      const seg = el("div", "seg");
      seg.style.flex = String(s);
      seg.appendChild(el("span", "lbl", escape(labels[i] ?? String(s))));
      const bar = el("div", "bar");
      const fill = el("div", "fill");
      bar.appendChild(fill);
      seg.appendChild(bar);
      row.appendChild(seg);
      this.segs.push({ root: seg, fill });
    });
    this.meter.appendChild(row);
  }

  /** Per-frame meter refresh. */
  update(dt: number, breath: Breath, visible: boolean, chokeFraction: number): void {
    if (visible !== this.shown) {
      this.shown = visible;
      this.meter.classList.toggle("visible", visible);
    }
    if (visible) {
      const seg = breath.segment;
      for (let i = 0; i < this.segs.length; i++) {
        const [fill, available] = breath.segmentFill(i);
        const s = this.segs[i];
        s.fill.style.width = `${(fill * 100).toFixed(1)}%`;
        s.root.classList.toggle("locked", !available);
        s.root.classList.toggle("current", available && i === seg && breath.left < breath.length - 0.01);
      }
      const t = breath.left.toFixed(1);
      if (this.secondsEl.textContent !== t) this.secondsEl.textContent = t;
    }
    const choking = chokeFraction > 0;
    if (choking !== this.choking) {
      this.choking = choking;
      this.meter.classList.toggle("choking", choking);
      this.choke.classList.toggle("pulse", choking);
    }
    this.choke.style.opacity = String(Math.min(1, chokeFraction * 1.1).toFixed(3));
    this.darkValue += (this.darkTarget - this.darkValue) * Math.min(1, dt * 2.5);
    this.dark.style.opacity = this.darkValue.toFixed(3);
    this.black.style.opacity = this.blackAmount.toFixed(3);
  }

  showHand(release: string, hold: string): void {
    this.hand.innerHTML = "";
    this.handFills = [];
    for (const [key, label] of [["W", release], ["E", hold]] as const) {
      const opt = el("div", "opt");
      opt.appendChild(el("div", "row", `<span class="key">${key}</span>${escape(label)}`));
      const bar = el("div", "hold");
      const fill = el("div", "");
      bar.appendChild(fill);
      opt.appendChild(bar);
      this.hand.appendChild(opt);
      this.handFills.push(fill);
    }
    this.hand.classList.add("visible");
  }

  setHandProgress(release: number, hold: number): void {
    if (this.handFills.length < 2) return;
    this.handFills[0].style.width = `${Math.min(100, release * 100).toFixed(1)}%`;
    this.handFills[1].style.width = `${Math.min(100, hold * 100).toFixed(1)}%`;
  }

  hideHand(): void {
    this.hand.classList.remove("visible");
  }

  /** Clears everything (wipe, capture). */
  reset(): void {
    this.blackAmount = 0;
    this.darkTarget = 0;
    this.darkValue = 0;
    this.hideHand();
    this.dark.style.opacity = "0";
    this.black.style.opacity = "0";
  }
}
