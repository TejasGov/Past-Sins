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

	var dressing := level.get_node("EnvironmentalDressing")
	for required_prop in [
		"GymFlatBenchPress", "GymSquatRack", "GymDumbbellRack",
		"GymExerciseBike", "GymCableMachine", "GymPunchingBag",
		"ShowerTileFloor", "ShowerFixture00", "ShowerDrain00",
		"ShowerBasin00", "ShowerMirror00", "ShowerToiletNorth",
	]:
		assert(dressing.has_node(required_prop), "Missing detailed prop: %s" % required_prop)

	# Central gym and shower approach lanes retain standing-player clearance.
	for point in [
		Vector3(0, 0.95, 0), Vector3(0, 0.95, 4), Vector3(0, 0.95, 9.5),
		Vector3(8.0, 0.95, 0), Vector3(8.0, 0.95, 6.0),
		Vector3(3.75, 0.95, -13.0), Vector3(6.0, 0.95, -14.0),
	]:
		assert(not _blocked(point), "Gym/shower circulation blocked at %s" % point)

	var yard := level.get_node("Floors/OutdoorYard")
	for boundary in ["YardWestPerimeter", "YardEastPerimeter", "YardSouthPerimeter", "YardNorthPerimeterWest", "YardNorthPerimeterEast"]:
		assert(yard.has_node(boundary), "Missing secure yard boundary: %s" % boundary)
	for required_yard_prop in [
		"NorthBasketballHoop", "SouthBasketballHoop", "YardPullUpBarA",
		"YardParallelBars", "GardenBenchNorth",
		"WestYardCamera", "NorthWestObservationPost", "YardSearchlightWest",
	]:
		assert(yard.has_node(required_yard_prop), "Missing yard detail: %s" % required_yard_prop)
	assert(yard.find_children("YardTree*", "Node3D", false, false).size() == 3, "Expected three lightweight yard trees")

	# Closed gate contains the yard; opening it clears a player-sized route in
	# both directions, followed by an unobstructed central path.
	var gate := level.get_node("Interactables/YardSecurityGate") as PrisonSlidingGate
	assert(_blocked(Vector3(0, -3.05, 20.82)), "Closed yard gate has no collision")
	gate.animation_duration = 0.05
	gate.interact(null)
	await get_tree().create_timer(0.12).timeout
	await get_tree().physics_frame
	for point in [Vector3(0, -3.05, 20.82), Vector3(0, -3.05, 22.0), Vector3(0, -3.05, 30.0), Vector3(0, -3.05, 45.0)]:
		assert(not _blocked(point), "Yard access/path blocked at %s" % point)

	# Representative low and jumping-height probes confirm that the perimeter is
	# continuous and cannot be cleared by the player's normal jump.
	for point in [
		Vector3(-18, -3.05, 35), Vector3(18, -3.05, 35),
		Vector3(0, -3.05, 55), Vector3(-8, -3.05, 21),
		Vector3(-18, 0.0, 35), Vector3(18, 0.0, 35), Vector3(0, 0.0, 55),
	]:
		assert(_blocked(point), "Yard perimeter gap at %s" % point)

	for guard in get_tree().get_nodes_in_group("guards"):
		assert(not (guard.global_position.y < -2.0 and guard.global_position.z > 21.0), "NPC was added to the outdoor yard")

	print("GYM_SHOWER_YARD_VALIDATION: PASS — detailed equipment, clear routes, secure yard perimeter")
	get_tree().quit(0)


func _blocked(center: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not _space_state.intersect_shape(query, 16).is_empty()
