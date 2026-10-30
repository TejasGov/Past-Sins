import type { StoryFeature } from "../../types";
import { LoopRuntime } from "./loop";
import type { LoopData } from "./data";

let runtime: LoopRuntime | null = null;

/**
 * W1 · Loop, capture & the wall.
 * Capture cinematic (HQ restricted lift → NIDRA B2 → Interrogation A chair → "Again."), the N03 wall and tally scratches, cistern stash, cycle presentation, Act III night-restart rule.
 * Owned by one workstream — see docs/story/BUILD_PLAN.md. Data: index.json `features.loop`.
 * Automation/dev: `__game.story.features.find((f) => f.id === "loop").runtime`.
 */
export const loopFeature: StoryFeature & { readonly runtime: LoopRuntime | null } = {
  id: "loop",
  init({ game, data }) {
    runtime = new LoopRuntime(game, (data ?? {}) as LoopData);
  },
  update(dt) {
    runtime?.update(dt);
  },
  onWipe(cycle) {
    runtime?.onWipe(cycle);
  },
  get runtime() {
    return runtime;
  },
};
