import { Quaternion, Vector3, type Mesh } from "three";
import { MeshKit } from "../../../world/builder";
import type { MaterialLibrary } from "../../../render/materials";
import type { PropModelDef } from "./data";

const V = (x: number, y: number, z: number) => new Vector3(x, y, z);
const upright = new Quaternion();
const lying = new Quaternion().setFromAxisAngle(V(1, 0, 0), -Math.PI / 2);

/** Small greybox meshes for story props the foundation's trigger models don't cover (origin at the base). */
export function buildPropModel(def: PropModelDef, materials: MaterialLibrary): Mesh {
  const kit = new MeshKit(materials);
  switch (def.kind) {
    case "keytag": {
      // A painted tag on a ring, like the dayroom rack keys; hangs from a hook or lies on a desk.
      const q = def.flat ? lying : upright;
      const p = (x: number, y: number, z: number) => (def.flat ? V(x, z + 0.012, -y) : V(x, y, z));
      kit.box(p(0, -0.14, 0), V(0.19, 0.27, 0.018), "plastic", def.color ?? 0xe8bd42, q);
      kit.box(p(0, -0.1, 0.01), V(0.14, 0.07, 0.004), "metal", 0x22201a, q);
      kit.cylinder(p(0, 0.02, 0), 0.035, 0.01, "steel", 0xd0d6d2, def.flat ? upright : new Quaternion().setFromAxisAngle(V(1, 0, 0), Math.PI / 2));
      kit.box(p(0.05, 0.08, 0), V(0.02, 0.1, 0.012), "steel", 0xc0c6c2, q);
      break;
    }
    case "clipboard":
      kit.box(V(0, 0.17, 0), V(0.24, 0.34, 0.012), "wood", def.color ?? 0x6f5a40);
      kit.box(V(0, 0.155, 0.008), V(0.21, 0.28, 0.003), "paper", 0xdcd6c2);
      kit.box(V(0, 0.32, 0.012), V(0.08, 0.035, 0.016), "steel", 0xb7bcb6);
      break;
    case "drawer":
      // A filing drawer left pulled open, folders standing in it.
      kit.box(V(0, 0.02, 0), V(0.42, 0.04, 0.4), "metal", def.color ?? 0x5f6863);
      for (const x of [-0.2, 0.2]) kit.box(V(x, 0.12, 0), V(0.02, 0.24, 0.4), "metal", def.color ?? 0x5f6863);
      kit.box(V(0, 0.13, 0.21), V(0.44, 0.27, 0.02), "metal", 0x667069);
      kit.box(V(0, 0.15, 0.225), V(0.16, 0.03, 0.02), "steel", 0xb0b6b2);
      for (let i = 0; i < 5; i++) kit.box(V(0, 0.13, -0.15 + i * 0.07), V(0.36, 0.2, 0.012), "paper", i % 2 ? 0xc8b27a : 0xd6d0bd);
      break;
    case "radio":
      kit.box(V(0, 0.06, 0), V(0.34, 0.12, 0.22), "dark", def.color ?? 0x2a2f2c);
      kit.box(V(-0.06, 0.07, 0.112), V(0.16, 0.08, 0.005), "metal", 0x3f4542);
      kit.box(V(0.11, 0.09, 0.112), V(0.02, 0.02, 0.005), "emissive_green", 0x3cff6a);
      kit.box(V(0.1, 0.135, 0.02), V(0.07, 0.05, 0.2), "plastic", 0x1c1f1d);
      kit.cylinder(V(-0.14, 0.25, -0.08), 0.008, 0.3, "steel", 0xa9afab, upright);
      break;
    case "folder":
      kit.box(V(0, 0.006, 0), V(0.24, 0.012, 0.32), "paper", def.color ?? 0xc8b27a);
      kit.box(V(0.07, 0.006, -0.17), V(0.08, 0.01, 0.03), "paper", def.color ?? 0xc8b27a);
      kit.box(V(-0.04, 0.0135, 0.06), V(0.12, 0.002, 0.05), "paper", 0xe9e4d4);
      break;
    case "sheet":
      // A single sheet taped up, facing out.
      kit.box(V(0, 0.11, 0), V(0.15, 0.21, 0.003), "paper", def.color ?? 0xd9d2bd);
      kit.box(V(0, 0.205, 0.002), V(0.05, 0.022, 0.002), "paper", 0xcfc6a0);
      break;
    case "wire":
      // The alarm loop's test link, hanging out of the junction box: pull it and the loop is open.
      for (const x of [-0.07, 0.07]) kit.box(V(x, 0.1, 0), V(0.014, 0.2, 0.014), "plastic", def.color ?? 0xb3261e);
      kit.box(V(0, 0.003, 0), V(0.154, 0.014, 0.014), "plastic", def.color ?? 0xb3261e);
      kit.box(V(0, 0.2, -0.01), V(0.2, 0.04, 0.03), "dark", 0x23282a);
      break;
    case "vial":
      kit.cylinder(V(0, 0.045, 0), 0.016, 0.09, "glass", 0xd8c4b8, upright);
      kit.cylinder(V(0, 0.097, 0), 0.018, 0.016, "plastic", def.color ?? 0xb3261e, upright);
      kit.box(V(0, 0.04, 0.0165), V(0.022, 0.03, 0.002), "paper", 0xe6e1d0);
      break;
  }
  const mesh = kit.build(`ContentProp:${def.kind}`);
  mesh.castShadow = false;
  return mesh;
}
