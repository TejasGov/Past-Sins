# Texture-ready surfaces

Named palette resources in `materials/props/` and the greybox factory's
color-cached materials use `StandardMaterial3D` with triplanar UV1. Fixed
surfaces use world-space mapping; moving gunmetal/AK wood use local mapping
(`metadata/mapping_space = "local"`) so their texture follows the weapon.
Texture density stays fixed when a wall stretches or static meshes are batched.
The factory default is 0.5 repeats per metre; named materials vary from 0.35 for
ground surfaces to 1.5 for rubber. Base colors and metallic values stay authored.

Authored PBR finishes and verified source references are listed in
`MATERIAL_REFERENCE.md`. Keep each functional finish in its own named resource.
Those authored maps take priority over procedural fallback and use VRAM compression.

Two shared text-only `NoiseTexture2D` resources generate seamless 256 × 256
fallback maps at runtime for surfaces without authored maps.
The albedo multiplier stays near white for subtle grime; an independent
red-channel roughness map adds restrained surface variation. Neither map adds
lights, geometry, transparency, or post-processing. Their shared references
avoid one noise texture per material or prop.

## Replacing fallback textures

In a named `.tres`, replace `albedo_texture` and/or `roughness_texture` with the
real tileable maps. Assign `normal_texture` and enable `normal_enabled` when a
normal map is available. Keep the UV scale or tune it to the authored texel size.
Adjust roughness texture channel if the source packs roughness in another channel.
No shader needs to be removed or rewritten: these are the regular material slots.

For procedural code use `surface_materials.gd.prepare(material, scale)` after
assigning authored maps; it never overwrites nonempty slots. Pass `false` as the
third argument to opt out of fallback noise while retaining triplanar setup.
Do not mutate a factory-cached material for a single object; duplicate it first.
Emissive surfaces retain their own clean emission color; grime affects albedo only.

Validation: run `scenes/tests/MaterialSurfaceValidation.tscn` with Godot headless.
