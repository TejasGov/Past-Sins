extends Node

const CAMPUS_SCENE := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	var campus := CAMPUS_SCENE.instantiate() as Node3D
	# Retain this regression as the isolated Cellhouse A migration slice. The
	# complete-campus validator owns the later six building interiors.
	campus.set("campus_interiors_enabled", false)
	add_child(campus)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var cellhouse := campus.get_node_or_null("Buildings/CellhouseA") as Node3D
	var interior := campus.get_node_or_null("Buildings/CellhouseA/Interior") as Node3D
	_check(cellhouse != null, "Cellhouse A shell is missing")
	_check(interior != null, "Cellhouse A Phase 2 interior is missing")
	if interior == null:
		_finish()
		return

	_validate_scope(cellhouse, interior)
	_validate_cells(campus, interior)
	await _validate_access(campus)
	_validate_stair_clearance(interior)
	_validate_floor_and_railing_seams(interior)
	_validate_playable_systems(campus, interior)
	_validate_budget(campus)
	_finish()


func _validate_scope(cellhouse: Node3D, interior: Node3D) -> void:
	for excluded_name in ["B2", "B1", "FoodServices", "Cafeteria", "Kitchen", "Medical", "Laboratory", "Surveillance", "Roof"]:
		_check(cellhouse.find_child(excluded_name, true, false) == null, "Cellhouse A incorrectly contains %s" % excluded_name)
	for required in ["GroundInteriorFinish", "Floor2NorthGallery", "Floor2SouthGallery", "Floor2CentralBridge", "Floor3NorthGallery", "Floor3SouthGallery", "Floor3CentralBridge"]:
		_check(interior.has_node(required), "Cellhouse A is missing %s" % required)
	var stair_treads := interior.find_children("Floor1ToFloor2StairStep*", "MeshInstance3D", true, false).size()
	stair_treads += interior.find_children("Floor2ToFloor3StairStep*", "MeshInstance3D", true, false).size()
	_check(stair_treads == 40, "Cellhouse A requires two 20-tread stair flights")
	_check(interior.get_node("Collision").find_children("*", "CollisionShape3D", true, false).size() > 30, "Interior structure requires collision, including two smooth stair ramps")
	_check(interior.find_children("Floor*GalleryTube*Backplate", "MeshInstance3D", true, false).size() == 12, "All gallery tube lights must use ceiling-flush backplates without hanging stems")


func _validate_cells(campus: Node3D, interior: Node3D) -> void:
	var cells: Array[Node] = []
	for cell in get_tree().get_nodes_in_group("campus_cells"):
		if campus.is_ancestor_of(cell):
			cells.append(cell)
	_check(cells.size() == 45, "Cellhouse A requires 45 ordinary cells after reserving one aligned service-core corner per floor")
	var floor_counts := {1: 0, 2: 0, 3: 0}
	var ids := {}
	var parth_count := 0
	for cell_node in cells:
		var cell := cell_node as Node3D
		_check(cell.has_node("CellFloor"), "%s is missing its floor" % cell.name)
		_check(cell.has_node("CellCeiling"), "%s is missing its ceiling" % cell.name)
		_check(cell.has_node("RearWall"), "%s is missing its rear wall" % cell.name)
		_check(cell.has_node("NorthPartition") and cell.has_node("SouthPartition"), "%s is not enclosed on both sides" % cell.name)
		_check(cell.has_node("DoorMarker"), "%s has no deliberate door opening" % cell.name)
		_check(cell.get_node_or_null("SlidingBarDoor") is PrisonSlidingGate, "%s does not own its reusable sliding barred door" % cell.name)
		_check(cell.has_node("PrisonBunkFrame") and cell.has_node("PrisonBunkMattress"), "%s is missing its supported bunk" % cell.name)
		_check(cell.find_children("PrisonBunkWallBracket*", "MeshInstance3D", true, false).size() >= 2, "%s bed is not visibly attached to the wall" % cell.name)
		_check(cell.has_node("ToiletPedestal") and cell.has_node("ToiletBowl"), "%s is missing its floor-mounted toilet" % cell.name)
		_check(cell.has_node("WashBasin") and cell.has_node("WashBasinFaucet"), "%s is missing its wash basin" % cell.name)
		_check(cell.has_node("SanitaryPrivacyWall"), "%s sanitary fixtures are not separated from the living area" % cell.name)
		_check(cell.has_node("CellCupboardBody"), "%s is missing its cupboard" % cell.name)
		_check(cell.has_node("WoodenChairSeat") and cell.find_children("WoodenChairLeg*", "MeshInstance3D", true, false).size() == 4, "%s is missing its supported wooden chair" % cell.name)
		var ceiling := cell.get_node("CellCeiling") as MeshInstance3D
		for wall_name in ["RearWall", "NorthPartition", "SouthPartition", "CellFrontHeader"]:
			var wall := cell.get_node(wall_name) as MeshInstance3D
			_check(_mesh_top(wall) >= _mesh_bottom(ceiling), "%s has a gap between %s and its ceiling" % [cell.name, wall_name])
		var cell_id := StringName(cell.get_meta("cell_access_id", &""))
		_check(not cell_id.is_empty() and not ids.has(cell_id), "%s has an invalid or duplicate access ID" % cell.name)
		ids[cell_id] = true
		if bool(cell.get_meta("is_parth_cell", false)):
			parth_count += 1
			_check(cell.has_node("ParthPlayableSpawn"), "Parth's cell requires its playable spawn")
		var floor_number := int(cell.get_meta("campus_floor_number", 0))
		_check(floor_counts.has(floor_number), "%s is assigned to an unintended building floor" % cell.name)
		if floor_counts.has(floor_number):
			floor_counts[floor_number] += 1
	for floor_number in [1, 2, 3]:
		_check(int(floor_counts[floor_number]) == 15, "Cellhouse A Floor %d must contain 15 cells plus its guard/elevator core" % floor_number)
	var cell_lamps: Array[Node] = []
	for lamp in get_tree().get_nodes_in_group("cell_lamps"):
		if interior.is_ancestor_of(lamp): cell_lamps.append(lamp)
	_check(cell_lamps.size() == 45, "Every Cellhouse A cell must own one reusable tube light")
	for lamp_node in cell_lamps:
		var diffuser := lamp_node.get_node_or_null("TubeDiffuser") as MeshInstance3D
		var diffuser_mesh := diffuser.mesh as CylinderMesh if diffuser else null
		_check(diffuser_mesh != null and absf(diffuser.global_basis.y.normalized().y) < 0.001, "%s must be a horizontal tube, not a vertical rod" % lamp_node.name)
		_check(lamp_node.find_children("*", "OmniLight3D", true, false).is_empty(), "%s must use pooled lighting instead of a permanent per-cell OmniLight" % lamp_node.name)
	_check(parth_count == 1, "Exactly one cell must be assigned to Parth")
	var service_cores: Array[Node] = []
	for core in get_tree().get_nodes_in_group("campus_guard_elevator_cores"):
		if campus.is_ancestor_of(core):
			service_cores.append(core)
	_check(service_cores.size() == 3, "Each Cellhouse A floor requires one vertically aligned guard/elevator core")
	for floor_number in [1, 2, 3]:
		var core := interior.get_node_or_null("Floor%dGuardElevatorCore" % floor_number) as Node3D
		_check(core != null, "Floor %d guard/elevator core is missing" % floor_number)
		if core != null:
			_check(core.has_node("GuardQuarterDoor"), "Floor %d guard quarter has no deliberate entrance" % floor_number)
			_check(core.has_node("ElevatorDoorPanelLeft") and core.has_node("ElevatorDoorPanelRight"), "Floor %d elevator placeholder lacks closed doors" % floor_number)
			_check(is_equal_approx(core.position.x, 17.5) and is_equal_approx(core.position.z, -13.85), "Floor %d elevator is not aligned with the shared shaft stack" % floor_number)
			_check(core.has_node("GuardDeskTop") and core.find_children("GuardDeskLeg*", "MeshInstance3D", true, false).size() == 4, "Floor %d guard desk lacks recognizable supports" % floor_number)
			_check(core.has_node("GuardMonitor") and core.has_node("GuardKeyboard") and core.has_node("GuardRadio"), "Floor %d guard quarter lacks security-workstation detail" % floor_number)
			_check(core.has_node("GuardLockerDoor") and core.has_node("GuardNoticeBoard"), "Floor %d guard quarter lacks locker and wall detail" % floor_number)


func _validate_access(campus: Node3D) -> void:
	var cell_doors: Array[Node] = []
	for door in get_tree().get_nodes_in_group("campus_cell_doors"):
		if campus.is_ancestor_of(door):
			cell_doors.append(door)
	_check(cell_doors.size() == 45, "Every remaining Cellhouse A cell requires one sliding gate")
	var access_ids := {}
	var parth_gate: PrisonSlidingGate
	for door_node in cell_doors:
		var door := door_node as PrisonSlidingGate
		var access_id := StringName(door.get_meta("cell_access_id", &""))
		_check(not access_id.is_empty() and not access_ids.has(access_id), "%s has an invalid or duplicate gate access ID" % door.name)
		access_ids[access_id] = true
		_check(door.master_key_id == &"cell_master_key", "%s must accept the future chief's master key" % door.name)
		_check(not door.reader_light_enabled, "%s should not allocate a per-cell OmniLight" % door.name)
		_check(door.gate_height >= 2.79, "%s leaves a gap below the cell-front header" % door.name)
		var slat_mesh_count := door.get_node("GateLeaf/Visuals").find_children("Slat*", "MeshInstance3D", true, false).size()
		var slat_multimesh := door.get_node_or_null("GateLeaf/Visuals/Slats") as MultiMeshInstance3D
		var slat_instances := slat_multimesh.multimesh.instance_count if slat_multimesh and slat_multimesh.multimesh else 0
		_check(slat_mesh_count >= 7 or slat_instances >= 7, "%s has no visible sliding bars" % door.name)
		var rails := door.get_node_or_null("GateLeaf/Visuals/CrossRails") as MultiMeshInstance3D
		_check(rails != null and rails.multimesh != null and rails.multimesh.instance_count == 3, "%s must preserve all three supported cross rails in its reusable draw batch" % door.name)
		_check((door.get_node("GateLeaf/Visuals") as Node3D).visible, "%s sliding bars are hidden" % door.name)
		var owning_cell := door.get_parent()
		if owning_cell != null and bool(owning_cell.get_meta("is_parth_cell", false)):
			parth_gate = door
		else:
			_check(door.starts_locked and not door.required_key_id.is_empty(), "%s must start locked with its individual key" % door.name)
	_check(parth_gate != null, "Parth's cell gate is missing")
	if parth_gate != null:
		_check(not parth_gate.is_locked, "Parth must not be trapped by his starting cell gate")
		_check(parth_gate.get_interaction_prompt(null) == "[E] Open Gate", "Parth's starting gate must be immediately usable")

	var exterior_gates: Array[Node] = []
	for gate in get_tree().get_nodes_in_group("campus_exterior_gates"):
		if campus.is_ancestor_of(gate):
			exterior_gates.append(gate)
	_check(exterior_gates.size() == 2, "Cellhouse A requires a main gate and a yard gate")
	_check(campus.has_node("Interactables/MainEntranceGate"), "Cellhouse A main gate is missing")
	_check(campus.has_node("Interactables/YardExitGate"), "Cellhouse A yard gate is missing")
	for gate_node in exterior_gates:
		var gate := gate_node as PrisonSlidingGate
		_check(not gate.is_locked, "%s must be usable during the Phase 2 slice" % gate.name)

	for placeholder_path in ["Buildings/CellhouseA/MainEntranceWest/PlaceholderDoor/Collision", "Buildings/CellhouseA/YardExitEast/PlaceholderDoor/Collision"]:
		var placeholder_collision := campus.get_node_or_null(placeholder_path) as CollisionShape3D
		_check(placeholder_collision != null and placeholder_collision.disabled, "%s must be disabled after the real gate is installed" % placeholder_path)

	# Prove the two exterior corridors are not hiding walls/cells behind their gates.
	for gate_path in ["Interactables/MainEntranceGate", "Interactables/YardExitGate"]:
		var gate := campus.get_node(gate_path) as PrisonSlidingGate
		var blocker := gate.get_node("GateLeaf/CollisionShape3D") as CollisionShape3D
		blocker.disabled = true
		await get_tree().physics_frame
		_check(not _blocked(gate.global_position + Vector3.UP), "%s does not open onto a clear corridor" % gate.name)
		blocker.disabled = false
		await get_tree().physics_frame


func _validate_playable_systems(campus: Node3D, interior: Node3D) -> void:
	var player := campus.get_node_or_null("Actors/Parth") as PlayerController
	_check(player != null, "Phase 2 campus must spawn Parth")
	_check(campus.get_node_or_null("HUD/HUDControl") != null, "Phase 2 campus must provide the existing HUD")
	var minimap := get_tree().get_first_node_in_group("minimap") as PrisonMinimap
	_check(minimap != null and minimap.get_floor_id() == "cellhouse-a-3", "Minimap must show the occupied Cellhouse A tier")
	_check(campus.get_node_or_null("Actors/CellhouseADayroomGuard") is GuardController, "Cellhouse A needs one existing-AI dayroom patrol")
	_check(interior.find_children("DayroomPatrolPoint*", "Marker3D", true, false).size() == 4, "Dayroom guard route requires four clear patrol points")
	_check(interior.find_children("InteriorNavAnchor*", "Marker3D", true, false).size() == 6, "Cellhouse A requires traversal anchors for all three floors and both exits")


func _validate_stair_clearance(interior: Node3D) -> void:
	# Standing-capsule samples on every stair approach/landing catch railings,
	# props, or walls accidentally placed across vertical circulation.
	for local_point in [
		Vector3(-18.0, 1.0, -7.0),
		Vector3(-18.0, 5.0, 7.0),
		Vector3(18.0, 5.0, 7.0),
		Vector3(18.0, 9.0, -7.0),
	]:
		_check(not _blocked(interior.to_global(local_point)), "A Cellhouse A stair approach is obstructed near %s" % local_point)
	# Sample the standing capsule along both complete slopes. This specifically
	# catches a receiving-floor slab acting as a low ceiling above upper treads.
	for ratio in [0.25, 0.5, 0.75, 0.9]:
		var lower_stair_point := Vector3(-18.0, 1.0 + 4.0 * ratio, -7.0 + 14.0 * ratio)
		var upper_stair_point := Vector3(18.0, 5.0 + 4.0 * ratio, 7.0 - 14.0 * ratio)
		_check(not _blocked(interior.to_global(lower_stair_point)), "Floor 1-2 stair loses standing headroom near %s" % lower_stair_point)
		_check(not _blocked(interior.to_global(upper_stair_point)), "Floor 2-3 stair loses standing headroom near %s" % upper_stair_point)


func _validate_floor_and_railing_seams(interior: Node3D) -> void:
	# Representative samples cover every slab-to-gallery, crosswalk, and bridge
	# junction on both elevated floors.
	for floor_y in [4.0, 8.0]:
		for floor_point in [Vector3(-20.0, floor_y, -7.0), Vector3(20.0, floor_y, -7.0), Vector3(-20.0, floor_y, 7.0), Vector3(20.0, floor_y, 7.0), Vector3(-2.1, floor_y, -7.0), Vector3(2.1, floor_y, 7.0)]:
			_check(_has_floor_below(interior.to_global(floor_point)), "Elevated floor has a corner seam near %s" % floor_point)
		for rail_point in [Vector3(-8.0, floor_y + 0.55, -7.0), Vector3(8.0, floor_y + 0.55, 7.0), Vector3(-2.1, floor_y + 0.55, 3.5), Vector3(2.1, floor_y + 0.55, -3.5)]:
			_check(_small_shape_blocked(interior.to_global(rail_point)), "Atrium railing has an unsafe opening near %s" % rail_point)
	# The unused Floor 3 west crosswalk edge must also be fully protected.
	_check(_small_shape_blocked(interior.to_global(Vector3(-16.76, 8.55, 0))), "Floor 3 west crosswalk is missing its edge-aligned railing")
	# The east crosswalk is a through route: bound its inner void edge without
	# placing a crossbar across the valid north gallery/crosswalk junction.
	_check(_small_shape_blocked(interior.to_global(Vector3(16.76, 4.55, 0))), "Floor 2 east crosswalk is missing its edge railing")
	# Probe both sides of every stair connection. These points meet the stair
	# rails, so a misplaced endpoint leaves an immediately detectable hole.
	for rail_join in [
		Vector3(-19.24, 4.55, 7.0), Vector3(-16.76, 4.55, 7.0),
		Vector3(16.76, 4.55, 7.0), Vector3(19.24, 4.55, 7.0),
		Vector3(16.76, 8.55, -7.0), Vector3(19.24, 8.55, -7.0),
	]:
		_check(_small_shape_blocked(interior.to_global(rail_join)), "Stair and floor railings do not connect near %s" % rail_join)


func _validate_budget(campus: Node3D) -> void:
	var node_count := _count_descendants(campus)
	var light_count := campus.find_children("*", "Light3D", true, false).size()
	# Preserve the previous 7,000-node content cap after accounting for only
	# audited visual-overhaul additions: 7 Areas+7 shapes, 47 reader shapes,
	# 8 supported searchlight gimbals, 6 guard-fixture meshes, 1 bob component.
	# These nodes are bounded by exact instance counts, not arbitrary slack.
	var zones := campus.find_children("InteriorEnvironmentZone", "Area3D", true, false)
	var readers := campus.find_children("ReaderInteractionShape", "CollisionShape3D", true, false)
	var gimbals := campus.find_children("LampGimbal", "Node3D", true, false)
	var guard_fixtures := campus.find_children("GuardCeilingLight*", "MeshInstance3D", true, false)
	var camera_motion := campus.find_children("CameraMotion", "Node", true, false)
	_check(zones.size() == 7 and readers.size() == 47 and gimbals.size() == 8 and guard_fixtures.size() == 6 and camera_motion.size() == 1, "Phase 2 visual-overhaul additions must remain exactly bounded (zones=%d, readers=%d, gimbals=%d, guard-fixtures=%d, bob=%d)" % [zones.size(), readers.size(), gimbals.size(), guard_fixtures.size(), camera_motion.size()])
	for zone in zones: _check(zone.get_child_count() == 1 and zone.get_child(0) is CollisionShape3D, "Each footprint zone must contain exactly one collision shape")
	var audited_additions := zones.size() * 2 + readers.size() + gimbals.size() + guard_fixtures.size() + camera_motion.size()
	_check(node_count - audited_additions <= 7000, "Phase 2 exceeds its original 7,000-node content cap plus %d audited framework nodes (%d total)" % [audited_additions, node_count])
	_check(light_count <= 12, "Phase 2 exceeds eight base lights plus four pooled cell lights (%d)" % light_count)
	print("PHASE 2 METRICS: %d nodes (%d original-content budget + %d audited additions), %d lights" % [node_count, node_count - audited_additions, audited_additions, light_count])


func _blocked(point: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not get_viewport().world_3d.direct_space_state.intersect_shape(query, 1).is_empty()


func _small_shape_blocked(point: Vector3) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.16
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = 1
	query.collide_with_areas = false
	return not get_viewport().world_3d.direct_space_state.intersect_shape(query, 1).is_empty()


func _has_floor_below(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.25, point + Vector3.DOWN * 0.35, 1)
	query.collide_with_areas = false
	return not get_viewport().world_3d.direct_space_state.intersect_ray(query).is_empty()


func _mesh_top(mesh_instance: MeshInstance3D) -> float:
	var box := mesh_instance.mesh as BoxMesh
	return mesh_instance.position.y + box.size.y * 0.5


func _mesh_bottom(mesh_instance: MeshInstance3D) -> float:
	var box := mesh_instance.mesh as BoxMesh
	return mesh_instance.position.y - box.size.y * 0.5


func _count_descendants(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_descendants(child)
	return total


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("PHASE 2 VALIDATION: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CAMPUS PHASE 2 VALIDATION: PASS")
		get_tree().quit(0)
		return
	print("CAMPUS PHASE 2 VALIDATION: FAIL (%d checks)" % _failures.size())
	for failure in _failures:
		print(" - %s" % failure)
	get_tree().quit(1)
