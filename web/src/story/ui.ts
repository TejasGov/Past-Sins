import "./story.css";
import type { Input } from "../core/input";
import type { DocumentDef } from "./types";

function el<K extends keyof HTMLElementTagNameMap>(tag: K, cls: string, parent: HTMLElement, html = ""): HTMLElementTagNameMap[K] {
  const e = document.createElement(tag);
  e.className = cls;
  if (html) e.innerHTML = html;
  parent.appendChild(e);
  return e;
}

function escape(s: string): string {
  return s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]!);
}

interface Line {
  speaker: string;
  text: string;
  seconds: number;
  resolve: () => void;
}

/**
 * Story overlays on top of the HUD: subtitles (queued, timed by game dt so
 * `__game.step()` stays deterministic), readable documents, dialogue choices
 * and title banners. Documents and choices are "blocking": the game stops
 * routing E to interactables while one is open.
 */
export class StoryUI {
  private subs: HTMLElement;
  private doc: HTMLElement;
  private choice: HTMLElement;
  private bannerEl: HTMLElement;
  private queue: Line[] = [];
  private line: Line | null = null;
  private lineTime = 0;
  private docResolve: (() => void) | null = null;
  private docAge = 0;
  private choiceResolve: ((i: number) => void) | null = null;
  private choiceCount = 0;
  private bannerTime = 0;
  private bannerResolve: (() => void) | null = null;

  constructor(root: HTMLElement) {
    this.subs = el("div", "story-subs", root);
    this.bannerEl = el("div", "story-banner", root);
    this.doc = el("div", "story-doc", root);
    this.choice = el("div", "story-choice", root);
  }

  /** True while a document or choice owns the keyboard. */
  get blocking(): boolean {
    return !!this.docResolve || !!this.choiceResolve;
  }

  get speaking(): boolean {
    return !!this.line || this.queue.length > 0;
  }

  /** Queue a subtitle line; resolves when it has been shown. Default length scales with the text. */
  say(speaker: string, text: string, seconds?: number): Promise<void> {
    return new Promise((resolve) => {
      this.queue.push({ speaker, text, seconds: seconds ?? Math.min(7, 1.6 + text.length * 0.055), resolve });
    });
  }

  clearSubtitles(): void {
    for (const l of this.queue) l.resolve();
    this.queue.length = 0;
    this.line?.resolve();
    this.line = null;
    this.subs.classList.remove("visible");
  }

  showDocument(def: DocumentDef): Promise<void> {
    this.docResolve?.();
    this.doc.className = `story-doc visible ${def.style ?? "paper"}`;
    this.doc.innerHTML =
      `<div class="sheet"><div class="title">${escape(def.title)}</div><div class="body">${escape(def.body)}</div>` +
      (def.footer ? `<div class="footer">${escape(def.footer)}</div>` : "") +
      `</div><div class="hint"><span class="key">E</span> PUT IT DOWN</div>`;
    this.docAge = 0;
    return new Promise((resolve) => {
      this.docResolve = () => {
        this.docResolve = null;
        this.doc.classList.remove("visible");
        resolve();
      };
    });
  }

  /** Numbered options (keys 1–9 or click). Resolves with the chosen index. */
  choose(options: string[], prompt = ""): Promise<number> {
    this.choiceResolve?.(0);
    this.choiceCount = options.length;
    this.choice.innerHTML =
      (prompt ? `<div class="prompt">${escape(prompt)}</div>` : "") +
      options.map((o, i) => `<button class="opt" data-i="${i}"><span class="key">${i + 1}</span>${escape(o)}</button>`).join("");
    this.choice.classList.add("visible");
    return new Promise((resolve) => {
      this.choiceResolve = (i: number) => {
        this.choiceResolve = null;
        this.choice.classList.remove("visible");
        resolve(i);
      };
      this.choice.querySelectorAll<HTMLButtonElement>(".opt").forEach((b) => {
        b.onclick = () => this.choiceResolve?.(Number(b.dataset.i));
      });
    });
  }

  /** Closes an open choice (resolves -1) and document, e.g. when a capture starts. */
  cancelBlocking(): void {
    this.choiceResolve?.(-1);
    this.docResolve?.();
  }

  /** Big centred title ("CYCLE 42", "ACT II · THE PATTERN"). */
  banner(title: string, sub = "", seconds = 3.2): Promise<void> {
    this.bannerResolve?.();
    this.bannerEl.innerHTML = `<div class="title">${escape(title)}</div>` + (sub ? `<div class="sub">${escape(sub)}</div>` : "");
    this.bannerEl.classList.add("visible");
    this.bannerTime = seconds;
    return new Promise((resolve) => {
      this.bannerResolve = () => {
        this.bannerResolve = null;
        this.bannerEl.classList.remove("visible");
        resolve();
      };
    });
  }

  update(dt: number, input: Input): void {
    // Subtitles
    if (this.line) {
      this.lineTime += dt;
      if (this.lineTime >= this.line.seconds) {
        const done = this.line;
        this.line = null;
        this.subs.classList.remove("visible");
        done.resolve();
      }
    }
    if (!this.line && this.queue.length) {
      this.line = this.queue.shift()!;
      this.lineTime = 0;
      this.subs.innerHTML = (this.line.speaker ? `<span class="speaker">${escape(this.line.speaker)}</span>` : "") + `<span class="text">${escape(this.line.text)}</span>`;
      this.subs.classList.add("visible");
    }
    // Documents: E / Enter / Space closes (after a beat so the opening press doesn't).
    if (this.docResolve) {
      this.docAge += dt;
      if (this.docAge > 0.25 && (input.justPressed("KeyE") || input.justPressed("Enter") || input.justPressed("Space"))) this.docResolve();
    }
    if (this.choiceResolve) {
      for (let i = 0; i < Math.min(9, this.choiceCount); i++) {
        if (input.justPressed(`Digit${i + 1}`) || input.justPressed(`Numpad${i + 1}`)) {
          this.choiceResolve(i);
          break;
        }
      }
    }
    if (this.bannerResolve) {
      this.bannerTime -= dt;
      if (this.bannerTime <= 0) this.bannerResolve();
    }
  }
}
