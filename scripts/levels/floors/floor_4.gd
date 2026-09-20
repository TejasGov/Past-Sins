extends Node3D

const Factory := preload("res://scripts/levels/greybox_factory.gd")


func _ready() -> void:
	var g = Factory.new(self, 128)
	var floor_color := Color("202323")
	var wall_color := Color("343938")
	var console_color := Color("263537")
	var restricted_color := Color("3e342c")
	var server_color := Color("1b2024")

	# Central Floor & Outer Walls
	g.box("NorthFloor", Vector3(0, -0.18, -12.5), Vector3(34, 0.36, 17), floor_color)
	g.box("SouthFloor", Vector3(0, -0.18, 12.5), Vector3(34, 0.36, 17), floor_color)
	g.box("WestFloor", Vector3(-12, -0.18, 0), Vector3(10, 0.36, 8), floor_color)
	g.box("EastFloor", Vector3(12, -0.18, 0), Vector3(10, 0.36, 8), floor_color)
	g.outer_walls(34, 42, 3.6, wall_color)

	# Surveillance and Monitor / Control Center Walls
	# Both entrances sit fully over the west/east floor bands. The former
	# openings at x=-6.75 and x=3.75 hung on the edges of the atrium void and
	# could not be approached safely from the stair landing.
	for wall_piece in [[-13.125, 7.75], [0.0, 15.5], [13.125, 7.75]]:
		g.box("ControlRoomWall", Vector3(wall_piece[0], 1.65, -4.5), Vector3(wall_piece[1], 3.3, 0.22), wall_color)
	g.door_frame("SurveillanceDoorWest", Vector3(-8.5, 0, -4.5), true, Color("48504f"), 1.5)
	g.door_frame("SurveillanceDoorEast", Vector3(8.5, 0, -4.5), true, Color("48504f"), 1.5)

	# Check-in Metal Detector at Main Surveillance Entry Corridor
	g.metal_detector("Floor4EntryCheckIn", Vector3(8.5, 0, -3.35), 0.0)

	# ==================================================
	# LARGE SURVEILLANCE MONITOR WALL (North Wall z = -20.6)
	# ==================================================
	# Background wall mounting frame
	g.box("MonitorWallFrame", Vector3(0, 2.1, -20.7), Vector3(28.0, 2.6, 0.12), Color("15191b"))

	# Grid of 8 main surveillance screens
	var screen_labels := [
		"CAM 01 — CELL BLOCK A",
		"CAM 02 — CELL BLOCK B",
		"CAM 03 — CAFETERIA",
		"CAM 04 — MAIN YARD",
		"CAM 05 — B1 MEDICAL",
		"CAM 06 — B2 LAB VAULT",
		"CAM 07 — STAIRWELL",
		"CAM 08 — SIGNAL LOST"
	]
	var screen_colors := [
		Color("19464a"), Color("19464a"), Color("1f4a3e"), Color("24452f"),
		Color("1a3848"), Color("2d2e4d"), Color("19464a"), Color("401d1d")
	]

	for row in range(2):
		for col in range(4):
			var idx := row * 4 + col
			var screen_x := -10.5 + col * 7.0
			var screen_y := 2.7 - row * 1.15
			g.monitor_wall_screen(
				"WallMonitor_%02d" % idx,
				Vector3(screen_x, screen_y, -20.62),
				Vector3(6.4, 0.95, 0.08),
				screen_labels[idx],
				screen_colors[idx]
			)

	# Operator Desks & Workstations along the Monitor Wall
	for index in range(7):
		var x: float = [-12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0][index]
		g.supported_surface("MonitorConsole%02d" % index, Vector3(x, 0, -10), Vector2(2.7, 0.85), 1.35, 0.16, console_color, Color("1c2829"))
		g.emissive_box("MonitorDisplay%02d" % index, Vector3(x, 1.85, -10.5), Vector3(2.3, 1.25, 0.15), Color("4f8f91"), 0.55)
		# Keyboard & Control Panel
		g.box("Keyboard%02d" % index, Vector3(x - 0.4, 1.38, -9.8), Vector3(0.7, 0.04, 0.26), Color("181d1f"), false)
		g.box("ControlPanel%02d" % index, Vector3(x + 0.5, 1.39, -9.8), Vector3(0.5, 0.05, 0.24), Color("283236"), false)
		# Operator Office Chair
		g.simple_chair("OperatorChair%02d" % index, Vector3(x, 0, -8.8), Color("1e2629"), Color("121618"))

	# Central Command Island Console
	g.supported_surface("ControlIsland", Vector3(0, 0, -16), Vector2(8.0, 1.3), 1.35, 0.18, console_color, Color("1c2829"))
	g.box("IslandControlPanelA", Vector3(-2.2, 1.4, -16.0), Vector3(1.8, 0.08, 0.6), Color("242d30"), false)
	g.box("IslandControlPanelB", Vector3(2.2, 1.4, -16.0), Vector3(1.8, 0.08, 0.6), Color("242d30"), false)
	g.emissive_box("TacticalScreenCenter", Vector3(0, 1.75, -16.4), Vector3(2.2, 0.7, 0.1), Color("28707a"), 0.8)
	g.sign("TACTICAL OVERWATCH", Vector3(0, 1.75, -16.32), Vector3.ZERO, Color("76f5ff"), 0.0035)

	# Partition Divider Wall
	g.partition_with_door("ControlSurveillanceDivider", Vector3(0, 0, -14), 33.4, true, 0.0, 1.6, wall_color)
	g.door_frame("ControlRoomDoor", Vector3(0, 0, -14), true, Color("4d6363"), 1.6)

	# Tactical Security Map Board on Control Divider Wall
	g.security_map_board("Floor4MapBoard", Vector3(-8.0, 2.0, -13.92), Vector3(0, 180, 0), Vector3(3.2, 1.6, 0.08))

	# Server Racks lining the East Wall of Surveillance Room (x = 15.8, z = -18..-10)
	for idx in range(4):
		var z_pos := -18.5 + idx * 2.2
		g.server_rack("ServerRack_%02d" % idx, Vector3(15.8, 1.1, z_pos), Vector3(0.9, 2.2, 0.95), server_color)

	# Filing & Communications Equipment Cabinets (x = -15.8, z = -18..-10)
	for idx in range(3):
		var z_pos := -18.0 + idx * 2.5
		g.storage_shelf("CommsCabinet_%02d" % idx, Vector3(-15.8, 0, z_pos), Vector3(0.8, 2.1, 1.2), Color("323a3d"))

	# Ambient Screen Lighting
	var monitor_light := Color("f0d38d")
	g.ceiling_light("ControlLightWest", Vector3(-9, 3.35, -12), monitor_light, 0.5, 7.0)
	g.ceiling_light("ControlLightCenter", Vector3(0, 3.35, -12), monitor_light, 0.5, 7.0)
	g.ceiling_light("ControlLightEast", Vector3(9, 3.35, -12), monitor_light, 0.5, 7.0)

	# CCTV Cameras in Floor 4 Control Room & Elevator Corridor
	g.cctv_camera("Floor4CamControlRoom", Vector3(15.5, 3.4, -19.5), 1, 225.0, -30.0) # Ceiling
	g.cctv_camera("Floor4CamCorridor", Vector3(-15.5, 3.4, -4.0), 1, 135.0, -25.0) # Ceiling
	g.cctv_camera("Floor4CamLift", Vector3(16.85, 3.4, 7.5), 0, -35.0, -20.0, 90.0) # Wall

	# Offices and evidence/security storage
	g.wall_segment("OfficeDivider", Vector3(-5, 0, 12.825), 16.05, false, wall_color)
	g.wall_segment("EvidenceDivider", Vector3(6, 0, 12.825), 16.05, false, wall_color)
	g.partition_with_door("OfficeAccessWall", Vector3(-10.925, 0, 4.8), 11.85, true, 0.925, 1.5, wall_color)
	g.partition_with_door("StaffLobbyAccessWall", Vector3(0.5, 0, 4.8), 11.0, true, 0.0, 1.5, wall_color)
	g.partition_with_door("EvidenceAccessWall", Vector3(11.425, 0, 4.8), 10.85, true, -2.425, 1.5, wall_color)
	g.partition_with_door("RestrictedCorridorWall", Vector3(2.8, 0, 12.825), 16.05, false, -5.625, 1.4, wall_color)

	for index in range(3):
		var z: float = [7.0, 12.0, 17.0][index]
		g.supported_surface("OfficeDesk%02d" % index, Vector3(-11, 0, z), Vector2(3.0, 1.0), 1.05, 0.16, Color("4b504f"), Color("303534"))
		g.simple_chair("OfficeChair%02d" % index, Vector3(-11, 0, z - 0.9), Color("303534"), Color("202423"))
	for index in range(3):
		var z: float = [7.0, 9.5, 17.0][index]
		g.storage_shelf("EvidenceRack%02d" % index, Vector3(9.5, 0, z), Vector3(4.0, 2.2, 0.55), Color("444947"))

	# A dedicated, collision-backed key-control board identifies the deliberate
	# Floor 4 storage location used by the individually collectible cell keys.
	# The future police-chief master key is intentionally absent from this board.
	g.box("CellKeyStorageBoard", Vector3(16.63, 1.65, 15.55), Vector3(0.1, 3.3, 8.8), Color("202a2a"))
	for z in [12.75, 14.95, 17.15, 19.35]:
		g.box("CellKeyBoardDivider", Vector3(16.56, 1.65, z), Vector3(0.05, 3.05, 0.045), Color("64706d"), false)
	g.sign("CELL KEY STORAGE — INDIVIDUAL ACCESS", Vector3(16.5, 3.32, 15.55), Vector3(0, -90, 0), Color("d5b95f"), 0.0035)
	g.sign("MASTER KEY — POLICE CHIEF", Vector3(16.49, 0.32, 15.55), Vector3(0, -90, 0), Color("9d6b55"), 0.0028)

	g.box("RestrictedCorridor", Vector3(4, 0.02, 11), Vector3(2.0, 0.05, 18), restricted_color, false)
	g.security_gate("RoofStairEnclosure", Vector3(10.5, 0, 15.425), 10.85, false, -2.425, 1.5, Color("46504e"))
	g.wall_segment("RoofStairNorthWall", Vector3(13.675, 0, 10.0), 6.35, true, wall_color)
	g.box("LiftAccessDoor", Vector3(16.78, 1.25, 8.5), Vector3(0.12, 2.5, 1.8), Color("252b2a"))
	g.door_frame("LiftAccessFrame", Vector3(16.62, 0, 8.5), false, Color("586360"), 1.8, 2.5)

	# Guardrails around the stair arrival opening
	g.railing(Vector3(-7, 0, -4), Vector3(-7, 0, 4), wall_color)
	g.railing(Vector3(-7, 0, -4), Vector3(7, 0, -4), wall_color)
	g.railing(Vector3(-7, 0, 4), Vector3(7, 0, 4), wall_color)
	g.stairs("Floor4ToRoof", Vector3(13.5, 0, 12), Vector3.BACK, 7.0, 4.0, 2.5, 20, wall_color)

	# Signage
	g.sign("SURVEILLANCE COMMAND", Vector3(0, 2.7, -20.5), Vector3(0, 0, 0), Color("76c2d2"), 0.007)
	g.sign("MONITOR / CONTROL", Vector3(0, 2.5, -4.35), Vector3(0, 0, 0), Color("8ecbd5"), 0.005)
	g.sign("CONTROL ROOM", Vector3(0, 2.5, -13.85), Vector3(0, 0, 0), Color("8ecbd5"), 0.005)
	g.sign("SECURITY OFFICES", Vector3(-8.5, 2.5, 4.7), Vector3(0, 180, 0), Color("a8b9bb"), 0.005)
	g.sign("RESTRICTED — EVIDENCE STORAGE", Vector3(6.2, 2.5, 10), Vector3(0, 90, 0), Color("d09a55"), 0.0045)
	g.sign("STAIR / LIFT ACCESS", Vector3(16.5, 2.75, 8.5), Vector3(0, -90, 0), Color("b8c5c2"), 0.004)
