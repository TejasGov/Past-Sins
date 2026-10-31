import "./routine.css";

function escape(s: string): string {
  return s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]!);
}

/** Fills `{name}` placeholders. */
export function fill(format: string, vars: Record<string, string>): string {
  return format.replace(/\{(\w+)\}/g, (_, k: string) => vars[k] ?? "");
}

export function clock(hours: number): string {
  const h = Math.floor((((hours % 24) + 24) % 24) + 1e-6);
  const m = Math.floor((hours - Math.floor(hours)) * 60 + 1e-6);
  return `${String(h).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;
}

/**
 * The routine line under the HUD clock: the current beat (or free time) and
 * the next one. `urgent` while Parth must get back to N03; `fresh` flashes
 * for a few seconds when a beat starts.
 */
export class RoutineHud {
  private readonly el: HTMLElement;
  private text = "";
  private fresh = 0;

  constructor(root: HTMLElement) {
    this.el = document.createElement("div");
    this.el.className = "routine-hud";
    root.appendChild(this.el);
  }

  set(now: string, next: string, separator: string, urgent: boolean): void {
    const html = `<span class="now">${escape(now)}</span>` + (next ? `<span class="sep">${escape(separator)}</span><span class="next">${escape(next)}</span>` : "");
    if (html !== this.text) {
      this.text = html;
      this.el.innerHTML = html;
    }
    this.el.classList.toggle("urgent", urgent);
  }

  flash(seconds = 4): void {
    this.fresh = seconds;
    this.el.classList.add("fresh");
  }

  update(dt: number): void {
    if (this.fresh > 0) {
      this.fresh -= dt;
      if (this.fresh <= 0) this.el.classList.remove("fresh");
    }
  }

  get textContent(): string {
    return this.el.textContent ?? "";
  }
}
