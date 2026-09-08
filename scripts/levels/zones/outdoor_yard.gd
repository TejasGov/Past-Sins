extends Node3D

const Factory := preload("res://scripts/levels/greybox_factory.gd")
const YARD_BENCH := preload("res://scenes/props/yard/YardBench.tscn")
const PULL_UP_BAR := preload("res://scenes/props/gym/PullUpBar.tscn")
const PARALLEL_BARS := preload("res://scenes/props/yard/ParallelBars.tscn")
const BASKETBALL_HOOP := preload("res://scenes/props/yard/BasketballHoop.tscn")
const SHRUB := preload("res://scenes/props/yard/Shrub.tscn")
const SMALL_TREE := preload("res://scenes/props/yard/SmallTree.tscn")
const CCTV := preload("res://scenes/props/yard/CCTVCamera.tscn")
const SEARCHLIGHT := preload("res://scenes/props/yard/Searchlight.tscn")
const OBSERVATION_POST := preload("res://scenes/props/yard/ObservationPost.tscn")

const VISUAL_LAYER := 8


func _ready() -> void:
	_build_secure_shell()
	_build_court()
	_build_garden()
	_build_exercise_area()
	_build_security_details()


func _place(scene: PackedScene, node_name: String, local_position: Vector3, yaw_degrees := 0.0, zone := "Outdoor Yard") -> Node3D:
	var prop := scene.instantiate() as Node3D
	prop.name = node_name
	prop.position = local_position
	prop.rotation_degrees.y = yaw_degrees
	prop.set("visual_layer_mask", VISUAL_LAYER)
	prop.set_meta("placement_zone", zone)
	add_child(prop)
	return prop


func _build_secure_shell() -> void:
	var g = Factory.new(self, VISUAL_LAYER)
	var concrete := Color("565b56")
	var fence := Color("2c3432")
	var asphalt := Color("343735")
	g.box("YardFloor", Vector3(0, -0.2, 17), Vector3(36, 0.4, 34), asphalt)
	# Four continuous 4.6 m barriers surround the yard. The only interruption is
	# the three-metre gate opening back into the Ground Floor.
	g.box("YardWestPerimeter", Vector3(-18, 2.3, 17), Vector3(0.45, 4.6, 34.4), concrete)
	g.box("YardEastPerimeter", Vector3(18, 2.3, 17), Vector3(0.45, 4.6, 34.4), concrete)
	g.box("YardSouthPerimeter", Vector3(0, 2.3, 34), Vector3(36.4, 4.6, 0.45), concrete)
	g.box("YardNorthPerimeterWest", Vector3(-9.85, 2.3, 0), Vector3(16.3, 4.6, 0.45), concrete)
	g.box("YardNorthPerimeterEast", Vector3(9.85, 2.3, 0), Vector3(16.3, 4.6, 0.45), concrete)
	g.box("YardGateHeader", Vector3(0, 4.15, 0), Vector3(3.4, 0.9, 0.45), concrete)
	# Cheap, non-colliding anti-climb silhouette above the collision-backed wall.
	for x in range(-18, 19, 3):
		g.box("SouthFencePost%02d" % (x + 18), Vector3(x, 5.1, 33.78), Vector3(0.07, 1.0, 0.07), fence, false)
	for z in range(2, 34, 3):
		g.box("WestFencePost%02d" % z, Vector3(-17.78, 5.1, z), Vector3(0.07, 1.0, 0.07), fence, false)
		g.box("EastFencePost%02d" % z, Vector3(17.78, 5.1, z), Vector3(0.07, 1.0, 0.07), fence, false)
	for y in [4.75, 5.25, 5.6]:
		g.box("SouthFenceRail%s" % y, Vector3(0, y, 33.77), Vector3(35.6, 0.045, 0.045), fence, false)
		g.box("WestFenceRail%s" % y, Vector3(-17.77, y, 17), Vector3(0.045, 0.045, 33.5), fence, false)
		g.box("EastFenceRail%s" % y, Vector3(17.77, y, 17), Vector3(0.045, 0.045, 33.5), fence, false)
	g.sign("SECURE EXERCISE YARD", Vector3(0, 3.25, 33.72), Vector3.ZERO, Color("d3c995"), 0.006)


func _build_court() -> void:
	var g = Factory.new(self, VISUAL_LAYER)
	var court := Color("514238")
	var marking := Color("c9c3a2")
	g.box("BasketballCourt", Vector3(-8.5, 0.025, 17), Vector3(15.5, 0.05, 23.0), court, false)
	# Low-cost line markings use shallow unlit-looking strips instead of decals.
	g.box("CourtNorthLine", Vector3(-8.5, 0.055, 5.6), Vector3(15.2, 0.012, 0.08), marking, false)
	g.box("CourtSouthLine", Vector3(-8.5, 0.055, 28.4), Vector3(15.2, 0.012, 0.08), marking, false)
	g.box("CourtWestLine", Vector3(-16.05, 0.055, 17), Vector3(0.08, 0.012, 22.8), marking, false)
	g.box("CourtEastLine", Vector3(-0.95, 0.055, 17), Vector3(0.08, 0.012, 22.8), marking, false)
	g.box("CourtCenterLine", Vector3(-8.5, 0.056, 17), Vector3(15.1, 0.012, 0.07), marking, false)
	# A square center mark and key lanes read clearly without costly curved meshes.
	for x in [-10.2, -6.8]:
		g.box("CenterMark%s" % x, Vector3(x, 0.057, 17), Vector3(0.07, 0.012, 3.2), marking, false)
	for z in [8.0, 26.0]:
		g.box("FreeThrowLine%s" % z, Vector3(-8.5, 0.057, z), Vector3(4.0, 0.012, 0.07), marking, false)
	_place(BASKETBALL_HOOP, "NorthBasketballHoop", Vector3(-8.5, 0, 6.1), 0, "Yard Basketball Court")
	_place(BASKETBALL_HOOP, "SouthBasketballHoop", Vector3(-8.5, 0, 27.9), 180, "Yard Basketball Court")


func _build_garden() -> void:
	var g = Factory.new(self, VISUAL_LAYER)
	var grass := Color("344b2d")
	var path := Color("777970")
	g.box("GardenGrassNorth", Vector3(10.0, 0.025, 21.5), Vector3(12.5, 0.05, 8.0), grass, false)
	g.box("GardenGrassSouth", Vector3(10.0, 0.025, 30.0), Vector3(12.5, 0.05, 6.5), grass, false)
	g.box("MainYardPath", Vector3(0, 0.04, 17), Vector3(2.6, 0.08, 34), path, false)
	g.box("GardenCrossPath", Vector3(9.3, 0.04, 25.5), Vector3(15.8, 0.08, 1.8), path, false)
	for item in [[5.0, 20.0], [9.0, 20.0], [14.5, 21.0], [5.5, 29.0], [10.5, 30.0], [15.0, 29.5]]:
		_place(SHRUB, "YardShrub_%s_%s" % [item[0], item[1]], Vector3(item[0], 0, item[1]), 0, "Yard Garden")
	for item in [[7.0, 30.5], [13.5, 22.0], [14.0, 31.0]]:
		_place(SMALL_TREE, "YardTree_%s_%s" % [item[0], item[1]], Vector3(item[0], 0, item[1]), 0, "Yard Garden")
	_place(YARD_BENCH, "GardenBenchNorth", Vector3(4.2, 0, 24.0), 90, "Yard Garden")
	_place(YARD_BENCH, "GardenBenchSouth", Vector3(14.5, 0, 26.8), -90, "Yard Garden")


func _build_exercise_area() -> void:
	var g = Factory.new(self, VISUAL_LAYER)
	g.box("OutdoorExercisePad", Vector3(9.5, 0.025, 9.5), Vector3(13.0, 0.05, 12.0), Color("454942"), false)
	_place(PULL_UP_BAR, "YardPullUpBarA", Vector3(5.0, 0, 7.0), 0, "Yard Exercise")
	_place(PULL_UP_BAR, "YardPullUpBarB", Vector3(9.0, 0, 7.0), 0, "Yard Exercise")
	_place(PARALLEL_BARS, "YardParallelBars", Vector3(14.0, 0, 9.0), 0, "Yard Exercise")
	_place(YARD_BENCH, "ExerciseBench", Vector3(8.0, 0, 14.2), 180, "Yard Exercise")


func _build_security_details() -> void:
	_place(OBSERVATION_POST, "NorthWestObservationPost", Vector3(-15.5, 0, 2.4), 0, "Yard Security")
	_place(OBSERVATION_POST, "SouthEastObservationPost", Vector3(15.2, 0, 31.4), 180, "Yard Security")
	_place(CCTV, "WestYardCamera", Vector3(-17.75, 0, 13.0), 90, "Yard Security")
	_place(CCTV, "EastYardCamera", Vector3(17.75, 0, 13.0), -90, "Yard Security")
	_place(CCTV, "SouthYardCamera", Vector3(0, 0, 33.75), 180, "Yard Security")
	_place(SEARCHLIGHT, "YardSearchlightWest", Vector3(-14.0, 0, 31.0), 20, "Yard Security")
	_place(SEARCHLIGHT, "YardSearchlightEast", Vector3(14.0, 0, 31.0), -20, "Yard Security")
	for item in [[-8.0, 2.9, 11.0], [8.0, 2.9, 11.0], [-8.0, 2.9, 25.0], [8.0, 2.9, 25.0]]:
		var light := OmniLight3D.new()
		light.name = "YardLight_%s_%s" % [item[0], item[2]]
		light.position = Vector3(item[0], item[1], item[2])
		light.light_color = Color("d9d2b3")
		light.light_energy = 0.5
		light.omni_range = 10.0
		light.light_cull_mask = VISUAL_LAYER
		light.shadow_enabled = false
		add_child(light)
