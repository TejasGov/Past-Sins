extends Node3D

const Factory := preload("res://scripts/levels/greybox_factory.gd")


func _ready() -> void:
	var g = Factory.new(self, 16)
	var floor_color := Color("403f3a")
	var wall_color := Color("595852")
	var equipment_color := Color("585b58")

	# Floor 1 is the bottom of the three-storey central atrium.
	g.floor_with_stairwell(34, 42, floor_color)
	g.outer_walls(34, 42, 3.6, wall_color)
	# Collision-backed arrival landing for the Ground Floor service stair.
	g.box("Floor1ServiceLanding", Vector3(13.5, -0.08, 20.0), Vector3(3.0, 0.16, 1.6), wall_color)
	g.box("AtriumExerciseFloor", Vector3(0, 0.02, 0), Vector3(14, 0.05, 24), Color("454641"), false)

	# Detailed reusable equipment now dresses this same gym footprint through
	# EnvironmentalDressing; the central circulation lanes remain unchanged.

	var gym_light := Color("e3cfa8")
	g.ceiling_light("GymLightNorth", Vector3(0, 3.5, -7), gym_light, 1.0, 8.5)
	g.ceiling_light("GymLightWest", Vector3(-7, 3.5, 4), gym_light, 0.95, 8.0)
	g.ceiling_light("GymLightEast", Vector3(7, 3.5, 4), gym_light, 0.95, 8.0)

	# Showers and changing area on the north side.
	for wall_piece in [[-12.25, 9.5], [-1.5, 9.0], [10.75, 12.5]]:
		g.box("NorthRoomWall", Vector3(wall_piece[0], 1.65, -12), Vector3(wall_piece[1], 3.3, 0.22), wall_color)
	g.door_frame("ChangingRoomDoor", Vector3(-6.75, 0, -12), true, Color("3f423f"), 1.5)
	g.door_frame("ShowerRoomDoor", Vector3(3.75, 0, -12), true, Color("3f423f"), 1.5)
	# Join the divider to both perimeter walls so neither wet room can be entered
	# by squeezing around its north or south end.
	g.partition_with_door("ChangingShowerDivider", Vector3(-4, 0, -16.425), 8.85, false, -0.075, 1.4, wall_color)
	for index in range(3):
		var x: float = [-13.0, -10.0, -7.0][index]
		g.supported_surface("ChangingBench%02d" % index, Vector3(x, 0, -16), Vector2(2.0, 0.55), 0.6, 0.16, equipment_color, Color("393d3b"))
	# Collision-backed reusable half-walls and fixtures replace the former
	# decorative-only shower dividers at these same bays.

	# Recreation area on the south side.
	for wall_piece in [[-12.25, 9.5], [-1.5, 9.0], [10.75, 12.5]]:
		g.box("SouthRoomWall", Vector3(wall_piece[0], 1.65, 12), Vector3(wall_piece[1], 3.3, 0.22), wall_color)
	g.door_frame("RecreationDoorWest", Vector3(-6.75, 0, 12), true, Color("454743"), 1.5)
	g.door_frame("RecreationDoorEast", Vector3(3.75, 0, 12), true, Color("454743"), 1.5)
	for index in range(5):
		var x: float = [-11.0, -6.0, -1.0, 4.0, 9.0][index]
		g.supported_surface("RecreationTable%02d" % index, Vector3(x, 0, 16.5), Vector2(2.4, 1.2), 0.84, 0.15, equipment_color, Color("393d3b"))

	# Open stair crossing the atrium to Floor 2.
	g.stairs("Floor1ToFloor2", Vector3(-7, 0, -6), Vector3.RIGHT, 14.0, 4.0, 2.4, 20, wall_color)
	g.security_gate("Floor1ServiceStairEnclosure", Vector3(11.7, 0, 16.425), 8.85, false, 3.575, 1.5, Color("3f423f"))
	g.sign("GYM", Vector3(0, 2.8, -11.85), Vector3(0, 0, 0), Color("9bd0d6"), 0.009)
	g.sign("EXERCISE AREA", Vector3(-6.8, 2.5, 0), Vector3(0, -90, 0), Color("9fb8bb"), 0.006)
	g.sign("SHOWERS / CHANGING", Vector3(0, 2.55, -12.15), Vector3(0, 180, 0), Color("8bc4cc"), 0.005)
	g.sign("8 SHOWERS — TOILETS — URINALS", Vector3(10.5, 2.7, -20.7), Vector3(0, 0, 0), Color("9ed4d8"), 0.0038)
	g.sign("RECREATION", Vector3(0, 2.55, 12.15), Vector3(0, 0, 0), Color("b6c5c5"), 0.006)
	g.sign("SERVICE STAIR", Vector3(11.55, 2.5, 19.5), Vector3(0, -90, 0), Color("c6b887"), 0.0045)
