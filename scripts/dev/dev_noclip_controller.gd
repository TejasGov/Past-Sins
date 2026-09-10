extends Node
class_name DevNoclipController

## Runtime-only free-flight adapter. It is attached by DevModeManager and never
## exists in Play Mode.
@export_range(1.0, 40.0, 0.5) var move_speed := 10.0
@export_range(1.0, 4.0, 0.1) var sprint_multiplier := 2.0

var player: CharacterBody3D
var _saved_collision_layer := 0
var _saved_collision_mask := 0
var _saved_physics_processing := true


func activate(target: CharacterBody3D) -> void:
	player = target
	_saved_collision_layer = player.collision_layer
	_saved_collision_mask = player.collision_mask
	_saved_physics_processing = player.is_physics_processing()
	player.velocity = Vector3.ZERO
	player.collision_layer = 0
	player.collision_mask = 0
	player.set_physics_process(false)
	set_physics_process(true)


func deactivate() -> void:
	if is_instance_valid(player):
		player.velocity = Vector3.ZERO
		player.collision_layer = _saved_collision_layer
		player.collision_mask = _saved_collision_mask
		player.set_physics_process(_saved_physics_processing)
	player = null
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or DevModeManager.is_menu_open():
		return
	var camera := player.get_viewport().get_camera_3d()
	if camera == null:
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := camera.global_basis * Vector3(input.x, 0.0, input.y)
	if Input.is_action_pressed("jump"):
		direction += Vector3.UP
	if Input.is_action_pressed("crouch"):
		direction += Vector3.DOWN
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	var speed := move_speed * (sprint_multiplier if Input.is_action_pressed("sprint") else 1.0)
	player.global_position += direction * speed * delta


func _exit_tree() -> void:
	deactivate()
