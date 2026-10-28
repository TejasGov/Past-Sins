import { Vector3 } from "three";
import type { StoryFeature } from "../../types";
import { RoutineRuntime } from "./routine";
import { dietaryWindow } from "./dose";
import type { RoutineData } from "./data";

let runtime: RoutineRuntime | null = null;

/**
 * W2 · Daily routine & the dose.
 * 06:00 count, meals, work, yard, lock-in, lights out, visitation day; the dietary-window pill (take / pocket), withdrawal effects and shimmering shards.
 * Owned by one workstream — see docs/story/BUILD_PLAN.md. Data: index.json `features.routine`.
 * Automation/dev: `__game.story.features.find((f) => f.id === "routine").runtime`.
 */
export const routineFeature: StoryFeature & { readonly runtime: RoutineRuntime | null } = {
  id: "routine",
  buildStatic(b, floors, data) {
    // Plate over the dietary/medical stall, on the dining side of the serving hatch.
    const d = (data as Partial<RoutineData> | null)?.dose;
    const w = d && dietaryWindow(floors, d.window);
    if (!d || !w || !d.window.sign) return;
    const was = b.chunkName;
    b.setChunk("food", true);
    const at = w.position.clone().setY(w.position.y - d.window.counterHeight + 2.37).addScaledVector(w.forward, 0.115);
    b.within(new Vector3(), 0, () => b.sign(d.window.sign, at, Math.atan2(w.forward.x, w.forward.z), 0xd8d0a4, 0.0026));
    b.setChunk(was, was !== "exterior");
  },
  init({ game, data }) {
    if (!data || !(data as Partial<RoutineData>).beats) {
      console.warn("[routine] no data/story/features/routine.json; routine off");
      return;
    }
    runtime = new RoutineRuntime(game, data as RoutineData);
  },
  update(dt) {
    runtime?.update(dt);
  },
  onWipe() {
    runtime?.onWipe();
  },
  get runtime() {
    return runtime;
  },
};
