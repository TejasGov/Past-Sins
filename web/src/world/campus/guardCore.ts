import type { StaticBuilder } from "../builder";
import { V, desk, locker, monitor, officeChair } from "../props";

const W = 5.0;
const D = 5.7;
const H = 3.55;

/**
 * Port of CampusGuardElevatorCore: guard quarter + sealed lift lobby that
 * replaces the north-east cell on every Cellhouse A tier.
 */
export function guardElevatorCore(b: StaticBuilder, floorNumber: number): void {
  const wall = 0x424743;
  const dark = 0x252a28;
  const lift = 0x737b77;
  b.box(V(0, -0.06, 0), V(W, 0.12, D), { mat: "concrete", color: 0x303431 });
  b.box(V(0, H, 0), V(W, 0.14, D), { mat: "concrete", color: wall });
  b.fixture(V(-1.2, H - 0.145, -0.4), V(1.32, 0.03, 0.17), { nightOnly: false, intensity: 3, range: 6 });
  b.box(V(0, H / 2, -D / 2), V(W, H, 0.2), { mat: "concrete", color: wall });
  b.box(V(-W / 2, H / 2, 0), V(0.2, H, D), { mat: "concrete", color: wall });
  b.box(V(W / 2, H / 2, 0), V(0.2, H, D), { mat: "concrete", color: wall });
  b.box(V(0.1, H / 2, 0), V(0.18, H, D), { mat: "concrete", color: wall });
  b.box(V(-2.18, 1.42, D / 2), V(0.64, 2.84, 0.2), { mat: "concrete", color: wall });
  b.box(V(-0.16, 1.42, D / 2), V(1.18, 2.84, 0.2), { mat: "concrete", color: wall });
  b.box(V(2.22, 1.42, D / 2), V(0.56, 2.84, 0.2), { mat: "concrete", color: wall });
  b.box(V(-1.3, 2.985, D / 2), V(1.12, 1.13, 0.22), { mat: "concrete", color: wall });
  b.box(V(1.2, 3.18, D / 2), V(1.5, 0.74, 0.22), { mat: "concrete", color: wall });

  b.door({
    kind: "door",
    position: V(-1.3, 0, D / 2 + 0.31),
    yaw: 0,
    width: 1.08,
    height: 2.42,
    openDirection: -1,
    openAngle: 90,
    requiredKey: "",
    persistentId: `cellhouse_a_floor${floorNumber}_guard_quarter`,
    displayName: `Floor ${floorNumber} Guard Quarter`,
    startsLocked: false,
  });
  for (const x of [-1.88, -0.72]) b.box(V(x, 1.21, D / 2 + 0.115), V(0.08, 2.42, 0.23), { mat: "metal", color: wall });

  const shaftZ = -D / 2 + 3.2;
  b.box(V(0.275, H / 2, shaftZ), V(0.35, H, 0.2), { mat: "concrete", color: wall });
  b.box(V(2.225, H / 2, shaftZ), V(0.55, H, 0.2), { mat: "concrete", color: wall });
  b.box(V(1.2, 2.985, shaftZ), V(1.5, 1.13, 0.2), { mat: "concrete", color: wall });
  for (const s of [-1, 1]) b.box(V(1.2 + s * 0.375, 1.21, shaftZ), V(0.73, 2.42, 0.16), { mat: "steel", color: lift });
  b.box(V(1.2, 1.21, shaftZ + 0.085), V(0.035, 2.3, 0.03), { mat: "dark", color: dark, collide: false });
  b.box(V(2.11, 1.25, shaftZ + 0.13), V(0.18, 0.52, 0.08), { mat: "dark", color: dark, collide: false });
  b.box(V(2.11, 1.32, shaftZ + 0.175), V(0.05, 0.05, 0.01), { mat: "emissive_red", collide: false, shadow: false });
  b.sign(`FLOOR ${floorNumber} — LIFT OFFLINE`, V(1.2, 2.68, shaftZ + 0.12), 0, 0xd2c98e, 0.0023);

  b.within(V(-1.3, 0, -1.45), Math.PI, () => desk(b, 1.62, 0.68));
  b.within(V(-1.15, 0, -1.5), 0, () => monitor(b));
  b.within(V(-1.15, 0, -0.48), Math.PI, () => officeChair(b));
  b.within(V(-2.05, 0, 1.35), Math.PI / 2, () => locker(b));
  b.box(V(-1.2, 1.95, -2.72), V(1.35, 0.72, 0.06), { mat: "wood", color: 0x7a684e, collide: false });
  for (const x of [-0.38, 0, 0.38]) b.box(V(-1.2 + x, 1.95, -2.68), V(0.28, 0.42, 0.015), { mat: "paper", color: 0xc0bca7, collide: false, shadow: false });

  b.sign(`GUARD QUARTER — FLOOR ${floorNumber}`, V(-1.3, 2.68, D / 2 + 0.13), 0, 0xc5cec8, 0.0025);
  b.sign("ELEVATOR — FUTURE SERVICE", V(1.2, 2.68, D / 2 + 0.13), 0, 0xd2c98e, 0.0023);
}
