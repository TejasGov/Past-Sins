extends Node3D

const Factory := preload("res://scripts/levels/greybox_factory.gd")


func _ready() -> void:
	var g = Factory.new(self, 2)
	var floor_color := Color("292d2d")
	var wall_color := Color("3c4140")
	var secure_color := Color("424a48")
	var equipment_color := Color("aeb8b6")

	g.box("B2Floor", Vector3(0, -0.2, 0), Vector3(34, 0.4, 42), floor_color)
	g.outer_walls(34, 42, 3.6, wall_color)
	g.box("SecureCorridor", Vector3(0, 0.02, 0), Vector3(4.2, 0.05, 38), secure_color, false)
	g.box("SecretLabFinish", Vector3(-9.5, 0.02, -10), Vector3(14.0, 0.05, 18.0), Color("a4aaa7"), false)
	g.box("ChemicalFinish", Vector3(-9.5, 0.02, 10), Vector3(14.0, 0.05, 18.0), Color("777f79"), false)
	g.box("ObservationFinish", Vector3(9.5, 0.02, -10), Vector3(14.0, 0.05, 18.0), Color("515957"), false)
	g.box("InterrogationFinish", Vector3(9.5, 0.02, 10), Vector3(14.0, 0.05, 18.0), Color("242726"), false)

	# Central secure corridor walls form continuous shell-to-shell boundaries.
	# Every interruption is now an exact 1.5 m doorway instead of a loose gap
	# around a decorative frame.
	for x in [-2.2, 2.2]:
		var side_name := "West" if x < 0.0 else "East"
		g.wall_segment("%sSecureNorthEnd" % side_name, Vector3(x, 0, -16.425), 8.85, false, wall_color, 3.3, 0.36)
		g.partition_with_door("%sNorthSecureDoor" % side_name, Vector3(x, 0, -10.75), 2.5, false, 0.0, 1.5, wall_color, 3.3, 2.35, 0.36)
		g.wall_segment("%sSecureNorthMiddle" % side_name, Vector3(x, 0, -6.0), 7.0, false, wall_color, 3.3, 0.36)
		g.partition_with_door("CentralSecureDoor", Vector3(x, 0, 0), 5.0, false, 0.0, 1.4, wall_color, 3.3, 2.35, 0.36)
		g.wall_segment("%sSecureSouthMiddle" % side_name, Vector3(x, 0, 6.0), 7.0, false, wall_color, 3.3, 0.36)
		g.partition_with_door("%sSouthSecureDoor" % side_name, Vector3(x, 0, 10.75), 2.5, false, 0.0, 1.5, wall_color, 3.3, 2.35, 0.36)
		g.wall_segment("%sSecureSouthEnd" % side_name, Vector3(x, 0, 16.425), 8.85, false, wall_color, 3.3, 0.36)
		g.door_frame("NorthSecureDoor", Vector3(x, 0, -10.75), false, Color("59635f"), 1.5, 2.35, 0.16, 0.42)
		g.door_frame("SouthSecureDoor", Vector3(x, 0, 10.75), false, Color("59635f"), 1.5, 2.35, 0.16, 0.42)
	g.security_gate("NorthStaffCheckpoint", Vector3(0, 0, -18.8), 4.4, true, 0.0, 1.4, Color("59635f"), 2.9, 0.58)
	g.security_gate("SouthStaffCheckpoint", Vector3(0, 0, 11.0), 4.4, true, 0.0, 1.4, Color("59635f"), 2.9, 0.58)

	# Laboratory and chemical research rooms.
	g.partition_with_door("LaboratoryChemicalDivider", Vector3(-9.5, 0, 0), 14.5, true, 4.5, 1.4, wall_color, 3.3, 2.35, 0.34)
	g.supported_surface("LabBenchA", Vector3(-10.5, 0, -10), Vector2(4.5, 1.0), 1.27, 0.16, equipment_color, Color("66706d"))
	g.supported_surface("LabBenchB", Vector3(-10.5, 0, -5.5), Vector2(4.5, 1.0), 1.27, 0.16, equipment_color, Color("66706d"))
	g.emissive_box("LabStatusPanelA", Vector3(-10.5, 1.38, -10), Vector3(1.4, 0.28, 1.02), Color("7ac4b8"), 0.75)
	g.emissive_box("LabStatusPanelB", Vector3(-10.5, 1.38, -5.5), Vector3(1.4, 0.28, 1.02), Color("8bb8c0"), 0.65)
	g.supported_surface("ChemicalBench", Vector3(-10.5, 0, 8), Vector2(5.0, 1.1), 1.27, 0.16, Color("76705b"), Color("4f5148"))
	for x in [-12.2, -10.5, -8.8]:
		g.box("ChemicalTank", Vector3(x, 1.05, 13), Vector3(0.8, 2.1, 0.8), Color("566d66"))
	g.partition_with_door("ChemicalStorageDivider", Vector3(-9.5, 0, 10.5), 14.4, true, 4.0, 1.4, wall_color, 3.3, 2.35, 0.34)
	var sterile_light := Color("e8f3ef")
	g.ceiling_light("LaboratoryLightNorth", Vector3(-10.5, 3.5, -13), sterile_light, 1.35, 7.0)
	g.ceiling_light("LaboratoryLightSouth", Vector3(-10.5, 3.5, -5), sterile_light, 1.35, 7.0)
	g.ceiling_light("ChemicalLight", Vector3(-10.5, 3.5, 10), Color("dce6d6"), 1.0, 7.0)

	# Observation and interrogation/torture facility.
	g.partition_with_door("ObservationInterrogationDivider", Vector3(9.5, 0, -1.5), 14.5, true, -4.5, 1.4, wall_color, 3.3, 2.35, 0.34)
	g.supported_surface("ObservationConsole", Vector3(9.0, 0, -10), Vector2(4.5, 0.9), 1.27, 0.16, equipment_color, Color("66706d"))
	g.box("ObservationWindow", Vector3(4.4, 1.7, -8), Vector3(0.12, 1.5, 5.2), Color("17201f"), false)
	for z in [-10.65, -5.35]:
		g.box("ObservationWindowPost", Vector3(4.4, 1.25, z), Vector3(0.18, 2.5, 0.18), Color("343b39"))
	g.box("ObservationWindowTopFrame", Vector3(4.4, 2.45, -8), Vector3(0.18, 0.16, 5.5), Color("343b39"))
	g.box("ObservationWindowBottomFrame", Vector3(4.4, 0.92, -8), Vector3(0.18, 0.16, 5.5), Color("343b39"))
	g.emissive_box("ObservationDisplay", Vector3(9.0, 1.38, -10), Vector3(1.8, 0.34, 0.92), Color("628f8b"), 0.6)
	# Detailed reusable restraint, examination, recording, and monitoring props
	# replace the anonymous table/chair placeholders in this same room footprint.
	g.ceiling_light("ObservationLight", Vector3(9.5, 3.5, -10), Color("a9c6c1"), 0.7, 6.0)
	g.ceiling_light("InterrogationLight", Vector3(10.0, 3.25, 8), Color("d8cdb5"), 0.95, 4.5, Vector3(0.7, 0.08, 0.7))

	# Lower flight of the side-by-side service switchback.
	g.stairs("B2ToB1", Vector3(12.75, 0, 12.5), Vector3.BACK, 7.0, 4.0, 1.3, 20, wall_color)
	# A two-metre-deep side landing now separates the secure checkpoint from the
	# first tread. The north wall is also pulled back clear of the stair nose.
	g.security_gate("B2StaffStairEnclosure", Vector3(10.0, 0, 15.425), 10.85, false, -2.425, 1.5, Color("59635f"), 2.9, 0.58)
	g.wall_segment("B2StaffArrivalNorthWall", Vector3(13.425, 0, 10.0), 6.85, true, wall_color, 3.3, 0.36)
	g.box("B2LiftDoor", Vector3(16.78, 1.25, 16.0), Vector3(0.12, 2.5, 1.8), Color("252a29"))
	g.door_frame("B2LiftFrame", Vector3(16.62, 0, 16.0), false, Color("59635f"), 1.8, 2.5, 0.16, 0.38)
	g.sign("B2 — SECURE RESEARCH", Vector3(0, 2.7, -20.75), Vector3(0, 0, 0), Color("d2a84a"), 0.005)
	g.sign("LABORATORY", Vector3(-2.35, 2.35, -10), Vector3(0, -90, 0), Color("77bfd2"))
	g.sign("CHEMICAL RESEARCH", Vector3(-2.35, 2.35, 8), Vector3(0, -90, 0), Color("d1bc72"), 0.005)
	g.sign("CHEMICAL STORAGE", Vector3(-9.5, 2.45, 10.35), Vector3(0, 0, 0), Color("d1bc72"), 0.0045)
	g.sign("OBSERVATION", Vector3(2.35, 2.35, -10), Vector3(0, 90, 0), Color("77bfd2"))
	g.sign("INTERROGATION", Vector3(2.35, 2.35, 8), Vector3(0, 90, 0), Color("d17868"))
	g.sign("STAFF ACCESS / LIFT", Vector3(16.5, 2.7, 16.0), Vector3(0, -90, 0), Color("c3b27c"), 0.004)
