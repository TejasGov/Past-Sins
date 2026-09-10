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

	# Security state must not hide architectural mistakes in the stair geometry.
	for item in level.get_node("Interactables").get_children():
		if item is NormalDoor or item is PrisonSlidingGate:
			(item.get("blocker") as CollisionShape3D).disabled = true
	await get_tree().physics_frame

	assert(level.find_children("*StairThreshold*").is_empty(), "Decorative stair threshold frames still exist")
	assert(level.find_children("RoofAccessDoor").is_empty(), "Roof access door still blocks the final tread")

	var stairs := [
		{
			"name": "B2 to B1",
			"start": Vector3(12.75, -12.0, 12.5),
			"direction": Vector3.BACK,
			"run": 7.0,
			"rise": 4.0,
			"bottom_landing": Vector3(11.0, -11.05, 13.0),
			"top_landing": Vector3(11.0, -7.05, 20.0),
		},
		{
			"name": "B1 to Ground",
			"start": Vector3(14.25, -8.0, 19.5),
			"direction": Vector3.FORWARD,
			"run": 7.0,
			"rise": 4.0,
			"bottom_landing": Vector3(12.5, -7.05, 20.0),
			"top_landing": Vector3(14.25, -3.05, 11.0),
		},
		{
			"name": "Ground to Floor 1",
			"start": Vector3(12.75, -4.0, 12.5),
			"direction": Vector3.BACK,
			"run": 7.0,
			"rise": 4.0,
			"bottom_landing": Vector3(12.75, -3.05, 11.0),
			"top_landing": Vector3(11.0, 0.95, 20.0),
		},
		{
			"name": "Floor 1 to Floor 2",
			"start": Vector3(-7.0, 0.0, -6.0),
			"direction": Vector3.RIGHT,
			"run": 14.0,
			"rise": 4.0,
			"bottom_landing": Vector3(-8.5, 0.95, -6.0),
			"top_landing": Vector3(8.5, 4.95, -6.0),
		},
		{
			"name": "Floor 2 to Floor 3",
			"start": Vector3(7.0, 4.0, 6.0),
			"direction": Vector3.LEFT,
			"run": 14.0,
			"rise": 4.0,
			"bottom_landing": Vector3(8.5, 4.95, 6.0),
			"top_landing": Vector3(-8.5, 8.95, 6.0),
		},
		{
			"name": "Floor 3 to Floor 4",
			"start": Vector3(-7.0, 8.0, 0.0),
			"direction": Vector3.RIGHT,
			"run": 14.0,
			"rise": 4.0,
			"bottom_landing": Vector3(-8.5, 8.95, 0.0),
			"top_landing": Vector3(8.5, 12.95, 0.0),
		},
		{
			"name": "Floor 4 to Roof",
			"start": Vector3(13.5, 12.0, 12.0),
			"direction": Vector3.BACK,
			"run": 7.0,
			"rise": 4.0,
			"bottom_landing": Vector3(11.4, 12.95, 13.0),
			"top_landing": Vector3(11.5, 16.95, 19.5),
		},
	]

	for stair in stairs:
		_validate_stair(stair)

	# Regression: the shared atrium camera used to be a pole placed on the
	# Floor 3 -> Floor 4 flight. It must remain overhead and outside the lane.
	for floor_name in ["Floor2", "Floor3"]:
		var atrium_camera := level.get_node("Floors/%s/CellCamAtriumBridge" % floor_name) as CCTVCamera
		assert(atrium_camera.mount_type == CCTVCamera.MountType.CEILING, "%s atrium CCTV is a floor obstruction" % floor_name)
		assert(absf(atrium_camera.global_position.x) >= 9.5, "%s atrium CCTV overlaps a stair/bridge lane" % floor_name)

	# Regression: the Floor 4 east security door must be reachable from the
	# arrival landing without stepping over the central atrium void.
	var floor4_gate := level.get_node("Interactables/Floor4SecurityGate") as PrisonSlidingGate
	assert(floor4_gate.global_position.is_equal_approx(Vector3(8.5, 12.0, -4.5)), "Floor 4 security gate is not aligned to the east gallery")
	for point in [
		Vector3(8.5, 12.95, 0.0), Vector3(8.5, 12.95, -2.0),
		Vector3(8.5, 12.95, -3.35), Vector3(8.5, 12.95, -4.5),
		Vector3(8.5, 12.95, -5.8),
	]:
		_assert_capsule_clear("Floor 4 security approach", point)

	print("STAIR_VALIDATION: PASS — all 7 vertical connections, CCTV clearance, and Floor 4 security approach")
	get_tree().quit(0)


func _validate_stair(stair: Dictionary) -> void:
	var stair_name := String(stair["name"])
	var start := stair["start"] as Vector3
	var direction := (stair["direction"] as Vector3).normalized()
	var run := float(stair["run"])
	var rise := float(stair["rise"])
	_assert_capsule_clear("%s bottom landing" % stair_name, stair["bottom_landing"])
	_assert_capsule_clear("%s top landing" % stair_name, stair["top_landing"])
	for index in range(17):
		var ratio := float(index) / 16.0
		var surface_point := start + direction * (run * ratio) + Vector3.UP * (rise * ratio)
		_assert_flight_clear("%s flight sample %d" % [stair_name, index], surface_point)
		var body_center := surface_point + Vector3.UP * 0.95
		var ray := PhysicsRayQueryParameters3D.create(body_center, body_center + Vector3.DOWN * 1.25, 1)
		var hit := _space_state.intersect_ray(ray)
		assert(not hit.is_empty(), "%s has no supporting collision at sample %d" % [stair_name, index])
		var hit_y := (hit["position"] as Vector3).y
		assert(absf(hit_y - surface_point.y) < 0.22, "%s has a collision lip or unsupported step at sample %d" % [stair_name, index])


func _assert_capsule_clear(label: String, center: Vector3) -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	assert(_space_state.intersect_shape(query, 8).is_empty(), "%s is blocked or lacks standing headroom" % label)


func _assert_flight_clear(label: String, surface_point: Vector3) -> void:
	# Keep the support ramp out of the query while checking the player's occupied
	# torso/head volume against rails, walls, ceilings, and props.
	var standing_volume := CapsuleShape3D.new()
	standing_volume.radius = 0.32
	standing_volume.height = 1.25
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing_volume
	query.transform = Transform3D(Basis.IDENTITY, surface_point + Vector3.UP * 1.16)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	assert(_space_state.intersect_shape(query, 8).is_empty(), "%s is blocked or lacks standing headroom" % label)
