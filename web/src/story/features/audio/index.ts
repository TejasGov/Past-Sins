import type { StoryFeature } from "../../types";
import { AudioDirector } from "./director";
import { readAudioData } from "./data";

/**
 * W6 · Audio.
 * WebAudio engine (src/audio/): ambience, footsteps, doors, alarms, water, rain, heartbeat, story stingers,
 * the 2·7·1·8 motif and voice clips per dialogue line, all synthesised and driven by events the game
 * already emits. Owned by one workstream — see docs/story/BUILD_PLAN.md. Data: index.json `features.audio`.
 * Automation: `__game.story.features.find(f => f.id === "audio").runtime.debugInfo()`.
 */
export const audioFeature: StoryFeature & { runtime: AudioDirector | null } = {
  id: "audio",
  runtime: null,
  init({ game, data }) {
    audioFeature.runtime = new AudioDirector(game, readAudioData(data));
  },
  update(dt) {
    audioFeature.runtime?.update(dt);
  },
};
