import type { StoryFeature } from "../../types";
import { NpcRuntime } from "./runtime";
import type { NpcsData } from "./types";

/**
 * W4 · NPCs & dialogue.
 * Bhosle, Kabir, Parth's mother, Meera's voice/silhouette; conversations, the Observation-glass dialogue, NPC visuals and schedules.
 * Owned by one workstream — see docs/story/BUILD_PLAN.md. Data: index.json `features.npcs`
 * (data/story/features/npcs.json), dialogue/npcs.json, triggers/npcs.json.
 */
export const npcsFeature: StoryFeature & { runtime: NpcRuntime | null } = {
  id: "npcs",
  runtime: null,
  async init({ game, data }) {
    if (!data) return;
    const rt = new NpcRuntime(game, data as NpcsData);
    await rt.init();
    npcsFeature.runtime = rt;
  },
  update(dt) {
    npcsFeature.runtime?.update(dt);
  },
  onWipe() {
    npcsFeature.runtime?.onWipe();
  },
};
