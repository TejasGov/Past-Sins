import type { StoryFeature } from "../../types";
import { readEndings } from "./data";
import { EndingsRuntime } from "./runtime";
import { buildEndingSets } from "./set";

/**
 * Integration · Act III flow & endings.
 * Forced monsoon and the 02:00 termination; Let Go / Hold On / Mercy, credits and New Game+.
 * Registered last, so it wraps the loop's capture handler. Data: index.json `features.endings`.
 * Automation/dev: `__game.story.features.find((f) => f.id === "endings").runtime`.
 */
export const endingsFeature: StoryFeature & { runtime: EndingsRuntime | null } = {
  id: "endings",
  runtime: null,
  buildStatic(b, _floors, data) {
    buildEndingSets(b, readEndings(data));
  },
  init({ game, data }) {
    endingsFeature.runtime = new EndingsRuntime(game, readEndings(data));
  },
  update(dt) {
    endingsFeature.runtime?.update(dt);
  },
  onWipe() {
    endingsFeature.runtime?.onWipe();
  },
};
