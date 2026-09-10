extends Node3D

const Factory := preload("res://scripts/levels/greybox_factory.gd")


func _ready() -> void:
	var g = Factory.new(self, 8)
	var floor_color := Color("4a4940")
	var wall_color := Color("6f7063")
	var checkpoint_color := Color("38423e")

	g.floor_with_stairwell(34, 42, floor_color)

	# Shell Walls
	g.box("NorthWall", Vector3(0, 1.8, -21), Vector3(34, 3.6, 0.3), wall_color)
	g.box("WestWall", Vector3(-17, 1.8, 0), Vector3(0.3, 3.6, 42), wall_color)
	g.box("EastWall", Vector3(17, 1.8, 0), Vector3(0.3, 3.6, 42), wall_color)
	g.box("SouthWallWest", Vector3(-9.25, 1.8, 21), Vector3(15.5, 3.6, 0.3), wall_color)
	g.box("SouthWallEast", Vector3(9.25, 1.8, 21), Vector3(15.5, 3.6, 0.3), wall_color)
	g.box("SouthWallYardHeader", Vector3(0, 3.05, 21), Vector3(3.0, 1.1, 0.3), wall_color)
	g.door_frame("YardAccessFrame", Vector3(0, 0, 20.82), true, checkpoint_color, 3.0, 2.5, 0.16, 0.38)
	# High-contrast floor route leads from the common circulation doorway to the
	# south-wall yard door without adding collision or narrowing the corridor.
	var yard_route_color := Color("ba8d31")
	g.box("YardRouteStripe", Vector3(0, 0.055, 16.55), Vector3(0.32, 0.02, 8.1), yard_route_color, false)
	for z in [13.0, 15.5, 18.0]:
		g.box("YardRouteArrowLeft", Vector3(-0.3, 0.068, z + 0.18), Vector3(0.08, 0.025, 0.48), yard_route_color, false)
		g.box("YardRouteArrowRight", Vector3(0.3, 0.068, z + 0.18), Vector3(0.08, 0.025, 0.48), yard_route_color, false)
		g.box("YardRouteArrowBar", Vector3(0, 0.068, z + 0.42), Vector3(0.68, 0.025, 0.08), yard_route_color, false)

	# Cafeteria & Common Area
	g.box("CafeteriaZone", Vector3(-5.0, 0.02, 2), Vector3(22, 0.05, 28), Color("555548"), false)
	g.partition_with_door("ServingKitchenAccess", Vector3(8.0, 0, -5.675), 30.35, false, 3.675, 1.6, wall_color)

	var cafeteria_light := Color("e5e4c7")
	g.ceiling_light("CafeteriaLightNorthWest", Vector3(-9, 3.5, -9), cafeteria_light, 1.0, 8.0)
	g.ceiling_light("CafeteriaLightNorthEast", Vector3(1, 3.5, -9), cafeteria_light, 1.0, 8.0)
	g.ceiling_light("CafeteriaLightSouthWest", Vector3(-9, 3.5, 8), cafeteria_light, 1.0, 8.0)
	g.ceiling_light("CafeteriaLightSouthEast", Vector3(2, 3.5, 8), cafeteria_light, 1.0, 8.0)

	g.partition_with_door("CafeteriaSouthBoundary", Vector3(-6.425, 0, 12.3), 20.85, true, 6.425, 1.8, wall_color)
	g.door_frame("CafeteriaEntryFrame", Vector3(0, 0, 12.3), true, checkpoint_color, 1.8)

	# Metal Detector Checkpoints
	g.metal_detector("CafeteriaEntryMetalDetector", Vector3(0, 0, 12.3), 0.0)
	g.metal_detector("IntakeMetalDetector", Vector3(7.0, 0, 16.5), 90.0)

	# Security Checkpoint Desk & Post Structure
	g.supported_surface("CheckpointDesk", Vector3(7.0, 0, 14.5), Vector2(4.5, 1.0), 1.05, 0.18, checkpoint_color, Color("29312f"))
	g.box("CheckpointPostA", Vector3(4.5, 1.25, 18), Vector3(0.3, 2.5, 0.3), checkpoint_color)
	g.box("CheckpointPostB", Vector3(9.5, 1.25, 18), Vector3(0.3, 2.5, 0.3), checkpoint_color)
	g.bar_between("CheckpointHeader", Vector3(4.5, 2.5, 18), Vector3(9.5, 2.5, 18), checkpoint_color, 0.25)
	g.partition_with_door("IntakeNorthWall", Vector3(7.75, 0, 12.3), 7.5, true, 2.25, 1.5, checkpoint_color)
	g.partition_with_door("IntakeWestWall", Vector3(4.0, 0, 16.575), 8.55, false, 1.625, 1.5, checkpoint_color)
	g.partition_with_door("IntakeEastWall", Vector3(11.5, 0, 15.175), 11.35, false, -1.625, 1.5, checkpoint_color)
	g.partition_with_door("FoodServiceSouthWall", Vector3(9.75, 0, 9.5), 3.5, true, 0.25, 1.3, wall_color)
	g.door_frame("FoodServiceStaffFrame", Vector3(10.0, 0, 9.5), true, checkpoint_color, 1.3)

	g.security_gate("GroundLowerStairGate", Vector3(12.375, 0, 9.5), 2.25, true, 0.375, 1.3, checkpoint_color)
	g.security_gate("GroundArrivalStairGate", Vector3(15.125, 0, 9.5), 3.25, true, -0.875, 1.3, checkpoint_color)

	g.box("GroundServiceLanding", Vector3(13.5, -0.08, 12.0), Vector3(3.0, 0.16, 1.6), wall_color)
	g.stairs("GroundToFloor1", Vector3(12.75, 0, 12.5), Vector3.BACK, 7.0, 4.0, 1.3, 20, wall_color)

	# CCTV Cameras on Ground Floor
	g.cctv_camera("GroundCamCafeteriaNW", Vector3(-16.85, 3.4, -19.5), 0, 35.0, -25.0, -90.0) # Wall
	g.cctv_camera("GroundCamCafeteriaSE", Vector3(16.85, 3.4, 8.0), 0, -35.0, -25.0, 90.0) # Wall
	g.cctv_camera("GroundCamIntake", Vector3(10.5, 3.4, 17.5), 1, -90.0, -30.0) # Ceiling
	g.cctv_camera("GroundCamYardAccess", Vector3(0.0, 3.4, 19.5), 1, 0.0, -25.0) # Ceiling

	# Signage
	g.sign("CAFETERIA", Vector3(-5, 2.9, -20.7), Vector3(0, 0, 0), Color("d2dedc"), 0.008)
	g.sign("FOOD SERVICE", Vector3(7.85, 2.4, -5), Vector3(0, -90, 0), Color("d2c48e"))
	g.sign("PRISONER COMMON AREA", Vector3(-15.8, 2.5, 8), Vector3(0, 90, 0), Color("9fb5b7"), 0.005)
	g.sign("SECURITY CHECKPOINT", Vector3(7, 2.65, 18.2), Vector3(0, 180, 0), Color("7ec0cf"), 0.005)
	g.sign("YARD ACCESS", Vector3(0, 2.65, 20.65), Vector3(0, 180, 0), Color("b7c7c7"))
	g.sign("YARD SECURITY DOOR — E TO OPEN", Vector3(0, 2.15, 20.64), Vector3(0, 180, 0), Color("d7bd68"), 0.0038)
	g.sign("YARD EXIT  ↓", Vector3(0, 1.55, 20.63), Vector3(0, 180, 0), Color("ffe183"), 0.006)
	g.sign("COMMON CIRCULATION", Vector3(-8, 2.45, 12.15), Vector3(0, 180, 0), Color("c3c6b7"), 0.0045)
