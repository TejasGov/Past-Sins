extends Node3D
class_name CellhouseAInterior

const Factory := preload("res://scripts/levels/greybox_factory.gd")
const CELL_SCENE := preload("res://scenes/levels/campus/modules/CampusPrisonCell.tscn")
const GUARD_ELEVATOR_CORE_SCENE := preload("res://scenes/levels/campus/modules/CampusGuardElevatorCore.tscn")
const SECURITY_CONSOLE := preload("res://scenes/props/security/SecurityConsole.tscn")
const BENCH_SCENE := preload("res://scenes/props/common/Bench.tscn")
const NOTICE_BOARD := preload("res://scenes/props/common/NoticeBoard.tscn")
const WALL_CLOCK := preload("res://scenes/props/common/WallClock.tscn")
const TRASH_BIN := preload("res://scenes/props/common/TrashBin.tscn")
const CLEANING_CART := preload("res://scenes/props/cafeteria/CleaningCart.tscn")
const DRINKING_FOUNTAIN := preload("res://scenes/props/cafeteria/DrinkingFountain.tscn")
const CCTV := preload("res://scenes/props/security/CCTVCamera.tscn")
const DETAIL_SCENE := preload("res://scenes/props/common/CampusDetailProp.tscn")
const Detail := preload("res://scripts/props/campus_detail_prop.gd")
const STAIR_FLIGHT_SCENE := preload("res://scenes/levels/campus/modules/CampusStairFlight.tscn")

@export_flags_3d_render var visual_layer_mask := 1

const FLOOR_HEIGHT := 4.0
const NORTH_CELL_Z := -13.85
const SOUTH_CELL_Z := 13.85
const CELL_X_POSITIONS := [-17.5, -12.5, -7.5, -2.5, 2.5, 7.5, 12.5, 17.5]


func _ready() -> void:
	add_to_group("campus_interiors")
	_build_structure()
	_build_cells()
	_build_markers()


func _build_structure() -> void:
	var g = Factory.new(self, visual_layer_mask)
	var concrete := Color("3c403d")
	var floor_color := Color("303330")
	var rail_color := Color("555b57")

	# Cellhouse A is now a purpose-built three-floor cell building. No basement,
	# cafeteria, gym, medical, laboratory, surveillance, or roof gameplay floor
	# is instanced here.
	g.box("GroundInteriorFinish", Vector3(0, -0.025, 0), Vector3(43.2, 0.05, 33.2), floor_color)

	for tier_index in [1, 2]:
		var floor_y := float(tier_index) * FLOOR_HEIGHT
		var prefix := "Floor%d" % (tier_index + 1)
		# Continuous north/south slabs cover both cells and gallery. They overlap
		# the crosswalk/bridge by 10cm, eliminating the corner holes visible in
		# the first version while preserving the central void.
		g.box("%sNorthGallery" % prefix, Vector3(0, floor_y - 0.08, -11.85), Vector3(43.2, 0.16, 9.7), floor_color)
		g.box("%sSouthGallery" % prefix, Vector3(0, floor_y - 0.08, 11.85), Vector3(43.2, 0.16, 9.7), floor_color)
		_build_crosswalk_floors(g, prefix, floor_y, tier_index, floor_color)
		g.box("%sCentralBridge" % prefix, Vector3(0, floor_y - 0.08, 0), Vector3(4.2, 0.16, 14.2), floor_color)

		# Inner railings leave deliberate openings only at the center bridge and
		# end crosswalk/stair lanes. The central void remains visibly three storeys tall.
		_build_connected_atrium_rails(g, floor_y, tier_index, rail_color)

	# Two separated, smooth-ramp stair flights connect all three cell floors.
	_build_stair("Floor1ToFloor2Stair", Vector3(-18.0, 0, -7.0), 0.0)
	_build_stair("Floor2ToFloor3Stair", Vector3(18.0, FLOOR_HEIGHT, 7.0), PI)

	# Four fixed flush-mounted fixtures share one real source per tier. The source
	# selects a nearby fixture instead of leaving the entire southern/eastern
	# galleries outside a permanently northwest-anchored light's range.
	for tier_index in range(3):
		var base_y := float(tier_index) * FLOOR_HEIGHT
		var fixture_y := 12.86 if tier_index == 2 else base_y + 3.80
		var sources := PackedVector3Array()
		for gallery_side in [-1.0, 1.0]:
			for fixture_index in range(2):
				var x_position := -10.0 + float(fixture_index) * 20.0
				var fixture_name := "Floor%dGalleryTube%s%02d" % [tier_index + 1, "N" if gallery_side < 0 else "S", fixture_index]
				# Backplate and diffuser touch the ceiling directly: no hanging stem.
				g.box("%sBackplate" % fixture_name, Vector3(x_position, fixture_y, gallery_side * 9.25), Vector3(2.25, 0.07, 0.36), concrete, false)
				var diffuser: MeshInstance3D = g.emissive_box(fixture_name, Vector3(x_position, fixture_y - 0.055, gallery_side * 9.25), Vector3(2.0, 0.045, 0.22), Color(0.82, 0.88, 0.80), 0.72)
				diffuser.add_to_group("campus_indoor_light_visuals")
				diffuser.set_meta("automatic_night_light", true)
				sources.append(Vector3(x_position, fixture_y - 0.25, gallery_side * 9.25))
		var night_light := preload("res://scripts/systems/gallery_lighting.gd").new()
		night_light.name = "Floor%dAmberGalleryLight" % (tier_index + 1)
		night_light.floor_number = tier_index + 1
		night_light.fixture_positions = sources
		night_light.position = sources[0]
		preload("res://scripts/systems/interior_lighting_profiles.gd").apply_to_light(night_light, "cellblock")
		night_light.omni_range = 14.0
		night_light.shadow_enabled = false
		night_light.visible = false
		add_child(night_light)

	g.sign("CELLHOUSE A — THREE-TIER GENERAL POPULATION", Vector3(0, 3.0, -16.75), Vector3.ZERO, Color("d7d0aa"), 0.0045)
	g.sign("YARD ACCESS", Vector3(21.55, 2.8, 0), Vector3(0, -90, 0), Color("d7c176"), 0.004)
	g.sign("FLOOR 1", Vector3(-21.55, 2.6, -5.0), Vector3(0, 90, 0), Color("b8c9c4"), 0.0035)
	g.sign("FLOOR 2", Vector3(-21.55, 6.6, -5.0), Vector3(0, 90, 0), Color("b8c9c4"), 0.0035)
	g.sign("FLOOR 3", Vector3(-21.55, 10.6, -5.0), Vector3(0, 90, 0), Color("d7c176"), 0.0035)

	_place_prop(SECURITY_CONSOLE, "OfficerControlDesk", Vector3(5.0, 0.0, 2.6), 180.0)
	_place_prop(BENCH_SCENE, "DayroomBenchWest", Vector3(-5.0, 0.0, 3.8), 90.0)
	_place_prop(BENCH_SCENE, "DayroomBenchEast", Vector3(5.0, 0.0, 3.8), -90.0)
	_place_prop(BENCH_SCENE, "DayroomBenchNorth", Vector3(-5.0, 0.0, -3.8), 90.0)
	_place_prop(BENCH_SCENE, "DayroomBenchSouth", Vector3(5.0, 0.0, -3.8), -90.0)
	_place_prop(TRASH_BIN, "DayroomTrashWest", Vector3(-13.8, 0.0, 5.7), 0.0)
	_place_prop(TRASH_BIN, "DayroomTrashEast", Vector3(13.8, 0.0, 5.7), 0.0)
	_place_prop(CLEANING_CART, "DayroomCleaningStation", Vector3(-13.5, 0.0, -5.4), 90.0)
	_place_prop(DRINKING_FOUNTAIN, "DayroomWaterFountain", Vector3(21.35, 0.0, 4.6), -90.0)
	_place_prop(NOTICE_BOARD, "GroundMovementBoard", Vector3(-21.35, 0.0, 4.7), 90.0)
	_place_prop(WALL_CLOCK, "GroundInstitutionalClock", Vector3(21.35, 0.0, -4.6), -90.0)
	_place_detail("GroundElectricalBox", Detail.DetailKind.ELECTRICAL_BOX, Vector3(-21.35, 0.0, -4.8), 90.0)
	_place_detail("GroundUtilityPipes", Detail.DetailKind.UTILITY_PIPE_RUN, Vector3(21.35, 0.0, -5.8), -90.0)
	for tier_index in range(3):
		var floor_y := float(tier_index) * FLOOR_HEIGHT
		_place_prop(CCTV, "Floor%dCameraWest" % (tier_index + 1), Vector3(-21.3, floor_y + 3.05, -5.8), 90.0)
		_place_prop(CCTV, "Floor%dCameraEast" % (tier_index + 1), Vector3(21.3, floor_y + 3.05, 5.8), -90.0)
		if tier_index > 0:
			_place_prop(NOTICE_BOARD, "Floor%dMovementBoard" % (tier_index + 1), Vector3(-21.35, floor_y, 4.8), 90.0)
			_place_prop(WALL_CLOCK, "Floor%dClock" % (tier_index + 1), Vector3(21.35, floor_y, -4.8), -90.0)
		g.sign("LEVEL %d · CONTROLLED MOVEMENT" % (tier_index + 1), Vector3(0, floor_y + 2.95, 16.75), Vector3(0, 180, 0), Color("c9c397"), 0.0027)


func _build_crosswalk_floors(g, prefix: String, floor_y: float, tier_index: int, floor_color: Color) -> void:
	# Receiving floors contain a real stairwell opening. Only the outside bypass
	# strip and a short top landing remain above the stair run, preserving full
	# standing headroom instead of putting a ceiling slab over the upper treads.
	if tier_index == 1:
		g.box("%sWestCrosswalkOuter" % prefix, Vector3(-20.45, floor_y - 0.08, 0), Vector3(2.3, 0.16, 14.2), floor_color)
		g.box("%sWestCrosswalkLanding" % prefix, Vector3(-18.0, floor_y - 0.08, 7.4), Vector3(2.6, 0.16, 0.8), floor_color)
	else:
		g.box("%sWestCrosswalk" % prefix, Vector3(-19.15, floor_y - 0.08, 0), Vector3(4.9, 0.16, 14.2), floor_color)

	if tier_index == 2:
		g.box("%sEastCrosswalkOuter" % prefix, Vector3(20.45, floor_y - 0.08, 0), Vector3(2.3, 0.16, 14.2), floor_color)
		g.box("%sEastCrosswalkLanding" % prefix, Vector3(18.0, floor_y - 0.08, -7.4), Vector3(2.6, 0.16, 0.8), floor_color)
	else:
		g.box("%sEastCrosswalk" % prefix, Vector3(19.15, floor_y - 0.08, 0), Vector3(4.9, 0.16, 14.2), floor_color)


func _build_stair(stair_name: String, start: Vector3, yaw: float) -> void:
	var flight := STAIR_FLIGHT_SCENE.instantiate() as CampusStairFlight
	flight.name = stair_name
	flight.position = start
	flight.rotation.y = yaw
	flight.run = 14.0
	flight.rise = FLOOR_HEIGHT
	flight.width = 2.6
	flight.steps = 20
	flight.visual_layer_mask = visual_layer_mask
	add_child(flight)


func _build_connected_atrium_rails(g, floor_y: float, tier_index: int, rail_color: Color) -> void:
	const BRIDGE_EDGE := 2.1
	const WEST_STAIR_OUTER := -19.24
	const WEST_STAIR_INNER := -16.76
	const EAST_STAIR_INNER := 16.76
	const EAST_STAIR_OUTER := 19.24

	# Follow the *exposed slab edge*. The outside bypass stays open at both
	# gallery corners, and receives its own level rail above descending stairs.
	var north_west_end := WEST_STAIR_OUTER if tier_index == 1 else WEST_STAIR_INNER
	var south_east_end := EAST_STAIR_OUTER if tier_index == 2 else EAST_STAIR_INNER
	g.railing(Vector3(north_west_end, floor_y, -7), Vector3(-BRIDGE_EDGE, floor_y, -7), rail_color)
	g.railing(Vector3(BRIDGE_EDGE, floor_y, -7), Vector3(EAST_STAIR_INNER, floor_y, -7), rail_color)
	g.railing(Vector3(WEST_STAIR_INNER, floor_y, 7), Vector3(-BRIDGE_EDGE, floor_y, 7), rail_color)
	g.railing(Vector3(BRIDGE_EDGE, floor_y, 7), Vector3(south_east_end, floor_y, 7), rail_color)
	if tier_index == 1:
		g.railing(Vector3(WEST_STAIR_OUTER, floor_y, -7), Vector3(WEST_STAIR_OUTER, floor_y, 7), rail_color)
		g.railing(Vector3(EAST_STAIR_INNER, floor_y, -7), Vector3(EAST_STAIR_INNER, floor_y, 7), rail_color)
	else:
		g.railing(Vector3(EAST_STAIR_OUTER, floor_y, -7), Vector3(EAST_STAIR_OUTER, floor_y, 7), rail_color)

	# Bridge sides turn the gallery rails through 90 degrees; there is never an
	# exposed edge at a bridge opening.
	g.railing(Vector3(-BRIDGE_EDGE, floor_y, -7.0), Vector3(-BRIDGE_EDGE, floor_y, 7.0), rail_color)
	g.railing(Vector3(BRIDGE_EDGE, floor_y, -7.0), Vector3(BRIDGE_EDGE, floor_y, 7.0), rail_color)

	# Floor 3's west crosswalk has no stair. Its rail follows the actual inner
	# floor edge instead of cutting across the landing surface.
	if tier_index == 2:
		g.railing(Vector3(WEST_STAIR_INNER, floor_y, -7.0), Vector3(WEST_STAIR_INNER, floor_y, 7.0), rail_color)


func _build_cells() -> void:
	for tier_index in range(3):
		var tier_y := float(tier_index) * FLOOR_HEIGHT
		for index in range(CELL_X_POSITIONS.size()):
			# The north-east corner is a vertically aligned service core on every
			# floor, replacing only one ordinary cell per tier.
			var is_parth := tier_index == 2 and index == 2
			if index != CELL_X_POSITIONS.size() - 1:
				_spawn_cell("North", index + 1, Vector3(CELL_X_POSITIONS[index], tier_y, NORTH_CELL_Z), -90.0, tier_index, is_parth)
			_spawn_cell("South", index + 1, Vector3(CELL_X_POSITIONS[index], tier_y, SOUTH_CELL_Z), 90.0, tier_index, false)
		_spawn_guard_elevator_core(tier_index)


func _spawn_guard_elevator_core(tier_index: int) -> void:
	var core := GUARD_ELEVATOR_CORE_SCENE.instantiate() as CampusGuardElevatorCore
	core.name = "Floor%dGuardElevatorCore" % (tier_index + 1)
	core.position = Vector3(CELL_X_POSITIONS[-1], float(tier_index) * FLOOR_HEIGHT, NORTH_CELL_Z)
	core.floor_number = tier_index + 1
	core.visual_layer_mask = visual_layer_mask
	add_child(core)


func _spawn_cell(side: String, number: int, cell_position: Vector3, yaw: float, tier_index: int, is_parth: bool) -> void:
	var cell := CELL_SCENE.instantiate() as CampusPrisonCell
	var floor_number := tier_index + 1
	var cell_id := "cellhouse_a_floor%d_%s_%02d" % [floor_number, side.to_lower(), number]
	cell.name = "ParthCell" if is_parth else "Floor%d%sCell%02d" % [floor_number, side, number]
	cell.position = cell_position
	cell.rotation_degrees.y = yaw
	cell.cell_access_id = StringName(cell_id)
	cell.cell_display_name = "Parth's Cell" if is_parth else "Cellhouse A Floor %d %s Cell %02d" % [floor_number, side, number]
	cell.cell_number_label = "A-%d-%s%02d" % [floor_number, side.left(1).to_upper(), number]
	cell.front_direction = 1.0
	cell.upper_tier = tier_index > 0
	cell.is_parth_cell = is_parth
	cell.visual_layer_mask = visual_layer_mask
	cell.set_meta("campus_floor_number", floor_number)
	add_child(cell)


func _build_markers() -> void:
	_create_access_marker("MainEntranceGateMarker", Vector3(-22.44, 0, 0), 90.0, "Cellhouse A Main Gate", 2.7, 3.15)
	_create_access_marker("YardExitGateMarker", Vector3(22.44, 0, 0), 90.0, "Cellhouse A Yard Gate", 2.7, 3.15)
	var g = Factory.new(self, visual_layer_mask)
	for side in [-1.0, 1.0]:
		for edge in [-1.0, 1.0]:
			g.box("ExteriorGateReveal", Vector3(side * 22.17, 1.25, edge * 1.4), Vector3(0.34, 2.5, 0.1), Color("555d56"))

	var patrol_positions := [
		Vector3(-8.0, 0, -4.5), Vector3(8.0, 0, -4.5),
		Vector3(8.0, 0, 4.5), Vector3(-8.0, 0, 4.5),
	]
	for index in range(patrol_positions.size()):
		var marker := Marker3D.new()
		marker.name = "DayroomPatrolPoint%02d" % index
		marker.position = patrol_positions[index]
		marker.add_to_group("cellhouse_a_patrol_points")
		add_child(marker)

	var navigation_positions := [
		Vector3(-20.0, 0.1, 0), Vector3(20.0, 0.1, 0),
		Vector3(-18.0, 4.1, 7.0), Vector3(0, 4.1, 0),
		Vector3(18.0, 8.1, -7.0), Vector3(0, 8.1, 0),
	]
	for index in range(navigation_positions.size()):
		var nav_marker := Marker3D.new()
		nav_marker.name = "InteriorNavAnchor%02d" % index
		nav_marker.position = navigation_positions[index]
		nav_marker.add_to_group("cellhouse_a_navigation_anchors")
		add_child(nav_marker)


func _create_access_marker(marker_name: String, marker_position: Vector3, yaw: float, display_name: String, width: float, travel: float) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = marker_position
	marker.rotation_degrees.y = yaw
	marker.add_to_group("cellhouse_a_access_markers")
	marker.set_meta("display_name", display_name)
	marker.set_meta("gate_width", width)
	marker.set_meta("slide_distance", travel)
	add_child(marker)


func _place_prop(scene: PackedScene, prop_name: String, prop_position: Vector3, yaw: float) -> void:
	var prop := scene.instantiate() as Node3D
	prop.name = prop_name
	prop.position = prop_position
	prop.rotation_degrees.y = yaw
	prop.set("visual_layer_mask", visual_layer_mask)
	prop.set_meta("placement_zone", "Cellhouse A")
	add_child(prop)


func _place_detail(prop_name: String, kind: int, prop_position: Vector3, yaw: float, text := "") -> void:
	var prop := DETAIL_SCENE.instantiate() as CampusDetailProp
	prop.name = prop_name
	prop.detail_kind = kind
	if not text.is_empty(): prop.display_text = text
	prop.position = prop_position
	prop.rotation_degrees.y = yaw
	prop.visual_layer_mask = visual_layer_mask
	prop.set_meta("placement_zone", "Cellhouse A")
	add_child(prop)
