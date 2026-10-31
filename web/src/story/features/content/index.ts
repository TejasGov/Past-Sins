import type { StoryFeature } from "../../types";
import type { ContentData } from "./data";
import { ContentRuntime } from "./runtime";
import { buildContentStatic } from "./static";

/**
 * W5 · Content & interactables.
 * Shards M02–M14 data, documents, props and triggers for Acts I–III, objectives, the restricted lift (281828), monitor wall, tape archive, radio, Jagran, doorplates.
 * Owned by one workstream — see docs/story/BUILD_PLAN.md. Data: index.json `features.content`.
 *
 * Props, documents, dialogue and objectives are plain story data (triggers/act1–3.json,
 * documents.json, dialogue/story.json, objectives.json); this feature adds what data
 * can't: furniture and anchors for those props, doorplates, the lift ride, and flags
 * that follow the world (locker open, B2 reached, Maintenance B1 in Act III).
 */
export const contentFeature: StoryFeature & { runtime: ContentRuntime | null } = {
  id: "content",
  runtime: null,
  buildStatic(b, floors, data) {
    buildContentStatic(b, floors, data as ContentData | null);
  },
  init({ game, data }) {
    if (data) this.runtime = new ContentRuntime(game, data as ContentData);
  },
  update(dt) {
    this.runtime?.update(dt);
  },
  onWipe() {
    this.runtime?.onWipe();
  },
};
