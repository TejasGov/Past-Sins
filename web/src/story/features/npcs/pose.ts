/**
 * Pose layers on top of the guard.glb clips (Mixamo rig, metres, bones run
 * along +Y). Each bone gets a local post-rotation in degrees (XYZ order);
 * `absolute` layers replace the clip's rotation with bind pose × offset
 * instead. `hips` moves the pelvis in model space (sitting).
 */
export interface PoseDef {
  bones: Record<string, [number, number, number]>;
  hips?: [number, number, number];
  absolute?: boolean;
}

const L = "mixamorigLeft";
const R = "mixamorigRight";

export const POSES: Record<string, PoseDef> = {
  /** On a chair or stool: thighs forward, shins down, pelvis on the seat. */
  sit: {
    absolute: true,
    hips: [0, -0.44, -0.12],
    bones: {
      [`${L}UpLeg`]: [90, 0, 0],
      [`${R}UpLeg`]: [90, 0, 0],
      [`${L}Leg`]: [-92, 0, 0],
      [`${R}Leg`]: [-92, 0, 0],
      [`${L}Foot`]: [8, 0, 0],
      [`${R}Foot`]: [8, 0, 0],
    },
  },
  /** Old shoulders: a little stoop, head forward. */
  stoop: {
    bones: { mixamorigSpine1: [10, 0, 0], mixamorigNeck: [8, 0, 0] },
  },
  /** Hands in the lap (seated). On this rig Z swings an arm forward (−Z right, +Z left); Y turns it in. */
  lap: {
    bones: {
      [`${L}Arm`]: [0, 30, 22],
      [`${R}Arm`]: [0, -30, -22],
      [`${L}ForeArm`]: [0, 0, 55],
      [`${R}ForeArm`]: [0, 0, -55],
    },
  },
  /** Right hand holding a tumbler at the chest. */
  carry: {
    bones: {
      [`${R}Arm`]: [0, 0, -12],
      [`${R}ForeArm`]: [0, 0, -70],
    },
  },
  /** Arms folded: she has watched this forty times. */
  folded: {
    bones: {
      [`${L}Arm`]: [0, 60, 15],
      [`${R}Arm`]: [0, -60, -15],
      [`${L}ForeArm`]: [0, 0, 100],
      [`${R}ForeArm`]: [0, 0, -100],
    },
  },
  /** Right palm flat on the glass in front of them. */
  palm: {
    bones: {
      [`${R}Arm`]: [0, 0, -50],
      [`${R}ForeArm`]: [0, 0, -35],
      [`${R}Hand`]: [0, 0, -70],
    },
  },
  /** Leaning in to the glass. */
  lean: {
    bones: { mixamorigSpine: [8, 0, 0], mixamorigSpine1: [8, 0, 0] },
  },
};
