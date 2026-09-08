extends CharacterBody3D
class_name PlayerController

signal interaction_prompt_changed(prompt: String)
signal movement_state_changed(is_sprinting: bool, is_crouching: bool)

@export_group("Movement")
@export_range(1.0, 10.0, 0.1) var walk_speed := 4.2
@export_range(1.0, 14.0, 0.1) var sprint_speed := 7.0
@export_range(0.5, 6.0, 0.1) var crouch_speed := 2.1
@export_range(1.0, 12.0, 0.1) var jump_velocity := 5.4
@export_range(1.0, 30.0, 0.5) var acceleration := 18.0
@export_range(1.0, 30.0, 0.5) var air_acceleration := 5.0

@export_group("Crouch")
@export_range(1.2, 2.5, 0.05) var standing_height := 1.8
@export_range(0.75, 1.8, 0.05) var crouched_height := 1.1
@export_range(-0.25, 2.0, 0.05) var standing_camera_height := 0.72
@export_range(-0.5, 1.5, 0.05) var crouched_camera_height := 0.04
@export_range(0.5, 12.0, 0.25) var collider_transition_speed := 4.0
@export_range(0.5, 12.0, 0.25) var camera_transition_speed := 3.2
@export_range(0.0, 0.1, 0.005) var clearance_margin := 0.02

@export_group("Look")
@export_range(0.0005, 0.01, 0.0001) var mouse_sensitivity := 0.0022
@export_range(45.0, 89.0, 1.0) var vertical_look_limit := 85.0

@export_group("Interaction")
@export_range(0.5, 8.0, 0.1) var interaction_distance := 3.2

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var body_collider: CollisionShape3D = $CollisionShape3D
@onready var stand_clearance: ShapeCast3D = $StandClearance

var control_enabled := true
var is_sprinting := false
var is_crouching := false
var restricted_suspicion_multiplier := 1.0

var _gravity := 18.0
var _current_interactable: Node = null
var _active_restricted_zones: Dictionary = {}
var _last_prompt := ""
var _failure_locked := false


func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	body_collider.shape = body_collider.shape.duplicate() as Shape3D
	_configure_crouch()
	interaction_ray.target_position = Vector3(0.0, 0.0, -interaction_distance)
	interaction_ray.collide_with_areas = true
	interaction_ray.collide_with_bodies = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if not control_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-vertical_look_limit), deg_to_rad(vertical_look_limit))


func _physics_process(delta: float) -> void:
	_update_interaction_target()
	if not control_enabled:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		if not is_on_floor():
			velocity.y -= _gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		return

	var was_sprinting := is_sprinting
	var was_crouching := is_crouching
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wants_to_crouch := Input.is_action_pressed("crouch")
	if wants_to_crouch:
		is_crouching = true
	else:
		var capsule := body_collider.shape as CapsuleShape3D
		var still_transitioning := capsule != null and capsule.height < standing_height - 0.001
		is_crouching = still_transitioning and not _can_stand()
	is_sprinting = Input.is_action_pressed("sprint") and not is_crouching and input_vector.length_squared() > 0.01
	_update_crouch(delta)
	if was_sprinting != is_sprinting or was_crouching != is_crouching:
		movement_state_changed.emit(is_sprinting, is_crouching)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump") and not is_crouching:
		velocity.y = jump_velocity

	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var target_speed := crouch_speed if is_crouching else (sprint_speed if is_sprinting else walk_speed)
	var target_velocity := direction * target_speed
	var current_acceleration := acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, current_acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, current_acceleration * delta)
	move_and_slide()

	if Input.is_action_just_pressed("interact") and is_instance_valid(_current_interactable):
		_current_interactable.call("interact", self)


func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled and not _failure_locked
	if not control_enabled:
		is_sprinting = false
		_current_interactable = null
		if not _last_prompt.is_empty():
			_last_prompt = ""
			interaction_prompt_changed.emit("")


func set_failure_locked() -> void:
	_failure_locked = true
	set_control_enabled(false)


func enter_restricted_zone(zone: Node, multiplier: float) -> void:
	_active_restricted_zones[zone] = maxf(1.0, multiplier)
	_recalculate_restricted_multiplier()


func exit_restricted_zone(zone: Node) -> void:
	_active_restricted_zones.erase(zone)
	_recalculate_restricted_multiplier()


func _recalculate_restricted_multiplier() -> void:
	restricted_suspicion_multiplier = 1.0
	for multiplier in _active_restricted_zones.values():
		restricted_suspicion_multiplier = maxf(restricted_suspicion_multiplier, float(multiplier))


func _update_crouch(delta: float) -> void:
	var target_height := crouched_height if is_crouching else standing_height
	var capsule := body_collider.shape as CapsuleShape3D
	if capsule:
		capsule.height = move_toward(capsule.height, target_height, delta * collider_transition_speed)
		# Offset the capsule so its base stays fixed while its height changes.
		body_collider.position.y = (capsule.height - standing_height) * 0.5
	var target_head_y := crouched_camera_height if is_crouching else standing_camera_height
	head.position.y = move_toward(head.position.y, target_head_y, delta * camera_transition_speed)


func _can_stand() -> bool:
	var capsule := body_collider.shape as CapsuleShape3D
	if capsule == null or capsule.height >= standing_height - 0.001:
		return true

	# Sweep only the extra headroom needed to expand the capsule. Testing a full
	# standing capsule here would include floor contact and can falsely block standing.
	var fixed_base_y := -standing_height * 0.5
	var current_cap_center_y := fixed_base_y + capsule.height - capsule.radius
	var standing_cap_center_y := fixed_base_y + standing_height - capsule.radius
	stand_clearance.position = Vector3(0.0, current_cap_center_y, 0.0)
	stand_clearance.target_position = Vector3.UP * (standing_cap_center_y - current_cap_center_y)
	stand_clearance.force_shapecast_update()
	return not stand_clearance.is_colliding()


func _configure_crouch() -> void:
	var capsule := body_collider.shape as CapsuleShape3D
	if capsule == null:
		push_error("Player crouch requires a CapsuleShape3D collision shape.")
		stand_clearance.enabled = false
		return

	var minimum_capsule_height := capsule.radius * 2.0 + 0.02
	standing_height = maxf(standing_height, minimum_capsule_height)
	crouched_height = clampf(crouched_height, minimum_capsule_height, standing_height)
	capsule.height = standing_height
	body_collider.position.y = 0.0
	head.position.y = standing_camera_height

	var clearance_shape := SphereShape3D.new()
	clearance_shape.radius = maxf(0.05, capsule.radius - clearance_margin)
	stand_clearance.shape = clearance_shape
	stand_clearance.collision_mask = collision_mask
	stand_clearance.collide_with_areas = false
	stand_clearance.collide_with_bodies = true
	stand_clearance.exclude_parent = true
	stand_clearance.enabled = true


func _update_interaction_target() -> void:
	if not is_instance_valid(_current_interactable):
		_current_interactable = null
	var next_interactable: Node = null
	if control_enabled and interaction_ray.is_colliding():
		next_interactable = _find_interactable(interaction_ray.get_collider() as Node)
	if next_interactable != _current_interactable:
		_current_interactable = next_interactable
	var next_prompt := ""
	if is_instance_valid(_current_interactable):
		next_prompt = str(_current_interactable.call("get_interaction_prompt", self))
	if next_prompt != _last_prompt:
		_last_prompt = next_prompt
		interaction_prompt_changed.emit(next_prompt)


func _find_interactable(start_node: Node) -> Node:
	var candidate := start_node
	for _depth in range(5):
		if candidate == null:
			break
		if candidate.has_method("get_interaction_prompt") and candidate.has_method("interact"):
			return candidate
		candidate = candidate.get_parent()
	return null
