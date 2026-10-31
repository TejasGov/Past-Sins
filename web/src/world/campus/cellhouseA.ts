import type { StaticBuilder } from "../builder";
import {
  V, bench, cctvCamera, cleaningCart, deg, drinkingFountain, electricalBox, noticeBoard, pipeRun, place, securityConsole, trashBin, wallClock,
} from "../props";
import { buildShell } from "./shell";
import { PARTH_SPAWN_LOCAL, PARTH_SPAWN_YAW, memoryShelf, prisonCell } from "./cell";
import { guardElevatorCore } from "./guardCore";
import { stairFlight } from "./stairs";

const FLOOR_HEIGHT = 4;
const NORTH_CELL_Z = -13.85;
const SOUTH_CELL_Z = 13.85;
const CELL_X = [-17.5, -12.5, -7.5, -2.5, 2.5, 7.5, 12.5, 17.5];

/**
 * Cellhouse A (scripts/levels/campus/buildings/cellhouse_a.gd +
 * interiors/cellhouse_a_interior.gd): three cell tiers around an open atrium,
 * bridges, two long stair flights and a guard/lift core per tier. A glazed
 * roof light over the atrium is new: it lets daylight shafts into the void.
 */
export function buildCellhouseA(b: StaticBuilder, origin = V(-50, 0, 0)): void {
  b.within(origin, 0, () => {
    b.setChunk("exterior", false);
    buildShell(b, {
      title: "CELLHOUSE A — GENERAL POPULATION",
      width: 44,
      height: 13,
      depth: 34,
      thickness: 0.45,
      openings: [
        { side: "west", offset: 0, width: 3.0, height: 3.2, label: "CELLHOUSE A — MAIN ENTRANCE" },
        { side: "east", offset: 0, width: 3.0, height: 3.2, label: "YARD ACCESS" },
      ],
      skylight: [-15, -5.6, 15, 5.6],
    });
    b.setChunk("cellhouseA", true);
    structure(b);
    cells(b);
    markers(b);
    // Nav export: each tier as a guard grid; rows run on the gallery centre
    // lines (z = ±9) and the bridge centre (x = 0). The flights record themselves.
    for (let tier = 0; tier < 3; tier++) {
      b.navRegion(-21.6, -16.7, 21.6, 16.7, tier * FLOOR_HEIGHT, { spacing: 1.8, align: [0, 9], tag: `cellhouseA_floor${tier + 1}` });
    }
  });
}

function structure(b: StaticBuilder): void {
  const floor = 0x303330;
  const rail = 0x3d4541;
  b.box(V(0, -0.025, 0), V(43.2, 0.05, 33.2), { mat: "concrete", color: 0x3a3d39 });
  // Painted floor markings on the dayroom (controlled movement lanes).
  for (const z of [-6.2, 6.2]) b.box(V(0, 0.003, z), V(30, 0.004, 0.12), { mat: "hazard", collide: false, shadow: false });

  for (const tier of [1, 2]) {
    const y = tier * FLOOR_HEIGHT;
    b.box(V(0, y - 0.08, -11.85), V(43.2, 0.16, 9.7), { mat: "concrete", color: floor });
    b.box(V(0, y - 0.08, 11.85), V(43.2, 0.16, 9.7), { mat: "concrete", color: floor });
    // Slab edge fascia with a hazard stripe reads the tier edges from below.
    for (const z of [-7.0, 7.0]) b.box(V(0, y - 0.24, z), V(43.2, 0.32, 0.12), { mat: "concrete", color: 0x2d302d, collide: false });
    if (tier === 1) {
      b.box(V(-20.45, y - 0.08, 0), V(2.3, 0.16, 14.2), { mat: "concrete", color: floor });
      b.box(V(-18.0, y - 0.08, 7.4), V(2.6, 0.16, 0.8), { mat: "concrete", color: floor });
    } else {
      b.box(V(-19.15, y - 0.08, 0), V(4.9, 0.16, 14.2), { mat: "concrete", color: floor });
    }
    if (tier === 2) {
      b.box(V(20.45, y - 0.08, 0), V(2.3, 0.16, 14.2), { mat: "concrete", color: floor });
      b.box(V(18.0, y - 0.08, -7.4), V(2.6, 0.16, 0.8), { mat: "concrete", color: floor });
    } else {
      b.box(V(19.15, y - 0.08, 0), V(4.9, 0.16, 14.2), { mat: "concrete", color: floor });
    }
    b.box(V(0, y - 0.08, 0), V(4.2, 0.16, 14.2), { mat: "concrete", color: floor });
    // Bridge underside steel beams.
    for (const x of [-1.9, 1.9]) b.box(V(x, y - 0.35, 0), V(0.2, 0.4, 14.2), { mat: "dark", color: 0x2a2e2b, collide: false });
    atriumRails(b, y, tier, rail);
  }
  b.within(V(-18, 0, -7), 0, () => stairFlight(b, 14, FLOOR_HEIGHT, 2.6, 20));
  b.within(V(18, FLOOR_HEIGHT, 7), Math.PI, () => stairFlight(b, 14, FLOOR_HEIGHT, 2.6, 20));

  // Gallery fluorescents: cellblock profile (full at night, dim by day).
  for (let tier = 0; tier < 3; tier++) {
    const fy = tier === 2 ? 12.86 : tier * FLOOR_HEIGHT + 3.8;
    for (const side of [-1, 1]) {
      for (const x of [-15, -5, 5, 15]) {
        const flicker = tier === 1 && side === 1 && x === 5 ? 1 : tier === 2 && side === -1 && x === -15 ? 0.6 : 0;
        b.fixture(V(x, fy - 0.055, side * 9.25), V(2.0, 0.045, 0.22), { nightOnly: true, intensity: 7, range: 13, flicker, color: 0xffd9a0 });
      }
    }
  }
  // Atrium high-bay lamps hanging from the roof trusses.
  for (const x of [-10, 0, 10]) {
    b.box(V(x, 12.2, 0), V(0.02, 1.3, 0.02), { mat: "steel", collide: false, shadow: false });
    b.cylinder(V(x, 11.45, 0), 0.32, 0.22, { mat: "dark", color: 0x2a2e2b });
    b.fixture(V(x, 11.32, 0), V(0.5, 0.03, 0.5), { nightOnly: true, intensity: 14, range: 20, color: 0xffc98a, backplate: false });
  }

  b.sign("YARD ACCESS", V(21.5, 3.6, 0), deg(-90), 0xd7c176, 0.004);
  b.sign("CELLHOUSE A — THREE-TIER GENERAL POPULATION", V(-21.5, 4.3, 0), deg(90), 0xd7d0aa, 0.0042);
  for (let tier = 0; tier < 3; tier++) {
    const y = tier * FLOOR_HEIGHT;
    b.sign(`FLOOR ${tier + 1}`, V(-21.5, y + 2.6, -5.0), deg(90), tier === 2 ? 0xd7c176 : 0xb8c9c4, 0.0035);
    b.sign(`LEVEL ${tier + 1} · CONTROLLED MOVEMENT`, V(0, y + 2.95, 16.5), deg(180), 0xc9c397, 0.0027);
    place(b, V(-21.3, y + 3.05, -5.8), 90, cctvCamera);
    place(b, V(21.3, y + 3.05, 5.8), -90, cctvCamera);
    if (tier > 0) {
      place(b, V(-21.5, y, 4.8), 90, noticeBoard);
      place(b, V(21.5, y, -4.8), -90, wallClock);
    }
  }

  place(b, V(5.0, 0, 2.6), 180, securityConsole);
  place(b, V(-5.0, 0, 3.8), 90, bench);
  place(b, V(5.0, 0, 3.8), -90, bench);
  place(b, V(-5.0, 0, -3.8), 90, bench);
  place(b, V(5.0, 0, -3.8), -90, bench);
  place(b, V(-13.8, 0, 5.7), 0, trashBin);
  place(b, V(13.8, 0, 5.7), 0, trashBin);
  place(b, V(-13.5, 0, -5.4), 90, cleaningCart);
  place(b, V(21.35, 0, 4.6), -90, drinkingFountain);
  place(b, V(-21.5, 0, 4.7), 90, noticeBoard);
  place(b, V(21.5, 0, -4.6), -90, wallClock);
  place(b, V(-21.55, 0, -4.8), 90, electricalBox);
  place(b, V(21.55, 0, -5.8), -90, (bb) => pipeRun(bb, 6));
}

function atriumRails(b: StaticBuilder, y: number, tier: number, color: number): void {
  const BR = 2.1;
  const WO = -19.24;
  const WI = -16.76;
  const EI = 16.76;
  const EO = 19.24;
  const nw = tier === 1 ? WO : WI;
  const se = tier === 2 ? EO : EI;
  b.railing(V(nw, y, -7), V(-BR, y, -7), color);
  b.railing(V(BR, y, -7), V(EI, y, -7), color);
  b.railing(V(WI, y, 7), V(-BR, y, 7), color);
  b.railing(V(BR, y, 7), V(se, y, 7), color);
  if (tier === 1) {
    b.railing(V(WO, y, -7), V(WO, y, 7), color);
    b.railing(V(EI, y, -7), V(EI, y, 7), color);
  } else {
    b.railing(V(EO, y, -7), V(EO, y, 7), color);
    b.railing(V(WI, y, -7), V(WI, y, 7), color);
  }
  b.railing(V(-BR, y, -7), V(-BR, y, 7), color);
  b.railing(V(BR, y, -7), V(BR, y, 7), color);
}

function cells(b: StaticBuilder): void {
  // Cell modules never see the sun: their own chunk skips the CSM passes.
  b.setChunk("cellhouseA_cells", true);
  for (let tier = 0; tier < 3; tier++) {
    const y = tier * FLOOR_HEIGHT;
    const floor = tier + 1;
    CELL_X.forEach((x, index) => {
      const isParth = tier === 2 && index === 2;
      if (index !== CELL_X.length - 1) spawnCell(b, "North", index + 1, V(x, y, NORTH_CELL_Z), -90, floor, isParth);
      spawnCell(b, "South", index + 1, V(x, y, SOUTH_CELL_Z), 90, floor, false);
    });
    b.within(V(CELL_X[7], y, NORTH_CELL_Z), 0, () => guardElevatorCore(b, floor));
  }
  b.setChunk("cellhouseA", true);
}

function spawnCell(b: StaticBuilder, side: string, number: number, at: ReturnType<typeof V>, yaw: number, floor: number, isParth: boolean): void {
  const id = `cellhouse_a_floor${floor}_${side.toLowerCase()}_${String(number).padStart(2, "0")}`;
  b.within(at, deg(yaw), () => {
    prisonCell(b, {
      accessId: id,
      displayName: isParth ? "Parth's Cell" : `Cellhouse A Floor ${floor} ${side} Cell ${String(number).padStart(2, "0")}`,
      numberLabel: `A-${floor}-${side[0]}${String(number).padStart(2, "0")}`,
      isParth,
      upperTier: floor > 1,
    });
    if (isParth) {
      b.anchor("parth_spawn", PARTH_SPAWN_LOCAL, PARTH_SPAWN_YAW);
      const shard = memoryShelf(b);
      b.anchors.set("parth_memory_shelf", { position: shard, yaw: b.worldYaw(0) });
    }
  });
}

function markers(b: StaticBuilder): void {
  for (const [name, x, label] of [["main", -22.44, "CELLHOUSE A"], ["yard", 22.44, "YARD"]] as const) {
    b.door({
      kind: "gate",
      position: V(x, 0, 0),
      yaw: deg(90),
      width: 2.7,
      height: 3.15,
      slideDistance: 3.15,
      openDirection: 1,
      requiredKey: "",
      persistentId: `cellhouse_a_${name}_gate`,
      displayName: name === "main" ? "Cellhouse A Main Gate" : "Cellhouse A Yard Gate",
      startsLocked: false,
      label,
      color: 0x343a38,
    });
  }
  for (const side of [-1, 1]) for (const edge of [-1, 1]) {
    b.box(V(side * 22.17, 1.25, edge * 1.55), V(0.34, 2.5, 0.1), { mat: "metal", color: 0x555d56 });
  }
  b.anchor("cellhouse_a_dayroom", V(0, 0, 0));
  b.anchor("cellhouse_a_skylight", V(0, 0, 0), 0, { x0: -15, z0: -5.6, x1: 15, z1: 5.6, top: 12.95, depth: 12.9 });
  b.anchor("cellhouse_a_key_rack", V(10.5, 0, 2.8), 0);
}
