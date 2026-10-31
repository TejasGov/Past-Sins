import { BufferGeometry, Float32BufferAttribute, type Material, Mesh, MeshStandardMaterial, Vector3 } from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { MeshoptDecoder } from "three/addons/libs/meshopt_decoder.module.js";

/** Poly Haven props built by web/asset-pipeline/scripts/build-props.mjs. */
export type PropId =
  | "trashbag" | "plastic_monobloc_chair_01" | "Television_01" | "standing_chalkboard_01" | "desk_lamp_arm_01"
  | "classic_laptop" | "vintage_radio_transceiver" | "plastic_crate_02" | "cardboard_box_01" | "long_life_food"
  | "russian_food_cans_01" | "medical_box" | "industrial_microscope" | "bunsen_burner" | "chemistry_set"
  | "metal_tool_chest" | "Barrel_01" | "cement_bag" | "metal_toolbox" | "bleach_bottle" | "mounted_fluorescent_lights"
  | "industrial_caged_sconce" | "street_lamp_01" | "pull_chain_light_socket" | "security_camera_01"
  | "korean_fire_extinguisher_01" | "security_camera_02";

export interface PropPart {
  geometry: BufferGeometry;
  material: MeshStandardMaterial;
  /** A separate glowing part (tube, lamp glass) that the game's diffuser can replace outright. */
  glowPart: boolean;
}

interface ManifestEntry {
  file: string;
  size: [number, number, number];
  tris: number;
}

const BASE = `${import.meta.env.BASE_URL}assets/props/`;

/**
 * A float copy of a meshopt/KHR_mesh_quantization geometry. Its attributes are
 * normalized integers that the node transform scales back up, so baking that
 * transform in without converting first would clamp every vertex to ±1.
 */
function dequantized(source: BufferGeometry): BufferGeometry {
  const geometry = new BufferGeometry();
  geometry.setIndex(source.index ? source.index.clone() : null);
  for (const [name, attr] of Object.entries(source.attributes)) {
    const out = new Float32Array(attr.count * attr.itemSize);
    for (let i = 0; i < attr.count; i++) for (let c = 0; c < attr.itemSize; c++) out[i * attr.itemSize + c] = attr.getComponent(i, c);
    geometry.setAttribute(name, new Float32BufferAttribute(out, attr.itemSize));
  }
  for (const group of source.groups) geometry.addGroup(group.start, group.count, group.materialIndex);
  return geometry;
}

/**
 * Every prop model, loaded once before the campus is built. Each model is
 * baked to geometry in its own frame (origin at floor contact, facing +Z) so
 * the builder can instance it.
 */
export class PropLibrary {
  private parts = new Map<PropId, PropPart[]>();
  private sizes = new Map<PropId, Vector3>();

  static async load(prepare: (m: Material) => void): Promise<PropLibrary> {
    const lib = new PropLibrary();
    const manifest = (await (await fetch(`${BASE}manifest.json`)).json()) as { props: Record<PropId, ManifestEntry> };
    const loader = new GLTFLoader().setMeshoptDecoder(MeshoptDecoder);
    await Promise.all(
      (Object.entries(manifest.props) as [PropId, ManifestEntry][]).map(async ([id, entry]) => {
        const gltf = await loader.loadAsync(`${BASE}${entry.file}`);
        gltf.scene.updateMatrixWorld(true);
        const meshes: Mesh[] = [];
        gltf.scene.traverse((o) => {
          if ((o as Mesh).isMesh) meshes.push(o as Mesh);
        });
        const parts = meshes.map((mesh): PropPart => {
          const material = mesh.material as MeshStandardMaterial;
          prepare(material);
          const glows = !!material.emissiveMap || material.emissive.getHex() !== 0 || /glass|lens|bulb/i.test(material.name);
          return {
            geometry: dequantized(mesh.geometry).applyMatrix4(mesh.matrixWorld),
            material,
            glowPart: glows && meshes.length > 1,
          };
        });
        lib.parts.set(id, parts);
        lib.sizes.set(id, new Vector3(...entry.size));
      }),
    );
    return lib;
  }

  /** Metallic prop materials get the same room reflections as the game's own metals. */
  applyReflections(reflect: (m: MeshStandardMaterial) => void): void {
    for (const parts of this.parts.values())
      for (const p of parts) if (p.material.metalness > 0.05 || p.material.metalnessMap) reflect(p.material);
  }

  get(id: PropId): PropPart[] {
    const parts = this.parts.get(id);
    if (!parts) throw new Error(`Prop model "${id}" is not in assets/props/manifest.json`);
    return parts;
  }

  /** Model-space bounding size in metres (x width, y height, z depth). */
  size(id: PropId): Vector3 {
    return this.sizes.get(id)!;
  }
}
