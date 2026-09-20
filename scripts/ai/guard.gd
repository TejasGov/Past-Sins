extends CharacterBody3D
class_name GuardController

signal caught_player(guard: Node)

@export_group("Patrol")
@export var patrol_points: Array[NodePath] = []
@export_range(0.5, 8.0, 0.1) var patrol_speed := 2.0
@export_range(0.5, 12.0, 0.1) var pursuit_speed := 4.8
@export_range(0.0, 10.0, 0.1) var wait_at_point := 1.2
@export var patrol_only := false

@export_group("Detection")
@export_range(1.0, 40.0, 0.5) var view_distance := 16.0
@export_range(10.0, 170.0, 1.0) var field_of_view_degrees := 78.0
@export_range(1.0, 40.0, 0.5) var suspicion_per_second := 10.0
@export_range(0.5, 5.0, 0.1) var catch_distance := 1.25
@export var debug_detection := true

@onready var debug_mesh: MeshInstance3D = $DebugVision
@onready var status_light: OmniLight3D = $StatusLight

var _player: PlayerController
var _patrol_nodes: Array[Node3D] = []
var _patrol_index := 0
var _wait_timer := 0.0
var _can_see_player := false
var _caught_once := false


func _ready() -> void:
	add_to_group("guards")
	for path in patrol_points:
		var point := get_node_or_null(path) as Node3D
		if point:
			_patrol_nodes.append(point)
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	_build_debug_cone()
	debug_mesh.visible = debug_detection


func set_patrol_nodes(nodes: Array[Node3D]) -> void:
	_patrol_nodes = nodes
	_patrol_index = 0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
		return

	_can_see_player = _check_player_visible()
	_update_debug_color()
	var suspicion := get_node_or_null("/root/SuspicionSystem")
	if _can_see_player and suspicion != null:
		# Suppression affects sound/flash only. A clearly visible firearm remains
		# an immediate high-threat identification regardless of its attachment.
		var weapon_controller := _player.get_node_or_null("WeaponController")
		if weapon_controller and weapon_controller.has_method("is_firearm_visibly_held") and weapon_controller.call("is_firearm_visibly_held"):
			suspicion.call("add_suspicion", 100.0)
		else:
			suspicion.call("add_suspicion", _detection_rate() * delta)

	var is_alert: bool = suspicion != null and int(suspicion.get("state")) == 2
	if is_alert and not patrol_only:
		_pursue_player(delta)
	else:
		_patrol(delta)
	move_and_slide()

	if not _caught_once and is_alert and global_position.distance_to(_player.global_position) <= catch_distance and _has_clear_line_of_sight():
		_caught_once = true
		caught_player.emit(self)


func _patrol(delta: float) -> void:
	if _patrol_nodes.is_empty():
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
		return
	var target := _patrol_nodes[_patrol_index]
	var flat_offset := target.global_position - global_position
	flat_offset.y = 0.0
	if flat_offset.length() < 0.55:
		velocity.x = 0.0
		velocity.z = 0.0
		_wait_timer += delta
		if _wait_timer >= wait_at_point:
			_wait_timer = 0.0
			_patrol_index = (_patrol_index + 1) % _patrol_nodes.size()
		return
	_move_toward(flat_offset, patrol_speed, delta)


func _pursue_player(delta: float) -> void:
	var offset := _player.global_position - global_position
	offset.y = 0.0
	_move_toward(offset, pursuit_speed, delta)


func _move_toward(offset: Vector3, speed: float, delta: float) -> void:
	if offset.length_squared() < 0.001:
		return
	var direction := offset.normalized()
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 10.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 10.0)
	var desired_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, minf(1.0, delta * 7.0))


func _check_player_visible() -> bool:
	var eye := global_position + Vector3.UP * 1.45
	var target := _player.global_position + Vector3.UP * (0.8 if _player.is_crouching else 1.25)
	var offset := target - eye
	var distance := offset.length()
	if distance > view_distance or distance < 0.01:
		return false
	var facing := -global_transform.basis.z
	if rad_to_deg(facing.angle_to(offset.normalized())) > field_of_view_degrees * 0.5:
		return false
	return _has_clear_line_of_sight()


func _has_clear_line_of_sight() -> bool:
	var eye := global_position + Vector3.UP * 1.45
	var target := _player.global_position + Vector3.UP * (0.8 if _player.is_crouching else 1.25)
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == _player


func _detection_rate() -> float:
	var distance := global_position.distance_to(_player.global_position)
	# Near targets are identified roughly three times faster than targets at max range.
	var proximity_multiplier := lerpf(3.0, 0.75, clampf(distance / view_distance, 0.0, 1.0))
	var movement_multiplier := 1.0
	if _player.is_sprinting:
		movement_multiplier = 1.85
	elif _player.is_crouching:
		movement_multiplier = 0.42
	return suspicion_per_second * proximity_multiplier * movement_multiplier * _player.restricted_suspicion_multiplier


func _build_debug_cone() -> void:
	var immediate := ImmediateMesh.new()
	var half_angle := deg_to_rad(field_of_view_degrees * 0.5)
	var segments := 18
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segments):
		var a0 := lerpf(-half_angle, half_angle, float(index) / segments)
		var a1 := lerpf(-half_angle, half_angle, float(index + 1) / segments)
		immediate.surface_add_vertex(Vector3(0.0, 0.08, 0.0))
		immediate.surface_add_vertex(Vector3(sin(a0) * view_distance, 0.08, -cos(a0) * view_distance))
		immediate.surface_add_vertex(Vector3(sin(a1) * view_distance, 0.08, -cos(a1) * view_distance))
	immediate.surface_end()
	debug_mesh.mesh = immediate
	_update_debug_color()


func _update_debug_color() -> void:
	var material := debug_mesh.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		debug_mesh.material_override = material
	var color := Color(0.95, 0.12, 0.08, 0.16) if _can_see_player else Color(0.15, 0.75, 0.45, 0.10)
	material.albedo_color = color
	var suspicion := get_node_or_null("/root/SuspicionSystem")
	var is_alert: bool = suspicion != null and int(suspicion.get("state")) == 2
	status_light.light_color = Color(1.0, 0.08, 0.04) if is_alert else Color(0.2, 0.8, 0.55)
