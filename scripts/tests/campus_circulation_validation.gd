extends Node3D

const CELLHOUSE := preload("res://scenes/levels/campus/interiors/CellhouseAInterior.tscn")
const STAIR := preload("res://scenes/levels/campus/modules/CampusSwitchbackStair.tscn")
const PLAYER := preload("res://scenes/player/Player.tscn")
var failures: Array[String] = []
var _player: PlayerController


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_player = PLAYER.instantiate() as PlayerController
	add_child(_player)
	_player.set_physics_process(false)
	var cellhouse := CELLHOUSE.instantiate() as Node3D
	add_child(cellhouse)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for stair_route in [
		PackedVector3Array([Vector3(-18, 0, -8), Vector3(-18, 0, -7), Vector3(-18, 4, 7), Vector3(-18, 4, 8)]),
		PackedVector3Array([Vector3(18, 4, 8), Vector3(18, 4, 7), Vector3(18, 8, -7), Vector3(18, 8, -8)]),
	]:
		await _walk_both_ways(stair_route, "Cellhouse straight stair")
	# Bypasses are ordinary through-routes at both ends, with a separate rail
	# on the stair-hole boundary. Probe the whole length, not just the corners.
	for route in [
		PackedVector3Array([Vector3(-20.45, 4, -8), Vector3(-20.45, 4, 8)]),
		PackedVector3Array([Vector3(20.45, 8, -8), Vector3(20.45, 8, 8)]),
	]:
		await _walk_both_ways(route, "Cellhouse outside bypass")
	for side in [-1.0, 1.0]:
		var y := 4.0 if side < 0 else 8.0
		for z in range(-7, 8):
			_check(_sphere_blocked(Vector3(side * 19.24, y + 0.55, z)), "Bypass railing missing at %s" % Vector3(side * 19.24, y, z))
	for cell in get_tree().get_nodes_in_group("campus_cells"):
		var floor_mesh := cell.get_node("CellFloor") as MeshInstance3D
		_check(is_zero_approx(floor_mesh.position.y + (floor_mesh.mesh as BoxMesh).size.y * 0.5), "Cell furniture must share the actual finished floor plane")
		_check(cell.has_node("SlidingBarDoor"), "Each cell must own its sliding door")
	cellhouse.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame

	for lower in ["s", "n", "e", "w"]:
		for upper in ["s", "n", "e", "w"]:
			var stair := STAIR.instantiate() as CampusSwitchbackStair
			stair.lower_entrance_side = lower
			stair.upper_entrance_side = upper
			add_child(stair)
			await get_tree().physics_frame
			await get_tree().physics_frame
			await _walk_both_ways(stair.get_route_points(), "Switchback %s to %s" % [lower, upper])
			_check(float(stair.get_meta("upper_headroom_above_turn")) >= 2.4, "Switchback turn has less than 2.4m structural headroom")
			stair.queue_free()
			await get_tree().physics_frame
			await get_tree().physics_frame

	# A four-storey reserved shaft must also work with repeating stairs. Its
	# middle floor is supplied once by the lower stair's upper landing ring.
	var bottom := STAIR.instantiate() as CampusSwitchbackStair
	bottom.position.y = -8.0
	bottom.continues_above = true
	add_child(bottom)
	var top := STAIR.instantiate() as CampusSwitchbackStair
	top.position.y = -4.0
	top.build_lower_landing = false
	top.continues_above = true
	add_child(top)
	var ground := STAIR.instantiate() as CampusSwitchbackStair
	ground.build_lower_landing = false
	add_child(ground)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var stacked_route := PackedVector3Array()
	for point in bottom.get_route_points():
		stacked_route.append(bottom.to_global(point))
	for point in top.get_route_points():
		stacked_route.append(top.to_global(point))
	for point in ground.get_route_points():
		stacked_route.append(ground.to_global(point))
	await _walk_both_ways(stacked_route, "Stacked B2/B1/ground/upper stair")
	_release_inputs()
	if failures.is_empty():
		print("CAMPUS CIRCULATION VALIDATION: PASS (actual controller up/down, 16 entrance combinations, stacked shaft, Cellhouse bypasses and floor contact)")
		get_tree().quit(0)
	else:
		print("CAMPUS CIRCULATION VALIDATION: FAIL (%d)" % failures.size())
		get_tree().quit(1)


func _walk_both_ways(route: PackedVector3Array, label: String) -> void:
	await _walk_route(route, label + " ascent")
	var reversed := route.duplicate()
	reversed.reverse()
	await _walk_route(reversed, label + " descent")


func _walk_route(route: PackedVector3Array, label: String) -> void:
	_release_inputs()
	_player.position = route[0] + Vector3.UP * 0.92
	_player.rotation = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	# Fixed-step calls exercise the shipped controller, including gravity,
	# acceleration and move_and_slide. No teleporting past treads or jumping.
	for _settle in range(12):
		_player._physics_process(1.0 / 60.0)
	for index in range(1, route.size()):
		var target := route[index] + Vector3.UP * 0.9
		var arrived := false
		for tick in range(1600):
			var offset := target - _player.position
			var horizontal := Vector2(offset.x, offset.z)
			var horizontal_velocity := Vector2(_player.velocity.x, _player.velocity.z)
			if horizontal.length() <= 0.1 and absf(offset.y) < 0.22 and horizontal_velocity.length() < 0.35:
				arrived = true
				break
			var direction := horizontal.normalized()
			_release_inputs()
			# Release movement to brake before a landing turn. Continuing full
			# input until the waypoint then instantly turning causes the test
			# driver to orbit a rail post because real acceleration carries it
			# half a metre past the corner. The controller itself stays unmodified.
			var stopping_speed := sqrt(2.0 * _player.acceleration * maxf(0.0, horizontal.length() - 0.04))
			if horizontal_velocity.dot(direction) < stopping_speed and horizontal.length() > 0.045:
				Input.action_press("move_right" if direction.x >= 0.0 else "move_left", absf(direction.x))
				Input.action_press("move_back" if direction.y >= 0.0 else "move_forward", absf(direction.y))
			_player._physics_process(1.0 / 60.0)
			if _player.position.y < -15.0:
				break
		_check(arrived, "%s cannot reach waypoint %d %s; stopped at %s" % [label, index, target, _player.position])
		if not arrived:
			break
	_release_inputs()


func _release_inputs() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back", "jump", "crouch"]:
		Input.action_release(action)


func _sphere_blocked(point: Vector3) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.14
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform.origin = point
	query.collision_mask = 1
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
