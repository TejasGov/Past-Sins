extends RefCounted
## Shared, texture-ready surface setup for primitive geometry and future assets.
## Noise is generated once by two shared 256px resources; never per object/frame.

const GRIME: NoiseTexture2D = preload("res://materials/procedural/surface_grime.tres")
const ROUGHNESS: NoiseTexture2D = preload("res://materials/procedural/surface_roughness.tres")
const DEFAULT_UV_SCALE := Vector3(0.5, 0.5, 0.5)


static func prepare(material: StandardMaterial3D, scale: Vector3 = DEFAULT_UV_SCALE, procedural_grime := true) -> StandardMaterial3D:
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = scale
	# Swap these normal material slots for authored tileable textures later. Never
	# overwrite an existing texture. normal_texture is intentionally left empty;
	# enable normal_enabled when a real normal map is supplied. No baked shader.
	if procedural_grime:
		if material.albedo_texture == null:
			material.albedo_texture = GRIME
		if material.roughness_texture == null:
			material.roughness_texture = ROUGHNESS
			material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	return material
