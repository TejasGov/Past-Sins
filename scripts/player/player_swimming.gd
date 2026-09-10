extends Node
class_name PlayerSwimming

signal swimming_state_changed(swimming: bool)

## Optional water motor/presentation, separate from interaction and land movement.
@export var swim_speed := 2.7
@export var vertical_speed := 2.2
@export var water_acceleration := 5.0
var water: SwimmingPool
var underwater := false
var immersion := 0.0
var _player: PlayerController
var _overlay: ColorRect
var _underwater_environment: Environment
var _previous_environment: Environment
var _has_override := false

func _ready() -> void:
	_player = get_parent() as PlayerController
	# Under HUD layers, and mouse-ignoring. No framebuffer copy/postprocess pass.
	var layer := CanvasLayer.new()
	layer.name = "WaterPresentation"
	layer.layer = 0
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/underwater_overlay.gdshader")
	_overlay.material = material
	_overlay.visible = false
	layer.add_child(_overlay)

func update_water() -> bool:
	var was_swimming := is_instance_valid(water)
	water = null
	for candidate in get_tree().get_nodes_in_group("swimming_water"):
		if candidate is SwimmingPool and candidate.contains_horizontal(_player.global_position):
			var y := _player.global_position.y
			if y > candidate.global_position.y - candidate.depth - 0.2 and y < candidate.surface_height() + 0.35:
				water = candidate
				break
	if was_swimming != (water != null): swimming_state_changed.emit(water != null)
	return water != null

func move_in_water(delta: float) -> void:
	_player.is_sprinting = false
	_player.is_crouching = not _player._can_stand()
	_player._update_crouch(delta)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _player.transform.basis * Vector3(input.x, 0, input.y)
	_player.velocity.x = move_toward(_player.velocity.x, direction.x * swim_speed, water_acceleration * delta)
	_player.velocity.z = move_toward(_player.velocity.z, direction.z * swim_speed, water_acceleration * delta)
	var target_y := 0.0
	if Input.is_action_pressed("crouch"):
		target_y = -vertical_speed
	elif Input.is_action_pressed("jump"):
		target_y = vertical_speed
	else:
		# Stable buoyancy target: eyes just above surface. No automatic drowning.
		var float_y := water.surface_height() - _player.standing_camera_height + 0.16
		target_y = clampf((float_y - _player.global_position.y) * 3.0, -vertical_speed, vertical_speed)
	_player.velocity.y = move_toward(_player.velocity.y, target_y, water_acceleration * delta)
	# Grounded exit steps must be walkable: don't force the capsule back into
	# their ramp. Gravity resumes above the water motor's chest-depth threshold.
	if _player.is_on_floor() and not Input.is_action_pressed("crouch"):
		_player.velocity.y = maxf(0.0, _player.velocity.y)
	_player.move_and_slide()

func _process(delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_player.camera): return
	var camera := _player.camera
	var submerged := false
	for candidate in get_tree().get_nodes_in_group("swimming_water"):
		if candidate is SwimmingPool and candidate.contains_horizontal(camera.global_position):
			var threshold: float = candidate.surface_height() + (0.025 if underwater else -0.025)
			submerged = camera.global_position.y < threshold and camera.global_position.y > candidate.global_position.y - candidate.depth
			if submerged: break
	underwater = submerged
	immersion = move_toward(immersion, 1.0 if underwater else 0.0, delta * 4.0)
	_overlay.visible = immersion > 0.001
	(_overlay.material as ShaderMaterial).set_shader_parameter("immersion", immersion)
	if immersion > 0.001:
		if not _has_override:
			_previous_environment = camera.environment
			var source := _previous_environment if _previous_environment else camera.get_world_3d().environment
			_underwater_environment = source.duplicate() as Environment if source else Environment.new()
			_has_override = true
			camera.environment = _underwater_environment
		_underwater_environment.fog_enabled = true
		_underwater_environment.fog_light_color = Color("286374")
		_underwater_environment.fog_density = immersion * 0.11
		_underwater_environment.fog_sky_affect = immersion
	elif _has_override:
		camera.environment = _previous_environment
		_has_override = false

func _exit_tree() -> void:
	if _has_override and is_instance_valid(_player) and is_instance_valid(_player.camera):
		_player.camera.environment = _previous_environment
