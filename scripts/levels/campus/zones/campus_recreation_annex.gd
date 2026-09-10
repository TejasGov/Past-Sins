extends Node3D

## Campus-coordinate composition, independent of the campus or building builder.
## Uses existing yard pads/fences and reusable grounded props. Pool security is
## at the campus perimeter, not a cage around a recreational swimming basin.
const FACTORY := preload("res://scripts/levels/greybox_factory.gd")
const FENCE := preload("res://scenes/levels/campus/zones/WireMeshFence.tscn")
const GATE := preload("res://scenes/interactables/PrisonSlidingGate.tscn")
const BENCH := preload("res://scenes/props/yard/YardBench.tscn")
const HOOP := preload("res://scenes/props/yard/BasketballHoop.tscn")
const PULL_UP := preload("res://scenes/props/gym/PullUpBar.tscn")
const PARALLEL := preload("res://scenes/props/yard/ParallelBars.tscn")
const SHRUB := preload("res://scenes/props/yard/Shrub.tscn")
const TREE := preload("res://scenes/props/yard/SmallTree.tscn")
const FLOWERS := preload("res://scenes/props/yard/FlowerCluster.tscn")
const GAZEBO := preload("res://scenes/props/yard/OfficerGazebo.tscn")
const KIOSK := preload("res://scenes/levels/campus/zones/CampusSecurityKiosk.tscn")
const BIN := preload("res://scenes/props/common/TrashBin.tscn")
const CCTV := preload("res://scenes/props/security/CCTVCamera.tscn")
const DETAIL := preload("res://scenes/props/common/CampusDetailProp.tscn")
const DetailKind := preload("res://scripts/props/campus_detail_prop.gd")
@export_flags_3d_render var visual_layer_mask := 1

var _g: RefCounted


func _ready() -> void:
	add_to_group("campus_recreation_annex")
	_g = FACTORY.new(self, visual_layer_mask)
	set_meta("pool_annex_footprint", Rect2(-27.5, 34, 27, 17))
	_build_yard_dressing()
	_build_pool_annex()
	_build_medical_connection()
	_build_pedestrian_crossing()
	_fit_existing_yard_gates()


func _place(scene: PackedScene, item_name: String, point: Vector3, yaw := 0.0) -> Node3D:
	var item := scene.instantiate() as Node3D
	item.name = item_name
	item.position = point
	item.rotation_degrees.y = yaw
	item.set("visual_layer_mask", visual_layer_mask)
	item.set_meta("placement_zone", "Campus Recreation")
	add_child(item)
	return item


func _yard_camera(item_name: String, point: Vector3, yaw: float) -> void:
	# Pole roots are placed at camera height; the reusable pole reaches exactly
	# down to the finished yard surface and remains outside primary paths.
	var camera := _place(CCTV, item_name, point + Vector3.UP * 3.4, yaw) as CCTVCamera
	camera.mount_type = CCTVCamera.MountType.POLE
	camera.pole_height = 3.4
	camera.tilt_degrees = -24.0
	camera.set_meta("support_type", "floor_pole")


func _fence_sign(item_name: String, point: Vector3, yaw: float, text: String) -> void:
	var sign := DETAIL.instantiate() as CampusDetailProp
	sign.name = item_name
	sign.detail_kind = DetailKind.DetailKind.FENCE_SIGN
	sign.display_text = text
	sign.position = point
	sign.rotation_degrees.y = yaw
	sign.visual_layer_mask = visual_layer_mask
	sign.set_meta("placement_zone", "Central Yard Fence")
	sign.set_meta("support_type", "fence_mounted")
	add_child(sign)


func _fence(item_name: String, a: Vector3, b: Vector3, height := 3.2) -> void:
	var panel := FENCE.instantiate() as Node3D
	panel.name = item_name
	panel.position = (a + b) * 0.5
	panel.rotation.y = -atan2(b.z - a.z, b.x - a.x)
	panel.set("length", a.distance_to(b))
	panel.set("height", height)
	panel.set("visual_layer_mask", visual_layer_mask)
	add_child(panel)


func _gate(item_name: String, point: Vector3, width: float, yaw := 0.0, locked := false, label := "RECREATION", direction := 1.0) -> void:
	var gate := GATE.instantiate() as PrisonSlidingGate
	gate.name = item_name
	gate.position = point
	gate.rotation_degrees.y = yaw
	gate.display_name = label.capitalize()
	gate.gate_width = width
	gate.gate_height = 3.2
	gate.slat_count = 10
	gate.slide_distance = width + 0.3
	gate.open_direction = direction
	gate.required_key_id = &"pool_maintenance_key" if locked else &""
	gate.persistent_access_id = StringName(item_name.to_snake_case())
	gate.starts_locked = locked
	gate.reader_light_enabled = false
	gate.panel_label = label
	gate.gate_color = Color("6d7a71")
	gate.add_to_group("campus_recreation_gates")
	add_child(gate)


func _path(item_name: String, center: Vector3, footprint: Vector2) -> void:
	# Surface matches the common ground at y=0; this thin finish has no collision lip.
	_g.box(item_name, center + Vector3.UP * 0.019, Vector3(footprint.x, 0.028, footprint.y), Color("979b90"), false)


func _build_yard_dressing() -> void:
	var line := Color("e0ddc7")
	for z in [-11.0, 11.0, 0.0]:
		_g.box("CourtCrossLine", Vector3(-14, 0.031, z), Vector3(14, 0.008, 0.08), line, false)
	for x in [-21.0, -7.0]:
		_g.box("CourtSideline", Vector3(x, 0.031, 0), Vector3(0.08, 0.008, 22), line, false)
	for z in [-7.0, 7.0]:
		_g.box("FreeThrowLine", Vector3(-14, 0.032, z), Vector3(4.6, 0.008, 0.08), line, false)
		for x in [-16.3, -11.7]:
			_g.box("CourtKeyLine", Vector3(x, 0.032, signf(z) * 9), Vector3(0.08, 0.008, 4), line, false)
	# A low-poly line ring is part of the court paint, never a physical barrier.
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		var next := TAU * float(index + 1) / 20.0
		var a := Vector3(-14 + cos(angle) * 1.8, 0.033, sin(angle) * 1.8)
		var b := Vector3(-14 + cos(next) * 1.8, 0.033, sin(next) * 1.8)
		var basis := Basis(Vector3.UP, -atan2(b.z - a.z, b.x - a.x))
		_g.oriented_box("CenterCirclePaint", Transform3D(basis, (a + b) * 0.5), Vector3(a.distance_to(b), 0.006, 0.06), line, false)
	_place(HOOP, "NorthBasketballHoop", Vector3(-14, 0.015, -12.3))
	_place(HOOP, "SouthBasketballHoop", Vector3(-14, 0.015, 12.3), 180)
	_place(PULL_UP, "PullUpStationA", Vector3(10, 0.015, -16))
	_place(PULL_UP, "PullUpStationB", Vector3(17, 0.015, -16))
	_place(PARALLEL, "ParallelBarStation", Vector3(10, 0.015, -10))
	_place(BENCH, "ExerciseBench", Vector3(18, 0.015, -7))
	# Paths subdivide the existing garden paint without adding another pad.
	_path("GardenNorthSouthPath", Vector3(14, 0, 12), Vector2(1.8, 16))
	_path("GardenEastWestPath", Vector3(14, 0, 12), Vector2(16, 1.8))
	for point in [Vector3(9, 0.015, 7), Vector3(19, 0.015, 7), Vector3(9, 0.015, 18), Vector3(19, 0.015, 18)]:
		_place(SHRUB, "GardenShrub", point)
	for point in [Vector3(10, 0.015, 9.5), Vector3(18, 0.015, 16)]:
		_place(TREE, "GardenTree", point)
	for point in [Vector3(10.5, 0.015, 15), Vector3(18, 0.015, 9), Vector3(17.5, 0.015, 19)]:
		_place(FLOWERS, "GardenFlowerBed", point)
	_place(BENCH, "GardenBenchWest", Vector3(10.5, 0.015, 13.8))
	_place(BENCH, "GardenBenchEast", Vector3(18.0, 0.015, 13.8))
	_place(BENCH, "CourtSpectatorBench", Vector3(-18, 0.01, 19), 180)
	_place(BIN, "SouthYardBin", Vector3(4, 0.01, 23))
	_place(BIN, "ExerciseAreaBin", Vector3(22.0, 0.01, -18.5))
	_yard_camera("NorthWestYardCamera", Vector3(-22.5, 0, -23.0), -135.0)
	_yard_camera("SouthEastYardCamera", Vector3(22.5, 0, 23.0), 45.0)
	_fence_sign("NorthFenceNotice", Vector3(-9.0, 0, -27.06), 180.0, "YARD RULES · CCTV")
	_fence_sign("SouthFenceNotice", Vector3(9.0, 0, 27.06), 0.0, "RESTRICTED BOUNDARY")
	_fence_sign("EastFenceNotice", Vector3(26.06, 0, 10.0), -90.0, "NO UNAUTHORIZED ACCESS")


func _build_pool_annex() -> void:
	# Four deck strips leave a genuine hole through to the recessed basin.
	_path("PoolDeckNorth", Vector3(-14, 0, 35.75), Vector2(27, 3.5))
	_path("PoolDeckSouth", Vector3(-14, 0, 49.25), Vector2(27, 3.5))
	_path("PoolDeckWest", Vector3(-25.75, 0, 42.5), Vector2(3.5, 10))
	_path("PoolDeckEast", Vector3(-2.25, 0, 42.5), Vector2(3.5, 10))
	_place(preload("res://scenes/props/yard/SwimmingPool.tscn"), "CommunityPool", Vector3(-14, 0, 42.5))
	# Deliberately open deck: retain the secure compound perimeter and the
	# road crossing checkpoint, remove the pool's inner AND outer wire cage.
	_place(BENCH, "PoolDeckBench", Vector3(-18.5, 0.035, 50.3), 180)
	_place(BIN, "PoolDeckBin", Vector3(-23, 0.035, 50.4))


func _build_medical_connection() -> void:
	# The Medical east door now meets the deck through a short 1.9m landing.
	_path("MedicalPoolLanding", Vector3(-28.45, 0, 50.5), Vector2(1.9, 3.0))
	_place(GAZEBO, "OfficerGazebo", Vector3(-36, 0.035, 28))
	_place(KIOSK, "RecreationSecurityPost", Vector3(-31, 0.035, 29), 90)
	_g.sign("GYM / SHOWERS / POOL", Vector3(-29.25, 2.2, 49.3), Vector3(0, 90, 0), Color("e0d7b9"), 0.003)


func _build_pedestrian_crossing() -> void:
	# Direct marked crossing from the south yard gate to the pool deck; the
	# former second fence/gate vestibule only consumed space and implied access.
	_path("YardPoolApproach", Vector3(-1, 0, 30.5), Vector2(3.0, 7.0))
	for z in [28.8, 29.7, 30.6, 31.5, 32.4, 33.3]:
		_g.box("PedestrianCrossingStripe", Vector3(-1, 0.033, z), Vector3(2.8, 0.012, 0.36), Color("dedcc7"), false)


func _fit_existing_yard_gates() -> void:
	# Existing infrastructure already has posts and matched 4m breaks. Leaves sit
	# 20cm off the fence face, so sideways travel doesn't clip the fixed mesh.
	_gate("CentralYardSouthGate", Vector3(0, 0, 27.2), 4.0, 0, false, "YARD / POOL")
	_gate("CentralYardNorthGate", Vector3(0, 0, -27.2), 4.0, 0, false, "YARD")
	_gate("CentralYardWestMainGate", Vector3(-26.2, 0, 0), 4.0, 90, false, "YARD")
	_gate("CentralYardWestSecondaryGate", Vector3(-26.2, 0, 15), 4.0, 90, false, "YARD")
	_gate("CentralYardEastGate", Vector3(26.2, 0, 0), 4.0, 90, false, "YARD")
