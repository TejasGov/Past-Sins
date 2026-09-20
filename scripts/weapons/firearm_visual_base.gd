extends Node3D
class_name FirearmVisualBase

const FirstPersonBodyStyle := preload("res://scripts/weapons/first_person_body_style.gd")
const GUNMETAL := preload("res://materials/props/gunmetal.tres")
const AK_WOOD := preload("res://materials/props/wood_ak_furniture.tres")

## Shared presentation contract for every firearm visual.
## Weapon scripts build only their model and weapon-specific animations. Runtime
## systems use this typed API and the standardized anchors below.

const FIRST_PERSON_ANCHORS := [
	"ADSAnchor",
	"RearSightAimPoint",
	"FrontSightAimPoint",
	"HipAnchor",
	"MuzzlePoint",
	"MuzzleFlashPoint",
	"MagazineSocket",
	"SuppressorAttachmentPoint",
]
const WORLD_ANCHORS := [
	"InteractionAnchor",
	"MuzzlePoint",
	"MagazineSocket",
	"SuppressorAttachmentPoint",
]

@export var first_person := false

var _suppressor_visual: Node3D
var _muzzle_flash_multiplier := 1.0
var _muzzle_flash_home := Vector3.ZERO
var _has_muzzle_flash_home := false


func get_visual_anchor(anchor_name: StringName) -> Marker3D:
	return find_child(String(anchor_name), true, false) as Marker3D


func has_visual_anchor(anchor_name: StringName) -> bool:
	return get_visual_anchor(anchor_name) != null


func validate_visual_contract() -> PackedStringArray:
	var failures := PackedStringArray()
	var required := FIRST_PERSON_ANCHORS if first_person else WORLD_ANCHORS
	for anchor_name in required:
		if not has_visual_anchor(anchor_name):
			failures.append("Missing required firearm visual anchor: %s" % anchor_name)
	return failures


func get_sight_alignment_pixels(camera: Camera3D) -> Dictionary:
	if camera == null:
		return {}
	var ads_anchor := get_visual_anchor(&"ADSAnchor")
	var rear_sight := get_visual_anchor(&"RearSightAimPoint")
	var front_sight := get_visual_anchor(&"FrontSightAimPoint")
	if ads_anchor == null or rear_sight == null or front_sight == null:
		return {}
	var screen_center := camera.get_viewport().get_visible_rect().size * 0.5
	var ads_screen := camera.unproject_position(ads_anchor.global_position)
	var rear_screen := camera.unproject_position(rear_sight.global_position)
	var front_screen := camera.unproject_position(front_sight.global_position)
	return {
		"screen_center": screen_center,
		"ads_anchor": ads_screen,
		"rear_sight": rear_screen,
		"front_sight": front_screen,
		"ads_error": ads_screen.distance_to(screen_center),
		"rear_error": rear_screen.distance_to(screen_center),
		"front_error": front_screen.distance_to(screen_center),
		"sight_separation": rear_screen.distance_to(front_screen),
	}


# Presentation callbacks. Weapon visuals override only what they support.
func play_fire_feedback(_rounds_remaining: int) -> void:
	pass


func set_slide_locked(_locked: bool) -> void:
	pass


func play_reload(_duration: float, _was_empty: bool) -> void:
	pass


func play_individual_round_load(_duration: float) -> void:
	pass


func set_ads_blend(_blend: float) -> void:
	pass


func finish_reload(_rounds_loaded: int) -> void:
	pass


func cancel_weapon_animation() -> void:
	pass


func set_suppressor_visual(suppressor: SuppressorDefinition, weapon_id: StringName) -> bool:
	clear_suppressor_visual()
	if suppressor == null or not suppressor.is_valid_suppressor() or not suppressor.supports_weapon(weapon_id):
		return false
	var socket := get_visual_anchor(&"SuppressorAttachmentPoint")
	if socket == null:
		return false
	_suppressor_visual = suppressor.attachment_visual_scene.instantiate() as Node3D
	_suppressor_visual.name = "Attached%s" % suppressor.display_name.to_pascal_case()
	socket.add_child(_suppressor_visual)
	if weapon_id == &"sniper_rifle":
		_suppressor_visual.scale.z = 1.18
	_muzzle_flash_multiplier = suppressor.muzzle_flash_multiplier
	_move_muzzle_flash_to_tip(suppressor.visual_length * (1.18 if weapon_id == &"sniper_rifle" else 1.0))
	return true


func clear_suppressor_visual() -> void:
	if _suppressor_visual:
		_suppressor_visual.queue_free()
		_suppressor_visual = null
	_muzzle_flash_multiplier = 1.0
	var flash := find_child("MuzzleFlash", true, false) as MeshInstance3D
	if flash and _has_muzzle_flash_home:
		flash.position = _muzzle_flash_home


func has_suppressor_visual() -> bool:
	return is_instance_valid(_suppressor_visual)


func get_muzzle_flash_multiplier() -> float:
	return _muzzle_flash_multiplier


func _move_muzzle_flash_to_tip(length: float) -> void:
	var flash := find_child("MuzzleFlash", true, false) as MeshInstance3D
	var socket := get_visual_anchor(&"SuppressorAttachmentPoint")
	if flash == null or socket == null:
		return
	if not _has_muzzle_flash_home:
		_muzzle_flash_home = flash.position
		_has_muzzle_flash_home = true
	var tip_global := socket.to_global(Vector3(0, 0, -length - 0.05))
	flash.position = (flash.get_parent() as Node3D).to_local(tip_global)


func _default_mesh_parent() -> Node3D:
	var kick_pivot := find_child("KickPivot", true, false) as Node3D
	return kick_pivot if kick_pivot else self


func _add_box(piece_name: String, piece_position: Vector3, size: Vector3, material: Material, rotation := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = piece_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	_configure_mesh(mesh_instance, piece_position, rotation, material, parent)
	return mesh_instance


func _add_cylinder(piece_name: String, piece_position: Vector3, radius: float, height: float, material: Material, rotation := Vector3.ZERO, parent: Node3D = null, radial_segments := 12) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = piece_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = radial_segments
	mesh_instance.mesh = cylinder
	_configure_mesh(mesh_instance, piece_position, rotation, material, parent)
	return mesh_instance


func _add_tapered_cylinder(piece_name: String, piece_position: Vector3, top_radius: float, bottom_radius: float, height: float, material: Material, rotation := Vector3.ZERO, parent: Node3D = null, radial_segments := 10) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = piece_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top_radius
	cylinder.bottom_radius = bottom_radius
	cylinder.height = height
	cylinder.radial_segments = radial_segments
	mesh_instance.mesh = cylinder
	_configure_mesh(mesh_instance, piece_position, rotation, material, parent)
	return mesh_instance


func _add_capsule(piece_name: String, piece_position: Vector3, radius: float, height: float, material: Material, rotation := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = piece_name
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	capsule.radial_segments = 8
	capsule.rings = 3
	mesh_instance.mesh = capsule
	_configure_mesh(mesh_instance, piece_position, rotation, material, parent)
	return mesh_instance


func _configure_mesh(mesh_instance: MeshInstance3D, piece_position: Vector3, rotation: Vector3, material: Material, parent: Node3D) -> void:
	mesh_instance.position = piece_position
	mesh_instance.rotation_degrees = rotation
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else _default_mesh_parent()).add_child(mesh_instance)


## Shared authored surface slots keep new firearms off environmental metal/wood.
## Shallow duplicates share the 1K textures; local triplanar follows moving guns.
func _gunmetal_material(tint: Color, roughness: float) -> StandardMaterial3D:
	var material := GUNMETAL.duplicate() as StandardMaterial3D
	# The old flat model colors are deliberately near-black. Lift their tint
	# before multiplying a real albedo map so receivers don't become black voids.
	material.albedo_color = tint.lerp(Color.WHITE, 0.55)
	material.roughness = clampf(roughness * 1.4, 0.32, 0.75)
	return material


func _ak_wood_material(highlight := false) -> StandardMaterial3D:
	var material := AK_WOOD.duplicate() as StandardMaterial3D
	if highlight:
		material.albedo_color = Color(1.0, 0.97, 0.90)
	return material


func _material(color: Color, roughness: float, emissive := false, emission_energy := 3.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	return material
