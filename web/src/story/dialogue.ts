import type { DialogueDef } from "./types";
import type { StoryDirector } from "./director";

/**
 * Runs a dialogue script: subtitle lines (with optional per-line actions and
 * conditions), numbered choices that branch via labels, goto and end.
 */
export async function runDialogue(def: DialogueDef, story: StoryDirector): Promise<void> {
  const labels = new Map<string, number>();
  def.nodes.forEach((n, i) => {
    if ("label" in n) labels.set(n.label, i);
  });
  let i = 0;
  let guard = 0;
  while (i < def.nodes.length && guard++ < 500) {
    const n = def.nodes[i];
    if ("label" in n) {
      i++;
    } else if ("goto" in n) {
      i = labels.get(n.goto) ?? def.nodes.length;
    } else if ("end" in n) {
      break;
    } else if ("speaker" in n) {
      if (!n.when || story.check(n.when)) {
        story.events.emit("dialogue", { id: def.id, speaker: n.speaker, text: n.text, audio: n.audio });
        await story.ui.say(n.speaker, n.text, n.seconds);
        if (n.actions) await story.run(n.actions);
      }
      i++;
    } else {
      const options = n.choice.filter((c) => !c.when || story.check(c.when));
      if (!options.length) {
        i++;
        continue;
      }
      const picked = options[await story.ui.choose(options.map((c) => c.text), n.prompt)];
      if (picked.actions) await story.run(picked.actions);
      i = picked.goto ? (labels.get(picked.goto) ?? def.nodes.length) : i + 1;
    }
  }
}
