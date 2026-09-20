extends RefCounted
class_name CampusRoomFurnisher

## Deliberate room-local recipes. All elevations are relative to finished floor.
## Call while room_root is in SceneTree so existing reusable props run _ready.
## Doors carry position:Vector3, width:float, axis:x/z, optional kind.
const Fixture := preload("res://scripts/levels/campus/furnishing/campus_furnishing_fixture.gd")
const Batcher := preload("res://scripts/levels/campus/furnishing/campus_furniture_batcher.gd")
const Detail := preload("res://scripts/props/campus_detail_prop.gd")
const DETAIL_SCENE := preload("res://scenes/props/common/CampusDetailProp.tscn")
const STEEL := preload("res://materials/props/stainless_steel.tres")
const DARK := preload("res://materials/props/security_dark.tres")

var _root: Node3D
var _width: float
var _depth: float
var _wall := 0.11
var _doors: Array
var _footprints: Array[Rect2] = []
var _skipped: Array[String] = []

static func dress(room_root: Node3D, plan_id: String, room_data: Dictionary, doorways: Array) -> void:
	if room_root.has_node("Furnishings") or String(room_data.get("type", "")) in ["stair", "lift", "void"]:
		return
	var maker := CampusRoomFurnisher.new()
	maker._root = Node3D.new()
	maker._root.name = "Furnishings"
	maker._root.set_meta("plan_id", plan_id)
	maker._root.set_meta("room_id", String(room_data.get("id", "")))
	maker._root.add_to_group("campus_furnished_rooms")
	room_root.add_child(maker._root)
	maker._width = float(room_data.w)
	maker._depth = float(room_data.d)
	maker._wall = float(room_data.get("wall_thickness", 0.22)) * 0.5
	maker._doors = doorways
	maker._recipe(plan_id, String(room_data.id), String(room_data.get("label", "")), String(room_data.get("type", "")))
	if maker._root.get_child_count() == 0:
		maker._root.queue_free()
		return
	maker._root.set_meta("furniture_footprints", maker._footprints)
	maker._root.set_meta("clearance_omissions", maker._skipped)
	# Static visual batching is confined to furniture: doors and gameplay nodes
	# belong to the architecture and are never merged or altered here.
	Batcher.consolidate(maker._root)

func _recipe(plan_id: String, id: String, label: String, room_type: String) -> void:
	if room_type == "corridor":
		_corridor_details(plan_id, id, label)
		return
	if plan_id.begins_with("cellhouse-a"):
		if id.begins_with("void"):
			_seating_room()
		return # Existing reusable cells and guard rooms already own their fittings.
	if plan_id == "food-ground":
		match id:
			"dining": _dining()
			"serving": _serving()
			"kitchen": _kitchen()
			"prep": _prep()
			"wash": _dishwash()
			"cold": _cold_storage()
			"dry": _storage("food")
			"receiving": _receiving()
		return
	if plan_id == "medical-ground":
		match id:
			"ward": _ward()
			"gym": _gym()
			"changing": _changing()
			"showers": _showers()
			"toilets": _toilets()
			"medicine": _medicine()
			"exam", "treatment": _clinic()
			_: _office()
		return
	if plan_id.begins_with("cellhouse-b"):
		if (id.begins_with("n") or id.begins_with("s")) and id.length() == 2:
			var rotation_y := 0.0 if id.begins_with("n") else PI
			_fixture("SecureCellFurniture", Vector3.ZERO, rotation_y, {})
		elif id in ["glassa", "glassb"]:
			_special_cell()
		elif "LINEN" in label:
			_storage("linen")
		elif "DUTY POINT" in label or id == "staff":
			_secure_duty_post(label)
		elif id == "interview" or "CONSULT" in label:
			_secure_interview()
		else:
			_office()
		return
	if plan_id.begins_with("hq"):
		match id:
			"surveillance", "control": _control_room()
			"server": _server_room()
			"keys": _key_room()
			"equipment", "evidence": _hq_secure_storage(id)
			"briefing", "staff": _meeting()
			_: _office()
		return
	if plan_id.begins_with("maintenance"):
		match id:
			"workshop", "tool": _workshop()
			"dirty", "clean": _laundry(id == "clean")
			"store", "spares": _storage("parts")
			"waste": _dishwash()
			_: _plant_room(label)
		return
	if plan_id == "nidra-b2":
		match id:
			"lab", "chem": _laboratory()
			"subjects": _subject_room()
			"interrogationa", "interrogationb": _interrogation()
			"observation": _control_room()
			"clean": _decontamination()
			"samples": _cold_storage()
			"hazmat": _storage("hazmat")
			_: _storage("records")
		return
	if plan_id == "admin-ground":
		match id:
			"visitation": _visitation()
			"visitorhall", "holding": _seating_room()
			"publicwc", "staffwc": _small_wc()
			"meeting": _meeting()
			"reception": _reception()
			"processing": _intake_processing()
			"records": _records_room()
			"office", "interview": _admin_office()
			_: _office()

func _corridor_details(plan_id: String, id: String, label: String) -> void:
	# Corridors receive wall-supported wayfinding and utilities only. Their
	# centre lines remain empty for player, gate and future NPC circulation.
	if plan_id.begins_with("cellhouse-b"):
		if id in ["spine", "westwing", "eastwing", "staffcorr"]:
			_wall_prop("security/CCTVCamera", "W" if _depth > _width else "N", -_depth * 0.5 + 2.0 if _depth > _width else -_width * 0.5 + 2.0)
			_wall_detail(Detail.DetailKind.SECURITY_SIGN, "E" if _depth > _width else "S", 0.0, "CONTROLLED MOVEMENT")
			_wall_detail(Detail.DetailKind.ELECTRICAL_BOX, "W" if _depth > _width else "N", _depth * 0.25 if _depth > _width else _width * 0.25)
		elif "CHECKPOINT" in label:
			_wall_detail(Detail.DetailKind.SECURITY_SIGN, "N", 0.0, "STOP · IDENTIFICATION")
	elif plan_id.begins_with("hq"):
		_wall_detail(Detail.DetailKind.SECURITY_SIGN, "E" if _depth > _width else "S", 0.0, "SECURITY HQ · RESTRICTED")
		_wall_prop("security/CCTVCamera", "W" if _depth > _width else "N", -_depth * 0.5 + 1.8 if _depth > _width else -_width * 0.5 + 1.8)
	elif plan_id.begins_with("maintenance"):
		_wall_detail(Detail.DetailKind.UTILITY_PIPE_RUN, "W" if _depth > _width else "N", 0.0)
		_wall_detail(Detail.DetailKind.ELECTRICAL_BOX, "E" if _depth > _width else "S", _depth * 0.25 if _depth > _width else _width * 0.25)
	elif plan_id == "nidra-b2":
		_wall_detail(Detail.DetailKind.SECURITY_SIGN, "E" if _depth > _width else "S", 0.0, "NIDRA · AUTHORIZED PERSONNEL")
		_wall_prop("security/CCTVCamera", "W" if _depth > _width else "N", -_depth * 0.5 + 2.0 if _depth > _width else -_width * 0.5 + 2.0)
	elif plan_id == "medical-ground":
		_wall_prop("common/NoticeBoard", "W" if _depth > _width else "N", 0.0)
		_wall_prop("common/WallClock", "E" if _depth > _width else "S", 0.0)
	elif plan_id == "food-ground":
		_wall_detail(Detail.DetailKind.SECURITY_SIGN, "N", -8.0, "FOOD SERVICE · STAFF ONLY")
		_wall_prop("common/WallClock", "S", 8.0)
	elif plan_id == "admin-ground":
		_wall_prop("common/NoticeBoard", "W" if _depth > _width else "N", 0.0)
		_wall_detail(Detail.DetailKind.SECURITY_SIGN, "E" if _depth > _width else "S", 0.0, "ESCORTED ACCESS")

func _dining() -> void:
	# Twelve six-place fixed table/bench frames. A 2.9m lane at x=5.25
	# aligns with the exterior entrance; x=-1.25 reaches the staff threshold.
	for z in [-4.8, -0.6, 3.6]:
		for x in [-10.0, -5.0, 2.5, 8.0]:
			var table := _place("cafeteria/CafeteriaTableSet", Vector3(x, 0, z))
			if table:
				table.add_to_group("campus_dining_table_sets")
				_top(table, "cafeteria/FoodTray", Vector3(-0.75, 0.86, 0))
				_top(table, "cafeteria/FoodTray", Vector3(0.75, 0.86, 0))
	_wall_prop("common/WallClock", "N", -7.0)
	_wall_prop("common/NoticeBoard", "N", 6.0)
	_wall_detail(Detail.DetailKind.INCIDENT_BOARD, "N", 0.0, "TODAY'S MENU")
	_wall_prop("cafeteria/DrinkingFountain", "W", 5.5)
	_place("cafeteria/WaterDispenser", Vector3(-11.9, 0, 5.9))
	_place("cafeteria/CondimentStation", Vector3(-3.5, 0, 6.5), PI)
	_place("common/TrashBin", Vector3(11.9, 0, 6.5))
	_place("cafeteria/CleaningCart", Vector3(-8.5, 0, 6.6))
	# Short queue lanes leave both end approaches open along the serving wall.
	for z in [-4.6, -1.0]:
		_place("cafeteria/QueueRailing", Vector3(11.2, 0, z), PI * 0.5)

func _serving() -> void:
	# The 6m hatch in the west boundary takes exactly three reusable 2m bays.
	_fixture("ServingLine", Vector3(-_width * 0.5 + _wall, 0, 0), PI * 0.5, {"count": 3, "bay_width": 2.0})
	for z in [-2.1, 2.1]:
		var counter := _place("kitchen/PrepCounter", Vector3(_width * 0.5 - 0.65, 0, z), -PI * 0.5)
		if counter:
			_detail_top(counter, Detail.DetailKind.FOOD_CONTAINERS, Vector3(0, 1.0, 0))
	# Keep the mobile cart in the centre service bay, clear of the south
	# serving-to-wash door's full swing envelope.
	_place("common/UtilityCart", Vector3(-1.4, 0, 0.0))

func _kitchen() -> void:
	for x in [-6.5, -2.8, 1.0]:
		var range_prop := _place("kitchen/CookingRange", Vector3(x, 0, -_depth * 0.5 + 0.9))
		if range_prop:
			_top(range_prop, "kitchen/CookingVessel", Vector3(0, 1.035, 0))
			var hood := _top(range_prop, "kitchen/ExtractorHood", Vector3(0, 0, -0.42))
			# Existing hood gets a wall-backed support column extending continuously
			# to its canopy; it does not hang below an absent ceiling.
			_support_box(hood, "HoodWallSupport", Vector3(0, 1.15, -0.2), Vector3(0.3, 2.3, 0.18))
	_place("kitchen/IndustrialOven", Vector3(6.3, 0, -_depth * 0.5 + 1.0))
	_place("kitchen/Refrigerator", Vector3(_width * 0.5 - 0.8, 0, -1.8), -PI * 0.5)
	_place("kitchen/IndustrialSink", Vector3(_width * 0.5 - 0.7, 0, 1.6), -PI * 0.5)
	for x in [-5.0, 1.0]:
		_place("kitchen/PrepCounter", Vector3(x, 0, 0.6))
	_wall_prop("kitchen/ToolRack", "W", -3.5)
	_place("common/TrashBin", Vector3(-_width * 0.5 + 0.65, 0, 4.8))
	_place("common/UtilityCart", Vector3(5.5, 0, 4.7))

func _prep() -> void:
	for z in [-2.5, 2.5]:
		var counter := _place("kitchen/PrepCounter", Vector3(-2.2, 0, z), PI if z > 0 else 0.0)
		if counter:
			_detail_top(counter, Detail.DetailKind.FOOD_CONTAINERS, Vector3(0, 1.0, 0))
	_place("kitchen/IndustrialSink", Vector3(2.2, 0, -2.5))
	_wall_prop("kitchen/ToolRack", "N", -2.2)
	_place("common/UtilityCart", Vector3(2.3, 0, 2.3))

func _dishwash() -> void:
	_place("kitchen/DishwashingStation", Vector3(_width * 0.5 - 0.9, 0, 0), -PI * 0.5)
	_place("kitchen/IndustrialSink", Vector3(-_width * 0.5 + 0.85, 0, -_depth * 0.5 + 1.4), PI * 0.5)
	_place("cafeteria/TrayReturn", Vector3(-_width * 0.5 + 0.65, 0, 0), -PI * 0.5)
	_place("common/StorageRack", Vector3(1.6, 0, _depth * 0.5 - 0.7), PI)
	_place("common/UtilityCart", Vector3(-2.6, 0, _depth * 0.5 - 0.85))
	_place("common/TrashBin", Vector3(_width * 0.5 - 0.65, 0, -_depth * 0.5 + 0.65))

func _cold_storage() -> void:
	_place("kitchen/Refrigerator", Vector3(-_width * 0.5 + 0.9, 0, -_depth * 0.5 + 0.85))
	_place("kitchen/Freezer", Vector3(_width * 0.5 - 1.0, 0, -_depth * 0.5 + 0.85))
	for x in [-_width * 0.5 + 0.9, _width * 0.5 - 0.9]:
		_place("common/MetalShelving", Vector3(x, 0, 1), PI * 0.5)

func _storage(kind: String) -> void:
	var step := 2.7
	for z in range(maxi(1, int((_depth - 2.0) / step))):
		var pz := -_depth * 0.5 + 1.5 + z * step
		for side in [-1.0, 1.0]:
			var x: float = side * (_width * 0.5 - 0.65)
			if kind == "hazmat":
				_place("laboratory/HazmatCabinet", Vector3(x, 0, pz), -side * PI * 0.5)
			else:
				var shelf := _place("common/StorageRack", Vector3(x, 0, pz), -side * PI * 0.5)
				if shelf:
					# Small supplies sit on actual shelf surfaces, never between shelves.
					_top(shelf, "common/StorageCrate", Vector3(0, 2.235, 0))
	if kind == "food":
		_place("kitchen/FoodSackStack", Vector3(_width * 0.5 - 1.2, 0, _depth * 0.5 - 1.15))
	elif kind == "evidence":
		_place("security/LargeEvidenceSafe", Vector3(0, 0, -_depth * 0.5 + 0.9))
	elif kind == "linen":
		_place("cafeteria/CleaningCart", Vector3(0, 0, -_depth * 0.5 + 1.0))

func _receiving() -> void:
	_place("kitchen/PrepCounter", Vector3(-2.8, 0, -1.7))
	_place("common/StorageRack", Vector3(_width * 0.5 - 0.75, 0, -1.65), -PI * 0.5)
	_place("common/UtilityCart", Vector3(-_width * 0.5 + 0.85, 0, 1.5))
	_place("common/StorageCrate", Vector3(2.8, 0, 1.6))
	_wall_prop("common/NoticeBoard", "W", 0)

func _ward() -> void:
	for x in [-2.8, 2.8]:
		for z in [-4.4, -0.8, 2.8]:
			_fixture("ClinicalBedBay", Vector3(x, 0, z), 0, {})
	for x in [-2.8, 2.8]:
		for z in [-2.6, 1.0]:
			_place("medical/PrivacyDivider", Vector3(x, 0, z))
	_wall_prop("medical/MedicalSink", "N", 0)
	_wall_prop("medical/MedicalDisplay", "N", -2.8)
	_place("medical/MedicalCart", Vector3(-_width * 0.5 + 0.75, 0, 5.0))
	_place("medical/Wheelchair", Vector3(_width * 0.5 - 0.9, 0, 5.0), PI)
	_place("medical/BiohazardBin", Vector3(_width * 0.5 - 0.6, 0, -5.6))

func _clinic() -> void:
	_place("medical/ExamTable", Vector3(-_width * 0.5 + 1.35, 0, 0))
	_place("medical/MedicalStool", Vector3(-_width * 0.5 + 2.5, 0, -0.4))
	_place("medical/DiagnosticMachine", Vector3(_width * 0.5 - 1.0, 0, -_depth * 0.5 + 1.2), -PI * 0.5)
	_place("medical/MedicalCart", Vector3(_width * 0.5 - 1.0, 0, 1.4))
	_wall_prop("medical/MedicalSink", "W", -_depth * 0.5 + 0.9)
	_wall_prop("medical/MedicineCabinet", "N", 0)
	_wall_prop("medical/MedicalDisplay", "W", 0)
	_place("medical/BiohazardBin", Vector3(-_width * 0.5 + 0.6, 0, _depth * 0.5 - 0.7))

func _medicine() -> void:
	for z in [-2.1, 0, 2.1]:
		_wall_prop("medical/MedicineCabinet", "W", z)
		_wall_prop("medical/MedicineCabinet", "E", z)
	_wall_prop("security/SmallWallSafe", "S", -0.8)

func _gym() -> void:
	# North strength line: Flat Bench, Incline Bench, Squat Rack, Cable Machine, Lat Pulldown
	_place("gym/FlatBenchPress", Vector3(-6.0, 0, -4.6))
	_place("gym/InclineBenchPress", Vector3(-3.0, 0, -4.6))
	_place("gym/SquatRack", Vector3(0.0, 0, -4.6))
	_place("gym/CableMachine", Vector3(3.0, 0, -4.6))
	_place("gym/LatPulldown", Vector3(5.8, 0, -4.6))

	# West free-weight & calisthenics area
	_place("gym/DumbbellRack", Vector3(-6.5, 0, -1.2), PI * 0.5)
	_place("gym/WeightPlateStack", Vector3(-6.5, 0, 1.2))
	_place("gym/WeightBench", Vector3(-3.8, 0, 0.2))
	_place("gym/Barbell", Vector3(-3.8, 0, -2.0), PI * 0.5)
	_place("gym/DipStation", Vector3(-6.5, 0, 3.8))
	_place("gym/PullUpBar", Vector3(-3.5, 0, 4.4))

	# East cardio & machine area: Treadmills, Rowing Machine, Leg Press, Exercise Bikes
	_place("gym/Treadmill", Vector3(3.2, 0, -1.5), PI)
	_place("gym/Treadmill", Vector3(5.8, 0, -1.5), PI)
	_place("gym/RowingMachine", Vector3(5.8, 0, 1.5), PI)
	_place("gym/LegPress", Vector3(2.5, 0, 1.5))
	_place("gym/ExerciseBike", Vector3(5.8, 0, 4.3), PI)
	_place("gym/ExerciseBike", Vector3(3.4, 0, 4.3), PI)

	# Central conditioning, punch bag and mats
	# Keep the suspended bag clear of the east-hall door swing and landing.
	_place("gym/PunchingBag", Vector3(-2.0, 0, 4.4))
	_place("gym/ExerciseMat", Vector3(-0.5, 0, 1.5))
	_place("gym/ExerciseMat", Vector3(-0.5, 0, -1.5))

	_wall_prop("cafeteria/DrinkingFountain", "E", 4.8)
	_wall_prop("common/WallClock", "N", 0)
	_place("common/MetalShelving", Vector3(-6.5, 0, -3.2), PI * 0.5)

func _changing() -> void:
	# Doors use the middle of all three long-side thresholds. Locker banks
	# are offset into the ends, leaving a continuous central change-over aisle.
	for x in [-7.0, -6.2, -5.4, -2.2, -1.4, 1.4, 2.2, 5.4, 6.2, 7.0]:
		_place("common/Locker", Vector3(x, 0, -_depth * 0.5 + 0.48))
	for x in [-6.4, 6.4]:
		_place("common/Bench", Vector3(x, 0, _depth * 0.5 - 0.6), PI)

func _showers() -> void:
	_fixture("ShowerBank", Vector3(-_width * 0.5 + _wall, 0, 0), PI * 0.5, {"count": 5, "bay_width": 2.1})
	_fixture("ShowerBank", Vector3(_width * 0.5 - _wall, 0, 0), -PI * 0.5, {"count": 5, "bay_width": 2.1})
	_wall_prop("prison/TowelHooks", "S", 0)
	_wall_detail(Detail.DetailKind.UTILITY_PIPE_RUN, "N", 0.0)
	_place("common/Bench", Vector3(0, 0, _depth * 0.5 - 0.6), PI)

func _toilets() -> void:
	# Eight west-wall toilet cubicles opposite eight divided urinals. The
	# remaining centre aisle exceeds 4m. One end cubicle is 1.8m wide.
	_fixture("ToiletBank", Vector3(-_width * 0.5 + _wall, 0, -0.65), PI * 0.5, {"count": 7, "bay_width": 1.3})
	_fixture("ToiletBank", Vector3(-_width * 0.5 + _wall, 0, 4.85), PI * 0.5, {"count": 1, "bay_width": 1.8})
	_fixture("UrinalBank", Vector3(_width * 0.5 - _wall, 0, 0), -PI * 0.5, {"count": 8, "bay_width": 1.3})
	for x in [-0.65, 0.65]:
		_wall_prop("prison/WashBasin", "S", x)
		_wall_prop("prison/Mirror", "S", x)
	_wall_prop("common/WallTrashBin", "S", 2.0)

func _office() -> void:
	var desks := 2 if _width >= 9.0 else 1
	for i in range(desks):
		var x := (i - (desks - 1) * 0.5) * 4.0
		var desk := _place("medical/DoctorDesk", Vector3(x, 0, -_depth * 0.5 + 1.0))
		if desk:
			_top(desk, "laboratory/ComputerTerminal", Vector3(0, 0.87, -0.05))
			_place("common/Chair", Vector3(x, 0, -_depth * 0.5 + 2.0), PI)
	_place("common/FilingCabinet", Vector3(-_width * 0.5 + 0.8, 0, _depth * 0.5 - 0.75), PI)
	_place("common/Locker", Vector3(_width * 0.5 - 0.6, 0, _depth * 0.5 - 0.7), PI)
	_wall_prop("common/NoticeBoard", "W", 0)
	_wall_prop("common/WallClock", "E", 0)

func _meeting() -> void:
	for z in [-1.2, 1.2]:
		_place("common/Table", Vector3(0, 0, z), PI * 0.5)
		for x in [-1.05, 1.05]:
			_place("common/Chair", Vector3(x, 0, z), -signf(x) * PI * 0.5)
	_wall_prop("common/NoticeBoard", "N", 0)
	_place("common/FilingCabinet", Vector3(_width * 0.5 - 0.8, 0, -_depth * 0.5 + 0.8))
	_wall_prop("common/WallClock", "W", 0)

func _control_room() -> void:
	var along := maxi(1, int((_width - 1.5) / 2.6))
	for i in range(along):
		var x := (i - (along - 1) * 0.5) * 2.6
		var console := _place("security/SecurityConsole", Vector3(x, 0, -_depth * 0.5 + 0.7))
		if console:
			_detail_top(console, Detail.DetailKind.RADIO_SET if i % 2 == 0 else Detail.DetailKind.PAPERWORK, Vector3(0.55, 0.98, 0.05))
		_place("common/Chair", Vector3(x, 0, -_depth * 0.5 + 1.75), PI)
	if _depth > 5.0:
		for z in [0.0, 2.5]:
			_place("laboratory/MonitoringEquipment", Vector3(_width * 0.5 - 0.7, 0, z), -PI * 0.5)
	_wall_prop("common/WallClock", "N", 0)
	# Both control-room entrances are centred in the south wall. Keep the full
	# monitor array on the uninterrupted north wall so it cannot cover a door.
	_wall_detail(Detail.DetailKind.MONITOR_WALL, "N", 0.0)
	_wall_detail(Detail.DetailKind.SECURITY_MAP, "W", 0.0, "FACILITY STATUS")

func _server_room() -> void:
	for side in [-1.0, 1.0]:
		for z in [-2.2, -0.8, 0.6, 2.0]:
			_fixture("ServerCabinet", Vector3(side * (_width * 0.5 - 0.8), 0, z), -side * PI * 0.5, {})

func _key_room() -> void:
	# Actual key interactables/cabinets are installed by gameplay migration;
	# this recipe reserves the west and east walls entirely for that system.
	_place("security/MediumOfficeSafe", Vector3(-2, 0, -_depth * 0.5 + 0.75))
	_place("medical/DoctorDesk", Vector3(1.2, 0, _depth * 0.5 - 0.9), PI)
	_place("common/Chair", Vector3(1.2, 0, _depth * 0.5 - 2))
	# The key-room entry occupies the north wall; controlled keys belong on the
	# solid south wall opposite it.
	_wall_detail(Detail.DetailKind.KEY_CABINET, "S", 0.0)
	_wall_detail(Detail.DetailKind.SECURITY_SIGN, "S", -2.0, "KEY CONTROL · LOG ALL USE")

func _hq_secure_storage(id: String) -> void:
	_storage("evidence")
	_wall_detail(Detail.DetailKind.INCIDENT_BOARD, "N", 0.0, "CHAIN OF CUSTODY" if id == "evidence" else "EQUIPMENT ISSUE")
	_wall_detail(Detail.DetailKind.SECURITY_MAP, "S", 0.0, "SECURE STORAGE")

func _workshop() -> void:
	for x in [-_width * 0.5 + 1.8, _width * 0.5 - 1.8]:
		_place("workshop/WorkshopBench", Vector3(x, 0, -_depth * 0.5 + 0.8))
	for z in [0, 3.0]:
		_place("common/StorageRack", Vector3(_width * 0.5 - 0.65, 0, z), -PI * 0.5)
	_place("common/UtilityCart", Vector3(-_width * 0.5 + 1.0, 0, 1.0))
	_wall_prop("common/FireExtinguisherCabinet", "W", 3.0)
	_wall_detail(Detail.DetailKind.TOOL_BOARD, "N", 0.0)
	_detail(Detail.DetailKind.MECHANICAL_PARTS, Vector3(0, 0, 3.4), 0.0, true)

func _laundry(clean: bool) -> void:
	var machine_positions := [-4.4, -2.0, 3.5] if clean else [-4.4, -1.8, 0.8]
	for z in machine_positions:
		_fixture("LaundryMachine", Vector3(-_width * 0.5 + 0.9, 0, z), PI * 0.5, {"display_label": "INDUSTRIAL DRY" if clean else "INDUSTRIAL WASH"})
	if clean:
		_place("kitchen/PrepCounter", Vector3(0.4, 0, 0))
		_place("common/StorageRack", Vector3(_width * 0.5 - 0.65, 0, -3), -PI * 0.5)
	else:
		_place("kitchen/IndustrialSink", Vector3(_width * 0.5 - 0.7, 0, -3), -PI * 0.5)
	_place("common/UtilityCart", Vector3(_width * 0.5 - 1.0, 0, 3.8))
	_detail(Detail.DetailKind.CLEANING_SUPPLIES, Vector3(_width * 0.5 - 0.7, 0, -_depth * 0.5 + 0.8), 0.0, true)

func _plant_room(label: String) -> void:
	if "ELECTRICAL" in label:
		for z in [-2.2, 0, 2.2]:
			_fixture("ServerCabinet", Vector3(-_width * 0.5 + 0.8, 0, z), PI * 0.5, {})
		_wall_prop("laboratory/ControlPanel", "E", 0)
		_wall_detail(Detail.DetailKind.ELECTRICAL_PANEL, "N", 0.0, "DISTRIBUTION")
	else:
		for x in [-_width * 0.5 + 2.0, _width * 0.5 - 2.0]:
			_fixture("PlantSkid", Vector3(x, 0, -_depth * 0.5 + 1.5), 0, {"display_label": label.split("/")[0].strip_edges()})
		_place("common/StorageRack", Vector3(-_width * 0.5 + 0.7, 0, _depth * 0.5 - 2.0), PI * 0.5)
		_wall_detail(Detail.DetailKind.UTILITY_PIPE_RUN, "E", 0.0)

func _laboratory() -> void:
	for side in [-1.0, 1.0]:
		for z in [-_depth * 0.5 + 2.0, 0.4]:
			var bench := _place("laboratory/LabWorkbench", Vector3(side * (_width * 0.5 - 0.8), 0, z), -side * PI * 0.5)
			if bench:
				_top(bench, "laboratory/Microscope", Vector3(-0.65, 1.01, 0.2))
				_top(bench, "laboratory/SampleRack", Vector3(0.55, 1.01, 0.15))
				_place("medical/MedicalStool", Vector3(side * (_width * 0.5 - 1.85), 0, z))
	_place("laboratory/NidraTerminal", Vector3(_width * 0.5 - 0.9, 0, _depth * 0.5 - 1.4), PI)
	_wall_prop("laboratory/LabSink", "N", 0)
	_wall_prop("laboratory/LabSign", "S", -1.4)
	_place("laboratory/LabRefrigerator", Vector3(-_width * 0.5 + 0.85, 0, _depth * 0.5 - 1.2), PI)

func _subject_room() -> void:
	for x in [-2.5, 2.5]:
		_place("medical/HospitalBed", Vector3(x, 0, 1.7))
		_place("laboratory/SubjectStorage", Vector3(x, 0, -_depth * 0.5 + 1.0))
	_place("medical/MedicalCart", Vector3(-_width * 0.5 + 0.9, 0, 0))
	_wall_prop("medical/MedicalDisplay", "N", 0)

func _interrogation() -> void:
	_place("laboratory/RestraintChair", Vector3(-1.3, 0, 0.8))
	_place("laboratory/MetalExamTable", Vector3(1.5, 0, -0.8))
	# The supported cantilever lamp intentionally projects above the exam pad;
	# its floor base remains separate and its arm has no low invisible collider.
	_place("laboratory/ExaminationLight", Vector3(0.3, 0, -0.8), 0, false)
	_place("laboratory/EquipmentTrolley", Vector3(-_width * 0.5 + 0.9, 0, -2.2))
	_wall_prop("security/RecordingCamera", "N", -1.3)
	_wall_prop("laboratory/ControlPanel", "E", 1.8)
	_place("laboratory/MonitoringEquipment", Vector3(_width * 0.5 - 0.8, 0, 2.3), -PI * 0.5)
	_place("prison/FloorDrain", Vector3(0, 0, 2.0), 0, false)

func _decontamination() -> void:
	_wall_prop("laboratory/EmergencyShower", "W", -2.0)
	_wall_prop("laboratory/LabSink", "E", -1.7)
	for x in [-4, -2, 2, 4]:
		_place("common/Locker", Vector3(x, 0, _depth * 0.5 - 0.6), PI)
	_place("medical/BiohazardBin", Vector3(-_width * 0.5 + 0.7, 0, 2.4))

func _special_cell() -> void:
	_place("medical/HospitalBed", Vector3(-_width * 0.5 + 1.4, 0, -_depth * 0.5 + 2.2))
	_wall_prop("prison/WashBasin", "N", 1.2)
	_place("prison/Toilet", Vector3(_width * 0.5 - 1.0, 0, -_depth * 0.5 + 0.55))
	_place("common/Chair", Vector3(-1.0, 0, 0))
	_place("common/Locker", Vector3(_width * 0.5 - 0.7, 0, 1.7), -PI * 0.5)
	_wall_prop("security/RecordingCamera", "N", 0)
	_wall_detail(Detail.DetailKind.SECURITY_SIGN, "S", 0.0, "CONSTANT OBSERVATION")

func _secure_duty_post(label: String) -> void:
	var console := _place("security/SecurityConsole", Vector3(0, 0, -_depth * 0.5 + 0.8))
	if console:
		_detail_top(console, Detail.DetailKind.RADIO_SET, Vector3(0.55, 0.98, 0.04))
		_detail_top(console, Detail.DetailKind.PAPERWORK, Vector3(-0.55, 0.98, 0.04))
	_place("common/Chair", Vector3(0, 0, -_depth * 0.5 + 1.9), PI)
	_place("common/FilingCabinet", Vector3(-_width * 0.5 + 0.7, 0, _depth * 0.5 - 0.7), PI)
	_wall_prop("security/RecordingCamera", "S", 0.0)
	_wall_detail(Detail.DetailKind.INCIDENT_BOARD, "E", 0.0, label)

func _secure_interview() -> void:
	var table := _place("common/Table", Vector3(0, 0, 0))
	if table:
		_detail_top(table, Detail.DetailKind.PAPERWORK, Vector3(0, 0.88, 0))
	for z in [-1.0, 1.0]:
		_place("common/Chair", Vector3(0, 0, z), PI if z < 0 else 0.0)
	_wall_prop("security/RecordingCamera", "N", 0.0)
	_wall_detail(Detail.DetailKind.SECURITY_SIGN, "S", 0.0, "SECURE INTERVIEW")

func _seating_room() -> void:
	for x in [-_width * 0.5 + 2.0, _width * 0.5 - 2.0]:
		for z in [-_depth * 0.5 + 0.85, _depth * 0.5 - 0.85]:
			_place("common/Bench", Vector3(x, 0, z), PI if z > 0 else 0.0)
	_wall_prop("common/NoticeBoard", "W", 0)
	_wall_prop("common/WallClock", "E", 0)

func _small_wc() -> void:
	_fixture("ToiletBank", Vector3(-_width * 0.5 + _wall, 0, 0.4), PI * 0.5, {"count": 2, "bay_width": 1.5})
	_wall_prop("prison/WashBasin", "E", 0.5)
	_wall_prop("prison/Mirror", "E", 0.5)

func _visitation() -> void:
	_fixture("VisitationBooths", Vector3.ZERO, 0, {"count": 7, "bay_width": 2.0})
	# End return panels close both 1.75m side strips up to the room walls.
	# The only entries are the separate north/south aisles from the blueprint.
	for side in [-1.0, 1.0]:
		_support_box(_root, "VisitationEndScreen", Vector3(side * 7.85, 1.4, 0), Vector3(1.7, 2.8, 0.12), true)

func _reception() -> void:
	var desk := _place("medical/DoctorDesk", Vector3(0, 0, -_depth * 0.5 + 1.0))
	if desk:
		_top(desk, "laboratory/ComputerTerminal", Vector3(-0.45, 0.87, -0.05))
		_detail_top(desk, Detail.DetailKind.PAPERWORK, Vector3(0.48, 0.88, 0.05))
	_place("common/Chair", Vector3(0, 0, -_depth * 0.5 + 2.0), PI)
	_place("common/FilingCabinet", Vector3(-_width * 0.5 + 0.75, 0, _depth * 0.5 - 0.7), PI)
	_wall_prop("common/WallClock", "E", 0.0)
	_wall_prop("common/NoticeBoard", "W", 0.0)

func _intake_processing() -> void:
	for x in [-2.0, 2.0]:
		var table := _place("common/Table", Vector3(x, 0, 0))
		if table:
			_detail_top(table, Detail.DetailKind.PAPERWORK, Vector3(0, 0.88, 0))
	for x in [-_width * 0.5 + 0.7, _width * 0.5 - 0.7]:
		_place("common/Locker", Vector3(x, 0, _depth * 0.5 - 0.65), PI)
	_wall_detail(Detail.DetailKind.SECURITY_SIGN, "N", 0.0, "SEARCH / PROPERTY")

func _records_room() -> void:
	for z in [-2.1, 0.0, 2.1]:
		_place("common/FilingCabinet", Vector3(-_width * 0.5 + 0.7, 0, z), PI * 0.5)
		_place("common/StorageRack", Vector3(_width * 0.5 - 0.65, 0, z), -PI * 0.5)
	_wall_detail(Detail.DetailKind.INCIDENT_BOARD, "N", 0.0, "INTAKE RECORDS")

func _admin_office() -> void:
	_office()
	_wall_detail(Detail.DetailKind.SECURITY_MAP, "S", 0.0, "CAMPUS OPERATIONS")

func _fixture(scene_name: String, at: Vector3, yaw: float, settings: Dictionary) -> Node3D:
	var prop := load("res://scenes/levels/campus/furnishing/%s.tscn" % scene_name).instantiate() as Node3D
	prop.position = at
	prop.rotation.y = yaw
	for key in settings:
		prop.set(key, settings[key])
	_root.add_child(prop)
	prop.set_meta("fixture_recipe", scene_name)
	prop.set_meta("support_type", "assembly")
	prop.set_meta("furniture_bounds", _bounds(prop, prop.transform))
	prop.add_to_group("campus_placed_furniture")
	return prop

func _place(scene_name: String, at: Vector3, yaw := 0.0, reserve := true) -> Node3D:
	var prop := load("res://scenes/props/%s.tscn" % scene_name).instantiate() as Node3D
	prop.name = scene_name.get_file()
	prop.position = at
	prop.rotation.y = yaw
	_root.add_child(prop)
	_repair_supports(prop, scene_name)
	var bounds := _bounds(prop, prop.transform)
	# Correct tiny legacy foot/caster offsets from the actual visible geometry.
	if absf(bounds.position.y) < 0.15:
		prop.position.y -= bounds.position.y
	var rect := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
	if not _can_place(rect, reserve):
		_skipped.append(scene_name)
		prop.free()
		return null
	if reserve:
		_footprints.append(rect)
	prop.set_meta("source_prop_scene", scene_name)
	prop.set_meta("support_type", "floor")
	prop.set_meta("furniture_bounds", _bounds(prop, prop.transform))
	prop.add_to_group("campus_placed_furniture")
	return prop

func _detail(kind: int, at: Vector3, yaw := 0.0, reserve := false, text := "") -> Node3D:
	var prop := DETAIL_SCENE.instantiate() as CampusDetailProp
	prop.detail_kind = kind
	prop.display_text = text if not text.is_empty() else prop.display_text
	prop.position = at
	prop.rotation.y = yaw
	_root.add_child(prop)
	var bounds := _bounds(prop, prop.transform)
	var rect := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
	if not _can_place(rect, reserve):
		_skipped.append("detail/%s" % Detail.DetailKind.keys()[kind].to_lower())
		prop.free()
		return null
	if reserve:
		_footprints.append(rect)
	prop.set_meta("support_type", "floor")
	prop.set_meta("furniture_bounds", bounds)
	prop.add_to_group("campus_placed_furniture")
	return prop

func _wall_detail(kind: int, wall: String, along: float, text := "") -> Node3D:
	var prop := DETAIL_SCENE.instantiate() as CampusDetailProp
	prop.detail_kind = kind
	prop.display_text = text if not text.is_empty() else prop.display_text
	match wall:
		"N": prop.position = Vector3(along, 0, -_depth * 0.5 + _wall)
		"S":
			prop.position = Vector3(along, 0, _depth * 0.5 - _wall)
			prop.rotation.y = PI
		"W":
			prop.position = Vector3(-_width * 0.5 + _wall, 0, along)
			prop.rotation.y = PI * 0.5
		"E":
			prop.position = Vector3(_width * 0.5 - _wall, 0, along)
			prop.rotation.y = -PI * 0.5
	_root.add_child(prop)
	var bounds := _bounds(prop, prop.transform)
	var rect := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
	if not _can_place(rect, false):
		_skipped.append("detail/%s" % Detail.DetailKind.keys()[kind].to_lower())
		prop.free()
		return null
	prop.set_meta("wall_mount", wall)
	prop.set_meta("support_type", "wall")
	prop.set_meta("furniture_bounds", bounds)
	prop.add_to_group("campus_placed_furniture")
	return prop

func _detail_top(parent: Node3D, kind: int, at: Vector3, text := "") -> Node3D:
	var prop := DETAIL_SCENE.instantiate() as CampusDetailProp
	prop.detail_kind = kind
	prop.display_text = text if not text.is_empty() else prop.display_text
	prop.position = at
	parent.add_child(prop)
	prop.set_meta("supported_by", parent.name)
	prop.set_meta("support_type", "parent_surface")
	return prop

func _wall_prop(scene_name: String, wall: String, along: float) -> Node3D:
	var prop := load("res://scenes/props/%s.tscn" % scene_name).instantiate() as Node3D
	match wall:
		"N": prop.position = Vector3(along, 0, -_depth * 0.5 + _wall)
		"S":
			prop.position = Vector3(along, 0, _depth * 0.5 - _wall)
			prop.rotation.y = PI
		"W":
			prop.position = Vector3(-_width * 0.5 + _wall, 0, along)
			prop.rotation.y = PI * 0.5
		"E":
			prop.position = Vector3(_width * 0.5 - _wall, 0, along)
			prop.rotation.y = -PI * 0.5
	_root.add_child(prop)
	var inward: Vector3 = prop.basis.z
	if scene_name == "security/RecordingCamera":
		# CCTV library roots are at mount height and face -Z; most older
		# wall fixtures are floor-rooted and face +Z. Adapt explicitly.
		prop.rotation.y += PI
		prop.position += inward * 0.04
		prop.position.y = 2.65
	else:
		var native_bounds := _bounds(prop, Transform3D.IDENTITY)
		prop.position += inward * maxf(0, -native_bounds.position.z)
	var bounds := _bounds(prop, prop.transform)
	var rect := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
	# Wall items may sit above floor furniture, but never above a door opening.
	if not _can_place(rect, false):
		_skipped.append(scene_name)
		prop.free()
		return null
	prop.set_meta("wall_mount", wall)
	prop.set_meta("source_prop_scene", scene_name)
	prop.set_meta("support_type", "wall")
	prop.set_meta("furniture_bounds", bounds)
	prop.add_to_group("campus_placed_furniture")
	return prop

func _can_place(rect: Rect2, check_furniture: bool) -> bool:
	var allowed := Rect2(Vector2(-_width * 0.5 + _wall - 0.04, -_depth * 0.5 + _wall - 0.04), Vector2(_width - 2 * _wall + 0.08, _depth - 2 * _wall + 0.08))
	if not allowed.encloses(rect):
		return false
	for door in _doors:
		if String(door.get("kind", "")) in ["hatch", "window"]:
			continue
		var p: Vector3 = door.get("position", Vector3.ZERO)
		var width := float(door.get("width", 1.2)) + 0.35
		var keep_clear: Rect2
		if String(door.get("axis", "x")) == "x":
			keep_clear = Rect2(Vector2(p.x - width * 0.5, p.z - 1.6), Vector2(width, 3.2))
		else:
			keep_clear = Rect2(Vector2(p.x - 1.6, p.z - width * 0.5), Vector2(3.2, width))
		if rect.intersects(keep_clear):
			return false
	if check_furniture:
		for existing in _footprints:
			if rect.intersects(existing.grow(0.06)):
				return false
	return true

static func _bounds(node: Node3D, transform: Transform3D) -> AABB:
	var result := AABB()
	var has_bounds := false
	for child in node.get_children():
		if not child is Node3D:
			continue
		var child_transform: Transform3D = transform * child.transform
		var value: AABB
		if child is MeshInstance3D and child.mesh:
			value = child_transform * child.get_aabb()
		else:
			value = _bounds(child, child_transform)
		if value.size == Vector3.ZERO:
			continue
		result = result.merge(value) if has_bounds else value
		has_bounds = true
	return result

func _top(parent: Node3D, scene_name: String, at: Vector3) -> Node3D:
	var prop := load("res://scenes/props/%s.tscn" % scene_name).instantiate() as Node3D
	prop.position = at
	parent.add_child(prop)
	_repair_supports(prop, scene_name)
	prop.set_meta("supported_by", parent.name)
	prop.set_meta("support_type", "parent_surface")
	return prop

func _repair_supports(prop: Node3D, scene_name: String) -> void:
	if scene_name == "cafeteria/CafeteriaTableSet":
		for x in [-0.88, 0.88]:
			_support_box(prop, "TableFrameCap", Vector3(x, 0.695, 0), Vector3(0.12, 0.04, 0.84))
	elif scene_name == "laboratory/ComputerTerminal":
		_support_box(prop, "DisplayNeck", Vector3(0, 0.2, -0.1), Vector3(0.09, 0.2, 0.1))
	elif scene_name == "workshop/WorkshopBench":
		for x in [-1.0, 1.0]:
			_support_box(prop, "PegboardSupport", Vector3(x, 1.2, -0.36), Vector3(0.07, 0.65, 0.07))
	elif scene_name == "laboratory/LabWorkbench":
		# Detailed tabletop instrument scenes occupy these same supported pads.
		for part in ["InstrumentA", "InstrumentB"]:
			var placeholder := prop.get_node_or_null(part)
			if placeholder: placeholder.free()
	elif scene_name in ["common/UtilityCart", "medical/MedicalCart", "laboratory/EquipmentTrolley"]:
		# Castor fork links each wheel axle to the lowest shelf frame.
		var half_x := 0.47 if scene_name == "common/UtilityCart" else 0.4
		for x in [-half_x, half_x]:
			for z in [-0.22, 0.22]:
				_support_box(prop, "CastorFork", Vector3(x, 0.19, z), Vector3(0.06, 0.2, 0.08))

func _support_box(parent: Node3D, part: String, at: Vector3, size: Vector3, collision := false) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.name = part
	visual.mesh = mesh
	visual.material_override = STEEL
	visual.position = at
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	if collision:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.position = at
		body.add_child(shape)
		parent.add_child(body)
