extends Node3D

const Factory := preload("res://scripts/levels/greybox_factory.gd")

@export_range(2, 3, 1) var floor_number := 2
@export var is_parth_floor := false


func _ready() -> void:
	var visual_layer_mask := 32 if floor_number == 2 else 64
	var g = Factory.new(self, visual_layer_mask)
	var floor_color := Color("353633") if floor_number == 2 else Color("303230")
	var wall_color := Color("4a4b47")
	var rail_color := Color("555854")

	# Four floor bands form balcony walkways around a 14 x 24 metre void.
	g.box("NorthWalkway", Vector3(0, -0.18, -16.5), Vector3(34, 0.36, 9), floor_color)
	g.box("SouthWalkway", Vector3(0, -0.18, 16.5), Vector3(34, 0.36, 9), floor_color)
	g.box("WestWalkway", Vector3(-12, -0.18, 0), Vector3(10, 0.36, 24), floor_color)
	g.box("EastWalkway", Vector3(12, -0.18, 0), Vector3(10, 0.36, 24), floor_color)
	g.outer_walls(34, 42, 3.6, wall_color)
	# Flat, low-contrast grime breaks up the pristine primitive walls without
	# textures, transparency, decals, or extra collision.
	g.box("WestWallGrime", Vector3(-16.82, 0.48, -4), Vector3(0.04, 0.58, 25), Color("383934"), false)
	g.box("EastWallGrime", Vector3(16.82, 0.42, 6), Vector3(0.04, 0.46, 21), Color("3a3b36"), false)

	var institutional_light := Color("f0d38d")
	g.ceiling_light("CellLightWestNorth", Vector3(-10.5, 3.5, -10), institutional_light, 1.05, 6.5)
	g.ceiling_light("CellLightEastNorth", Vector3(10.5, 3.5, -10), institutional_light, 1.05, 6.5)
	g.ceiling_light("CellLightWestSouth", Vector3(-10.5, 3.5, 10), institutional_light, 1.05, 6.5)
	g.ceiling_light("CellLightEastSouth", Vector3(10.5, 3.5, 10), institutional_light, 1.05, 6.5)

	# Warm golden mood lights — low-energy amber/golden bulbs along the
	# cell galleries and corridor approaches for moody institutional atmosphere.
	var mood_gold := Color("c4a55c")
	# Gallery walkways (between cell fronts and atrium rails)
	g.ceiling_light("MoodLightWestGalleryN", Vector3(-10, 3.45, -16), mood_gold, 0.55, 5.5, Vector3(0.9, 0.07, 0.25))
	g.ceiling_light("MoodLightWestGalleryS", Vector3(-10, 3.45, 16), mood_gold, 0.55, 5.5, Vector3(0.9, 0.07, 0.25))
	g.ceiling_light("MoodLightEastGalleryN", Vector3(10, 3.45, -16), mood_gold, 0.55, 5.5, Vector3(0.9, 0.07, 0.25))
	g.ceiling_light("MoodLightEastGalleryS", Vector3(10, 3.45, 16), mood_gold, 0.55, 5.5, Vector3(0.9, 0.07, 0.25))
	# North and south corridor ends
	g.ceiling_light("MoodLightNorthCorridorW", Vector3(-5, 3.45, -18), mood_gold, 0.45, 5.0, Vector3(0.7, 0.07, 0.25))
	g.ceiling_light("MoodLightNorthCorridorE", Vector3(5, 3.45, -18), mood_gold, 0.45, 5.0, Vector3(0.7, 0.07, 0.25))
	g.ceiling_light("MoodLightSouthCorridorW", Vector3(-5, 3.45, 18), mood_gold, 0.45, 5.0, Vector3(0.7, 0.07, 0.25))
	g.ceiling_light("MoodLightSouthCorridorE", Vector3(5, 3.45, 18), mood_gold, 0.45, 5.0, Vector3(0.7, 0.07, 0.25))
	# Central bridge and stairwell approaches
	g.ceiling_light("MoodLightCenterBridge", Vector3(0, 3.45, 0), mood_gold, 0.4, 4.5, Vector3(0.7, 0.07, 0.25))
	g.ceiling_light("MoodLightStairApproach", Vector3(0, 3.45, 8), mood_gold, 0.4, 4.5, Vector3(0.7, 0.07, 0.25))

	_build_cell_row(g, -15.0, -13.0, is_parth_floor, true, false)
	_build_cell_row(g, 15.0, 13.0, false, false, is_parth_floor)
	_build_atrium_rails(g, rail_color)
	_build_wing_gates(g, rail_color)

	# CCTV Cameras monitoring cell galleries & atrium void
	g.cctv_camera("CellCamNW", Vector3(-16.85, 3.4, -18.0), 0, 35.0, -25.0, -90.0) # Wall
	g.cctv_camera("CellCamNE", Vector3(16.85, 3.4, -18.0), 0, -35.0, -25.0, 90.0) # Wall
	g.cctv_camera("CellCamSW", Vector3(-16.85, 3.4, 18.0), 0, -35.0, -25.0, -90.0) # Wall
	g.cctv_camera("CellCamSE", Vector3(16.85, 3.4, 18.0), 0, 35.0, -25.0, 90.0) # Wall
	# Keep surveillance off every bridge/stair approach. A ceiling mount above
	# the west gallery preserves atrium coverage without putting a pole on the
	# Floor 3 -> Floor 4 stair line.
	g.cctv_camera("CellCamAtriumBridge", Vector3(-10.0, 3.4, 0.0), 1, 90.0, -30.0) # Ceiling-mounted over gallery

	g.sign("HIGH SECURITY — NORTH", Vector3(0, 2.65, -14.15), Vector3(0, 180, 0), Color("d6a45b"), 0.005)
	g.sign("HIGH SECURITY — SOUTH", Vector3(0, 2.65, 14.15), Vector3.ZERO, Color("d6a45b"), 0.005)

	if floor_number == 2:
		g.bridge_x("Floor2BridgeCenter", 0.0, 7.0, 2.4, floor_color)
		g.bridge_x("Floor2BridgeSouth", 9.0, 7.0, 2.4, floor_color)
		g.stairs("Floor2ToFloor3", Vector3(7, 0, 6), Vector3.LEFT, 14.0, 4.0, 2.4, 20, wall_color)
		g.sign("CELL BLOCK — FLOOR 2", Vector3(0, 2.7, -20.7), Vector3(0, 0, 0), Color("a9bec1"), 0.006)
	else:
		g.bridge_x("Floor3BridgeNorth", -6.0, 7.0, 2.4, floor_color)
		g.bridge_x("Floor3BridgeSouth", 9.0, 7.0, 2.4, floor_color)
		g.stairs("Floor3ToFloor4", Vector3(-7, 0, 0), Vector3.RIGHT, 14.0, 4.0, 2.4, 20, wall_color)
		g.door_frame("StaffMaintenanceThreshold", Vector3(12.88, 0, 17.5), false, Color("78633d"), 1.3, 2.4)
		g.sign("CELL BLOCK — FLOOR 3", Vector3(0, 2.7, -20.7), Vector3(0, 0, 0), Color("d2c58e"), 0.006)
		g.sign("CELL 07 — PARTH", Vector3(-12.82, 2.62, -12.5), Vector3(0, -90, 0), Color("d5bf73"), 0.0024)
		g.sign("RESTRICTED MAINTENANCE", Vector3(12.82, 2.35, 17.5), Vector3(0, 90, 0), Color("d39a46"), 0.0045)
	g.sign("WEST CELL WING", Vector3(-12, 2.55, -12.25), Vector3(0, 180, 0), Color("b9bbb3"), 0.0045)
	g.sign("EAST CELL WING", Vector3(12, 2.55, -12.25), Vector3(0, 180, 0), Color("b9bbb3"), 0.0045)


const CELL_BARS := preload("res://materials/props/cell_bars.tres")

func _build_cell_row(g, cell_x: float, front_x: float, mark_parth: bool, west_side: bool, skip_last_bed: bool) -> void:
	var wall_color := Color("42433f")
	var door_color := Color("282a28")
	var bed_color := Color("565954")
	for boundary_z in [-20.0, -15.0, -10.0, -5.0, 0.0, 5.0, 10.0, 15.0, 20.0]:
		g.box("CellPartition", Vector3(cell_x, 1.55, boundary_z), Vector3(4.0, 3.1, 0.16), wall_color)
	var centers := [-17.5, -12.5, -7.5, -2.5, 2.5, 7.5, 12.5, 17.5]
	for index in range(centers.size()):
		var center_z: float = centers[index]
		var front_a: MeshInstance3D = g.box("CellFrontA", Vector3(front_x, 1.4, center_z - 1.575), Vector3(0.16, 2.8, 1.85), door_color)
		front_a.material_override = CELL_BARS
		var front_b: MeshInstance3D = g.box("CellFrontB", Vector3(front_x, 1.4, center_z + 1.575), Vector3(0.16, 2.8, 1.85), door_color)
		front_b.material_override = CELL_BARS
		var header: MeshInstance3D = g.box("CellHeader", Vector3(front_x, 2.7, center_z), Vector3(0.18, 0.3, 5.0), door_color)
		header.material_override = CELL_BARS
		if not skip_last_bed or index != centers.size() - 1:
			var bed_x := cell_x - 0.6 if west_side else cell_x + 0.6
			var color := Color("666964") if mark_parth and index == 1 else bed_color
			var side_name := "West" if west_side else "East"
			g.prison_bunk("%sCellBunk%02d" % [side_name, index], Vector3(bed_x, 0, center_z - 0.8), Vector2(1.15, 2.1), color, Color("343735"))
			g.cell_lamp("%sCellLamp%02d" % [side_name, index], Vector3(cell_x, 2.05, center_z - 2.42))
			# The Floor 3 east terminal bay remains maintenance, so its
			# neighboring prisoner cell completes that high-security pair.
			var replaces_maintenance_pair := skip_last_bed and index == centers.size() - 2
			if index == 0 or index == centers.size() - 1 or replaces_maintenance_pair:
				_build_high_security_cell(g, cell_x, front_x, center_z, west_side, side_name, index)


func _build_high_security_cell(g, cell_x: float, front_x: float, center_z: float, west_side: bool, side_name: String, index: int) -> void:
	var prefix := "%sHighSecurityCell%02d" % [side_name, index]
	g.box("%sFloor" % prefix, Vector3(cell_x, 0.025, center_z), Vector3(3.7, 0.05, 4.7), Color("292c2a"), false)
	# The actual barrier is an interactive reinforced-glass sliding door spawned
	# by CellBlockPrototype. Keeping it out of static floor geometry ensures the
	# visible panel and collision move together when authorized.
	var rear_x := -16.78 if west_side else 16.78
	g.box("%sRestraintAnchor" % prefix, Vector3(rear_x, 1.15, center_z + 0.75), Vector3(0.14, 0.35, 0.45), Color("4d514d"), false)
	var sign_x := front_x + (0.18 if west_side else -0.18)
	var sign_rotation := Vector3(0, -90, 0) if west_side else Vector3(0, 90, 0)
	var wing_name := "NORTH" if center_z < 0.0 else "SOUTH"
	g.sign("HIGH SECURITY %s" % wing_name, Vector3(sign_x, 3.02, center_z), sign_rotation, Color("d6a45b"), 0.003)


func _build_atrium_rails(g, color: Color) -> void:
	# Gaps line up with bridge and stair lanes at z=-6, 0, 6, and 9.
	var spans := [[-12.0, -7.3], [-4.7, -1.3], [1.3, 4.7], [7.3, 7.8], [10.2, 12.0]]
	for span in spans:
		g.railing(Vector3(-7, 0, span[0]), Vector3(-7, 0, span[1]), color)
		g.railing(Vector3(7, 0, span[0]), Vector3(7, 0, span[1]), color)
	g.railing(Vector3(-7, 0, 12), Vector3(7, 0, 12), color)
	if floor_number == 3:
		# One deliberate future traversal gap overlooks the atrium.
		g.railing(Vector3(-7, 0, -12), Vector3(-1.2, 0, -12), color)
		g.railing(Vector3(1.2, 0, -12), Vector3(7, 0, -12), color)
	else:
		g.railing(Vector3(-7, 0, -12), Vector3(7, 0, -12), color)


func _build_wing_gates(g, color: Color) -> void:
	# Open center doorways preserve circulation while barred side panels create
	# visible security thresholds between north/south wings and side galleries.
	for x in [-10.0, 10.0]:
		# Gates span only the six-metre gallery between the cell fronts and
		# atrium rails; they never pass through the cells themselves.
		g.security_gate("NorthWingGate", Vector3(x, 0, -14.0), 5.6, true, 0.0, 1.6, color, 2.8, 0.64)
		g.security_gate("SouthWingGate", Vector3(x, 0, 14.0), 5.6, true, 0.0, 1.6, color, 2.8, 0.64)
