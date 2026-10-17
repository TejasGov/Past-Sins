import type { StoryFeature } from "../../types";

/**
 * W6 · Audio.
 * WebAudio engine: ambience, footsteps, doors, alarms, water, rain, story stingers, optional voice clips per dialogue line.
 * Owned by one workstream — see docs/story/BUILD_PLAN.md. Data: index.json `features.audio`.
 */
export const audioFeature: StoryFeature = {
  id: "audio",
};
