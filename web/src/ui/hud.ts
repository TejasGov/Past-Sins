import { animate, createTimeline, stagger, utils } from "animejs";
import "./hud.css";
import type { SuspicionState } from "../systems/suspicion";

export interface MemoryPresentation {
  id: string;
  title: string;
  transcript: string;
  clue?: string;
  tag?: string;
}

const STATE_COLORS: Record<SuspicionState, string> = {
  NORMAL: "#8ed6b0",
  WATCHING: "#e7d678",
  SUSPICIOUS: "#e8a45e",
  SEARCHING: "#e65f4f",
  ALERT: "#ff253a",
};

function el<K extends keyof HTMLElementTagNameMap>(tag: K, cls: string, parent: HTMLElement, html = ""): HTMLElementTagNameMap[K] {
  const e = document.createElement(tag);
  e.className = cls;
  if (html) e.innerHTML = html;
  parent.appendChild(e);
  return e;
}

/**
 * DOM HUD (port of scripts/ui/hud.gd). anime.js drives every text animation:
 * prompt fades, status messages, the suspicion meter, the memory transcript
 * typewriter/glitch reveal and the DETAINED overlay.
 */
export class Hud {
  readonly root: HTMLElement;
  private prompt: HTMLElement;
  private crosshair: HTMLElement;
  private message: HTMLElement;
  private suspicionFill: HTMLElement;
  private suspicionState: HTMLElement;
  private suspicionValue: HTMLElement;
  private env: HTMLElement;
  private controls: HTMLElement;
  private inventory: HTMLElement;
  private objective: HTMLElement;
  private memory: HTMLElement;
  private failure: HTMLElement;
  private alertVignette: HTMLElement;
  readonly start: HTMLElement;
  readonly devBadge: HTMLElement;
  readonly fps: HTMLElement;
  private lastPrompt = "";
  private messageAnim: ReturnType<typeof animate> | null = null;
  memoryPlaying = false;
  private skipRequested = false;
  private landControls = "WASD MOVE   SHIFT SPRINT   C CROUCH   SPACE JUMP\nE INTERACT   M MAP   ESC RELEASE MOUSE";

  constructor(root: HTMLElement) {
    this.root = root;
    this.crosshair = el("div", "hud-crosshair", root);
    this.prompt = el("div", "hud-prompt", root);
    this.message = el("div", "hud-message", root);
    const sus = el("div", "hud-suspicion", root);
    const label = el("div", "label", sus);
    this.suspicionState = el("span", "state", label, "NORMAL");
    this.suspicionValue = el("span", "value", label, "000%");
    const bar = el("div", "bar", sus);
    this.suspicionFill = el("div", "fill", bar);
    el("div", "ticks", bar);
    this.env = el("div", "hud-env", root);
    this.controls = el("div", "hud-controls", root, this.landControls);
    this.inventory = el("div", "hud-inventory", root);
    this.objective = el("div", "hud-objective", root);
    this.alertVignette = el("div", "alert-vignette", root);
    this.devBadge = el("div", "dev-badge", root, "DEV MODE");
    this.fps = el("div", "fps", root);

    this.memory = el("div", "overlay memory", root);
    this.failure = el("div", "overlay failure", root, `<div class="word">DETAINED</div><div class="sub">RETURNED TO CELL</div>`);
    this.start = el(
      "div",
      "overlay start visible",
      root,
      `<h1>BLACKSITE</h1><h2>GHOST EXIT</h2><div class="hint">CLICK TO WAKE</div><div class="loading"></div>`,
    );
    this.start.style.opacity = "1";
  }

  setLoading(text: string): void {
    const l = this.start.querySelector(".loading");
    if (l) l.textContent = text;
  }

  hideStart(): void {
    this.start.classList.remove("visible");
    animate(this.start, { opacity: [1, 0], duration: 900, ease: "outQuad" });
  }

  showStartPaused(): void {
    this.start.classList.add("visible");
    const hint = this.start.querySelector(".hint");
    if (hint) hint.textContent = "CLICK TO RESUME";
    animate(this.start, { opacity: [0, 0.85], duration: 300, ease: "outQuad" });
  }

  setPrompt(text: string): void {
    if (this.memoryPlaying) text = "";
    if (text === this.lastPrompt) return;
    this.lastPrompt = text;
    this.crosshair.classList.toggle("active", text.length > 0);
    const html = text.replace(/^\[(\w)\]\s*/, '<span class="key">$1</span>');
    this.prompt.innerHTML = html;
    if (text) animate(this.prompt, { opacity: [0, 1], translateY: [6, 0], duration: 220, ease: "outQuad" });
  }

  showMessage(text: string, duration = 1.5): void {
    this.messageAnim?.pause();
    this.message.textContent = text;
    utils.set(this.message, { opacity: 0 });
    const tl = createTimeline();
    tl.add(this.message, { opacity: [0, 1], letterSpacing: ["0.5em", "0.22em"], duration: 260, ease: "outQuad" })
      .add(this.message, { opacity: 0, duration: 380, ease: "inQuad" }, `+=${Math.max(250, duration * 1000)}`);
    this.messageAnim = null;
  }

  setSuspicion(value: number, state: SuspicionState): void {
    this.suspicionFill.style.width = `${value.toFixed(1)}%`;
    this.suspicionValue.textContent = `${String(Math.round(value)).padStart(3, "0")}%`;
    if (this.suspicionState.textContent !== state) {
      this.suspicionState.textContent = state;
      this.suspicionState.style.color = STATE_COLORS[state];
      animate(this.suspicionState, { scale: [1.35, 1], duration: 420, ease: "outElastic(1, .6)" });
    }
    const alert = state === "ALERT" ? 0.55 : state === "SEARCHING" ? 0.28 : 0;
    this.alertVignette.style.boxShadow = `inset 0 0 180px rgba(255, 30, 30, ${alert})`;
  }

  setEnvironment(text: string): void {
    this.env.textContent = text;
  }

  setSwimming(swimming: boolean): void {
    this.controls.textContent = swimming
      ? "WASD SWIM   SPACE RISE   C DIVE   M MAP\nRELEASE TO FLOAT   USE STEPS TO EXIT"
      : this.landControls;
  }

  setInventory(items: string[]): void {
    this.inventory.innerHTML = items.length ? items.map((i) => `<div class="item">${i}</div>`).join("") : "";
  }

  setObjective(title: string, text: string): void {
    this.objective.innerHTML = title ? `<div class="title">${title}</div><div>${text}</div>` : "";
    if (title) animate(this.objective, { opacity: [0, 1], translateX: [-12, 0], duration: 600, ease: "outQuad" });
  }

  setVisible(visible: boolean): void {
    for (const e of [this.prompt, this.crosshair, this.inventory, this.objective, this.controls]) e.style.visibility = visible ? "visible" : "hidden";
  }

  requestSkip(): void {
    this.skipRequested = true;
  }

  /** Memory reconstruction: glitch-in frame, typewriter transcript, scrambled clue. */
  playMemorySequence(data: MemoryPresentation): Promise<void> {
    this.memoryPlaying = true;
    this.skipRequested = false;
    this.setPrompt("");
    const m = this.memory;
    m.innerHTML = "";
    const frame = el("div", "frame", m);
    el("div", "tag", frame, data.tag ?? `MEMORY RECONSTRUCTION · ${data.id.toUpperCase()}`);
    const title = el("div", "title", frame, data.title.toUpperCase());
    const transcript = el("div", "transcript", frame);
    const clue = el("div", "clue", frame);
    el("div", "scan", frame);
    const glitch = el("div", "glitch", frame);

    const chars: HTMLElement[] = [];
    for (const line of data.transcript.split("\n")) {
      const isSpeaker = /^[A-Z][A-Z .'-]+:$/.test(line.trim());
      const lineEl = el("span", isSpeaker ? "speaker" : "", transcript);
      for (const ch of line) {
        const s = el("span", "ch", lineEl);
        s.textContent = ch;
        chars.push(s);
      }
      transcript.appendChild(document.createTextNode("\n"));
    }

    return new Promise((resolve) => {
      const typeMs = 24;
      const typeDuration = chars.length * typeMs;
      const tl = createTimeline({
        onComplete: () => {
          this.memoryPlaying = false;
          m.classList.remove("visible");
          resolve();
        },
      });
      m.classList.add("visible");
      tl.add(m, { opacity: [0, 1], duration: 450, ease: "outQuad" })
        .add(frame, { scaleY: [0.02, 1], scaleX: [1.08, 1], duration: 420, ease: "outExpo" }, 0)
        .add(title, { opacity: [0, 1], translateX: [-14, 0], duration: 500, ease: "outQuad" }, 220)
        .add(chars, { opacity: [0, 1], duration: 90, delay: stagger(typeMs), ease: "linear" }, 600)
        .add(glitch, { opacity: [0, 0.9, 0], top: ["18%", "72%"], duration: 260, ease: "linear" }, 900)
        .add(frame, { translateX: [0, -5, 4, 0], duration: 180, ease: "linear" }, 920)
        .add(glitch, { opacity: [0, 0.8, 0], top: ["80%", "34%"], duration: 200, ease: "linear" }, 600 + typeDuration * 0.6)
        .add(frame, { translateX: [0, 6, -3, 0], filter: ["hue-rotate(0deg)", "hue-rotate(40deg)", "hue-rotate(0deg)"], duration: 200, ease: "linear" }, 600 + typeDuration * 0.6)
        .add(clue, { opacity: [0, 1], duration: 300, ease: "outQuad" }, 600 + typeDuration + 300)
        .add(m, { opacity: [1, 0], duration: 650, ease: "inQuad" }, 600 + typeDuration + 3900);
      if (data.clue) this.scramble(clue, `PRACTICAL CLUE RECOVERED:  ${data.clue}`, 600 + typeDuration + 300, 1200);
      // Allow skipping once the transcript has been typed.
      const poll = window.setInterval(() => {
        if (!this.memoryPlaying) return window.clearInterval(poll);
        if (this.skipRequested && tl.currentTime > 600 + typeDuration && tl.currentTime < 600 + typeDuration + 3900) {
          tl.seek(600 + typeDuration + 3900);
        }
        this.skipRequested = false;
      }, 100);
    });
  }

  private scramble(target: HTMLElement, text: string, delayMs: number, durationMs: number): void {
    const glyphs = "▓▒░#%&@$0123456789ABCDEF";
    window.setTimeout(() => {
      const start = performance.now();
      const tick = () => {
        const p = Math.min(1, (performance.now() - start) / durationMs);
        const solid = Math.floor(text.length * p);
        let out = text.slice(0, solid);
        for (let i = solid; i < text.length; i++) out += text[i] === " " ? " " : glyphs[(Math.random() * glyphs.length) | 0];
        target.textContent = out;
        if (p < 1) requestAnimationFrame(tick);
      };
      tick();
    }, delayMs);
  }

  showDetained(): Promise<void> {
    this.setPrompt("");
    this.failure.classList.add("visible");
    return new Promise((resolve) => {
      createTimeline({ onComplete: () => resolve() })
        .add(this.failure, { opacity: [0, 1], duration: 800, ease: "inOutQuad" })
        .add(this.failure.querySelector(".word")!, { letterSpacing: ["1.2em", "0.5em"], opacity: [0, 1], duration: 900, ease: "outExpo" }, 200);
    });
  }

  hideDetained(): void {
    animate(this.failure, { opacity: 0, duration: 700, ease: "outQuad", onComplete: () => this.failure.classList.remove("visible") });
  }
}
