# Shared PSX humanoid source

- Mesh/UV/rig: **Characters PSX 1.1** by Elbolilloduro (CC0), downloaded from
  https://elbolilloduro.itch.io/characters-psx on 2026-09-19.
- Selected source: `Models/Rig/Male/Character_21_Police.fbx` from
  `Characters_psx_1.1.zip` (itch upload 18893245).
- Project import: `operator_base.fbx`; its zeroed foot origin is retained and
  its source +X forward / +Z up basis is corrected once by
  `ModularCharacter.SOURCE_TO_GODOT_BASIS` to Godot -Z forward / +Y up.
- Original UV repaint: `Character_21_Police.png`, authored for this project on
  the unchanged 512x512 source atlas. Palette: charcoal-green balaclava,
  near-black torso, gray-green vest blocks, blue-gray trousers, black boots,
  muted skin, and subtle grime. It is not the pack's tactical texture.
- Locomotion: Adobe Mixamo idle, walk, run, crouch-idle and sneak clips from
  the Godot-oriented source project
  https://github.com/aaronsnoswell/3DCharacter. Only skeleton/animation data
  is extracted into `res://scenes/characters/MixamoLocomotionRig.tscn`; that
  project's mesh and texture are not shipped or rendered.
- Generator: `res://tools/build_mixamo_locomotion_rig.gd` strips root motion,
  discards the source mesh, and writes one shared animation scene.

Guard and inmate appearances share this mesh, UV texture, skeleton, shader,
and animation data. Factions differ only through cached shader palette values.
