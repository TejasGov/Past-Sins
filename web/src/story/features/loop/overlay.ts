import "./loop.css";

function div(cls: string, parent: HTMLElement, html = ""): HTMLDivElement {
  const e = document.createElement("div");
  e.className = cls;
  if (html) e.innerHTML = html;
  parent.appendChild(e);
  return e;
}

function escape(s: string): string {
  return s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]!);
}

/** A hand as SVG rects (fingers toward −y, wrist at +y), origin at the palm's centre. */
function hand(id: string, fill: string): string {
  const fingers = [
    [-31, 62],
    [-11, 74],
    [9, 70],
    [28, 54],
  ]
    .map(([x, len]) => `<rect x="${x - 8.5}" y="${-28 - len}" width="17" height="${len + 16}" rx="8.5"/>`)
    .join("");
  // The forearm dissolves into the dark water.
  return (
    `<mask id="${id}-fade" maskUnits="userSpaceOnUse" x="-120" y="-160" width="240" height="480">` +
    `<linearGradient id="${id}-grad" gradientUnits="userSpaceOnUse" x1="0" y1="30" x2="0" y2="210"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#000"/></linearGradient>` +
    `<rect x="-120" y="-160" width="240" height="480" fill="url(#${id}-grad)"/></mask>` +
    `<g id="${id}" fill="${fill}" mask="url(#${id}-fade)">` +
    `<rect x="-42" y="-34" width="84" height="88" rx="30"/>${fingers}` +
    `<rect x="-52" y="-8" width="18" height="58" rx="9" transform="rotate(-38 -43 20)"/>` +
    `<rect x="-30" y="40" width="60" height="260" rx="22"/></g>`
  );
}

/**
 * The loop's screen-space layer: eyelids, letterbox, location captions, the
 * cold open's water and hands, the lift-descent streaks, the B1 klaxon and the
 * skip hint. Inserted just before the story subtitles so subtitles and banners
 * stay on top while the HUD sits underneath.
 */
export class LoopOverlay {
  readonly root: HTMLDivElement;
  readonly water: HTMLDivElement;
  readonly adultHand: SVGGElement;
  readonly childHand: SVGGElement;
  readonly streaks: HTMLDivElement;
  readonly lidTop: HTMLDivElement;
  readonly lidBottom: HTMLDivElement;
  readonly barTop: HTMLDivElement;
  readonly barBottom: HTMLDivElement;
  readonly caption: HTMLDivElement;
  readonly flash: HTMLDivElement;
  private klaxonEl: HTMLDivElement;
  private skipEl: HTMLDivElement;

  constructor(hudRoot: HTMLElement) {
    this.root = document.createElement("div");
    this.root.className = "loop-overlay";
    hudRoot.insertBefore(this.root, hudRoot.querySelector(".story-subs"));
    this.water = div("loop-water", this.root, `<div class="caustic"></div><div class="bubbles"></div>`);
    const bubbles = this.water.querySelector(".bubbles")!;
    for (let i = 0; i < 14; i++) {
      const b = document.createElement("i");
      b.style.left = `${(i * 37) % 100}%`;
      b.style.animationDelay = `${(i * 0.61) % 4.2}s`;
      b.style.transform = `scale(${0.6 + ((i * 7) % 5) * 0.2})`;
      bubbles.appendChild(b);
    }
    this.water.insertAdjacentHTML(
      "beforeend",
      `<svg viewBox="-200 -200 400 400"><defs><filter id="loop-blur"><feGaussianBlur stdDeviation="3.2"/></filter></defs>` +
        // Outer groups are what the timeline moves; inner ones only pose the hands.
        `<g filter="url(#loop-blur)"><g class="adult"><g transform="translate(0,-10) rotate(180)">${hand("loop-adult", "#6f8884")}</g></g>` +
        `<g class="child"><g transform="translate(6,80) scale(0.68)">${hand("loop-child", "#a7bab3")}</g></g></g></svg>`,
    );
    this.adultHand = this.water.querySelector("g.adult")!;
    this.childHand = this.water.querySelector("g.child")!;
    this.streaks = div("loop-streaks", this.root, "<i></i><i></i><i></i>");
    this.lidTop = div("loop-lid top", this.root);
    this.lidBottom = div("loop-lid bottom", this.root);
    this.barTop = div("loop-bar top", this.root);
    this.barBottom = div("loop-bar bottom", this.root);
    this.caption = div("loop-caption", this.root);
    this.flash = div("loop-flash", this.root);
    this.klaxonEl = div("loop-klaxon", this.root);
    this.skipEl = div("loop-skip", this.root);
  }

  setCaption(text: string): void {
    this.caption.textContent = text;
  }

  setSkipHint(text: string | null): void {
    if (text !== null) this.skipEl.innerHTML = `<span class="key">E</span>${escape(text)}`;
    this.skipEl.classList.toggle("visible", text !== null && text !== "");
  }

  klaxon(on: boolean): void {
    this.klaxonEl.classList.toggle("on", on);
    if (!on) this.klaxonEl.style.opacity = "0";
    else this.klaxonEl.style.removeProperty("opacity");
  }

  /** Back to fully transparent (nothing covering the view). */
  clear(): void {
    for (const e of [this.water, this.streaks, this.caption, this.flash]) e.style.opacity = "0";
    this.lidTop.style.transform = "translateY(-110%)";
    this.lidBottom.style.transform = "translateY(110%)";
    this.barTop.style.transform = "scaleY(0)";
    this.barBottom.style.transform = "scaleY(0)";
    this.setSkipHint(null);
  }
}
