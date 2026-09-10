extends "res://scripts/tests/campus_circulation_validation.gd"

const CAMPUS := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn")


func _run() -> void:
	var campus := CAMPUS.instantiate() as Node3D
	campus.set("gameplay_enabled", false)
	add_child(campus)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player = PLAYER.instantiate() as PlayerController
	campus.get_node("Actors").add_child(_player)
	_player.set_physics_process(false)
	await get_tree().physics_frame
	var stairs := get_tree().get_nodes_in_group("campus_switchback_stairs")
	_check(stairs.size() == 7, "Full campus must contain the seven planned reusable switchbacks")
	var nidra_stack: Array[CampusSwitchbackStair] = []
	for node in stairs:
		var stair := node as CampusSwitchbackStair
		if String(stair.get_path()).contains("CellhouseB0/Stair_stairn"):
			_check(stair.secondary_upper_entrances.size() == 1, "Cellhouse B north stair must receive its secondary upper entrance configuration")
		var route := PackedVector3Array()
		for point in stair.get_route_points():
			route.append(stair.to_global(point))
		await _walk_both_ways(route, String(stair.get_path()))
		var stair_path := String(stair.get_path())
		if stair_path.contains("/SecurityHQ/") and (stair.name.begins_with("NidraStair") or stair.name == "Stair_stairn"):
			nidra_stack.append(stair)
	_check(nidra_stack.size() == 3, "B2-to-HQ-upper shaft needs three aligned stair modules")
	nidra_stack.sort_custom(func(a: CampusSwitchbackStair, b: CampusSwitchbackStair) -> bool: return a.global_position.y < b.global_position.y)
	var complete_stack_route := PackedVector3Array()
	for stair in nidra_stack:
		for point in stair.get_route_points():
			complete_stack_route.append(stair.to_global(point))
	if not complete_stack_route.is_empty():
		await _walk_both_ways(complete_stack_route, "INTEGRATED B2/B1/HQ/UPPER")
	await _validate_secondary_staff_routes(campus)
	_release_inputs()
	if failures.is_empty():
		print("CAMPUS INTEGRATED CIRCULATION VALIDATION: PASS (seven furnished-campus switchbacks, complete B2/HQ shaft, both secondary staff doors; actual controller both directions)")
		get_tree().quit(0)
	else:
		print("CAMPUS INTEGRATED CIRCULATION VALIDATION: FAIL (%d)" % failures.size())
		get_tree().quit(1)


func _validate_secondary_staff_routes(campus: Node3D) -> void:
	var assembly := campus.get_node("CampusInteriors") as CampusInteriorAssembly
	for floor_id in ["cellhouse-b-0", "cellhouse-b-1"]:
		var floor_node: CampusBlueprintFloor = assembly.floors[floor_id]
		var staff_door: NormalDoor
		for record in floor_node.door_records:
			if record.a == "staff" and record.b == "stairn":
				staff_door = record.node as NormalDoor
		_check(staff_door != null, "%s requires its secondary staff entrance" % floor_id)
		if staff_door == null:
			continue
		if not staff_door.required_key_id.is_empty():
			AccessManager.add_key(staff_door.required_key_id)
		staff_door.animation_duration = 0.01
		if not staff_door.is_open:
			staff_door.interact(_player)
		await get_tree().create_timer(0.04).timeout
		await get_tree().physics_frame
		_check(staff_door.is_open, "%s staff doorway must open for authorized access" % floor_id)
		var record: Dictionary
		for candidate in floor_node.door_records:
			if candidate.a == "staff" and candidate.b == "stairn":
				record = candidate
				break
		var threshold := floor_node.to_global(record.position)
		var normal: Vector3 = floor_node.global_basis * record.mount_normal
		# Circulation routes describe the walkable floor plane; the shared walker
		# adds the controller's standing offset itself.
		var y := floor_node.global_position.y
		# Exercise the actual threshold from its furnished staff side through the
		# secondary stair-wall opening. Deriving this from the plan keeps the test
		# valid when the campus or its circulation strips are compacted.
		var staff_route := PackedVector3Array([
			Vector3(threshold.x, y, threshold.z) + normal * 1.45,
			Vector3(threshold.x, y, threshold.z) + normal * 0.55,
			Vector3(threshold.x, y, threshold.z) - normal * 0.55,
			Vector3(threshold.x, y, threshold.z) - normal * 1.25,
		])
		await _walk_both_ways(staff_route, "%s secondary staff bypass" % floor_id)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
	if is_instance_valid(_player):
		print("CONTROLLER DIAGNOSTIC: velocity %s; physics delta %f; process delta %f; physics frame %s; enabled %s" % [_player.velocity, _player.get_physics_process_delta_time(), _player.get_process_delta_time(), Engine.is_in_physics_frame(), _player.control_enabled])
		for index in range(_player.get_slide_collision_count()):
			var hit := _player.get_slide_collision(index)
			var collider := hit.get_collider() as Node
			print("COLLISION DIAGNOSTIC: %s at %s normal %s" % [collider.get_path() if collider else "unknown", hit.get_position(), hit.get_normal()])
