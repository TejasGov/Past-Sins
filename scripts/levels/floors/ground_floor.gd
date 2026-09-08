extends Node3D

const Factory := preload("res://scripts/levels/greybox_factory.gd")


func _ready() -> void:
	var g = Factory.new(self, 8)
	var floor_color := Color("4a4940")
	var wall_color := Color("6f7063")
	var checkpoint_color := Color("38423e")

	g.floor_with_stairwell(34, 42, floor_color)
	# The Ground Floor shell remains continuous except for the deliberate, gated
	# three-metre yard opening in the south wall.
	g.box("NorthWall", Vector3(0, 1.8, -21), Vector3(34, 3.6, 0.3), wall_color)
	g.box("WestWall", Vector3(-17, 1.8, 0), Vector3(0.3, 3.6, 42), wall_color)
	g.box("EastWall", Vector3(17, 1.8, 0), Vector3(0.3, 3.6, 42), wall_color)
	g.box("SouthWallWest", Vector3(-9.25, 1.8, 21), Vector3(15.5, 3.6, 0.3), wall_color)
	g.box("SouthWallEast", Vector3(9.25, 1.8, 21), Vector3(15.5, 3.6, 0.3), wall_color)
	g.box("SouthWallYardHeader", Vector3(0, 3.05, 21), Vector3(3.0, 1.1, 0.3), wall_color)
	g.door_frame("YardAccessFrame", Vector3(0, 0, 20.82), true, checkpoint_color, 3.0, 2.5, 0.16, 0.38)

	# Large cafeteria and common area.
	g.box("CafeteriaZone", Vector3(-5.0, 0.02, 2), Vector3(22, 0.05, 28), Color("555548"), false)
	# Reusable prison table scenes now populate this same dining zone through
	# EnvironmentalDressing, leaving the east side open for the serving queue.

	# Food serving line connected to the service side.
	# This wall runs all the way from the north shell to the cafeteria's south
	# boundary. The former short segment left a walk-around opening at its south
	# end, making the dining hall and food-service zone one accidental space.
	g.partition_with_door("ServingKitchenAccess", Vector3(8.0, 0, -5.675), 30.35, false, 3.675, 1.6, wall_color)
	# Reusable numbered serving stalls replace the former anonymous counter slabs.

	var cafeteria_light := Color("e5e4c7")
	g.ceiling_light("CafeteriaLightNorthWest", Vector3(-9, 3.5, -9), cafeteria_light, 1.0, 8.0)
	g.ceiling_light("CafeteriaLightNorthEast", Vector3(1, 3.5, -9), cafeteria_light, 1.0, 8.0)
	g.ceiling_light("CafeteriaLightSouthWest", Vector3(-9, 3.5, 8), cafeteria_light, 1.0, 8.0)
	g.ceiling_light("CafeteriaLightSouthEast", Vector3(2, 3.5, 8), cafeteria_light, 1.0, 8.0)

	# The dining hall remains open internally, but reads as one room from the
	# common circulation and intake side.
	g.partition_with_door("CafeteriaSouthBoundary", Vector3(-6.425, 0, 12.3), 20.85, true, 6.425, 1.8, wall_color)
	g.door_frame("CafeteriaEntryFrame", Vector3(0, 0, 12.3), true, checkpoint_color, 1.8)

	# Security checkpoint between the common area and yard access.
	g.supported_surface("CheckpointDesk", Vector3(7.0, 0, 14.5), Vector2(4.5, 1.0), 1.05, 0.18, checkpoint_color, Color("29312f"))
	g.box("CheckpointPostA", Vector3(4.5, 1.25, 18), Vector3(0.3, 2.5, 0.3), checkpoint_color)
	g.box("CheckpointPostB", Vector3(9.5, 1.25, 18), Vector3(0.3, 2.5, 0.3), checkpoint_color)
	g.bar_between("CheckpointHeader", Vector3(4.5, 2.5, 18), Vector3(9.5, 2.5, 18), checkpoint_color, 0.25)
	g.partition_with_door("IntakeNorthWall", Vector3(7.75, 0, 12.3), 7.5, true, 2.25, 1.5, checkpoint_color)
	g.partition_with_door("IntakeWestWall", Vector3(4.0, 0, 16.575), 8.55, false, 1.625, 1.5, checkpoint_color)
	g.partition_with_door("IntakeEastWall", Vector3(11.5, 0, 15.175), 11.35, false, -1.625, 1.5, checkpoint_color)
	# Two narrow, deliberate thresholds line up with the side-by-side service
	# stair lanes. They now sit three metres before the first tread, creating a
	# real landing/vestibule instead of touching the stairs.
	g.partition_with_door("FoodServiceSouthWall", Vector3(9.75, 0, 9.5), 3.5, true, 0.25, 1.3, wall_color)
	g.door_frame("FoodServiceStaffFrame", Vector3(10.0, 0, 9.5), true, checkpoint_color, 1.3)

	# Open metal threshold separates the service stair without adding door logic.
	g.security_gate("GroundLowerStairGate", Vector3(12.375, 0, 9.5), 2.25, true, 0.375, 1.3, checkpoint_color)
	g.security_gate("GroundArrivalStairGate", Vector3(15.125, 0, 9.5), 3.25, true, -0.875, 1.3, checkpoint_color)

	# Continue the alternating service switchback from B1.
	g.box("GroundServiceLanding", Vector3(13.5, -0.08, 12.0), Vector3(3.0, 0.16, 1.6), wall_color)
	g.stairs("GroundToFloor1", Vector3(12.75, 0, 12.5), Vector3.BACK, 7.0, 4.0, 1.3, 20, wall_color)
	g.sign("CAFETERIA", Vector3(-5, 2.9, -20.7), Vector3(0, 0, 0), Color("d2dedc"), 0.008)
	g.sign("FOOD SERVICE", Vector3(7.85, 2.4, -5), Vector3(0, -90, 0), Color("d2c48e"))
	g.sign("PRISONER COMMON AREA", Vector3(-15.8, 2.5, 8), Vector3(0, 90, 0), Color("9fb5b7"), 0.005)
	g.sign("SECURITY CHECKPOINT", Vector3(7, 2.65, 18.2), Vector3(0, 180, 0), Color("7ec0cf"), 0.005)
	g.sign("YARD ACCESS", Vector3(0, 2.65, 20.65), Vector3(0, 180, 0), Color("b7c7c7"))
	g.sign("COMMON CIRCULATION", Vector3(-8, 2.45, 12.15), Vector3(0, 180, 0), Color("c3c6b7"), 0.0045)
