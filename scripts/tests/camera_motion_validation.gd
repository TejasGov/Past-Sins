extends Node3D

const PLAYER := preload("res://scenes/player/Player.tscn")
const CAMERA_MOTION := preload("res://scripts/player/camera_motion.gd")
const PISTOL := preload("res://resources/weapons/pistol.tres")
const SNIPER := preload("res://resources/weapons/sniper_rifle.tres")
const MONOCULAR := preload("res://resources/items/monocular.tres")
var _player: PlayerController
var _motion: CAMERA_MOTION
var _failures: Array[String] = []
var _sample_phase_advance := 0.0


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	Engine.max_fps = 120
	DevModeManager.set_enabled(true)
	InventoryManager.clear_all_inventory(false)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 0.5, 200.0)
	floor_shape.shape = box
	floor_body.position.y = -0.25
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	_player = PLAYER.instantiate() as PlayerController
	_player.position = Vector3(0, 0.91, 0)
	add_child(_player)
	_motion = _player.get_node("CameraMotion") as CAMERA_MOTION
	await _frames(20)
	_check(_player.is_on_floor(), "Test player must stand on a real collision floor")
	_check(_motion.get_position_offset().is_zero_approx(), "Stationary player must have no bob")
	Input.action_press("move_forward")
	await _frames(3)
	_check(_motion.get_position_offset().length() < 0.005, "Starting movement must ease in instead of snapping to a full footfall")
	await _frames(30)
	var walk := await _sample_motion(60)
	var walk_phase_advance := _sample_phase_advance
	Input.action_press("sprint")
	await _frames(25)
	var sprint := await _sample_motion(60)
	_check(_sample_phase_advance > walk_phase_advance * 1.4, "Bob frequency must rise with actual sprint speed")
	_check(walk.x > 0.006 and walk.y > 0.01, "Walking must create both horizontal and vertical bob")
	_check(sprint.y > walk.y * 1.3, "Sprinting must produce larger bob than walking")
	_check(sprint.z > walk.z * 1.5, "Sprint must have more micro-rotation than walking")
	_check(sprint.y < 0.065, "Sprint bob must stay small enough for readable movement")
	Input.action_release("sprint")
	Input.action_press("crouch")
	await _frames(30)
	var crouch := await _sample_motion(60)
	_check(_player.is_crouching and is_equal_approx(_player.head.position.y, _player.crouched_camera_height), "Crouch must retain its own correct head height")
	_check(crouch.y < walk.y * 0.5, "Crouching must reduce movement bob")
	Input.action_release("crouch")
	await _frames(30)
	_check(is_equal_approx(_player.head.position.y, _player.standing_camera_height), "Standing must restore head height independently of bob")
	var controller := _player.get_node("WeaponController") as PlayerWeaponController
	InventoryManager.add_item(PISTOL)
	controller.equip_slot(0)
	controller._set_aim_held(true)
	await _frames(45)
	_check(controller.ads_active, "Pistol must actually be in ADS during the motion-suppression test")
	_check(_motion.get_position_offset().length() < 0.0001, "Pistol ADS must settle to a steady view while walking")
	_check(_motion.get_rotation_offset().length() < 0.00001, "ADS must not jitter the iron-sight direction")
	var center := _player.camera.get_viewport().get_visible_rect().size * 0.5
	_check(_player.camera.project_ray_normal(center).dot(-_player.camera.global_basis.z) > 0.99999, "The screen center must still be the camera firing ray")
	_check(_player.interaction_ray.global_position.is_equal_approx(_player.camera.global_position), "Interaction ray must move with the camera, not remain at the unbobbed origin")
	controller.unequip_current()
	InventoryManager.clear_all_inventory(false)
	InventoryManager.add_item(SNIPER)
	controller.equip_slot(0)
	controller._set_aim_held(true)
	controller.set_advanced_scope_zoom(true)
	await _frames(45)
	_check(controller.is_advanced_scope_zoom_active(), "Sniper must actually be using advanced zoom during this test")
	_check(_motion.get_position_offset().length() < 0.0001, "Advanced sniper scope must also suppress walking motion")
	controller.unequip_current()
	InventoryManager.add_item(MONOCULAR)
	var equipment := _player.get_node("EquipmentController") as PlayerEquipmentController
	equipment.toggle_selected()
	equipment.activate()
	equipment.set_zoom_state(PlayerEquipmentController.ZoomState.ZOOM_3)
	await _frames(45)
	_check(equipment.active and equipment.get_zoom_label() == "8x", "Monocular must actually be raised at 8x during this test")
	_check(_motion.get_position_offset().length() < 0.0001, "8x monocular must also suppress walking motion")
	equipment.deactivate(true)
	Input.action_release("move_forward")
	await _frames(50)
	_check(_motion.get_position_offset().is_zero_approx() and _motion.get_rotation_offset().is_zero_approx(), "Stopping must ease to an exactly calm view")
	# An additive transform introduced by another system must survive bob updates.
	var base_position := Vector3(0.015, -0.01, 0.005)
	var base_rotation := Vector3(0.015, -0.02, 0.004)
	_player.camera.position += base_position
	_player.camera.rotation += base_rotation
	Input.action_press("move_forward")
	await _frames(40)
	_check((_player.camera.position - _motion.get_position_offset()).distance_to(base_position) < 0.00001, "Bob must preserve external camera translation")
	_check((_player.camera.rotation - _motion.get_rotation_offset()).distance_to(base_rotation) < 0.00001, "Bob must preserve external camera/recoil rotation")
	Input.action_release("move_forward")
	await _frames(50)
	_check(_player.camera.position.distance_to(base_position) < 0.00001 and _player.camera.rotation.distance_to(base_rotation) < 0.00001, "Repeated motion must not accumulate transform drift")
	_motion.enabled = false
	Input.action_press("move_forward")
	await _frames(30)
	_check(_motion.get_position_offset().is_zero_approx(), "Camera motion must be independently configurable/disableable")
	Input.action_release("move_forward")
	print("Camera motion RMS walk=%s sprint=%s crouch=%s" % [walk, sprint, crouch])
	if _failures.is_empty():
		print("CAMERA MOTION VALIDATION PASSED")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _sample_motion(count: int) -> Vector3:
	var sum := Vector3.ZERO
	_sample_phase_advance = 0.0
	var previous_phase := float(_motion.get("_phase"))
	for frame in count:
		await get_tree().physics_frame
		var phase := float(_motion.get("_phase"))
		_sample_phase_advance += fposmod(phase - previous_phase, TAU * 2.0)
		previous_phase = phase
		var offset := _motion.get_position_offset()
		sum.x += offset.x * offset.x
		sum.y += offset.y * offset.y
		sum.z += _motion.get_rotation_offset().length_squared()
	return Vector3(sqrt(sum.x / count), sqrt(sum.y / count), sqrt(sum.z / count))


func _frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
