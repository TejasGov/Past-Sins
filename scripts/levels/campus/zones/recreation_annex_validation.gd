extends Node3D

## Opt-in headless physical clearance check. Not included in the playable scene.
const ANNEX := preload("res://scenes/levels/campus/zones/CampusRecreationAnnex.tscn")
const YARD := preload("res://scenes/levels/campus/infrastructure/CentralYardGrounds.tscn")
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var annex := ANNEX.instantiate() as Node3D
	add_child(annex)
	add_child(YARD.instantiate())
	await get_tree().physics_frame
	await get_tree().physics_frame
	for node in get_tree().get_nodes_in_group("campus_recreation_gates"):
		var gate := node as PrisonSlidingGate
		_check(_blocked(gate.global_position + Vector3.UP), "%s closed leaf must block passage" % gate.name)
		gate.interact(null)
	await get_tree().create_timer(1.0).timeout
	await get_tree().physics_frame
	for node in get_tree().get_nodes_in_group("campus_recreation_gates"):
		var gate := node as PrisonSlidingGate
		_check(gate.is_open != gate.starts_locked, "%s respects access state" % gate.name)
		_check(_blocked(gate.global_position + Vector3.UP) == gate.starts_locked, "%s open passage/closed collision mismatch" % gate.name)
	# Follow the actual continuous deck and Medical approach with a standing
	# player capsule, including each unlocked gate, turns and wet-edge clearance.
	_check_route([
		Vector3(-29.4, 0, 50.5), Vector3(-26, 0, 50.5), Vector3(-26, 0, 48.5),
		Vector3(-1.5, 0, 48.5),
		Vector3(-1.5, 0, 35.2), Vector3(-1, 0, 33), Vector3(-1, 0, 28.2),
		Vector3(0, 0, 27.2), Vector3(0, 0, 25)
	], "Medical to pool and central yard")
	_check_route([
		Vector3(-26, 0, 48.5), Vector3(-2, 0, 48.5), Vector3(-2, 0, 35),
		Vector3(-26, 0, 35), Vector3(-26, 0, 48.5)
	], "Pool deck circuit")
	# The recreational deck is open. Security belongs at the compound perimeter.
	for point in [Vector3(-14, 0, 50), Vector3(-2, 0, 42.5), Vector3(-26, 0, 36), Vector3(-26, 0, 49)]:
		_check(not _blocked(point + Vector3.UP), "No wire cage may block the pool deck at %s" % point)
	_check_route([Vector3(-28, 0, 31), Vector3(28, 0, 31)], "South cross road")
	_check_route([Vector3(5, 0, 34), Vector3(5, 0, 57)], "Central avenue")
	var count := annex.find_children("*", "", true, false).size()
	print("Recreation annex: %d nodes, 0 extra light sources" % count)
	if _failures.is_empty():
		print("PASS: recreation gates, pool containment, Medical route, deck circuit and roads")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _check_route(points: Array, label: String) -> void:
	for index in range(points.size() - 1):
		var a: Vector3 = points[index]
		var b: Vector3 = points[index + 1]
		var steps := maxi(1, ceili(a.distance_to(b) / 0.25))
		for step in range(steps + 1):
			var point := a.lerp(b, float(step) / steps) + Vector3.UP * 1.02
			if _blocked(point):
				_failures.append("%s obstructed at %s" % [label, point])
				break


func _blocked(point: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.32
	query.shape = capsule
	query.transform.origin = point
	query.collision_mask = 1
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
