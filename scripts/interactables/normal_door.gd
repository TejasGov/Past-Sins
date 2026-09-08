extends Node3D
class_name NormalDoor

enum MotionType { SWING, SLIDE }

@export var display_name := "Door"
@export var required_key_id: StringName = &""
@export var persistent_access_id: StringName = &""
@export var starts_locked := false
@export var starts_open := false
@export_enum("Swing", "Slide") var motion_type: int = MotionType.SWING
@export var open_direction := 1.0
@export_range(60.0, 120.0, 1.0) var open_angle_degrees := 95.0
@export_range(0.5, 3.0, 0.05) var slide_distance := 1.5
@export_range(0.15, 2.0, 0.05) var animation_duration := 0.6
@export_range(0.9, 2.2, 0.05) var door_width := 1.35
@export_range(1.8, 3.0, 0.05) var door_height := 2.35
@export_range(0.08, 0.3, 0.01) var door_thickness := 0.14

@onready var pivot: Node3D = $DoorPivot
@onready var leaf: AnimatableBody3D = $DoorPivot/DoorLeaf
@onready var visual: MeshInstance3D = $DoorPivot/DoorLeaf/Visual
@onready var blocker: CollisionShape3D = $DoorPivot/DoorLeaf/CollisionShape3D
@onready var safety_shape: CollisionShape3D = $DoorwaySafety/CollisionShape3D

var is_open := false
var is_locked := false
var _moving := false
var _transition: Tween
var _closed_leaf_position := Vector3.ZERO


func _ready() -> void:
	_configure_geometry()
	is_locked = starts_locked and not _is_persistently_unlocked()
	is_open = starts_open and not is_locked
	_apply_pose(is_open)
	blocker.disabled = is_open


func get_interaction_prompt(_player: Node) -> String:
	if _moving:
		return ""
	if is_locked and not _has_required_key():
		return "[E] Locked"
	return "[E] Close Door" if is_open else "[E] Open Door"


func interact(_player: Node) -> void:
	if _moving:
		return
	if is_locked:
		if not _has_required_key():
			_show_message("KEY REQUIRED" if not required_key_id.is_empty() else "%s LOCKED" % display_name.to_upper())
			return
		is_locked = false
		if not persistent_access_id.is_empty():
			AccessManager.unlock_access(persistent_access_id)
	if is_open and _doorway_is_blocked():
		_show_message("DOORWAY BLOCKED")
		return
	_animate_to(not is_open)


func _configure_geometry() -> void:
	var mesh := visual.mesh.duplicate() as BoxMesh
	mesh.size = Vector3(door_width, door_height, door_thickness)
	visual.mesh = mesh
	visual.position.y = door_height * 0.5
	var shape := blocker.shape.duplicate() as BoxShape3D
	shape.size = Vector3(door_width, door_height, door_thickness)
	blocker.shape = shape
	blocker.position.y = door_height * 0.5
	var clearance := safety_shape.shape.duplicate() as BoxShape3D
	clearance.size = Vector3(door_width + 0.35, door_height, maxf(0.85, door_width * 0.72))
	safety_shape.shape = clearance
	safety_shape.position.y = door_height * 0.5
	if motion_type == MotionType.SWING:
		pivot.position.x = -door_width * 0.5
		leaf.position.x = door_width * 0.5
	else:
		pivot.position = Vector3.ZERO
		leaf.position = Vector3.ZERO
	_closed_leaf_position = leaf.position


func _apply_pose(opened: bool) -> void:
	var direction := 1.0 if open_direction >= 0.0 else -1.0
	if motion_type == MotionType.SWING:
		pivot.rotation.y = deg_to_rad(open_angle_degrees) * direction if opened else 0.0
	else:
		leaf.position = _closed_leaf_position + Vector3.RIGHT * (slide_distance * direction if opened else 0.0)


func _animate_to(opened: bool) -> void:
	if _transition and _transition.is_valid():
		_transition.kill()
	_moving = true
	is_open = opened
	blocker.set_deferred("disabled", true)
	var direction := 1.0 if open_direction >= 0.0 else -1.0
	_transition = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if motion_type == MotionType.SWING:
		var target_rotation := deg_to_rad(open_angle_degrees) * direction if opened else 0.0
		_transition.tween_property(pivot, "rotation:y", target_rotation, animation_duration)
	else:
		var target_position := _closed_leaf_position + Vector3.RIGHT * (slide_distance * direction if opened else 0.0)
		_transition.tween_property(leaf, "position", target_position, animation_duration)
	_transition.tween_callback(_finish_transition.bind(opened))


func _finish_transition(opened: bool) -> void:
	_moving = false
	if not opened and _doorway_is_blocked():
		_show_message("DOORWAY BLOCKED")
		_animate_to(true)
		return
	blocker.set_deferred("disabled", opened)


func _doorway_is_blocked() -> bool:
	# Direct-space results are authoritative; Area3D overlap lists can briefly
	# retain a body after it has already left the doorway.
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
