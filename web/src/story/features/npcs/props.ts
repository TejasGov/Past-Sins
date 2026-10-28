import {
  BoxGeometry, CylinderGeometry, DoubleSide, Group, LatheGeometry, Mesh, MeshBasicMaterial, MeshStandardMaterial, Object3D, SphereGeometry, Vector2,
  type Material,
} from "three";

type Prepare = (m: Material) => void;

/** Where a prop hangs on the rig, and its local transform there. */
interface PropSpec {
  bone: string;
  build: (mat: (color: number, rough?: number, metal?: number) => Material) => Object3D;
}

const lathe = (pts: [number, number][], segments = 18) => new LatheGeometry(pts.map(([r, y]) => new Vector2(r, y)), segments);

function mesh(geo: ConstructorParameters<typeof Mesh>[0], mat: Material, x = 0, y = 0, z = 0): Mesh {
  // Lathe profiles here run top to bottom (normals inwards); open shells are seen from both sides.
  if (geo instanceof LatheGeometry || (geo instanceof SphereGeometry && geo.parameters.thetaLength < Math.PI)) {
    mat = mat.clone();
    mat.side = DoubleSide;
  }
  const m = new Mesh(geo, mat);
  m.position.set(x, y, z);
  m.castShadow = true;
  m.receiveShadow = true;
  return m;
}

/** Steel chai tumbler (shared by Bhosle's hand and the one he leaves at the gate). Origin at its base. */
export function tumbler(mat: Material): Object3D {
  const g = new Group();
  g.add(mesh(lathe([[0.001, 0], [0.034, 0], [0.036, 0.01], [0.043, 0.115], [0.045, 0.12], [0.041, 0.12], [0.038, 0.012], [0.001, 0.012]]), mat));
  return g;
}

/** A steel-framed stool with a wooden seat (origin at its feet; the seat is 0.46 m up). */
export function stool(prepare: Prepare): Object3D {
  const g = new Group();
  const wood = new MeshStandardMaterial({ color: 0x6b5843, roughness: 0.8 });
  const steel = new MeshStandardMaterial({ color: 0x5c6660, roughness: 0.5, metalness: 0.6 });
  prepare(wood);
  prepare(steel);
  g.add(mesh(new CylinderGeometry(0.17, 0.17, 0.035, 16), wood, 0, 0.445, 0));
  for (const [x, z] of [[0.11, 0.11], [-0.11, 0.11], [0.11, -0.11], [-0.11, -0.11]]) {
    const leg = mesh(new CylinderGeometry(0.012, 0.014, 0.43, 6), steel, x, 0.215, z);
    leg.rotation.set(z * 0.5, 0, -x * 0.5);
    g.add(leg);
  }
  return g;
}

/**
 * A plain face in place of the guard's gas mask, in the head bone's frame
 * (+Y up the skull, +Z forward). Ink = a silhouette.
 */
export function buildFace(skinHex: string, browHex: string, prepare: Prepare, ink: boolean): Object3D {
  const g = new Group();
  g.name = "NpcFace";
  const mat = (color: string | number, rough = 0.7): Material => {
    if (ink) return new MeshBasicMaterial({ color: 0x030405, fog: false });
    const m = new MeshStandardMaterial({ color, roughness: rough });
    prepare(m);
    return m;
  };
  const skin = mat(skinHex, 0.62);
  const skull = mesh(new SphereGeometry(0.1, 22, 16), skin, 0, 0.115, 0.045);
  skull.scale.set(0.86, 1.13, 1.0);
  g.add(skull);
  const jaw = mesh(new SphereGeometry(0.07, 16, 10), skin, 0, 0.06, 0.07);
  jaw.scale.set(1.0, 0.85, 0.95);
  g.add(jaw);
  g.add(mesh(new CylinderGeometry(0.047, 0.055, 0.12, 14), skin, 0, -0.005, 0.0));
  if (ink) return g;
  const nose = mesh(new BoxGeometry(0.026, 0.05, 0.03), skin, 0, 0.1, 0.143);
  nose.rotation.x = -0.25;
  g.add(nose);
  for (const s of [-1, 1]) {
    const ear = mesh(new SphereGeometry(0.024, 10, 8), skin, s * 0.087, 0.11, 0.035);
    ear.scale.set(0.45, 1.1, 0.8);
    g.add(ear);
    g.add(mesh(new SphereGeometry(0.011, 8, 6), mat(0x16110d, 0.4), s * 0.034, 0.128, 0.132));
    const brow = mesh(new BoxGeometry(0.036, 0.009, 0.012), mat(browHex, 0.9), s * 0.035, 0.143, 0.136);
    brow.rotation.z = s * -0.12;
    g.add(brow);
  }
  return g;
}

/**
 * Props by id (data: `look.props`). Bone frames on this rig: +Y runs down
 * the chain (up the spine and neck, down the arms and legs), +Z is the
 * character's front for the spine/head.
 */
const PROPS: Record<string, PropSpec> = {
  // Bhosle: steel tumbler in the right hand, khaki peaked cap, grey hair and moustache.
  tumbler: {
    bone: "mixamorigRightHand",
    build: (m) => {
      const t = tumbler(m(0xb9beb8, 0.32, 0.9));
      t.position.set(0.03, 0.06, 0.05);
      t.rotation.set(0, 0, Math.PI / 2);
      return t;
    },
  },
  cap: {
    bone: "mixamorigHead",
    build: (m) => {
      const g = new Group();
      g.add(mesh(new CylinderGeometry(0.1, 0.096, 0.075, 20), m(0x8a7a52, 0.9), 0, 0.232, 0.035));
      g.add(mesh(new CylinderGeometry(0.102, 0.102, 0.022, 20), m(0x3a2f1e, 0.6), 0, 0.2, 0.035));
      const peak = mesh(new BoxGeometry(0.15, 0.01, 0.07), m(0x1d1a14, 0.4), 0, 0.195, 0.135);
      peak.rotation.x = 0.22;
      g.add(peak);
      g.add(mesh(new BoxGeometry(0.035, 0.03, 0.01), m(0xc9a640, 0.3, 0.8), 0, 0.235, 0.134));
      return g;
    },
  },
  greyhair: {
    bone: "mixamorigHead",
    build: (m) => {
      const g = new Group();
      const hair = mesh(new SphereGeometry(0.1, 18, 12, 0, Math.PI * 2, 0, Math.PI * 0.5), m(0x6f6c68, 0.95), 0, 0.152, 0.03);
      hair.scale.set(0.9, 0.85, 1.04);
      g.add(hair);
      g.add(mesh(new BoxGeometry(0.062, 0.015, 0.02), m(0x6a6560, 0.95), 0, 0.078, 0.14));
      return g;
    },
  },
  // Kabir: a long prison kurta over the uniform, unkempt hair and a beard.
  kurta: {
    bone: "mixamorigHips",
    build: (m) => {
      const k = mesh(lathe([[0.16, 0.1], [0.19, 0.0], [0.215, -0.2], [0.235, -0.38], [0.001, -0.38]], 20), m(0xbdb7a4, 0.95));
      k.scale.z = 0.7;
      return k;
    },
  },
  wildhair: {
    bone: "mixamorigHead",
    build: (m) => {
      const g = new Group();
      const ink = m(0x17130f, 0.95);
      const hair = mesh(new SphereGeometry(0.106, 18, 12, 0, Math.PI * 2, 0, Math.PI * 0.52), ink, 0, 0.152, 0.03);
      hair.scale.set(0.94, 1.0, 1.08);
      g.add(hair);
      const beard = mesh(new SphereGeometry(0.06, 12, 8), ink, 0, 0.05, 0.1);
      beard.scale.set(1.05, 0.95, 0.75);
      g.add(beard);
      return g;
    },
  },
  // Parth's mother: a shawl over the head and shoulders.
  shawl: {
    bone: "mixamorigSpine2",
    build: (m) => {
      const drape = mesh(lathe([[0.07, 0.25], [0.14, 0.22], [0.195, 0.15], [0.215, 0.05], [0.205, -0.1]], 22), m(0x5e2622, 0.95), 0, 0, -0.01);
      drape.scale.z = 0.78;
      return drape;
    },
  },
  hood: {
    bone: "mixamorigHead",
    build: (m) => {
      const g = new Group();
      // Open at the front (+Z is phi = π/2 on a three.js sphere).
      const hood = mesh(new SphereGeometry(0.122, 20, 14, Math.PI / 2 + 0.75, Math.PI * 2 - 1.5, 0, Math.PI * 0.78), m(0x5e2622, 0.95), 0, 0.118, 0.03);
      hood.scale.set(1, 1.08, 1.05);
      g.add(hood);
      const hair = mesh(new SphereGeometry(0.102, 16, 10, 0, Math.PI * 2, 0, Math.PI * 0.42), m(0x2b2622, 0.9), 0, 0.152, 0.035);
      hair.scale.set(0.9, 1.05, 1.02);
      g.add(hair);
      return g;
    },
  },
  // Meera: lab coat flare, hair in a bun.
  coat: {
    bone: "mixamorigHips",
    build: (m) => {
      const c = mesh(lathe([[0.17, 0.2], [0.2, 0.05], [0.25, -0.2], [0.29, -0.5], [0.275, -0.51], [0.001, -0.51]], 20), m(0xdfe3e2, 0.9));
      c.scale.z = 0.7;
      return c;
    },
  },
  bun: {
    bone: "mixamorigHead",
    build: (m) => {
      const g = new Group();
      const ink = m(0x0d0c0b, 0.9);
      const hair = mesh(new SphereGeometry(0.106, 18, 12, 0, Math.PI * 2, 0, Math.PI * 0.55), ink, 0, 0.145, 0.03);
      hair.scale.set(0.92, 1.05, 1.06);
      g.add(hair);
      g.add(mesh(new SphereGeometry(0.055, 12, 8), ink, 0, 0.16, -0.075));
      return g;
    },
  },
  // A photo held in the right hand (the mother presses it to the glass).
  photo: {
    bone: "mixamorigRightHand",
    build: (m) => {
      const p = mesh(new BoxGeometry(0.1, 0.15, 0.004), m(0xd8cfb4, 0.8), 0.01, 0.12, 0.03);
      p.name = "photo";
      return p;
    },
  },
};

/** Builds and attaches the listed props; returns them by id (photo can be toggled). */
export function attachProps(ids: string[], bones: Map<string, Object3D>, prepare: Prepare, ink: boolean): Map<string, Object3D> {
  const out = new Map<string, Object3D>();
  const inkMat = new MeshBasicMaterial({ color: 0x030405, fog: false });
  const mat = (color: number, rough = 0.85, metal = 0): Material => {
    if (ink) return inkMat;
    const m = new MeshStandardMaterial({ color, roughness: rough, metalness: metal });
    prepare(m);
    return m;
  };
  for (const id of ids) {
    const spec = PROPS[id];
    const bone = spec && bones.get(spec.bone);
    if (!spec || !bone) {
      console.warn(`[npcs] unknown prop "${id}"`);
      continue;
    }
    const obj = spec.build(mat);
    obj.name = `NpcProp:${id}`;
    bone.add(obj);
    out.set(id, obj);
  }
  return out;
}
