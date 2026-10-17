/** Types + loader for data/campus/floor_plans.json (copied to public/data/campus). */
export interface PlanRoom {
  id: string;
  label: string;
  x: number;
  y: number;
  w: number;
  d: number;
  type: string;
  detail: string;
  lighting_type?: string;
  floor_finish?: string;
}

export interface PlanDoor {
  a: string;
  b: string;
  x: number;
  y: number;
  axis: "x" | "z";
  width: number;
  kind: string;
  detail?: string;
  side?: string;
}

export interface FloorPlan {
  id: string;
  name: string;
  level: string;
  width: number;
  depth: number;
  elevation: number;
  summary: string;
  rooms: PlanRoom[];
  doors: PlanDoor[];
  notes?: string[];
  compacted?: boolean;
}

export async function loadFloorPlans(url = "data/campus/floor_plans.json"): Promise<FloorPlan[]> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to load ${url}: ${res.status}`);
  const json = (await res.json()) as { plans: FloorPlan[] };
  return json.plans;
}

/**
 * Port of campus_plan_compactor.gd: removes only oversized circulation strips.
 * Endpoints outside a strip translate together so rooms keep their size.
 */
const STRIPS: Record<string, { x?: [number, number, number][]; z?: [number, number, number][] }> = {
  "food-ground": { z: [[14, 18, 3.2]] },
  "medical-ground": { x: [[17, 21, 3.2]], z: [[14, 18, 3.2]] },
  "cellhouse-b-0": { x: [[16, 20, 3.2]], z: [[20, 26, 4.8]] },
  "cellhouse-b-1": { x: [[16, 20, 3.2]], z: [[20, 26, 4.8]] },
  "hq-0": { x: [[16, 20, 3.2]], z: [[14, 18, 3.2]] },
  "hq-1": { x: [[16, 20, 3.2]], z: [[14, 18, 3.2]] },
  "maintenance-ground": { x: [[16, 20, 3.2]], z: [[14, 18, 3.2]] },
  "maintenance-b1": { x: [[16, 20, 3.2]], z: [[14, 18, 3.2]] },
  "nidra-b2": { x: [[16, 20, 3.2]], z: [[14, 18, 3.2]] },
  "admin-ground": { x: [[18, 22, 3.2]] },
};

function map(value: number, strips: [number, number, number][] = []): number {
  let result = value;
  for (const [start, finish, target] of strips) {
    const removed = finish - start - target;
    if (value >= finish) result -= removed;
    else if (value > start) result -= ((value - start) * removed) / (finish - start);
  }
  return result;
}

export function compactPlan(source: FloorPlan): FloorPlan {
  const plan: FloorPlan = JSON.parse(JSON.stringify(source));
  const s = STRIPS[plan.id];
  if (!s) return plan;
  for (const r of plan.rooms) {
    const ox = r.x;
    const oz = r.y;
    r.x = map(ox, s.x);
    r.y = map(oz, s.z);
    r.w = map(ox + r.w, s.x) - r.x;
    r.d = map(oz + r.d, s.z) - r.y;
  }
  for (const d of plan.doors) {
    d.x = map(d.x, s.x);
    d.y = map(d.y, s.z);
  }
  plan.width = map(plan.width, s.x);
  plan.depth = map(plan.depth, s.z);
  plan.compacted = true;
  return plan;
}
