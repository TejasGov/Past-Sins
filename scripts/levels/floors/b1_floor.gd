extends Node3D

const Factory := preload("res://scripts/levels/greybox_factory.gd")


func _ready() -> void:
	var g = Factory.new(self, 4)
	var floor_color := Color("666b68")
	var wall_color := Color("929895")
	var medical_color := Color("c2c8c4")

	g.floor_with_stairwell(34, 42, floor_color)
	g.outer_walls(34, 42, 3.6, wall_color)
	g.box("MedicalFloorFinish", Vector3(-9.5, 0.02, -9.5), Vector3(14.0, 0.05, 20.0), Color("858c89"), false)
	g.box("KitchenFloorFinish", Vector3(9.5, 0.02, -10.0), Vector3(14.0, 0.05, 18.0), Color("656657"), false)
	g.box("ServiceCorridor", Vector3(0, 0.03, 0), Vector3(5.0, 0.05, 38), Color("555b58"), false)
	# The medical and food-service doors intentionally sit at different points
	# along the central hall. Both corridor walls now meet the north shell instead
	# of leaving a narrow end-run around either department.
	g.partition_with_door("MedicalCorridorWall", Vector3(-2.5, 0, -9.175), 23.35, false, -0.825, 1.5, wall_color)
	g.partition_with_door("KitchenCorridorWall", Vector3(2.5, 0, -9.175), 23.35, false, -2.825, 1.5, wall_color)

	# Infirmary and treatment bays on the west side.
	g.partition_with_door("MedicalSouthDivider", Vector3(-9.675, 0, 1.5), 14.35, true, 5.675, 1.5, wall_color)
	# Reusable examination tables and wheeled privacy screens now dress these
	# same treatment bays through EnvironmentalDressing.
	g.supported_surface("TreatmentDesk", Vector3(-12, 0, -17.5), Vector2(3.0, 0.9), 0.92, 0.16, medical_color, Color("69716e"))
	var clinical_light := Color("f1f3ed")
	g.ceiling_light("MedicalLightNorth", Vector3(-10.5, 3.5, -13.5), clinical_light, 1.2, 7.0)
	g.ceiling_light("MedicalLightSouth", Vector3(-10.5, 3.5, -5.0), clinical_light, 1.2, 7.0)

	# Kitchen, food preparation, cold storage, and dry storage.
	g.partition_with_door("KitchenStorageDivider", Vector3(9.675, 0, -1.0), 14.35, true, -5.675, 1.5, wall_color)
	g.partition_with_door("KitchenPrepDivider", Vector3(9.675, 0, -10.0), 14.35, true, -5.175, 1.5, wall_color)
	# Reusable stainless preparation counters retain this row while giving the
	# kitchen a clearer central service path and recognizable equipment spacing.
	# Cold/dry storage is a complete four-sided room. Its only opening is the
	# west-side storage doorway; the east wall also protects the stair void.
	g.partition_with_door("ColdStorageWestWall", Vector3(7.0, 0, 7.5), 12.0, false, 0.5, 1.4, wall_color, 3.2)
	g.wall_segment("ColdStorageEastWall", Vector3(11.5, 0, 7.5), 12.0, false, wall_color, 3.2)
	g.wall_segment("ColdStorageNorthWall", Vector3(9.25, 0, 1.5), 4.5, true, wall_color, 3.2)
	g.wall_segment("ColdStorageSouthWall", Vector3(9.25, 0, 13.5), 4.5, true, wall_color, 3.2)
	g.storage_shelf("StorageShelfA", Vector3(9.2, 0, 7), Vector3(4.0, 2.2, 0.55), Color("4b5152"))
	g.storage_shelf("StorageShelfB", Vector3(9.2, 0, 12), Vector3(4.0, 2.2, 0.55), Color("4b5152"))
	g.partition_with_door("MaintenancePartition", Vector3(-7.175, 0, 13.5), 19.35, true, 4.675, 1.5, wall_color)
	g.wall_segment("MaintenanceEastWall", Vector3(2.5, 0, 17.175), 7.35, false, wall_color)
	g.partition_with_door("UtilityRoomDivider", Vector3(-9.0, 0, 17.175), 7.35, false, -0.675, 1.4, wall_color)
	g.box("ServiceEquipment", Vector3(-11.5, 1.1, 16.5), Vector3(4.5, 2.2, 1.1), Color("606663"))
	var kitchen_light := Color("ddd9bc")
	g.ceiling_light("KitchenLightNorth", Vector3(10.0, 3.5, -13.0), kitchen_light, 1.0, 7.0)
	g.ceiling_light("KitchenLightSouth", Vector3(10.0, 3.5, -5.0), kitchen_light, 1.0, 7.0)

	# The B2 arrival and B1 departure meet on this landing, then reverse in the
	# adjacent lane instead of occupying the same volume.
	g.box("B1ServiceLanding", Vector3(13.5, -0.08, 20.0), Vector3(3.0, 0.16, 1.6), wall_color)
	g.stairs("B1ToGround", Vector3(14.25, 0, 19.5), Vector3.FORWARD, 7.0, 4.0, 1.3, 20, wall_color)
	g.security_gate("B1ServiceStairEnclosure", Vector3(11.7, 0, 16.425), 8.85, false, 3.575, 1.5, Color("606966"))
	g.wall_segment("B1ServiceStairNorthWall", Vector3(14.275, 0, 12.0), 5.15, true, wall_color)
	g.sign("MEDICAL", Vector3(-2.65, 2.35, -10), Vector3(0, -90, 0), Color("8ad3cf"))
	g.sign("KITCHEN", Vector3(2.65, 2.35, -11), Vector3(0, 90, 0), Color("d3c28a"))
	g.sign("FOOD PREPARATION", Vector3(9.5, 2.4, -9.85), Vector3(0, 0, 0), Color("d3c28a"), 0.0045)
	g.sign("STORAGE", Vector3(7.2, 2.35, 8), Vector3(0, 90, 0), Color("adb8b5"))
	g.sign("MAINTENANCE / SERVICE", Vector3(-2.65, 2.35, 16), Vector3(0, -90, 0), Color("d1aa5d"), 0.005)
	g.sign("UTILITY", Vector3(-8.85, 2.4, 16.5), Vector3(0, -90, 0), Color("b5bcb8"), 0.0045)
