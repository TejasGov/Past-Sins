import RAPIER from "@dimforge/rapier3d-compat";
import { Quaternion, Vector3 } from "three";

export { RAPIER };

/** Collision membership bits (Rapier InteractionGroups: membership << 16 | filter). */
export const Layer = {
  STATIC: 1 << 0,
  PLAYER: 1 << 1,
  GUARD: 1 << 2,
  DOOR: 1 << 3,
  WATER: 1 << 4,
} as const;

export function groups(membership: number, filter: number): number {
  return ((membership & 0xffff) << 16) | (filter & 0xffff);
}

export const STATIC_GROUPS = groups(Layer.STATIC, Layer.PLAYER | Layer.GUARD);
export const DOOR_GROUPS = groups(Layer.DOOR, Layer.PLAYER | Layer.GUARD);
export const PLAYER_GROUPS = groups(Layer.PLAYER, Layer.STATIC | Layer.DOOR | Layer.GUARD);
export const GUARD_GROUPS = groups(Layer.GUARD, Layer.STATIC | Layer.DOOR | Layer.PLAYER);

const _q = new Quaternion();

/**
 * Thin wrapper over a Rapier world. All level geometry is fixed colliders with
 * no parent body; doors/gates use kinematic position-based bodies.
 */
export class Physics {
  readonly world: RAPIER.World;

  private constructor() {
    this.world = new RAPIER.World({ x: 0, y: -18, z: 0 });
  }

  static async create(): Promise<Physics> {
    await RAPIER.init();
    return new Physics();
  }

  addStaticBox(center: Vector3, half: Vector3, rotationY = 0): RAPIER.Collider {
    const desc = RAPIER.ColliderDesc.cuboid(half.x, half.y, half.z)
      .setTranslation(center.x, center.y, center.z)
      .setCollisionGroups(STATIC_GROUPS);
    if (rotationY !== 0) {
      _q.setFromAxisAngle(new Vector3(0, 1, 0), rotationY);
      desc.setRotation({ x: _q.x, y: _q.y, z: _q.z, w: _q.w });
    }
    return this.world.createCollider(desc);
  }

  addStaticBoxQuat(center: Vector3, half: Vector3, q: Quaternion): RAPIER.Collider {
    const desc = RAPIER.ColliderDesc.cuboid(half.x, half.y, half.z)
      .setTranslation(center.x, center.y, center.z)
      .setRotation({ x: q.x, y: q.y, z: q.z, w: q.w })
      .setCollisionGroups(STATIC_GROUPS);
    return this.world.createCollider(desc);
  }

  /** Smooth stair ramps: a convex hull of world-space points. */
  addStaticConvex(points: Vector3[]): RAPIER.Collider | null {
    const flat = new Float32Array(points.length * 3);
    points.forEach((p, i) => flat.set([p.x, p.y, p.z], i * 3));
    const desc = RAPIER.ColliderDesc.convexHull(flat);
    if (!desc) return null;
    desc.setCollisionGroups(STATIC_GROUPS);
    return this.world.createCollider(desc);
  }

  /** Kinematic body for a moving door leaf; the collider is in body space. */
  addKinematicBox(half: Vector3, offset: Vector3): { body: RAPIER.RigidBody; collider: RAPIER.Collider } {
    const body = this.world.createRigidBody(RAPIER.RigidBodyDesc.kinematicPositionBased());
    const collider = this.world.createCollider(
      RAPIER.ColliderDesc.cuboid(half.x, half.y, half.z)
        .setTranslation(offset.x, offset.y, offset.z)
        .setCollisionGroups(DOOR_GROUPS),
      body,
    );
    return { body, collider };
  }

  /** Overlap test for a box in world space against the given membership mask. */
  boxOverlaps(center: Vector3, half: Vector3, rotationY: number, mask: number, exclude?: RAPIER.Collider): RAPIER.Collider | null {
    _q.setFromAxisAngle(new Vector3(0, 1, 0), rotationY);
    const shape = new RAPIER.Cuboid(half.x, half.y, half.z);
    return this.world.intersectionWithShape(
      { x: center.x, y: center.y, z: center.z },
      { x: _q.x, y: _q.y, z: _q.z, w: _q.w },
      shape,
      undefined,
      groups(0xffff, mask),
      exclude,
    );
  }

  step(dt: number): void {
    this.world.timestep = Math.min(dt, 1 / 30);
    this.world.step();
  }
}
