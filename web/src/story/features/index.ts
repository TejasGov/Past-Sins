import type { StoryFeature } from "../types";
import { loopFeature } from "./loop";
import { routineFeature } from "./routine";
import { waterFeature } from "./water";
import { npcsFeature } from "./npcs";
import { contentFeature } from "./content";
import { audioFeature } from "./audio";
import { endingsFeature } from "./endings";

/** Every story feature, in init/update order. Each folder belongs to one workstream (docs/story/BUILD_PLAN.md). */
export const FEATURES: StoryFeature[] = [loopFeature, routineFeature, waterFeature, npcsFeature, contentFeature, audioFeature, endingsFeature];
