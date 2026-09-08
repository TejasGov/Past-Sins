extends Node

const MAIN_SCENE := preload("res://scenes/levels/CellBlockPrototype.tscn")

var _space_state: PhysicsDirectSpaceState3D


func _ready() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	var level := MAIN_SCENE.instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_space_state = get_viewport().world_3d.direct_space_state

	var assemblies: Dictionary = {}
	var part_count := 0
	for floor_root in level.get_node("Floors").get_children():
		var collision_root := floor_root.get_node("Collision") as StaticBody3D
		var collision_shapes: Array[CollisionShape3D] = []
		for child in collision_root.get_children():
			if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
				collision_shapes.append(child as CollisionShape3D)
		for child in floor_root.get_children():
			if child is not MeshInstance3D or not child.has_meta("furniture_assembly"):
				continue
			var part := child as MeshInstance3D
			var assembly_id := "%s/%s" % [floor_root.name, part.get_meta("furniture_assembly")]
			var role := String(part.get_meta("furniture_role"))
			if not assemblies.has(assembly_id):
				assemblies[assembly_id] = {}
			var roles := assemblies[assembly_id] as Dictionary
			roles[role] = int(roles.get(role, 0)) + 1
			part_count += 1
			assert(_has_matching_collision(part, collision_shapes), "%s has collision that differs from its visible box" % part.get_path())
			if bool(part.get_meta("furniture_touches_floor")):
				var mesh := part.mesh as BoxMesh
				var bottom := part.position.y - mesh.size.y * 0.5
				assert(absf(bottom) <= 0.005, "%s support does not meet the floor (bottom %.3f)" % [part.get_path(), bottom])

	# Cafeteria tables and kitchen prep counters now live in the reusable prop
	# catalog and are validated by PropLibraryValidation.
	assert(assemblies.size() >= 60, "Expected the retained procedural furniture inventory, found only %d assemblies" % assemblies.size())
	for assembly_id in assemblies:
		var roles := assemblies[assembly_id] as Dictionary
		assert(roles.has("support"), "%s has no visible structural support" % assembly_id)
		assert(roles.has("surface") or roles.has("seat"), "%s has no usable visible surface" % assembly_id)

	# Open only the physics blockers so every authored doorway can be checked with
	# the standing player's real capsule dimensions, independent of key state.
	for item in level.get_node("Interactables").get_children():
		if item is NormalDoor or item is PrisonSlidingGate:
			(item.get("blocker") as CollisionShape3D).disabled = true
	await get_tree().physics_frame
	for item in level.get_node("Interactables").get_children():
		if item is NormalDoor or item is PrisonSlidingGate:
			_assert_route_clear("%s doorway" % item.name, item.global_position + Vector3.UP * 0.95)

	var fixed_thresholds := {
		"Ground cafeteria entry": Vector3(0, -3.05, 12.3),
		"Ground B1 stair arrival": Vector3(14.25, -3.05, 12.3),
		"B1 maintenance entry": Vector3(-2.5, -7.05, 13.5),
		"B1 service stair": Vector3(11.7, -7.05, 20.0),
		"Floor 1 service stair": Vector3(11.7, 0.95, 20.0),
		"Floor 4 roof stair": Vector3(11.7, 12.95, 12.5),
	}
	for route_name in fixed_thresholds:
		_assert_route_clear(route_name, fixed_thresholds[route_name])

	print("FURNITURE_VALIDATION: PASS — %d assemblies / %d collision-matched parts" % [assemblies.size(), part_count])
	get_tree().quit(0)


func _has_matching_collision(visual: MeshInstance3D, shapes: Array[CollisionShape3D]) -> bool:
	var visual_box := visual.mesh as BoxMesh
	for shape_node in shapes:
		var collision_box := shape_node.shape as BoxShape3D
		if visual_box.size.is_equal_approx(collision_box.size) and visual.transform.origin.is_equal_approx(shape_node.transform.origin):
			return true
	return false


func _assert_route_clear(label: String, center: Vector3) -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	assert(_space_state.intersect_shape(query, 8).is_empty(), "%s is obstructed" % label)
