import type { StoryDirector } from "../../director";
import type { DialogueDef, DialogueNode } from "../../types";
import type { TokenDef } from "./types";

const ONES = [
  "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
  "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen",
];
const TENS = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"];
const ORDINAL: Record<string, string> = { one: "first", two: "second", three: "third", five: "fifth", eight: "eighth", nine: "ninth", twelve: "twelfth" };

export function numberWords(n: number): string {
  n = Math.max(0, Math.floor(n));
  if (n < 20) return ONES[n];
  if (n < 100) return TENS[Math.floor(n / 10)] + (n % 10 ? `-${ONES[n % 10]}` : "");
  if (n < 1000) return `${ONES[Math.floor(n / 100)]} hundred` + (n % 100 ? ` and ${numberWords(n % 100)}` : "");
  return String(n);
}

/** 41 → "forty-first". */
export function ordinalWords(n: number): string {
  const w = numberWords(n);
  const last = /([a-z]+)$/.exec(w)![1];
  const rep = ORDINAL[last] ?? (last.endsWith("y") ? `${last.slice(0, -1)}ieth` : `${last}th`);
  return w.slice(0, w.length - last.length) + rep;
}

export interface ScriptHooks {
  /** A line starts/stops for this speaker (talk animation). */
  speaking(speaker: string, on: boolean): void;
  /** Stop: a capture started, or the talk was cancelled. */
  aborted(): boolean;
}

/**
 * The foundation dialogue runner (src/story/dialogue.ts) with two additions
 * NPC talks need: `{token}` substitution in lines and choices (Kabir's visit
 * count, the cycle), and an abort check so a capture cuts a conversation off.
 */
export class NpcDialogue {
  constructor(
    private story: StoryDirector,
    private tokens: Record<string, TokenDef>,
  ) {}

  fill(text: string): string {
    return text.replace(/\{([a-z_]+)\}/g, (all, key: string) => {
      const t = this.tokens[key];
      if (!t) return all;
      const n = (t.cycle ? this.story.state.cycle : this.story.getVar(t.var ?? "")) + (t.add ?? 0);
      if (t.format === "words") return numberWords(n);
      if (t.format === "Words") return numberWords(n).replace(/^./, (c) => c.toUpperCase());
      if (t.format === "ordinal") return ordinalWords(n);
      return String(n);
    });
  }

  async run(def: DialogueDef, hooks: ScriptHooks): Promise<void> {
    const story = this.story;
    const labels = new Map<string, number>();
    def.nodes.forEach((n, i) => {
      if ("label" in n) labels.set(n.label, i);
    });
    let i = 0;
    let guard = 0;
    while (i < def.nodes.length && guard++ < 500 && !hooks.aborted()) {
      const n: DialogueNode = def.nodes[i];
      if ("label" in n) i++;
      else if ("goto" in n) i = labels.get(n.goto) ?? def.nodes.length;
      else if ("end" in n) break;
      else if ("speaker" in n) {
        if (!n.when || story.check(n.when)) {
          const text = this.fill(n.text);
          story.events.emit("dialogue", { id: def.id, speaker: n.speaker, text, audio: n.audio });
          hooks.speaking(n.speaker, true);
          await story.ui.say(n.speaker, text, n.seconds);
          hooks.speaking(n.speaker, false);
          if (hooks.aborted()) break;
          if (n.actions) await story.run(n.actions);
        }
        i++;
      } else {
        const options = n.choice.filter((c) => !c.when || story.check(c.when));
        if (!options.length) {
          i++;
          continue;
        }
        const picked = options[await story.ui.choose(options.map((c) => this.fill(c.text)), n.prompt ? this.fill(n.prompt) : undefined)];
        if (hooks.aborted()) break;
        if (picked.actions) await story.run(picked.actions);
        i = picked.goto ? (labels.get(picked.goto) ?? def.nodes.length) : i + 1;
      }
    }
  }
}
