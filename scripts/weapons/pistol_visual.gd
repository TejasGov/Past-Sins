extends Node3D
class_name PistolVisual

## Lightweight primitive visual shared by the held and world pickup variants.
## It has no collision and no firearm logic.
@export var first_person := false

const SLIDE_LOCK_OFFSET := Vector3(0, 0, 0.13)

var _reload_pivot: Node3D
var _kick_pivot: Node3D
var _slide_pivot: Node3D
var _magazine: Node3D
var _muzzle_flash: MeshInstance3D
var _kick_tween: Tween
var _slide_tween: Tween
var _flash_tween: Tween
var _reload_tween: Tween
var _magazine_home_position := Vector3.ZERO
var _magazine_home_rotation := Vector3.ZERO
var _reload_playing := false


func _ready() -> void:
	_build_visual()


func play_fire_feedback(rounds_remaining: int) -> void:
	if not first_person or _kick_pivot == null:
		return
	if _kick_tween and _kick_tween.is_valid():
		_kick_tween.kill()
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_kick_pivot.position = Vector3.ZERO
	_kick_pivot.rotation_degrees = Vector3.ZERO
	_muzzle_flash.visible = true
	_muzzle_flash.scale = Vector3.ONE * randf_range(0.85, 1.15)
	_slide_pivot.position = SLIDE_LOCK_OFFSET
	_kick_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_kick_tween.tween_property(_kick_pivot, "position", Vector3(0, 0.018, 0.045), 0.035)
	_kick_tween.parallel().tween_property(_kick_pivot, "rotation_degrees", Vector3(3.5, 0, 0), 0.035)
	_kick_tween.tween_property(_kick_pivot, "position", Vector3.ZERO, 0.12)
	_kick_tween.parallel().tween_property(_kick_pivot, "rotation_degrees", Vector3.ZERO, 0.12)
	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.035)
	_flash_tween.tween_callback(func() -> void: _muzzle_flash.visible = false)
	if rounds_remaining > 0:
		_slide_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_slide_tween.tween_property(_slide_pivot, "position", Vector3.ZERO, 0.075)


func set_slide_locked(locked: bool) -> void:
	if _slide_pivot == null:
		return
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_pivot.position = SLIDE_LOCK_OFFSET if locked else Vector3.ZERO


func play_reload(duration: float, was_empty: bool) -> void:
	if not first_person or _reload_pivot == null or duration <= 0.0:
		return
	cancel_weapon_animation()
	set_slide_locked(was_empty)
	_reload_playing = true
	var scale_time := duration / 1.5
	var magazine_out := _magazine_home_position + Vector3(0, -0.38, 0.06)
	_reload_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_reload_tween.tween_property(_reload_pivot, "position", Vector3(0.08, -0.18, 0.08), 0.2 * scale_time)
	_reload_tween.parallel().tween_property(_reload_pivot, "rotation_degrees", Vector3(10, 0, -14), 0.2 * scale_time)
	_reload_tween.tween_property(_magazine, "position", magazine_out, 0.25 * scale_time)
	_reload_tween.parallel().tween_property(_magazine, "rotation_degrees", _magazine_home_rotation + Vector3(8, 0, 5), 0.25 * scale_time)
	_reload_tween.tween_callback(func() -> void: _magazine.visible = false)
	_reload_tween.tween_interval(0.1 * scale_time)
	_reload_tween.tween_callback(func() -> void:
		_magazine.position = magazine_out
		_magazine.rotation_degrees = _magazine_home_rotation
		_magazine.visible = true
	)
	_reload_tween.tween_property(_magazine, "position", _magazine_home_position, 0.3 * scale_time)
	_reload_tween.tween_interval(0.15 * scale_time)
	if was_empty:
		_reload_tween.tween_callback(func() -> void: set_slide_locked(false))
	_reload_tween.tween_property(_reload_pivot, "position", Vector3.ZERO, 0.5 * scale_time)
	_reload_tween.parallel().tween_property(_reload_pivot, "rotation_degrees", Vector3.ZERO, 0.5 * scale_time)
	_reload_tween.tween_callback(func() -> void: _reload_playing = false)


func finish_reload(rounds_loaded: int) -> void:
	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()
	_reload_playing = false
	_reset_reload_pose()
	set_slide_locked(rounds_loaded <= 0)


func cancel_weapon_animation() -> void:
	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()
	_reload_playing = false
	_reset_reload_pose()
	if _kick_tween and _kick_tween.is_valid():
		_kick_tween.kill()
	if _kick_pivot:
		_kick_pivot.position = Vector3.ZERO
		_kick_pivot.rotation_degrees = Vector3.ZERO
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	if _muzzle_flash:
		_muzzle_flash.visible = false


func is_slide_locked() -> bool:
	return _slide_pivot != null and _slide_pivot.position.distance_to(SLIDE_LOCK_OFFSET) < 0.001


func is_reload_playing() -> bool:
	return _reload_playing


func is_magazine_visible() -> bool:
	return _magazine != null and _magazine.visible


func is_muzzle_flash_visible() -> bool:
	return _muzzle_flash != null and _muzzle_flash.visible


func get_slide_offset() -> float:
	return _slide_pivot.position.z if _slide_pivot else 0.0


func get_magazine_offset() -> float:
	return _magazine.position.distance_to(_magazine_home_position) if _magazine else 0.0


func _reset_reload_pose() -> void:
	if _reload_pivot:
		_reload_pivot.position = Vector3.ZERO
		_reload_pivot.rotation_degrees = Vector3.ZERO
	if _magazine:
		_magazine.visible = true
		_magazine.position = _magazine_home_position
		_magazine.rotation_degrees = _magazine_home_rotation


func _build_visual() -> void:
	_reload_pivot = Node3D.new()
	_reload_pivot.name = "ReloadPivot"
	add_child(_reload_pivot)
	_kick_pivot = Node3D.new()
	_kick_pivot.name = "KickPivot"
	_reload_pivot.add_child(_kick_pivot)
	_slide_pivot = Node3D.new()
	_slide_pivot.name = "SlidePivot"
	_kick_pivot.add_child(_slide_pivot)
	var near_black := _material(Color("15191b"), 0.5)
	var slide := _material(Color("343b3f"), 0.3)
	var slide_edge := _material(Color("4c5559"), 0.26)
	var polymer := _material(Color("242a2c"), 0.88)
	var grip_panel := _material(Color("1b2021"), 0.96)
	var steel := _material(Color("727a7d"), 0.24)
	var sight_insert := _material(Color("d9e6df"), 0.45)

	# The slide is a single low-poly chamfered extrusion rather than a plain box.
	# Thin rails and a tapered nose give it a recognizable service-pistol profile.
	_add_chamfered_box("Slide", Vector3(0, 0.125, -0.30), 0.22, 0.16, 0.66, 0.035, slide, _slide_pivot)
	_add_box("SlideLowerRail", Vector3(0, 0.055, -0.27), Vector3(0.19, 0.035, 0.55), slide_edge, Vector3.ZERO, _slide_pivot)
	_add_box("SlideNose", Vector3(0, 0.12, -0.635), Vector3(0.19, 0.13, 0.045), slide_edge, Vector3.ZERO, _slide_pivot)
	_add_box("EjectionPortTop", Vector3(0.035, 0.211, -0.235), Vector3(0.115, 0.012, 0.16), near_black, Vector3.ZERO, _slide_pivot)
	_add_box("Extractor", Vector3(0.111, 0.14, -0.20), Vector3(0.012, 0.035, 0.12), steel, Vector3.ZERO, _slide_pivot)
	for index in range(5):
		var serration_z := -0.015 - index * 0.027
		_add_box("LeftSerration%d" % index, Vector3(-0.112, 0.135, serration_z), Vector3(0.009, 0.105, 0.011), near_black, Vector3(0, 0, -7), _slide_pivot)
		_add_box("RightSerration%d" % index, Vector3(0.112, 0.135, serration_z), Vector3(0.009, 0.105, 0.011), near_black, Vector3(0, 0, 7), _slide_pivot)

	# Real sight notch and a contrasting front insert preserve the tuned ADS line.
	_add_box("RearSightLeft", Vector3(-0.066, 0.23, -0.015), Vector3(0.048, 0.06, 0.065), near_black, Vector3.ZERO, _slide_pivot)
	_add_box("RearSightRight", Vector3(0.066, 0.23, -0.015), Vector3(0.048, 0.06, 0.065), near_black, Vector3.ZERO, _slide_pivot)
	_add_box("FrontSight", Vector3(0, 0.23, -0.54), Vector3(0.045, 0.06, 0.055), near_black, Vector3.ZERO, _slide_pivot)
	_add_box("FrontSightInsert", Vector3(0, 0.262, -0.545), Vector3(0.016, 0.016, 0.058), sight_insert, Vector3.ZERO, _slide_pivot)

	# The polymer frame, dust cover, beavertail and tapered grip establish the
	# handgun's lower silhouette. Raised side panels avoid a featureless slab.
	_add_box("FrameChassis", Vector3(0, 0.008, -0.255), Vector3(0.195, 0.09, 0.47), polymer)
	_add_box("DustCover", Vector3(0, -0.032, -0.445), Vector3(0.18, 0.075, 0.25), polymer)
	_add_box("Beavertail", Vector3(0, 0.005, 0.035), Vector3(0.205, 0.07, 0.115), polymer)
	_add_tapered_grip("Grip", -0.02, -0.49, 0.20, 0.165, -0.015, 0.09, 0.235, 0.18, polymer)
	_add_box("LeftGripPanel", Vector3(-0.102, -0.275, 0.035), Vector3(0.012, 0.31, 0.145), grip_panel, Vector3(12, 0, 0))
	_add_box("RightGripPanel", Vector3(0.102, -0.275, 0.035), Vector3(0.012, 0.31, 0.145), grip_panel, Vector3(12, 0, 0))
	for index in range(4):
		var panel_y := -0.18 - index * 0.07
		_add_box("LeftGripRib%d" % index, Vector3(-0.11, panel_y, 0.045 + index * 0.016), Vector3(0.009, 0.018, 0.13), slide_edge, Vector3(12, 0, 0))
		_add_box("RightGripRib%d" % index, Vector3(0.11, panel_y, 0.045 + index * 0.016), Vector3(0.009, 0.018, 0.13), slide_edge, Vector3(12, 0, 0))

	# A slim, open trigger guard reads more naturally than the previous solid
	# blocks while keeping the trigger clearly visible from the side.
	_add_box("TriggerGuardLeft", Vector3(-0.086, -0.09, -0.255), Vector3(0.022, 0.025, 0.22), polymer, Vector3(-9, 0, 0))
	_add_box("TriggerGuardRight", Vector3(0.086, -0.09, -0.255), Vector3(0.022, 0.025, 0.22), polymer, Vector3(-9, 0, 0))
	_add_box("TriggerGuardBow", Vector3(0, -0.145, -0.365), Vector3(0.175, 0.03, 0.035), polymer, Vector3(-12, 0, 0))
	_add_box("Trigger", Vector3(0, -0.075, -0.245), Vector3(0.026, 0.105, 0.025), steel, Vector3(-20, 0, 0))
	_add_box("SlideStop", Vector3(-0.106, 0.025, -0.085), Vector3(0.018, 0.035, 0.09), steel)
	_add_cylinder("TakedownPin", Vector3(-0.11, -0.005, -0.25), 0.022, 0.018, steel, Vector3(0, 0, 90))
	_add_cylinder("MagazineRelease", Vector3(-0.108, -0.065, -0.035), 0.024, 0.016, near_black, Vector3(0, 0, 90))

	# Magazine is its own animated assembly so the body and floor plate travel
	# together during the procedural reload.
	_magazine = Node3D.new()
	_magazine.name = "Magazine"
	_magazine.position = Vector3(0, -0.27, 0.045)
	_magazine.rotation_degrees = Vector3(12, 0, 0)
	_kick_pivot.add_child(_magazine)
	_add_box("MagazineBody", Vector3.ZERO, Vector3(0.135, 0.31, 0.13), steel, Vector3.ZERO, _magazine)
	_add_box("MagazineBasePlate", Vector3(0, -0.17, 0.005), Vector3(0.18, 0.035, 0.17), near_black, Vector3.ZERO, _magazine)
	_magazine_home_position = _magazine.position
	_magazine_home_rotation = _magazine.rotation_degrees

	# Barrel, dark bore and guide rod give the muzzle a readable mechanical face.
	_add_cylinder("Barrel", Vector3(0, 0.125, -0.675), 0.058, 0.08, steel, Vector3(90, 0, 0))
	_add_cylinder("Bore", Vector3(0, 0.125, -0.718), 0.037, 0.012, near_black, Vector3(90, 0, 0))
	_add_cylinder("GuideRod", Vector3(0, 0.045, -0.674), 0.025, 0.075, near_black, Vector3(90, 0, 0))
	var flash_material := _material(Color("fff1a0"), 0.1, true)
	_muzzle_flash = _add_cylinder("MuzzleFlash", Vector3(0, 0.125, -0.785), 0.075, 0.12, flash_material, Vector3(90, 0, 0))
	_muzzle_flash.visible = false
	if first_person:
		var skin := _material(Color("8a6b58"), 0.92)
		var sleeve := _material(Color("263238"), 0.94)
		_add_capsule("Hand", Vector3(0.015, -0.31, 0.09), 0.105, 0.32, skin, Vector3(12, 0, 0))
		_add_tapered_cylinder("Sleeve", Vector3(0.035, -0.49, 0.39), 0.12, 0.17, 0.68, sleeve, Vector3(-68, 0, 0))
		_add_cylinder("Cuff", Vector3(0.025, -0.335, 0.075), 0.13, 0.09, sleeve, Vector3(-68, 0, 0))
		for index in range(3):
			_add_box("Finger%d" % index, Vector3(0.115, -0.20 - index * 0.072, -0.015 + index * 0.015), Vector3(0.055, 0.055, 0.16), skin, Vector3(10, 0, 0))


func _add_chamfered_box(piece_name: String, position: Vector3, width: float, height: float, length: float, chamfer: float, material: Material, parent: Node3D) -> MeshInstance3D:
	var half_width := width * 0.5
	var half_height := height * 0.5
	var bevel := minf(chamfer, minf(half_width, half_height) * 0.8)
	var profile := PackedVector2Array([
		Vector2(-half_width, -half_height),
		Vector2(half_width, -half_height),
		Vector2(half_width, half_height - bevel),
		Vector2(half_width - bevel, half_height),
		Vector2(-half_width + bevel, half_height),
		Vector2(-half_width, half_height - bevel),
	])
	return _add_generated_mesh(piece_name, position, _make_extruded_profile(profile, length), material, parent)


func _add_tapered_grip(piece_name: String, top_y: float, bottom_y: float, top_width: float, bottom_width: float, top_center_z: float, bottom_center_z: float, top_depth: float, bottom_depth: float, material: Material) -> MeshInstance3D:
	var vertices := PackedVector3Array([
		Vector3(-top_width * 0.5, top_y, top_center_z + top_depth * 0.5),
		Vector3(top_width * 0.5, top_y, top_center_z + top_depth * 0.5),
		Vector3(top_width * 0.5, top_y, top_center_z - top_depth * 0.5),
		Vector3(-top_width * 0.5, top_y, top_center_z - top_depth * 0.5),
		Vector3(-bottom_width * 0.5, bottom_y, bottom_center_z + bottom_depth * 0.5),
		Vector3(bottom_width * 0.5, bottom_y, bottom_center_z + bottom_depth * 0.5),
		Vector3(bottom_width * 0.5, bottom_y, bottom_center_z - bottom_depth * 0.5),
		Vector3(-bottom_width * 0.5, bottom_y, bottom_center_z - bottom_depth * 0.5),
	])
	var triangles := PackedInt32Array([
		0, 1, 2, 0, 2, 3,
		4, 7, 6, 4, 6, 5,
		0, 4, 5, 0, 5, 1,
		3, 2, 6, 3, 6, 7,
		0, 3, 7, 0, 7, 4,
		1, 5, 6, 1, 6, 2,
	])
	return _add_generated_mesh(piece_name, Vector3.ZERO, _make_triangle_mesh(vertices, triangles), material, _kick_pivot)


func _make_extruded_profile(profile: PackedVector2Array, length: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rear_z := length * 0.5
	var front_z := -rear_z
	for index in range(1, profile.size() - 1):
		_add_surface_triangle(surface,
			Vector3(profile[0].x, profile[0].y, rear_z),
			Vector3(profile[index].x, profile[index].y, rear_z),
			Vector3(profile[index + 1].x, profile[index + 1].y, rear_z))
		_add_surface_triangle(surface,
			Vector3(profile[0].x, profile[0].y, front_z),
			Vector3(profile[index + 1].x, profile[index + 1].y, front_z),
			Vector3(profile[index].x, profile[index].y, front_z))
	for index in range(profile.size()):
		var next := (index + 1) % profile.size()
		var rear_a := Vector3(profile[index].x, profile[index].y, rear_z)
		var front_a := Vector3(profile[index].x, profile[index].y, front_z)
		var front_b := Vector3(profile[next].x, profile[next].y, front_z)
		var rear_b := Vector3(profile[next].x, profile[next].y, rear_z)
		_add_surface_triangle(surface, rear_a, front_a, front_b)
		_add_surface_triangle(surface, rear_a, front_b, rear_b)
	surface.generate_normals()
	return surface.commit()


func _make_triangle_mesh(vertices: PackedVector3Array, triangles: PackedInt32Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in triangles:
		surface.add_vertex(vertices[index])
	surface.generate_normals()
	return surface.commit()


func _add_surface_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


func _add_generated_mesh(piece_name: String, position: Vector3, mesh: Mesh, material: Material, parent: Node3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = piece_name
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_box(piece_name: String, position: Vector3, size: Vector3, material: Material, rotation := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = piece_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else _kick_pivot).add_child(mesh_instance)
	return mesh_instance


func _add_cylinder(piece_name: String, position: Vector3, radius: float, height: float, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = piece_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_kick_pivot.add_child(mesh_instance)
	return mesh_instance


func _add_tapered_cylinder(piece_name: String, position: Vector3, top_radius: float, bottom_radius: float, height: float, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = piece_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_kick_pivot.add_child(mesh_instance)
	return mesh_instance


func _add_capsule(piece_name: String, position: Vector3, radius: float, height: float, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = piece_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 3
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_kick_pivot.add_child(mesh_instance)
	return mesh_instance


func _material(color: Color, roughness: float, emissive := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 3.0
	return material
