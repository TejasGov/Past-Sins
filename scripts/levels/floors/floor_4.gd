extends Node3D

const Factory := preload("res://scripts/levels/greybox_factory.gd")


func _ready() -> void:
	var g = Factory.new(self, 128)
	var floor_color := Color("202323")
	var wall_color := Color("343938")
	var console_color := Color("263537")
	var restricted_color := Color("3e342c")

	# A smaller central opening receives the stair from Floor 3.
	g.box("NorthFloor", Vector3(0, -0.18, -12.5), Vector3(34, 0.36, 17), floor_color)
	g.box("SouthFloor", Vector3(0, -0.18, 12.5), Vector3(34, 0.36, 17), floor_color)
	g.box("WestFloor", Vector3(-12, -0.18, 0), Vector3(10, 0.36, 8), floor_color)
	g.box("EastFloor", Vector3(12, -0.18, 0), Vector3(10, 0.36, 8), floor_color)
	g.outer_walls(34, 42, 3.6, wall_color)

	# Surveillance and monitor/control center.
	for wall_piece in [[-12.25, 9.5], [-1.5, 9.0], [10.75, 12.5]]:
		g.box("ControlRoomWall", Vector3(wall_piece[0], 1.65, -4.5), Vector3(wall_piece[1], 3.3, 0.22), wall_color)
	g.door_frame("SurveillanceDoorWest", Vector3(-6.75, 0, -4.5), true, Color("48504f"), 1.5)
	g.door_frame("SurveillanceDoorEast", Vector3(3.75, 0, -4.5), true, Color("48504f"), 1.5)
	for index in range(7):
		var x: float = [-12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0][index]
		g.supported_surface("MonitorConsole%02d" % index, Vector3(x, 0, -10), Vector2(2.7, 0.85), 1.35, 0.16, console_color, Color("1c2829"))
		# The display's lower edge and front face now overlap the console top, so it
		# reads as a mounted workstation rather than a panel floating behind it.
		g.emissive_box("MonitorDisplay%02d" % index, Vector3(x, 1.85, -10.5), Vector3(2.3, 1.25, 0.15), Color("4f8f91"), 0.55)
	g.supported_surface("ControlIsland", Vector3(0, 0, -16), Vector2(8.0, 1.3), 1.35, 0.18, console_color, Color("1c2829"))
	g.partition_with_door("ControlSurveillanceDivider", Vector3(0, 0, -14), 33.4, true, 0.0, 1.6, wall_color)
	g.door_frame("ControlRoomDoor", Vector3(0, 0, -14), true, Color("4d6363"), 1.6)
	var monitor_light := Color("6ea5a6")
	g.ceiling_light("ControlLightWest", Vector3(-9, 3.35, -12), monitor_light, 0.5, 7.0)
	g.ceiling_light("ControlLightCenter", Vector3(0, 3.35, -12), monitor_light, 0.5, 7.0)
	g.ceiling_light("ControlLightEast", Vector3(9, 3.35, -12), monitor_light, 0.5, 7.0)

	# Offices and evidence/security storage.
	# Exact wall-to-wall room rectangles keep the office, staff lobby, evidence
	# room, and restricted passage from bleeding into one another at their ends.
	g.wall_segment("OfficeDivider", Vector3(-5, 0, 12.825), 16.05, false, wall_color)
	g.wall_segment("EvidenceDivider", Vector3(6, 0, 12.825), 16.05, false, wall_color)
	g.partition_with_door("OfficeAccessWall", Vector3(-10.925, 0, 4.8), 11.85, true, 0.925, 1.5, wall_color)
	g.partition_with_door("StaffLobbyAccessWall", Vector3(0.5, 0, 4.8), 11.0, true, 0.0, 1.5, wall_color)
	g.partition_with_door("EvidenceAccessWall", Vector3(11.425, 0, 4.8), 10.85, true, -2.425, 1.5, wall_color)
	g.partition_with_door("RestrictedCorridorWall", Vector3(2.8, 0, 12.825), 16.05, false, -5.625, 1.4, wall_color)
	for index in range(3):
		var z: float = [7.0, 12.0, 17.0][index]
		g.supported_surface("OfficeDesk%02d" % index, Vector3(-11, 0, z), Vector2(3.0, 1.0), 1.05, 0.16, Color("4b504f"), Color("303534"))
	for index in range(3):
		var z: float = [7.0, 9.5, 17.0][index]
		g.storage_shelf("EvidenceRack%02d" % index, Vector3(9.5, 0, z), Vector3(4.0, 2.2, 0.55), Color("444947"))
	g.box("RestrictedCorridor", Vector3(4, 0.02, 11), Vector3(2.0, 0.05, 18), restricted_color, false)
	g.security_gate("RoofStairEnclosure", Vector3(10.5, 0, 15.425), 10.85, false, -2.425, 1.5, Color("46504e"))
	g.wall_segment("RoofStairNorthWall", Vector3(13.675, 0, 10.0), 6.35, true, wall_color)
	g.box("LiftAccessDoor", Vector3(16.78, 1.25, 8.5), Vector3(0.12, 2.5, 1.8), Color("252b2a"))
	g.door_frame("LiftAccessFrame", Vector3(16.62, 0, 8.5), false, Color("586360"), 1.8, 2.5)

	# Guardrails around the stair arrival opening; east side is the landing.
	g.railing(Vector3(-7, 0, -4), Vector3(-7, 0, 4), wall_color)
	g.railing(Vector3(-7, 0, -4), Vector3(7, 0, -4), wall_color)
	g.railing(Vector3(-7, 0, 4), Vector3(7, 0, 4), wall_color)
	g.stairs("Floor4ToRoof", Vector3(13.5, 0, 12), Vector3.BACK, 7.0, 4.0, 2.5, 20, wall_color)

	g.sign("SURVEILLANCE", Vector3(0, 2.7, -20.7), Vector3(0, 0, 0), Color("76c2d2"), 0.007)
	g.sign("MONITOR / CONTROL", Vector3(0, 2.5, -4.35), Vector3(0, 0, 0), Color("8ecbd5"), 0.005)
	g.sign("CONTROL ROOM", Vector3(0, 2.5, -13.85), Vector3(0, 0, 0), Color("8ecbd5"), 0.005)
	g.sign("SECURITY OFFICES", Vector3(-8.5, 2.5, 4.7), Vector3(0, 180, 0), Color("a8b9bb"), 0.005)
	g.sign("RESTRICTED — EVIDENCE STORAGE", Vector3(6.2, 2.5, 10), Vector3(0, 90, 0), Color("d09a55"), 0.0045)
	g.sign("STAIR / LIFT ACCESS", Vector3(16.5, 2.75, 8.5), Vector3(0, -90, 0), Color("b8c5c2"), 0.004)
