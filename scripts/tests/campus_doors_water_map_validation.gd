extends Node3D

var failures: Array[String] = []
var player: PlayerController
var campus: Node3D

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	campus = preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn").instantiate()
	campus.set("gameplay_enabled", false)
	add_child(campus)
	player = preload("res://scenes/player/Player.tscn").instantiate()
	campus.get_node("Actors").add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0.95, 35)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_validate_maps()
	await _validate_doors()
	await _validate_pool()
	for action in ["move_right", "move_left", "move_forward", "move_back", "crouch", "jump"]: Input.action_release(action)
	if failures.is_empty(): print("PASS: door detail/sweeps, 13 interior floor maps + outdoors, recessed pool, dive/surface/exit and restored land controls")
	get_tree().quit(0 if failures.is_empty() else 1)

func _validate_maps() -> void:
	var map := get_tree().get_first_node_in_group("minimap") as PrisonMinimap
	map._find_player()
	_check(map._campus_maps.size() == 13, "All 13 planned storeys must have maps")
	for entry in map._campus_maps:
		var plan: Dictionary = entry.plan
		player.global_position = entry.shell.to_global(Vector3(0, float(plan.elevation) + 0.92, 0))
		map._update_floor()
		_check(map.get_floor_id() == plan.id, "Wrong interior map for " + String(plan.id))
		_check(map.get_visible_access_marker_count() > 0, "Missing live access markers in " + String(plan.id))
		for node in map._get_access_nodes():
			if map._is_on_current_map(node):
				_check(absf(node.global_position.y - map._floor_y) <= 1.45, "Different floor's door leaked onto minimap")
		# A normal jump from the tier must not change floors.
		player.position.y += 0.8
		map._update_floor()
		_check(map.get_floor_id() == plan.id, "Jump changed minimap floor")
	player.global_position = Vector3(-14, -1, 42.5)
	map._update_floor()
	_check(map.get_floor_id() == "CAMPUS", "Outdoor pool must return to the campus map")
	var nidra_stair := campus.get_node("CampusInteriors").floors["nidra-b2"].room_node("stairn") as Node3D
	player.global_position = Vector3(nidra_stair.global_position.x, -1.5, nidra_stair.global_position.z)
	map._update_floor()
	_check(map.get_floor_id() == "nidra-b2", "Continuous B2/HQ stair must not flash the outdoor map at the unoccupied B1 level")
	player.global_position = Vector3(-28.1, 0.92, 0)
	map._update_floor()
	_check(map.get_floor_id() == "cellhouse-a-1", "Building threshold inside must zoom in")
	player.global_position.x = -27.4
	map._update_floor()
	_check(map.get_floor_id() == "CAMPUS", "Leaving a doorway must restore overview")
	map.toggle_minimap()
	map._update_floor()
	map.toggle_minimap()
	_check(map.visible, "Map toggle must continue working")
	print("MAP: 13 floor contexts, live door height filters, jumps and building thresholds checked")

func _validate_doors() -> void:
	var doors := get_tree().get_nodes_in_group("normal_doors")
	# Ignore actor shapes and other open leaves; test against structural solids.
	for node in get_tree().get_nodes_in_group("map_access"):
		node.blocker.disabled = true
	await get_tree().physics_frame
	for node in doors:
		var door := node as NormalDoor
		var detail := door.leaf.get_node_or_null("InstitutionalDoorVisual")
		_check(detail != null and detail.find_children("*", "Label3D", true, false).size() == 2, "%s needs readable detail on both faces" % door.get_path())
		for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var pivot := door.pivot.transform
			pivot.basis = Basis(Vector3.UP, deg_to_rad(door.open_angle_degrees) * signf(door.open_direction) * fraction)
			var pose: Transform3D = door.global_transform * pivot * Transform3D(Basis.IDENTITY, door._closed_leaf_position)
			pose.origin += pose.basis.y * (door.door_height * 0.5)
			var shape := BoxShape3D.new()
			shape.size = Vector3(door.door_width - 0.04, door.door_height - 0.10, door.door_thickness - 0.02)
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = shape
			q.transform = pose
			q.collision_mask = 1
			q.exclude = [door.leaf.get_rid()]
			var hits := get_world_3d().direct_space_state.intersect_shape(q, 4)
			if not hits.is_empty():
				var hit: Dictionary = hits[0]
				var owner = hit.collider.shape_owner_get_owner(hit.collider.shape_find_owner(hit.shape))
				_check(false, "%s at %s%% swing clips %s at %s" % [door.get_path(), fraction * 100, owner.get_path(), owner.global_position])
	for node in get_tree().get_nodes_in_group("map_access"):
		node.blocker.disabled = node.is_open
	print("DOORS: %d reusable two-sided leaves and five swing poses checked" % doors.size())

func _validate_pool() -> void:
	var pool := get_tree().get_first_node_in_group("swimming_water") as SwimmingPool
	_check(pool != null, "Pool volume missing")
	var ray := PhysicsRayQueryParameters3D.create(Vector3(-14, 1, 42.5), Vector3(-14, -4, 42.5), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	_check(not hit.is_empty() and absf(hit.position.y + 2.4) < 0.02, "Terrain/deck must not cap the recessed pool")
	player.global_position = Vector3(-14, 0.95, 42.5)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	for i in range(120): await _tick()
	var swimming := player.swimming as PlayerSwimming
	_check(swimming.water == pool, "Player must enter water motor")
	_check(String(campus.get_node("HUD/HUDControl/Controls").text).contains("WASD SWIM"), "HUD must show swimming controls")
	_check(player.global_position.y < 0 and player.global_position.y > -1.5, "Buoyancy must hold a stable surface pose")
	_check(not swimming.underwater, "Resting swimmer's eyes should be above water")
	Input.action_press("crouch")
	for i in range(75): await _tick()
	_check(swimming.underwater and swimming.immersion > 0.9, "Diving must activate underwater presentation")
	_check(player.camera.environment != null and player.camera.environment.fog_enabled, "Underwater fog missing")
	_check(player.global_position.y >= -1.6, "Player must collide with basin floor")
	Input.action_release("crouch")
	Input.action_press("jump")
	for i in range(100): await _tick()
	Input.action_release("jump")
	for i in range(100): await _tick()
	_check(not swimming.underwater and swimming.immersion < 0.01, "Surfacing must remove water tint")
	_check(player.camera.environment == null, "Camera must restore original environment on surfacing")
	for side in [-1.0, 1.0]:
		player.global_position = Vector3(-14 + side * 3.0, -0.7, 42.5)
		player.velocity = Vector3.ZERO
		var action := "move_right" if side > 0 else "move_left"
		Input.action_press(action)
		for i in range(250): await _tick()
		Input.action_release(action)
		_check(absf(player.global_position.x + 14) > 10.5 and player.global_position.y > 0.85, "Pool exit steps must be walkable without jumping: %s" % player.global_position)
		_check(swimming.water == null, "Swimming must stop on dry deck")
	Input.action_press("crouch")
	for i in range(40): await _tick()
	_check(player.is_crouching, "Land crouch must still work after swimming")
	Input.action_release("crouch")
	for i in range(40): await _tick()
	_check(not player.is_crouching, "Land stand must still work after swimming")
	_check(String(campus.get_node("HUD/HUDControl/Controls").text).contains("WASD MOVE"), "Land control hints must be restored")
	print("POOL: fall-in, float, dive, surface, both walk-out exits, dry-land crouch tested")

func _tick() -> void:
	await get_tree().physics_frame
	player._physics_process(1.0 / 60.0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
