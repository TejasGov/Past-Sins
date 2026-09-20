extends Node3D

const CAMERA := preload("res://scenes/props/security/CCTVCamera.tscn")
const Batcher := preload("res://scripts/levels/campus/furnishing/campus_furniture_batcher.gd")

var _failures: Array[String] = []
var _events: Array[Vector2] = []


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var camera := CAMERA.instantiate() as CCTVCamera
	camera.position = Vector3(3.0, 4.0, -2.0)
	add_child(camera)
	camera.set_process(false)
	camera.detection_changed.connect(_on_detection_changed)
	var head := camera.get_node("CameraHead") as Node3D
	_check(camera.sweep_range_degrees == 45.0 and camera.sweep_speed == 0.15, "Default sweep configuration must remain tunable")
	_check(camera.view_distance == 10.0 and camera.view_angle_degrees == 40.0 and not camera.debug_draw, "Detection defaults must match the requested values, with debug off")
	var period := TAU / (camera.sweep_speed * camera.SWEEP_PHASE_RATE)
	_check(period >= 8.0 and period <= 12.0, "Default sweep round trip must take roughly 8–12 seconds")
	camera.pan_degrees = 25.0
	camera._process(0.0)
	_check(is_equal_approx(head.rotation_degrees.y, 25.0), "Sweep must start at the configured baseline pan")
	camera._process(period / 4.0)
	_check(is_equal_approx(head.rotation_degrees.y, 70.0), "Positive turn must equal pan + sweep range")
	camera._process(period / 2.0)
	_check(is_equal_approx(head.rotation_degrees.y, -20.0), "Negative turn must equal pan - sweep range")
	camera._process(period / 4.0)
	_check(is_equal_approx(head.rotation_degrees.y, 25.0), "A complete sweep must return to baseline")
	# Compare equal-length time slices at the middle and at a turn: sine motion
	# must slow down at the turn rather than reverse at a constant linear speed.
	var center_start := head.rotation_degrees.y
	camera._process(period / 100.0)
	var center_motion := absf(head.rotation_degrees.y - center_start)
	camera._process(period * 0.24)
	var turn_start := head.rotation_degrees.y
	camera._process(period / 100.0)
	_check(absf(head.rotation_degrees.y - turn_start) < center_motion * 0.1, "Sweep must ease near each turn")
	for sample in range(100):
		camera._process(period / 100.0)
		_check(head.rotation_degrees.y >= -20.001 and head.rotation_degrees.y <= 70.001, "Sweep must not exceed its configured bounds")

	camera.sweep_range_degrees = 0.0
	camera.sweep_speed = 0.0
	camera.pan_degrees = 0.0
	camera.tilt_degrees = 0.0
	camera._process(0.1)
	_check(not camera.player_in_view and camera.view_strength == 0.0, "An absent player must produce no detection")
	var player := Node3D.new()
	player.name = "DetectionTestPlayer"
	player.add_to_group("player")
	add_child(player)
	player.global_position = head.to_global(Vector3(0.0, 0.0, -5.0))
	camera._process(0.1)
	_check(camera.player_in_view and is_equal_approx(camera.view_strength, 0.5), "A centered player at 5m must be detected at half strength")
	var event_count := _events.size()
	camera._process(0.1)
	_check(_events.size() == event_count, "Unchanged detection data must not emit duplicate signals")
	player.global_position = head.to_global(Vector3(0.0, 0.0, -2.0))
	camera._process(0.1)
	_check(is_equal_approx(camera.view_strength, 0.8) and _events.size() == event_count + 1, "Distance changes must update strength and emit a signal even while still in view")

	player.global_position = head.to_global(Vector3(0.0, 0.0, 2.0))
	camera._process(0.1)
	_check(not camera.player_in_view and camera.view_strength == 0.0, "A player behind the lens must not be detected")
	player.global_position = head.to_global(Vector3(0.0, 0.0, -10.1))
	camera._process(0.1)
	_check(not camera.player_in_view, "Distance beyond 10m must be rejected")
	player.global_position = head.to_global(Vector3(sin(deg_to_rad(39.0)), 0.0, -cos(deg_to_rad(39.0))) * 5.0)
	camera._process(0.1)
	_check(camera.player_in_view and camera.view_strength < 0.1, "Near the cone edge, detection must be weaker than dead center")
	player.global_position = head.to_global(Vector3(sin(deg_to_rad(41.0)), 0.0, -cos(deg_to_rad(41.0))) * 5.0)
	camera._process(0.1)
	_check(not camera.player_in_view, "Outside the configured half-angle must be rejected")
	player.global_position = head.to_global(Vector3(0.0, sin(deg_to_rad(41.0)), -cos(deg_to_rad(41.0))) * 5.0)
	camera._process(0.1)
	_check(not camera.player_in_view, "Vertical cone checks must work as well as horizontal checks")

	# Detection must follow both the parent orientation and the current head pan
	# and tilt, not use a fixed world-space or mount-space forward direction.
	camera.rotation_degrees.y = 90.0
	camera.pan_degrees = 35.0
	camera.tilt_degrees = -20.0
	camera._process(0.1)
	player.global_position = head.global_position - head.global_basis.z.normalized() * 3.0
	camera._process(0.1)
	_check(camera.player_in_view and is_equal_approx(camera.view_strength, 0.7), "Detection must follow actual global pan and tilt")
	_check(not head.has_node("DetectionDebugCone"), "Debug must allocate no geometry while disabled")
	camera.debug_draw = true
	camera._process(0.0)
	var debug := head.get_node("DetectionDebugCone") as MeshInstance3D
	_check(debug.visible and debug.get_parent() == head, "Visible debug rays must track the live head transform")
	_check(debug.mesh is ImmediateMesh and debug.mesh.get_surface_count() == 1, "Debug cone must use one lightweight immediate line surface")
	_check(debug.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and debug.get_child_count() == 0, "Debug geometry must have no shadows or collision")
	var mesh_id := debug.mesh.get_instance_id()
	for sample in range(10): camera._process(0.1)
	_check(debug.mesh.get_instance_id() == mesh_id, "Debug mesh must be reused instead of allocated every frame")
	player.global_position = head.global_position + head.global_basis.z.normalized() * 3.0
	camera._process(0.1)
	_check(not debug.visible, "Debug rays must hide when the player leaves view")
	player.global_position = head.global_position - head.global_basis.z.normalized() * 3.0
	camera._process(0.1)
	camera.debug_draw = false
	camera._process(0.0)
	_check(not debug.visible, "Turning debug off must hide an existing visualization")
	camera.debug_draw = true
	camera.set_active(false)
	_check(not camera.player_in_view and camera.view_strength == 0.0 and not debug.visible, "Disabling a camera must immediately clear detection and debug")
	var stopped_pan := head.rotation_degrees.y
	camera._process(period)
	_check(is_equal_approx(head.rotation_degrees.y, stopped_pan), "Inactive cameras must not sweep")
	camera.set_active(true)
	camera._process(0.0)
	_check(camera.player_in_view and debug.visible, "Reactivation must resample detection immediately")

	camera.view_distance = 0.0
	camera._process(0.1)
	_check(not camera.player_in_view and camera.view_strength == 0.0, "Zero view distance must disable detection without division by zero")
	camera.view_distance = 10.0
	player.global_position = head.global_position
	camera._process(0.1)
	_check(camera.player_in_view and camera.view_strength == 1.0, "A coincident player must produce finite bounded detection")
	camera.view_angle_degrees = 0.0
	camera.pan_degrees = 0.0
	camera.tilt_degrees = 0.0
	camera.rotation = Vector3.ZERO
	camera._process(0.1)
	player.global_position = head.to_global(Vector3(0.0, 0.0, -1.0))
	camera._process(0.1)
	_check(camera.player_in_view and is_equal_approx(camera.view_strength, 0.9), "Zero-angle axial detection must remain finite")
	camera.view_angle_degrees = 40.0
	# Rebuilds must retain stable node names and reacquire a head/debug cone.
	for mount in [CCTVCamera.MountType.WALL, CCTVCamera.MountType.CEILING, CCTVCamera.MountType.POLE]:
		camera.set_mount_type(mount)
		head = camera.get_node("CameraHead") as Node3D
		player.global_position = head.to_global(Vector3(0.0, 0.0, -1.0))
		camera._process(0.0)
		_check(camera.player_in_view and head.has_node("DetectionDebugCone"), "Every mount must support detection/debug after rebuilding")
	Batcher.consolidate(self)
	_check(is_instance_valid(head) and head.has_node("CameraBody"), "Furniture batching must preserve moving camera visuals")
	player.free()
	camera._process(0.1)
	_check(not camera.player_in_view and camera.view_strength == 0.0, "A removed player must clear detection without stale-reference errors")
	for event in _events:
		_check(event.y >= 0.0 and event.y <= 1.0 and (event.x == 1.0 or event.y == 0.0), "All emitted strengths must be finite and bounded, with zero when out of view")
	for failure in _failures: push_error(failure)
	print("CCTV VALIDATION: ", "PASS" if _failures.is_empty() else "FAIL", " — eased sweep, current global cone, bounded strength, change signals, debug lines, all mounts, no gameplay integration")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _on_detection_changed(in_view: bool, strength: float) -> void:
	_events.append(Vector2(1.0 if in_view else 0.0, strength))


func _check(ok: bool, message: String) -> void:
	if not ok: _failures.append(message)
