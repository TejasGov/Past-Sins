extends Node3D
class_name PrisonSlidingGate

@export var display_name := "Prison Gate"
@export var required_key_id: StringName = &"cellblock_key"
@export var persistent_access_id: StringName = &""
@export var starts_locked := true
@export var starts_open := false
@export var open_direction := 1.0
@export_range(0.5, 3.5, 0.05) var slide_distance := 1.7
@export_range(0.2, 2.0, 0.05) var animation_duration := 0.75
@export_range(1.1, 2.4, 0.05) var gate_width := 1.5
@export_range(2.0, 3.0, 0.05) var gate_height := 2.5
@export_range(4, 10, 1) var slat_count := 7

@onready var leaf: AnimatableBody3D = $GateLeaf
@onready var visuals: Node3D = $GateLeaf/Visuals
@onready var blocker: CollisionShape3D = $GateLeaf/CollisionShape3D
@onready var safety_shape: CollisionShape3D = $DoorwaySafety/CollisionShape3D

var is_open := false
var is_locked := true
var _moving := false
var _transition: Tween
var _closed_position := Vector3.ZERO


func _ready() -> void:
	_build_gate_visuals()
	_configure_collision()
	is_locked = starts_locked and not _is_persistently_unlocked()
	is_open = starts_open and not is_locked
	_closed_position = leaf.position
	_apply_pose(is_open)
	blocker.disabled = is_open


func get_interaction_prompt(_player: Node) -> String:
	if _moving:
		return ""
	if is_locked:
		return "[E] Unlock Gate" if _has_required_key() else "[E] Locked"
	return "[E] Close Gate" if is_open else "[E] Open Gate"


func interact(_player: Node) -> void:
	if _moving:
		return
	if is_locked:
		if not _has_required_key():
			_show_message("KEY REQUIRED")
			return
		is_locked = false
		if not persistent_access_id.is_empty():
			AccessManager.unlock_access(persistent_access_id)
		_show_message("ACCESS GRANTED")
		_animate_to(true)
		return
	if is_open and _doorway_is_blocked():
		_show_message("GATEWAY BLOCKED")
		return
	_animate_to(not is_open)


func _build_gate_visuals() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("343a38")
	material.metallic = 0.55
	material.roughness = 0.48
	var usable_width := gate_width - 0.16
	for index in range(slat_count):
		var ratio := float(index) / float(maxi(1, slat_count - 1))
		var x := lerpf(-usable_width * 0.5, usable_width * 0.5, ratio)
		_add_visual_box("Slat%02d" % index, Vector3(x, gate_height * 0.5, 0), Vector3(0.09, gate_height, 0.13), material)
	for y in [0.18, gate_height * 0.52, gate_height - 0.18]:
		_add_visual_box("CrossRail", Vector3(0, y, 0), Vector3(gate_width, 0.12, 0.16), material)


func _add_visual_box(piece_name: String, center: Vector3, size: Vector3, material: Material) -> void:
	var piece := MeshInstance3D.new()
	piece.name = piece_name
	var mesh := BoxMesh.new()
	mesh.size = size
	piece.mesh = mesh
	piece.position = center
	piece.material_override = material
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visuals.add_child(piece)


func _configure_collision() -> void:
	var shape := blocker.shape.duplicate() as BoxShape3D
	shape.size = Vector3(gate_width, gate_height, 0.16)
	blocker.shape = shape
	blocker.position.y = gate_height * 0.5
	var clearance := safety_shape.shape.duplicate() as BoxShape3D
	clearance.size = Vector3(gate_width + 0.3, gate_height, 1.0)
	safety_shape.shape = clearance
	safety_shape.position.y = gate_height * 0.5
	$FrameLeft.position = Vector3(-gate_width * 0.5 - 0.1, gate_height * 0.5, 0)
	$FrameRight.position = Vector3(gate_width * 0.5 + 0.1, gate_height * 0.5, 0)
	$FrameHeader.position = Vector3(0, gate_height + 0.08, 0)
	for post in [$FrameLeft, $FrameRight]:
		var post_mesh := post.mesh.duplicate() as BoxMesh
		post_mesh.size.y = gate_height + 0.2
		post.mesh = post_mesh
	var header_mesh := $FrameHeader.mesh.duplicate() as BoxMesh
	header_mesh.size.x = gate_width + 0.3
	$FrameHeader.mesh = header_mesh


func _apply_pose(opened: bool) -> void:
	var direction := 1.0 if open_direction >= 0.0 else -1.0
	leaf.position = _closed_position + Vector3.RIGHT * (slide_distance * direction if opened else 0.0)


func _animate_to(opened: bool) -> void:
	if _transition and _transition.is_valid():
		_transition.kill()
	_moving = true
	is_open = opened
	blocker.set_deferred("disabled", true)
	var direction := 1.0 if open_direction >= 0.0 else -1.0
	var target := _closed_position + Vector3.RIGHT * (slide_distance * direction if opened else 0.0)
	_transition = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(leaf, "position", target, animation_duration)
	_transition.tween_callback(_finish_transition.bind(opened))


func _finish_transition(opened: bool) -> void:
	_moving = false
	if not opened and _doorway_is_blocked():
		_show_message("GATEWAY BLOCKED")
		_animate_to(true)
		return
	blocker.set_deferred("disabled", opened)


func _doorway_is_blocked() -> bool:
	safety_shape.force_update_transform()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = safety_shape.shape
	query.transform = safety_shape.global_transform
	query.collision_mask = 1 << 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	for result in get_world_3d().direct_space_state.intersect_shape(query, 8):
		var collider := result.get("collider") as Node
		if collider and collider.is_in_group("player"):
			return true
	return false


func _has_required_key() -> bool:
	return not required_key_id.is_empty() and AccessManager.has_key(required_key_id)


func _is_persistently_unlocked() -> bool:
	return not persistent_access_id.is_empty() and AccessManager.is_access_unlocked(persistent_access_id)


func _show_message(message: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.call("show_message", message)
