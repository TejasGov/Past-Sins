extends Node
class_name PlayerCameraMotion

## Small render-frame motion layered on Camera3D, never on Head or the body.
## Weapons, their sights and the interaction/firing rays all remain children of
## this same camera. This changes the view, not the alignment of the aiming ray.
@export var camera_path := NodePath("../Head/Camera3D")
@export var enabled := true
@export_group("Walking")
@export_range(0.0, 0.08, 0.001) var vertical_amplitude := 0.024
@export_range(0.0, 0.05, 0.001) var horizontal_amplitude := 0.013
@export_range(0.8, 4.0, 0.1) var meters_per_bob_cycle := 2.0
@export_range(1.0, 2.0, 0.05) var sprint_multiplier := 1.45
@export_range(0.0, 1.0, 0.05) var crouch_multiplier := 0.45
@export_range(0.15, 0.3, 0.01) var ease_seconds := 0.22
@export_group("Footfall Micro Motion")
@export_range(0.0, 0.008, 0.0001) var jitter_position_amplitude := 0.0015
@export_range(0.0, 0.2, 0.005) var jitter_rotation_degrees := 0.045
@export_range(5.0, 30.0, 1.0) var jitter_frequency := 17.0
@export_group("Precision Aiming")
@export_range(0.0, 0.2, 0.01) var aiming_motion_multiplier := 0.0

@onready var _player := get_parent() as PlayerController
@onready var _camera := get_node(camera_path) as Camera3D
@onready var _weapons := get_parent().get_node_or_null("WeaponController") as PlayerWeaponController
@onready var _equipment := get_parent().get_node_or_null("EquipmentController") as PlayerEquipmentController

var _noise := FastNoiseLite.new()
var _phase := 0.0
var _noise_time := 0.0
var _motion_weight := 0.0
var _last_position := Vector3.ZERO
var _last_rotation := Vector3.ZERO


func _ready() -> void:
	# Recoil controllers run at priority 0. Their own additive removal and ours
	# can coexist without either script replacing the other's camera transform.
	process_priority = 20
	_noise.seed = 1731
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0


func _process(delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_camera):
		return
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var precision := 0.0
	if is_instance_valid(_weapons):
		precision = maxf(_weapons.get_ads_blend(), 1.0 if _weapons.ads_active else 0.0)
	if is_instance_valid(_equipment):
		precision = maxf(precision, maxf(_equipment.use_blend, 1.0 if _equipment.active else 0.0))
	var allowed := enabled and _player.control_enabled and _player.is_physics_processing() \
		and _player.is_on_floor()
	if is_instance_valid(_player.swimming) and is_instance_valid(_player.swimming.get("water")):
		allowed = false
	var ratio := clampf(speed / maxf(_player.walk_speed, 0.1), 0.0, 1.8)
	var stance := crouch_multiplier if _player.is_crouching else (sprint_multiplier if _player.is_sprinting else 1.0)
	var target_weight := ratio * stance * lerpf(1.0, aiming_motion_multiplier, precision) if allowed and speed > 0.06 else 0.0
	# 95% of the transition completes within ease_seconds, independent of FPS.
	var dt := minf(delta, 0.1)
	_motion_weight = lerpf(_motion_weight, target_weight, 1.0 - exp(-3.0 * dt / ease_seconds))
	if _motion_weight < 0.0005:
		_motion_weight = 0.0
	if allowed and speed > 0.06:
		_phase = fmod(_phase + speed * TAU * dt / maxf(meters_per_bob_cycle, 0.1), TAU * 2.0)
		_noise_time = fmod(_noise_time + dt * jitter_frequency, 10000.0)
	var jitter := Vector3(_noise.get_noise_1d(_noise_time), _noise.get_noise_1d(_noise_time + 53.0), _noise.get_noise_1d(_noise_time + 107.0))
	var position_offset := Vector3(sin(_phase * 0.5) * horizontal_amplitude, sin(_phase) * vertical_amplitude, 0.0)
	position_offset += Vector3(jitter.x, jitter.y, 0.0) * jitter_position_amplitude
	position_offset *= _motion_weight
	var rotation_offset := Vector3(jitter.y * 0.5, jitter.x * 0.35, jitter.z) * deg_to_rad(jitter_rotation_degrees) * _motion_weight
	_apply_offsets(position_offset, rotation_offset)


func _apply_offsets(position_offset: Vector3, rotation_offset: Vector3) -> void:
	# Do NOT cache/restore a complete base transform: other systems can legitimately
	# change it (recoil, scripted views). Remove only this component's contribution.
	_camera.position += position_offset - _last_position
	_camera.rotation += rotation_offset - _last_rotation
	_last_position = position_offset
	_last_rotation = rotation_offset


func reset_motion() -> void:
	if is_instance_valid(_camera):
		_apply_offsets(Vector3.ZERO, Vector3.ZERO)
	_motion_weight = 0.0
	_phase = 0.0
	_noise_time = 0.0


func get_position_offset() -> Vector3:
	return _last_position


func get_rotation_offset() -> Vector3:
	return _last_rotation


func _exit_tree() -> void:
	reset_motion()
