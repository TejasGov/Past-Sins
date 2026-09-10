extends Node3D

## Full assembled-campus integration audit. This is an opt-in test scene only;
## posing access leaves does not grant keys or modify session authorization.
const CAMPUS := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn")
const EXPECTED_PLANS := ["food-ground", "medical-ground", "cellhouse-b-0", "cellhouse-b-1", "hq-0", "hq-1", "maintenance-ground", "maintenance-b1", "nidra-b2", "admin-ground"]
const RADIUS := 0.34
const HEIGHT := 1.8
var _failures: Array[String] = []
var _closed_states: Array[Dictionary] = []
var _capsule: CapsuleShape3D
var _door_count := 0
var _open_count := 0
var _furniture_count := 0
var _room_count := 0


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	_capsule = CapsuleShape3D.new()
	_capsule.radius = RADIUS
	_capsule.height = HEIGHT
	var campus := CAMPUS.instantiate() as Node3D
	# Full interiors are part of the migrated playable campus. Freeze actors
	# immediately after deferred spawning so they cannot alter the geometry test.
	campus.set("phase_two_enabled", true)
	campus.set("campus_interiors_enabled", true)
	add_child(campus)
	await get_tree().process_frame
	var actors := campus.get_node_or_null("Actors")
	if actors != null:
		actors.process_mode = Node.PROCESS_MODE_DISABLED
		for shape in actors.find_children("*", "CollisionShape3D", true, false):
			shape.disabled = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	var floors: Array[Node3D] = []
	var found_plans: Array[String] = []
	for node in get_tree().get_nodes_in_group("campus_blueprint_floors"):
		if campus.is_ancestor_of(node):
			floors.append(node as Node3D)
			found_plans.append(String(node.get("plan_id")))
	for id in EXPECTED_PLANS:
		_check(found_plans.has(id), "Missing implemented floor: %s" % id)
	for floor_node in floors:
		_validate_closed_doors(floor_node)
	_open_all_leaves(campus)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for floor_node in floors:
		_validate_thresholds(floor_node)
		_validate_furnishings(floor_node)
	_validate_render_budget(campus)
	_restore_leaves()
	print("Campus building audit: %d floors, %d rooms, %d physical doors, %d open thresholds, %d furniture assemblies" % [floors.size(), _room_count, _door_count, _open_count, _furniture_count])
	if _failures.is_empty():
		print("PASS: all intended room thresholds are walkable, closed leaves contain, furniture fits rooms")
	else:
		for message in _failures:
			push_error(message)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _validate_closed_doors(floor_node: Node3D) -> void:
	var plan_id := String(floor_node.get("plan_id"))
	for record in floor_node.get("door_records"):
		var door: Node3D = record.get("node")
		if door == null:
			continue
		_door_count += 1
		if bool(door.get("is_open")):
			continue
		var found := false
		for hit in _hits(door.global_position + Vector3.UP):
			var collider := hit.get("collider") as Node
			if collider != null and door.is_ancestor_of(collider):
				found = true
		_check(found, "%s/%s↔%s: closed door has no leaf collision at %s" % [plan_id, record.a, record.b, door.global_position])


func _open_all_leaves(campus: Node3D) -> void:
	for node in campus.find_children("*", "Node3D", true, false):
		if node is NormalDoor or node is PrisonSlidingGate:
			var door := node as Node3D
			var blocker := door.get("blocker") as CollisionShape3D
			if blocker == null:
				continue
			_closed_states.append({"door": door, "blocker": blocker, "open": bool(door.get("is_open")), "disabled": blocker.disabled})
			door.call("_apply_pose", true)
			door.set("is_open", true)
			blocker.disabled = true


func _restore_leaves() -> void:
	for state in _closed_states:
		var door: Node3D = state.door
		door.call("_apply_pose", state.open)
		door.set("is_open", state.open)
		var blocker: CollisionShape3D = state.blocker
		blocker.disabled = bool(state.disabled)


func _validate_thresholds(floor_node: Node3D) -> void:
	var plan_id := String(floor_node.get("plan_id"))
	var rooms: Dictionary = floor_node.get("rooms")
	var checked := 0
	var skipped := 0
	var entry_rooms: Dictionary = {}
	for record in floor_node.get("door_records"):
		var kind := String(record.get("kind", "door"))
		var meets_stair := _is_stair(rooms.get(String(record.a))) or _is_stair(rooms.get(String(record.b)))
		if kind in ["hatch", "window", "sealed"] or (kind == "open" and meets_stair):
			skipped += 1
			continue
		if kind == "open":
			_open_count += 1
		var width := float(record.get("clear_width", record.width))
		_check(width >= RADIUS * 2.0 + 0.16, "%s/%s↔%s: opening too narrow at %.2fm" % [plan_id, record.a, record.b, width])
		var center: Vector3 = record.position
		var normal := Vector3.BACK if record.axis == "x" else Vector3.RIGHT
		# Include the entire 0.77m exterior surface reveal and enough space to
		# stand on both sides. A 4m corridor's opposite wall is beyond this sweep.
		# A staff room opening onto a stair still requires a clear landing. Test
		# the 1.2m landing ring, without extending the probe over a sloped flight.
		var extent := 0.6 if meets_stair else 1.3
		var clear := true
		for step in range(14):
			var local := center + normal * lerpf(-extent, extent, float(step) / 13.0) + Vector3.UP
			var world := floor_node.to_global(local)
			var hits := _hits(world)
			if not hits.is_empty():
				_failures.append("%s/%s↔%s (%s) blocked at plan-local %s, world %s; %s" % [plan_id, record.a, record.b, kind, local, world, _describe_hit(hits[0])])
				clear = false
				break
		if clear:
			checked += 1
			entry_rooms[String(record.a)] = true
			entry_rooms[String(record.b)] = true
	for room_id in rooms:
		var room := rooms[room_id] as Node3D
		if not _is_stair(room):
			_check(entry_rooms.has(String(room_id)), "%s/%s: room has no clear intended entrance" % [plan_id, room_id])
	print("Thresholds %s: %d clear; %d deliberate hatches/windows/seals/stair transitions excluded" % [plan_id, checked, skipped])


func _validate_furnishings(floor_node: Node3D) -> void:
	var plan_id := String(floor_node.get("plan_id"))
	var rooms: Dictionary = floor_node.get("rooms")
	for room_value in rooms.values():
		var room := room_value as Node3D
		_room_count += 1
		var data: Dictionary = room.get_meta("room_data", {})
		var furnishing := room.get_node_or_null("Furnishings") as Node3D
		if furnishing == null:
			continue
		var half_width := float(data.w) * 0.5
		var half_depth := float(data.d) * 0.5
		for prop_node in furnishing.find_children("*", "Node3D", true, false):
			if not prop_node.is_in_group("campus_placed_furniture"):
				continue
			_furniture_count += 1
			var bounds: AABB = prop_node.get_meta("furniture_bounds", AABB())
			var support := String(prop_node.get_meta("support_type", ""))
			var label := "%s/%s/%s" % [plan_id, data.id, prop_node.name]
			_check(bounds.size != Vector3.ZERO, "%s has no furniture audit bounds" % label)
			# This detects objects penetrating adjacent rooms. Up to 3cm overlap
			# with a centerline is accepted for actual brackets mounted in a wall.
			_check(bounds.position.x >= -half_width - 0.03 and bounds.end.x <= half_width + 0.03 and bounds.position.z >= -half_depth - 0.03 and bounds.end.z <= half_depth + 0.03, "%s extends through room perimeter: bounds=%s, room=%.2fx%.2f" % [label, bounds, float(data.w), float(data.d)])
			if support == "floor":
				_check(absf(bounds.position.y) <= 0.025, "%s floats/sinks relative to finished floor: %.3fm" % [label, bounds.position.y])
			_check(bounds.end.y <= float(floor_node.get("story_height")) - 0.16, "%s penetrates ceiling: top %.2f" % [label, bounds.end.y])


func _is_stair(node: Node) -> bool:
	if node == null:
		return false
	return String(node.get_meta("room_data", {}).get("type", "")) in ["stair", "lift", "void"]


func _validate_render_budget(campus: Node3D) -> void:
	var nodes := campus.find_children("*", "", true, false)
	var meshes := 0
	var lights := 0
	var shadow_lights := 0
	var triangles := 0
	var triangle_cache: Dictionary = {}
	var mesh_distribution: Dictionary = {}
	for node in nodes:
		if node is Light3D:
			lights += 1
			if (node as Light3D).shadow_enabled:
				shadow_lights += 1
		var mesh: Mesh
		var instances := 1
		if node is MeshInstance3D and node.is_visible_in_tree():
			mesh = node.mesh
		elif node is MultiMeshInstance3D and node.is_visible_in_tree() and node.multimesh:
			mesh = node.multimesh.mesh
			instances = node.multimesh.instance_count if node.multimesh.visible_instance_count < 0 else node.multimesh.visible_instance_count
		if mesh == null:
			continue
		meshes += 1
		var path := String(node.get_path())
		var zone := "Campus exterior/other"
		var building_marker := path.find("/Buildings/")
		if building_marker >= 0:
			zone = path.substr(building_marker + 11).get_slice("/", 0)
		mesh_distribution[zone] = int(mesh_distribution.get(zone, 0)) + 1
		var id := mesh.get_instance_id()
		if not triangle_cache.has(id):
			triangle_cache[id] = mesh.get_faces().size() / 3
		triangles += int(triangle_cache[id]) * instances
	print("Full campus budget: %d nodes, %d visible mesh nodes, %d triangles, %d lights" % [nodes.size() + 1, meshes, triangles, lights])
	print("Visible mesh distribution: ", mesh_distribution)
	# Whole-campus ceilings (seven furnished buildings), independent of the
	# earlier single-cellhouse 6,500-node limit. These guard against accidental
	# unbatching, procedural duplication or per-fixture light proliferation.
	_check(nodes.size() + 1 <= 25000, "Campus exceeds 25,000 nodes")
	_check(meshes <= 6000, "Campus exceeds 6,000 visible mesh nodes")
	_check(triangles <= 1000000, "Campus exceeds 1,000,000 triangles")
	# Thirteen unshadowed storey lights and three tower beams are switched as
	# groups by the day/night controller; the remaining nodes are the sun and
	# existing gameplay indicators. Keep the total bounded and shadows disabled.
	_check(lights <= 19, "Campus exceeds the 19-node automatic-light budget")
	_check(shadow_lights == 0, "Campus automatic-light budget must remain shadow-free")


func _hits(point: Vector3) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.transform.origin = point
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(query, 8)


func _describe_hit(hit: Dictionary) -> String:
	var collider := hit.get("collider") as CollisionObject3D
	if collider == null:
		return str(hit)
	var owner_id := collider.shape_find_owner(int(hit.get("shape", 0)))
	var owner := collider.shape_owner_get_owner(owner_id) as CollisionShape3D
	if owner == null:
		return String(collider.get_path())
	var size := str((owner.shape as BoxShape3D).size) if owner.shape is BoxShape3D else owner.shape.get_class()
	return "%s shape at %s size %s" % [owner.get_path(), owner.global_position, size]


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
