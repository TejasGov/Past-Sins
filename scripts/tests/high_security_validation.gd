extends Node

const MAIN_SCENE := preload("res://scenes/levels/CellBlockPrototype.tscn")


func _ready() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	var level := MAIN_SCENE.instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var dedicated_guards: Array[GuardController] = []
	for child in level.get_node("Actors").get_children():
		if child is GuardController and child.name.contains("SecurityGuard"):
			dedicated_guards.append(child as GuardController)
	assert(dedicated_guards.size() == 4, "Expected one guard in each high-security zone on Floors 2 and 3")
	for guard in dedicated_guards:
		assert(guard.patrol_only, "%s is not confined to its patrol" % guard.name)
		var points: Array = guard.get("_patrol_nodes")
		assert(points.size() == 6, "%s patrol is incomplete" % guard.name)
		var north_zone := guard.name.contains("North")
		for point in points:
			var z := (point as Node3D).global_position.z
			assert(z <= -14.0 if north_zone else z >= 14.0, "%s patrol leaves its gated zone" % guard.name)

	var floor2_bars := _count_special_cell_bars(level.get_node("Floors/Floor2"))
	var floor3_bars := _count_special_cell_bars(level.get_node("Floors/Floor3"))
	assert(floor2_bars == 20, "Floor 2 high-security cells are incomplete: found %d bars" % floor2_bars)
	# The fourth terminal room on Floor 3 remains the existing maintenance/keypad room.
	assert(floor3_bars == 15, "Floor 3 high-security cells are incomplete: found %d bars" % floor3_bars)

	var zone_gate_counts := {4: 0, 8: 0}
	for item in level.get_node("Interactables").get_children():
		if item is PrisonSlidingGate and is_equal_approx(absf(item.position.z), 14.0):
			var floor_y := int(item.position.y)
			if zone_gate_counts.has(floor_y):
				zone_gate_counts[floor_y] += 1
	assert(zone_gate_counts[4] == 4 and zone_gate_counts[8] == 4, "Every north/south zone needs gates on both approaches")

	print("HIGH_SECURITY_VALIDATION: PASS — 7 special cells, 8 zone gates, 4 confined patrol guards")
	get_tree().quit(0)


func _count_special_cell_bars(floor_root: Node) -> int:
	var count := 0
	for child in floor_root.get_children():
		if child is MeshInstance3D and child.name.contains("HighSecurityCell") and child.name.contains("DoorBar"):
			count += 1
	return count
