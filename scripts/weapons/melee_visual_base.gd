extends Node3D
class_name MeleeVisualBase

const FirstPersonBodyStyle := preload("res://scripts/weapons/first_person_body_style.gd")

const FIRST_PERSON_ANCHORS := ["GripAnchor", "ImpactPoint", "HipAnchor"]
const WORLD_ANCHORS := ["InteractionAnchor", "GripAnchor"]

@export var first_person := false


func validate_visual_contract() -> PackedStringArray:
	var failures := PackedStringArray()
	for anchor_name in FIRST_PERSON_ANCHORS if first_person else WORLD_ANCHORS:
		if find_child(anchor_name, true, false) == null:
			failures.append("Missing required melee visual anchor: %s" % anchor_name)
	return failures


func play_attack(_duration: float, _impact_time: float) -> void:
	pass


func play_impact(_heavy: bool) -> void:
	pass


func cancel_melee_animation() -> void:
	pass


func _add_box(piece_name: String, piece_position: Vector3, size: Vector3, material: Material, rotation := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = piece_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	_configure(instance, piece_position, rotation, material, parent)
	return instance


func _add_cylinder(piece_name: String, piece_position: Vector3, radius: float, height: float, material: Material, rotation := Vector3.ZERO, parent: Node3D = null, segments := 10) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = piece_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	instance.mesh = mesh
	_configure(instance, piece_position, rotation, material, parent)
	return instance


func _add_tapered(piece_name: String, piece_position: Vector3, top_radius: float, bottom_radius: float, height: float, material: Material, rotation := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = piece_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 8
	instance.mesh = mesh
	_configure(instance, piece_position, rotation, material, parent)
	return instance


func _add_capsule(piece_name: String, piece_position: Vector3, radius: float, height: float, material: Material, rotation := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = piece_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 3
	instance.mesh = mesh
	_configure(instance, piece_position, rotation, material, parent)
	return instance


func _configure(instance: MeshInstance3D, piece_position: Vector3, rotation: Vector3, material: Material, parent: Node3D) -> void:
	instance.position = piece_position
	instance.rotation_degrees = rotation
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(instance)


func _material(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _add_anchor(parent: Node3D, anchor_name: String, anchor_position: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = anchor_name
	marker.position = anchor_position
	parent.add_child(marker)
	return marker
