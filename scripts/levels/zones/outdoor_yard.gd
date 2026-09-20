extends Node3D

const Factory := preload("res://scripts/levels/greybox_factory.gd")
const COURT_CONCRETE := preload("res://materials/props/court_concrete.tres")
const YARD_BENCH := preload("res://scenes/props/yard/YardBench.tscn")
const PULL_UP_BAR := preload("res://scenes/props/gym/PullUpBar.tscn")
const PARALLEL_BARS := preload("res://scenes/props/yard/ParallelBars.tscn")
const BASKETBALL_HOOP := preload("res://scenes/props/yard/BasketballHoop.tscn")
const SHRUB := preload("res://scenes/props/yard/Shrub.tscn")
const SMALL_TREE := preload("res://scenes/props/yard/SmallTree.tscn")
const CCTV := preload("res://scenes/props/yard/CCTVCamera.tscn")
const SEARCHLIGHT := preload("res://scenes/props/yard/Searchlight.tscn")
const OBSERVATION_POST := preload("res://scenes/props/yard/ObservationPost.tscn")
const FLOWER_CLUSTER := preload("res://scenes/props/yard/FlowerCluster.tscn")
const OFFICER_GAZEBO := preload("res://scenes/props/yard/OfficerGazebo.tscn")
const YARD_SECURITY_POST := preload("res://scenes/props/yard/YardSecurityPost.tscn")

const VISUAL_LAYER := 8


func _ready() -> void:
	_build_secure_shell()
	_build_walking_track()
	_build_court()
	_build_garden()
	_build_exercise_area()
	_build_pool()
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
	g.box("YardFloor", Vector3(0, -0.2, 25), Vector3(54, 0.4, 50), asphalt)
	# Invisible continuous collision sits directly behind an inexpensive wire-grid
	# silhouette. This reads as mesh fencing while remaining impossible to squeeze
	# through or jump over.
	var west := g.box("YardWestPerimeter", Vector3(-27, 2.75, 25), Vector3(0.18, 5.5, 50.4), concrete)
	var east := g.box("YardEastPerimeter", Vector3(27, 2.75, 25), Vector3(0.18, 5.5, 50.4), concrete)
	var south := g.box("YardSouthPerimeter", Vector3(0, 2.75, 50), Vector3(54.4, 5.5, 0.18), concrete)
	var north_west := g.box("YardNorthPerimeterWest", Vector3(-14.35, 2.75, 0), Vector3(25.3, 5.5, 0.18), concrete)
	var north_east := g.box("YardNorthPerimeterEast", Vector3(14.35, 2.75, 0), Vector3(25.3, 5.5, 0.18), concrete)
	for collision_proxy in [west, east, south, north_west, north_east]:
		collision_proxy.visible = false
	for item in [[-27.0, 25.0, 0.22, 50.0], [27.0, 25.0, 0.22, 50.0]]:
		g.box("FenceCurb", Vector3(item[0], 0.3, item[1]), Vector3(item[2], 0.6, item[3]), concrete)
	g.box("FenceCurbSouth", Vector3(0, 0.3, 50), Vector3(54, 0.6, 0.22), concrete)
	g.box("FenceCurbNorthWest", Vector3(-14.35, 0.3, 0), Vector3(25.3, 0.6, 0.22), concrete)
	g.box("FenceCurbNorthEast", Vector3(14.35, 0.3, 0), Vector3(25.3, 0.6, 0.22), concrete)
	for x in range(-27, 28, 3):
		g.box("SouthMeshPost%02d" % (x + 27), Vector3(x, 2.75, 49.88), Vector3(0.09, 5.5, 0.09), fence, false)
		if absi(x) >= 3:
			g.box("NorthMeshPost%02d" % (x + 27), Vector3(x, 2.75, 0.12), Vector3(0.09, 5.5, 0.09), fence, false)
	for z in range(1, 50, 3):
		g.box("WestMeshPost%02d" % z, Vector3(-26.88, 2.75, z), Vector3(0.09, 5.5, 0.09), fence, false)
		g.box("EastMeshPost%02d" % z, Vector3(26.88, 2.75, z), Vector3(0.09, 5.5, 0.09), fence, false)
	for y in [1.0, 2.0, 3.0, 4.0, 5.25]:
		g.box("SouthMeshWire%s" % y, Vector3(0, y, 49.88), Vector3(54, 0.045, 0.045), fence, false)
		g.box("WestMeshWire%s" % y, Vector3(-26.88, y, 25), Vector3(0.045, 0.045, 50), fence, false)
		g.box("EastMeshWire%s" % y, Vector3(26.88, y, 25), Vector3(0.045, 0.045, 50), fence, false)
		g.box("NorthMeshWireWest%s" % y, Vector3(-14.35, y, 0.12), Vector3(25.3, 0.045, 0.045), fence, false)
		g.box("NorthMeshWireEast%s" % y, Vector3(14.35, y, 0.12), Vector3(25.3, 0.045, 0.045), fence, false)
	g.box("YardGateHeader", Vector3(0, 5.15, 0), Vector3(3.4, 0.7, 0.22), fence)
	g.sign("YARD SECURITY DOOR", Vector3(0, 4.45, 0.16), Vector3.ZERO, Color("d7bd68"), 0.0045)
	g.sign("SECURE COMMUNITY YARD — WIRE MESH PERIMETER", Vector3(0, 4.55, 49.78), Vector3.ZERO, Color("d3c995"), 0.005)


func _build_walking_track() -> void:
	var g = Factory.new(self, VISUAL_LAYER)
	var track := Color("604a42")
	var lane := Color("c5b99b")
	g.box("WalkingTrackWest", Vector3(-23.0, 0.035, 25), Vector3(3.0, 0.07, 42), track, false)
	g.box("WalkingTrackEast", Vector3(23.0, 0.035, 25), Vector3(3.0, 0.07, 42), track, false)
	g.box("WalkingTrackNorth", Vector3(0, 0.035, 4), Vector3(49, 0.07, 3.0), track, false)
	g.box("WalkingTrackSouth", Vector3(0, 0.035, 46), Vector3(49, 0.07, 3.0), track, false)
	for x in [-22.2, -23.8, 22.2, 23.8]:
		g.box("WalkingLane%s" % x, Vector3(x, 0.075, 25), Vector3(0.05, 0.012, 42), lane, false)
	for z in [3.2, 4.8, 45.2, 46.8]:
		g.box("WalkingLane%s" % z, Vector3(0, 0.075, z), Vector3(49, 0.012, 0.05), lane, false)
	g.sign("WALKING TRACK", Vector3(22.85, 0.2, 25), Vector3(-90, 0, 90), Color("e0d6bc"), 0.004)


func _build_court() -> void:
	var g = Factory.new(self, VISUAL_LAYER)
	var court := Color("514238")
	var marking := Color("c9c3a2")
	g.box("BasketballCourt", Vector3(-8.5, 0.025, 17), Vector3(15.5, 0.05, 23.0), court, false, COURT_CONCRETE)
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
	g.box("GardenGrassNorth", Vector3(12.0, 0.025, 21.0), Vector3(16.0, 0.05, 7.0), grass, false)
	g.box("GardenGrassSouth", Vector3(11.5, 0.025, 42.0), Vector3(17.0, 0.05, 6.0), grass, false)
	g.box("MainYardPath", Vector3(0, 0.04, 25), Vector3(2.8, 0.08, 50), path, false)
	g.box("GardenCrossPath", Vector3(12.0, 0.04, 40), Vector3(21.0, 0.08, 1.8), path, false)
	for item in [[6.0, 20.0], [11.0, 20.0], [17.0, 21.0], [6.0, 43.0], [12.0, 42.0], [18.0, 43.0]]:
		_place(SHRUB, "YardShrub_%s_%s" % [item[0], item[1]], Vector3(item[0], 0, item[1]), 0, "Yard Garden")
	for item in [[7.0, 44.0], [16.0, 20.5], [18.0, 44.0]]:
		_place(SMALL_TREE, "YardTree_%s_%s" % [item[0], item[1]], Vector3(item[0], 0, item[1]), 0, "Yard Garden")
	for item in [[7.0, 41.0], [11.0, 44.0], [17.0, 41.0], [20.0, 44.0]]:
		_place(FLOWER_CLUSTER, "YardFlowers_%s_%s" % [item[0], item[1]], Vector3(item[0], 0, item[1]), 0, "Yard Garden")
	_place(YARD_BENCH, "GardenBenchNorth", Vector3(4.2, 0, 39.0), 90, "Yard Garden")
	_place(YARD_BENCH, "GardenBenchSouth", Vector3(19.5, 0, 39.0), -90, "Yard Garden")


func _build_exercise_area() -> void:
	var g = Factory.new(self, VISUAL_LAYER)
	g.box("OutdoorExercisePad", Vector3(9.5, 0.025, 9.5), Vector3(13.0, 0.05, 12.0), Color("454942"), false)
	_place(PULL_UP_BAR, "YardPullUpBarA", Vector3(5.0, 0, 7.0), 0, "Yard Exercise")
	_place(PULL_UP_BAR, "YardPullUpBarB", Vector3(9.0, 0, 7.0), 0, "Yard Exercise")
	_place(PARALLEL_BARS, "YardParallelBars", Vector3(14.0, 0, 9.0), 0, "Yard Exercise")
	_place(YARD_BENCH, "ExerciseBench", Vector3(8.0, 0, 14.2), 180, "Yard Exercise")


func _build_pool() -> void:
	var g = Factory.new(self, VISUAL_LAYER)
	var coping := Color("c1c4b8")
	var water := Color("34778b")
	var pool_dark := Color("244a58")
	g.box("CommunityPoolDeck", Vector3(13.5, 0.03, 31.0), Vector3(19.0, 0.06, 13.0), coping, false)
	g.box("CommunityPoolWater", Vector3(13.5, 0.065, 31.0), Vector3(16.0, 0.07, 10.0), water, false)
	for x in [7.5, 11.5, 15.5, 19.5]:
		g.box("PoolLane%s" % x, Vector3(x, 0.105, 31.0), Vector3(0.06, 0.012, 9.7), Color("d8ded5"), false)
	for z in [25.8, 36.2]:
		g.box("PoolCoping%s" % z, Vector3(13.5, 0.16, z), Vector3(17.0, 0.22, 0.35), coping)
	for x in [5.3, 21.7]:
		g.box("PoolCoping%s" % x, Vector3(x, 0.16, 31.0), Vector3(0.35, 0.22, 10.7), coping)
	for x in [8.0, 19.0]:
		for side in [-0.38, 0.38]:
			g.box("PoolLadderPost", Vector3(x + side, 0.55, 26.0), Vector3(0.08, 1.1, 0.08), pool_dark)
		for step in range(3):
			g.box("PoolLadderStep", Vector3(x, 0.25 + step * 0.25, 26.0), Vector3(0.82, 0.06, 0.08), pool_dark, false)
	g.railing(Vector3(4.8, 0, 25.3), Vector3(22.2, 0, 25.3), pool_dark)
	g.railing(Vector3(4.8, 0, 36.7), Vector3(22.2, 0, 36.7), pool_dark)
	g.railing(Vector3(4.8, 0, 25.3), Vector3(4.8, 0, 36.7), pool_dark)
	g.railing(Vector3(22.2, 0, 25.3), Vector3(22.2, 0, 30.0), pool_dark)
	g.railing(Vector3(22.2, 0, 32.4), Vector3(22.2, 0, 36.7), pool_dark)
	g.sign("COMMUNITY SWIMMING POOL", Vector3(13.5, 0.22, 36.45), Vector3(-90, 0, 0), Color("ecf3e8"), 0.0045)


func _build_security_details() -> void:
	_place(OBSERVATION_POST, "NorthWestObservationPost", Vector3(-15.5, 0, 2.4), 0, "Yard Security")
	_place(OBSERVATION_POST, "SouthEastObservationPost", Vector3(24.5, 0, 47.0), 180, "Yard Security")
	_place(OFFICER_GAZEBO, "OfficerGazebo", Vector3(-14.5, 0, 40.5), 0, "Yard Officer Area")
	_place(YARD_SECURITY_POST, "YardSecurityPost", Vector3(21.0, 0, 8.5), 180, "Yard Security")
	# Pole-mounted yard cameras — placed at ground level with visible support
	# poles reaching up to surveillance height. Previously these floated at y=3.8
	# because default WALL mount has no surface against the perimeter wire fence.
	var west_cam := _place(CCTV, "WestYardCamera", Vector3(-26.75, 0, 17.0), -90, "Yard Security") as CCTVCamera
	west_cam.mount_type = CCTVCamera.MountType.POLE
	west_cam.pole_height = 3.8
	var east_cam := _place(CCTV, "EastYardCamera", Vector3(26.75, 0, 17.0), 90, "Yard Security") as CCTVCamera
	east_cam.mount_type = CCTVCamera.MountType.POLE
	east_cam.pole_height = 3.8
	var south_cam := _place(CCTV, "SouthYardCamera", Vector3(0, 0, 49.75), 0, "Yard Security") as CCTVCamera
	south_cam.mount_type = CCTVCamera.MountType.POLE
	south_cam.pole_height = 3.8
	_place(SEARCHLIGHT, "YardSearchlightWest", Vector3(-24.0, 0, 47.0), 20, "Yard Security")
	_place(SEARCHLIGHT, "YardSearchlightEast", Vector3(24.0, 0, 47.0), -20, "Yard Security")
	var g = Factory.new(self, VISUAL_LAYER)
	for item in [[-20.0, 3.4, 9.0], [20.0, 3.4, 9.0], [-20.0, 3.4, 41.0], [20.0, 3.4, 41.0]]:
		g.box("YardLightPole_%s_%s" % [item[0], item[2]], Vector3(item[0], item[1] * 0.5, item[2]), Vector3(0.14, item[1], 0.14), Color("343b39"))
		g.box("YardLightArm_%s_%s" % [item[0], item[2]], Vector3(item[0], item[1], item[2] + 0.3), Vector3(0.12, 0.12, 0.7), Color("343b39"), false)
		g.emissive_box("YardLightFixture_%s_%s" % [item[0], item[2]], Vector3(item[0], item[1], item[2] + 0.65), Vector3(0.55, 0.12, 0.28), Color("d9d2b3"), 0.7)
		# Four existing supported fixtures form sodium pools on the path; no
		# omnidirectional yard wash and no extra shadow-map budget in this legacy yard.
		var light := SpotLight3D.new()
		light.name = "YardLight_%s_%s" % [item[0], item[2]]
		light.position = Vector3(item[0], item[1] - 0.15, item[2] + 0.65)
		light.rotation_degrees.x = -90.0
		light.light_color = Color("ffcf8d")
		light.light_energy = 2.0
		light.spot_range = 9.0
		light.spot_angle = 46.0
		light.spot_angle_attenuation = 1.2
		light.light_cull_mask = VISUAL_LAYER
		light.shadow_enabled = false
		add_child(light)
