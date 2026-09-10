extends Node

const CAMPUS_SCENE := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn")
const LEGACY_SCENE := preload("res://scenes/levels/CellBlockPrototype.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	_check(
		String(ProjectSettings.get_setting("application/run/main_scene", "")) == "res://scenes/levels/campus/PrisonCampusPrototype.tscn",
		"Phase 2 must launch the separated prison campus"
	)

	var campus := CAMPUS_SCENE.instantiate() as Node3D
	campus.set("phase_two_enabled", false)
	add_child(campus)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_validate_hierarchy(campus)
	await _validate_buildings(campus)
	_validate_watchtowers(campus)
	_validate_infrastructure(campus)
	_validate_anchors_and_budget(campus)

	campus.queue_free()
	await get_tree().process_frame

	var legacy := LEGACY_SCENE.instantiate()
	add_child(legacy)
	await get_tree().process_frame
	_check(legacy.has_node("Floors"), "Legacy CellBlockPrototype must still instantiate with Floors")
	_check(legacy.has_node("Actors"), "Legacy CellBlockPrototype must still instantiate with Actors")
	_check(legacy.has_node("Interactables"), "Legacy CellBlockPrototype must still instantiate with Interactables")
	legacy.queue_free()

	_finish()


func _validate_hierarchy(campus: Node3D) -> void:
	for path in [
		"CampusShell", "Buildings", "Underground", "Actors", "Interactables",
		"PatrolRoutes", "EnvironmentalProps", "Navigation", "HUD", "DebugAudits"
	]:
		_check(campus.has_node(path), "Campus hierarchy is missing %s" % path)

	var world_environment := campus.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_check(world_environment != null, "Campus requires a WorldEnvironment")
	if world_environment != null:
		_check(world_environment.environment != null, "Campus WorldEnvironment must contain an Environment resource")
	_check(campus.get_node_or_null("PreviewCamera") is Camera3D, "Campus requires its non-gameplay preview camera")


func _validate_buildings(campus: Node3D) -> void:
	var expected := {
		"CellhouseA": {"position": Vector3(-50, 0, 0), "size": Vector2(44, 34), "doors": ["MainEntranceWest", "YardExitEast"]},
		"CellhouseB": {"position": Vector3(50, 0, 0), "size": Vector2(35.2, 44.8), "doors": ["MainEntranceWest", "NorthSallyPort"]},
		"FoodServices": {"position": Vector3(-48, 0, -51.5), "size": Vector2(38, 33.2), "doors": ["MainDiningEntrance", "ServiceLoadingDock"]},
		"MedicalWellness": {"position": Vector3(-48, 0, 51.5), "size": Vector2(37.2, 33.2), "doors": ["MainMedicalEntrance", "YardGymEntrance", "AmbulanceBay"]},
		"SecurityHQ": {"position": Vector3(48, 0, -51.5), "size": Vector2(35.2, 33.2), "doors": ["MainSecurityEntrance", "StaffSideEntrance"]},
		"Maintenance": {"position": Vector3(48, 0, 51.5), "size": Vector2(35.2, 33.2), "doors": ["MainMaintenanceEntrance", "ServiceYardDoor"]},
		"Administration": {"position": Vector3(0, 0, 71), "size": Vector2(39.2, 24), "doors": ["MainIntakeEntrance", "PublicFrontEntrance"]},
	}
	var buildings := campus.get_node_or_null("Buildings") as Node3D
	_check(buildings != null, "Buildings root must exist")
	if buildings == null:
		return
	_check(buildings.get_child_count() == 7, "Phase 1 must contain exactly seven building shells")

	var footprints: Array[Dictionary] = []
	for building_name in expected:
		var spec: Dictionary = expected[building_name]
		var building := buildings.get_node_or_null(building_name) as Node3D
		_check(building != null, "Missing building shell: %s" % building_name)
		if building == null:
			continue
		_check(building.position.is_equal_approx(spec["position"]), "%s is at the wrong campus position" % building_name)
		_check(building.is_in_group("campus_buildings"), "%s must be tagged as a campus building" % building_name)
		_check(building.has_meta("building_title"), "%s is missing building title metadata" % building_name)
		_check(building.has_meta("footprint_size"), "%s is missing footprint metadata" % building_name)
		_check(building.has_node("RoofSlab"), "%s must be roofed and sealed" % building_name)
		footprints.append({"name": building_name, "rect": _footprint_rect(building.position, spec["size"])})
		for doorway_name in spec["doors"]:
			await _validate_placeholder_entrance(building, doorway_name)

	for i in range(footprints.size()):
		for j in range(i + 1, footprints.size()):
			var a: Dictionary = footprints[i]
			var b: Dictionary = footprints[j]
			_check(not (a["rect"] as Rect2).intersects(b["rect"] as Rect2), "%s overlaps %s" % [a["name"], b["name"]])
			_check(_rect_gap(a["rect"], b["rect"]) >= 5.0, "%s and %s need at least 5m of circulation clearance" % [a["name"], b["name"]])

	for body in buildings.find_children("*", "StaticBody3D", true, false):
		_check(not body.find_children("*", "MeshInstance3D", true, false).is_empty(), "%s has collision but no visible mesh" % body.get_path())
		_check(not body.find_children("*", "CollisionShape3D", true, false).is_empty(), "%s has a mesh but no collision shape" % body.get_path())


func _validate_placeholder_entrance(building: Node3D, doorway_name: String) -> void:
	var doorway := building.get_node_or_null(doorway_name) as Node3D
	_check(doorway != null, "%s is missing entrance %s" % [building.name, doorway_name])
	if doorway == null:
		return
	_check(bool(doorway.get_meta("placeholder_entrance", false)), "%s must be marked as a placeholder entrance" % doorway.get_path())
	var placeholder := doorway.get_node_or_null("PlaceholderDoor") as StaticBody3D
	_check(placeholder != null, "%s requires a collision-backed placeholder door" % doorway.get_path())
	if placeholder == null:
		return

	var sample := doorway.global_position + Vector3.UP
	_check(_blocked(sample), "%s is not sealed while its placeholder door is closed" % doorway.get_path())
	var collision := placeholder.get_node_or_null("Collision") as CollisionShape3D
	_check(collision != null, "%s placeholder door is missing collision" % doorway.get_path())
	if collision == null:
		return
	collision.disabled = true
	await get_tree().physics_frame
	_check(not _blocked(sample), "%s opening still contains wall collision after its door is opened" % doorway.get_path())
	collision.disabled = false
	await get_tree().physics_frame


func _validate_watchtowers(campus: Node3D) -> void:
	var group := campus.get_node_or_null("CampusShell/Watchtowers") as Node3D
	_check(group != null, "Watchtowers group must exist")
	if group == null:
		return
	_check(group.get_child_count() == 8, "Phase 1 requires exactly eight watchtowers")

	var roads := campus.get_node_or_null("CampusShell/RoadsAndPaths")
	var road_rects: Array[Dictionary] = []
	if roads != null:
		for mesh_node in roads.get_children():
			var mesh_instance := mesh_node as MeshInstance3D
			if mesh_instance != null and mesh_instance.mesh is BoxMesh:
				road_rects.append({"name": mesh_instance.name, "rect": _mesh_rect(mesh_instance)})

	for tower_node in group.get_children():
		var tower := tower_node as Node3D
		_check(tower != null, "Every watchtower entry must be a Node3D")
		if tower == null:
			continue
		_check(absf(tower.global_position.y) < 0.01, "%s must be grounded" % tower.name)
		_check(tower.has_node("DeckPlatform"), "%s is missing its deck" % tower.name)
		_check(tower.has_node("CabinBody"), "%s is missing its cabin" % tower.name)
		_check(tower.has_node("AccessLadder"), "%s is missing its access ladder" % tower.name)
		_check(tower.has_node("SearchlightFixture"), "%s is missing its searchlight fixture" % tower.name)
		var ladder := tower.get_node_or_null("AccessLadder") as Node3D
		if ladder != null:
			var ladder_forward := ladder.global_transform.basis * Vector3.BACK
			ladder_forward.y = 0.0
			var inward := -Vector3(tower.global_position.x, 0, tower.global_position.z)
			if inward.length_squared() > 0.01:
				_check(ladder_forward.normalized().dot(inward.normalized()) > 0.7, "%s ladder must face into the secured campus" % tower.name)
		var tower_rect := Rect2(Vector2(tower.global_position.x - 2.3, tower.global_position.z - 2.3), Vector2(4.6, 4.6))
		for road in road_rects:
			_check(not tower_rect.intersects(road["rect"] as Rect2), "%s obstructs %s" % [tower.name, road["name"]])


func _validate_infrastructure(campus: Node3D) -> void:
	var perimeter := campus.get_node_or_null("CampusShell/Perimeter")
	_check(perimeter != null, "Campus perimeter must exist")
	if perimeter != null:
		for name in ["WestPerimeterWall", "EastPerimeterWall", "NorthWallWest", "NorthWallEast", "SouthWallWest", "SouthWallEast", "NorthServiceSallyPort", "SouthMainSallyPort"]:
			_check(perimeter.has_node(name), "Perimeter is missing %s" % name)
		for point in [Vector3(-78, 2.6, 0), Vector3(78, 2.6, 0), Vector3(-20, 2.6, -94), Vector3(20, 2.6, -94), Vector3(-20, 2.6, 94), Vector3(20, 2.6, 94), Vector3(0, 2.0, -97.6), Vector3(0, 2.0, 98.5), Vector3(-78, 4.7, 25), Vector3(78, 4.7, -25)]:
			_check(_blocked(point), "Perimeter collision is open near %s" % point)

	var yard := campus.get_node_or_null("CampusShell/CentralYard")
	_check(yard != null, "Central yard must exist")
	if yard != null:
		for name in ["YardFloorSlab", "BasketballCourtPad", "ExerciseEquipmentPad", "GardenPlotSurface", "WalkingTrackNorth", "WalkingTrackSouth", "WalkingTrackWest", "WalkingTrackEast", "NorthGatePosts", "SouthGatePosts", "WestGateMain", "WestGateYard", "EastGateMain"]:
			_check(yard.has_node(name), "Central yard is missing %s" % name)
		for point in [Vector3(-26, 1.0, -18), Vector3(-26, 1.0, 23), Vector3(26, 1.0, -18), Vector3(26, 1.0, 18), Vector3(-18, 1.0, -27), Vector3(18, 1.0, 27)]:
			_check(_blocked(point), "Central yard fence has an accidental gap near %s" % point)

	var roads := campus.get_node_or_null("CampusShell/RoadsAndPaths")
	_check(roads != null, "Road and path network must exist")
	if roads != null:
		var route_endpoints := {
			"PathCellhouseA_Main": Vector2(-72, 0),
			"PathCellhouseA_Yard": Vector2(-28, 0),
			"PathCellhouseB_Main": Vector2(32.4, 0),
			"PathFoodServices_Main": Vector2(-48, -34.9),
			"PathSecurityHQ_Main": Vector2(48, -34.9),
			"PathMedical_Main": Vector2(-48, 34.9),
			"PathMaintenance_Main": Vector2(48, 34.9),
			"PathAdmin_Main": Vector2(0, 59),
			"PathYardNorth": Vector2(0, -27),
			"PathYardSouth": Vector2(0, 27),
		}
		for path_name in route_endpoints:
			var path_mesh := roads.get_node_or_null(path_name) as MeshInstance3D
			_check(path_mesh != null, "Road network is missing %s" % path_name)
			if path_mesh != null:
				_check(_mesh_rect(path_mesh).has_point(route_endpoints[path_name]), "%s does not reach its intended doorway" % path_name)


func _validate_anchors_and_budget(campus: Node3D) -> void:
	_check(campus.has_node("Buildings/CellhouseA/ParthSpawnAnchor"), "Cellhouse A requires the future Parth spawn anchor")
	_check(campus.has_node("Buildings/SecurityHQ/B2ElevatorAnchor"), "Security HQ requires a B2 elevator anchor")
	_check(campus.has_node("Buildings/Maintenance/B1TunnelAnchor"), "Maintenance requires a B1 tunnel anchor")
	_check(campus.has_node("Underground/B1ServiceTunnelsAnchor"), "Campus requires a B1 service-tunnel anchor")
	_check(campus.has_node("Underground/B2NidraFacilityAnchor"), "Campus requires a B2 NIDRA-facility anchor")
	_check(campus.get_node("Navigation").get_child_count() >= 12, "Campus needs navigation anchors for every primary route")
	var lights := campus.find_children("*", "Light3D", true, false)
	var searchlights := campus.find_children("SearchlightBeam", "SpotLight3D", true, false)
	_check(lights.size() <= 6, "Campus exceeds the Phase 1 lightweight lighting budget")
	_check(searchlights.size() <= 4, "Too many active watchtower searchlights for Web export")
	_check(_count_descendants(campus) <= 1800, "Campus exceeds the Phase 1 node budget")


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


func _footprint_rect(position: Vector3, size: Vector2) -> Rect2:
	return Rect2(Vector2(position.x - size.x * 0.5, position.z - size.y * 0.5), size)


func _mesh_rect(mesh_instance: MeshInstance3D) -> Rect2:
	var box := mesh_instance.mesh as BoxMesh
	var center := mesh_instance.global_position
	return Rect2(Vector2(center.x - box.size.x * 0.5, center.z - box.size.z * 0.5), Vector2(box.size.x, box.size.z))


func _rect_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dy := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return Vector2(dx, dy).length()


func _count_descendants(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_descendants(child)
	return total


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("CAMPUS VALIDATION: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CAMPUS FOUNDATION VALIDATION: PASS")
		get_tree().quit(0)
		return
	print("CAMPUS FOUNDATION VALIDATION: FAIL (%d checks)" % _failures.size())
	for failure in _failures:
		print(" - %s" % failure)
	get_tree().quit(1)
