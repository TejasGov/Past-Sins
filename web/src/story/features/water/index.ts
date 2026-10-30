import type { StoryFeature } from "../../types";
import { buildCulvert, culvertLayout, type CulvertLayout } from "../../../world/campus/culvert";
import { V } from "../../../world/props";
import { readData } from "./data";
import { buildPoolStatic } from "./props";
import { WaterRuntime } from "./runtime";

let layout: CulvertLayout | null = null;

/**
 * W3 · Water: breath, pool shards, culvert.
 * 2·7·1·8 breath meter and drowning, pool dives and the deep-end grate (T1–T3), the Maintenance B1 drainage culvert with air pockets (T4) and the reservoir exit.
 * Owned by one workstream — see docs/story/BUILD_PLAN.md. Data: index.json `features.water`.
 */
export const waterFeature: StoryFeature & { runtime: WaterRuntime | null } = {
  id: "water",
  runtime: null,

  buildStatic(b, floors, raw) {
    const data = readData(raw);
    layout = culvertLayout(floors, data.culvert.gaps);
    if (layout) buildCulvert(b, layout, { sumpSign: data.culvert.sumpSign, outfallSign: data.culvert.outfallSign });
    const pool = b.anchors.get("pool");
    if (pool) {
      const prev = b.chunkName;
      b.setChunk("water", false);
      buildPoolStatic(b, pool.position, V(...data.pool.grate.at), V(...data.pool.t3.speaker));
      b.setChunk(prev, false);
    }
    // The Ghost Exit route: Bhosle's card opens the Gated Landing (and the B1 plant corridor).
    const r = data.route;
    for (const d of b.doors) {
      if (d.persistentId === r.landingDoor) {
        d.requiredKey = r.landingKey;
        d.masterKey = undefined;
      } else if (r.masterDoors.includes(d.persistentId)) d.masterKey = r.landingKey;
    }
  },

  init({ game, data }) {
    waterFeature.runtime = new WaterRuntime(game, readData(data), layout);
  },

  update(dt) {
    waterFeature.runtime?.update(dt);
  },

  onWipe() {
    waterFeature.runtime?.onWipe();
  },
};
