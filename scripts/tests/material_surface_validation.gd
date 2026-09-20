extends Node

const SURFACES := preload("res://scripts/levels/surface_materials.gd")
const FACTORY := preload("res://scripts/levels/greybox_factory.gd")
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var count := 0
	for file in DirAccess.get_files_at("res://materials/props"):
		if not file.ends_with(".tres"):
			continue
		var material := load("res://materials/props/" + file) as StandardMaterial3D
		_check(material != null, file + " must load as a StandardMaterial3D")
		if material == null:
			continue
		count += 1
		var local_mapping: bool = material.get_meta("mapping_space", "world") == "local"
		_check(material.uv1_triplanar and material.uv1_world_triplanar != local_mapping, file + " requires stable triplanar mapping in its declared space")
		_check(material.uv1_scale.x > 0.0 and material.uv1_scale.y > 0.0 and material.uv1_scale.z > 0.0, file + " requires a nonzero tile scale")
		_check(material.albedo_texture != null, file + " requires an albedo texture (PBR or shared grime)")
		_check(material.roughness_texture != null, file + " requires a roughness texture")
		if material.normal_enabled:
			_check(material.normal_texture != null, file + " normal_enabled is true but normal_texture is missing")
	_check(count >= 17, "Validate the entire named palette, not only concrete")

	var first_root := Node3D.new()
	var second_root := Node3D.new()
	add_child(first_root)
	add_child(second_root)
	var first := FACTORY.new(first_root)
	var second := FACTORY.new(second_root)
	var color := Color("65726a")
	var material: StandardMaterial3D = first.call("_material", color)
	_check(material == second.call("_material", color), "Factories should share cached materials to preserve batching")
	_check(material.albedo_texture == SURFACES.GRIME and material.roughness_texture == SURFACES.ROUGHNESS, "Ad-hoc geometry must use the same surface setup")
	var luminous: StandardMaterial3D = first.call("_emissive_material", color, 0.85)
	_check(luminous.uv1_triplanar and luminous.emission_enabled, "Emissive surfaces must be texture-ready without losing emission")
	_check(luminous.albedo_texture == SURFACES.GRIME, "Emissive surface grime should not need a special shader")

	# Authored textures are drop-in replacements, not overwritten on setup.
	var custom := StandardMaterial3D.new()
	var replacement := GradientTexture2D.new()
	custom.albedo_texture = replacement
	custom.roughness_texture = replacement
	SURFACES.prepare(custom)
	_check(custom.albedo_texture == replacement and custom.roughness_texture == replacement, "Do not replace authored textures with fallback noise")
	var clean := StandardMaterial3D.new()
	SURFACES.prepare(clean, SURFACES.DEFAULT_UV_SCALE, false)
	_check(clean.albedo_texture == null and clean.roughness_texture == null, "Procedural fallback must be optional")

	# Runtime-generated source resources, never imported/binary texture assets.
	for texture in [SURFACES.GRIME, SURFACES.ROUGHNESS]:
		_check(texture.width == 256 and texture.height == 256 and texture.seamless, "Noise textures must stay small and tileable")
		_check(texture.noise is FastNoiseLite, "Noise source must remain procedural")
		for attempt in range(600):
			if texture.get_image() != null:
				break
			await get_tree().process_frame
		var image: Image = texture.get_image()
		_check(image != null, "Runtime noise generation should complete")
		if image == null:
			continue
		var low := 1.0
		var high := 0.0
		for x in range(0, 256, 8):
			for y in range(0, 256, 8):
				var value: float = image.get_pixel(x, y).r
				low = minf(low, value)
				high = maxf(high, value)
		_check(low >= 0.75 and high <= 1.0 and high - low > 0.02, "Variation must remain subtle but non-flat")

	if _failures.is_empty():
		print("MATERIAL_SURFACE_VALIDATION_OK palette=%d shared_noise_textures=2 resolution=256" % count)
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
