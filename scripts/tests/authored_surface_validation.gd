extends Node3D

## Opt-in asset/integration audit; never part of normal gameplay.
const SOURCES := {
	"tile_shower": "Tiles133A", "gym_rubber": "Rubber004",
	"court_concrete": "Concrete048", "gunmetal": "Metal032",
	"wood_furniture": "Wood059", "wood_ak_furniture": "Wood030",
}
var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_validate")

func _validate() -> void:
	for finish in SOURCES:
		var material := load("res://materials/props/%s.tres" % finish) as StandardMaterial3D
		_check(material != null, finish + " must be independently loadable")
		if material == null: continue
		_check(material.get_meta("ambientcg_asset_id", "") == SOURCES[finish], finish + " source must be recorded")
		var moving: bool = finish in ["gunmetal", "wood_ak_furniture"]
		_check(material.uv1_triplanar and material.uv1_world_triplanar != moving, finish + " mapping must match fixed/moving use")
		_validate_map(finish, "albedo", material.albedo_texture)
		_validate_map(finish, "normal", material.normal_texture)
		_validate_map(finish, "roughness", material.roughness_texture)
		_check(material.normal_enabled, finish + " must use its GL normal")
		if finish == "gunmetal":
			_validate_map(finish, "metalness", material.metallic_texture)
			_check(material.metallic > 0.0, "Gunmetal must remain metallic")
	_check(FileAccess.get_sha256("res://textures/court_concrete/court_concrete_albedo.jpg") != FileAccess.get_sha256("res://textures/concrete/concrete_albedo.jpg"), "Court concrete must not duplicate generic concrete")
	_check(FileAccess.get_sha256("res://textures/wood_furniture/wood_furniture_albedo.jpg") != FileAccess.get_sha256("res://textures/wood_ak_furniture/wood_ak_furniture_albedo.jpg"), "Furniture and AK wood must be distinct sets")
	_validate_factory()
	await _validate_firearms()
	await _validate_campus()
	if _failures.is_empty():
		print("AUTHORED_SURFACE_VALIDATION_OK sets=6 maps=19 resolution=1K compression=VRAM campus_and_firearms=verified")
	else:
		for failure in _failures: push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)

func _validate_map(finish: String, role: String, texture: Texture2D) -> void:
	var path := "res://textures/%s/%s_%s.jpg" % [finish, finish, role]
	_check(texture is CompressedTexture2D and texture.resource_path == path, path + " must use the named imported map")
	if texture == null: return
	_check(texture.get_width() == 1024 and texture.get_height() == 1024, path + " must stay 1K")
	var config := ConfigFile.new()
	_check(config.load(path + ".import") == OK, path + " importer config must exist")
	_check(config.get_value("params", "compress/mode", -1) == 2, path + " requires VRAM compression")
	_check(config.get_value("params", "mipmaps/generate", false), path + " requires mipmaps")
	if role == "normal":
		_check(config.get_value("params", "compress/normal_map", -1) == 1, path + " requires normal compression")
		_check(not config.get_value("params", "process/normal_map_invert_y", true), path + " must preserve OpenGL orientation")

func _validate_factory() -> void:
	var root := Node3D.new()
	add_child(root)
	var g = preload("res://scripts/levels/greybox_factory.gd").new(root)
	var wood := preload("res://materials/props/wood_furniture.tres")
	var top: MeshInstance3D = g.box("ExplicitWood", Vector3(0, 1, 0), Vector3(2, 0.1, 1), Color.WHITE, true, wood)
	var support: MeshInstance3D = g.cylinder("ExplicitSupport", Vector3(0, 0.5, 0), 0.1, 1.0, Color.WHITE, true, Vector3.ZERO, wood)
	_check(top.material_override == wood and support.material_override == wood, "Factory explicit surface slots must preserve resources")
	_check(root.get_node("Collision").get_child_count() == 2, "Surface assignment must preserve furniture collision")
	root.queue_free()

func _validate_firearms() -> void:
	var gunmetal := preload("res://materials/props/gunmetal.tres")
	var ak_wood := preload("res://materials/props/wood_ak_furniture.tres")
	for id in ["pistol", "smg", "carbine_ar", "sniper_rifle"]:
		var definition := load("res://resources/weapons/%s.tres" % id) as FirearmDefinition
		for scene in [definition.first_person_visual_scene, definition.world_visual_scene]:
			var visual: Node = scene.instantiate()
			add_child(visual)
			await get_tree().process_frame
			_check(_uses_albedo(visual, gunmetal.albedo_texture), id + " must use gunmetal in FP and world visuals")
			if id == "carbine_ar":
				_check(_uses_albedo(visual, ak_wood.albedo_texture), "Carbine must use its distinct varnished wood")
			visual.queue_free()
			await get_tree().process_frame

func _validate_campus() -> void:
	var campus := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn").instantiate()
	campus.gameplay_enabled = false
	add_child(campus)
	for frame in range(4): await get_tree().process_frame
	var found_gym := false
	var found_showers := false
	var found_toilets := false
	for floor_root in get_tree().get_nodes_in_group("campus_blueprint_floors"):
		if not campus.is_ancestor_of(floor_root): continue
		if String(floor_root.plan_id) != "medical-ground": continue
		found_gym = _uses_albedo(floor_root, preload("res://materials/props/gym_rubber.tres").albedo_texture)
		for room_data in floor_root.plan.rooms:
			if room_data.id == "showers": found_showers = room_data.get("floor_finish", "") == "tile_shower"
			if room_data.id == "toilets": found_toilets = room_data.get("floor_finish", "") == "tile_shower"
		_check(_uses_albedo(floor_root.get_node("Architecture"), preload("res://materials/props/tile_shower.tres").albedo_texture), "Wet-room slabs must use ceramic tile even after batching")
	_check(found_gym and found_showers and found_toilets, "Existing medical/wellness rooms must retain their gym/shower/toilet plan and finishes")
	var yard := campus.get_node("CampusShell/CentralYard")
	_check(_uses_albedo(yard, preload("res://materials/props/court_concrete.tres").albedo_texture), "Campus basketball slab must use the new concrete")
	var cells := 0
	for cell in get_tree().get_nodes_in_group("campus_cells"):
		if not campus.is_ancestor_of(cell): continue
		cells += 1
		_check(_uses_albedo(cell, preload("res://materials/props/wood_furniture.tres").albedo_texture), "Reusable cells must use worn furniture wood")
	_check(cells > 0, "Audit must inspect actual playable cells")
	campus.queue_free()
	await get_tree().process_frame

func _uses_albedo(root: Node, texture: Texture2D) -> bool:
	if root is MeshInstance3D:
		var visual := root as MeshInstance3D
		if _matches(visual.material_override, texture): return true
		if visual.mesh != null:
			for surface in range(visual.mesh.get_surface_count()):
				if _matches(visual.get_active_material(surface), texture): return true
	for child in root.get_children():
		if _uses_albedo(child, texture): return true
	return false

func _matches(material: Material, texture: Texture2D) -> bool:
	return material is StandardMaterial3D and material.albedo_texture == texture

func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
