// Poly Haven (CC0) props used by the web port. `tris` is the target triangle
// count after simplification; repeated fixtures get the tightest budgets.
// `nodes` keeps only those root nodes, for files that pack several variants.
export const PROPS = [
  { id: "trashbag", tris: 500 },
  { id: "plastic_monobloc_chair_01", tris: 700 },
  { id: "Television_01", tris: 700 },
  { id: "standing_chalkboard_01", tris: 2372 },
  { id: "desk_lamp_arm_01", tris: 800 },
  { id: "classic_laptop", tris: 1200 },
  { id: "vintage_radio_transceiver", tris: 3000 },
  { id: "plastic_crate_02", tris: 600 },
  { id: "cardboard_box_01", tris: 300 },
  { id: "long_life_food", tris: 600 },
  { id: "russian_food_cans_01", tris: 500 },
  { id: "medical_box", tris: 1500 },
  { id: "industrial_microscope", tris: 4000 },
  { id: "bunsen_burner", tris: 2000 },
  { id: "chemistry_set", tris: 8000 },
  { id: "metal_tool_chest", tris: 3000 },
  { id: "Barrel_01", tris: 900 },
  { id: "cement_bag", tris: 844 },
  { id: "metal_toolbox", tris: 800 },
  { id: "bleach_bottle", tris: 250 },
  { id: "mounted_fluorescent_lights", tris: 250, nodes: ["mounted_fluorescent_lights_g"] },
  { id: "industrial_caged_sconce", tris: 1000, nodes: ["industrial_caged_sconce_a"] },
  { id: "street_lamp_01", tris: 2500 },
  { id: "pull_chain_light_socket", tris: 1200 },
  { id: "security_camera_01", tris: 700 },
  { id: "korean_fire_extinguisher_01", tris: 600 },
  { id: "security_camera_02", tris: 500 },
];

export const TEXTURE_SIZE = 1024;
export const SMALL_TEXTURE_SIZE = 512;
// Props under this size (metres, longest side) get the smaller texture budget.
export const SMALL_PROP_METRES = 0.45;
