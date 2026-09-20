extends Node3D
class_name CampusFurnishingFixture

## Floor-rooted reusable assemblies. A wall fixture's back is local -Z;
## its mounting plane is z=0 and its useful space extends toward +Z.
@export_enum("shower_bank", "toilet_bank", "urinal_bank", "clinical_bed_bay", "serving_line", "visitation_booths", "secure_cell_furniture", "laundry_machine", "plant_skid", "server_cabinet") var fixture_kind := "shower_bank"
@export var count := 5
@export var bay_width := 1.7
@export var display_label := ""

const STEEL := preload("res://materials/props/stainless_steel.tres")
const METAL := preload("res://materials/props/painted_metal.tres")
const DARK := preload("res://materials/props/security_dark.tres")
const WHITE := preload("res://materials/props/dirty_off_white.tres")
const TILE := preload("res://materials/props/tile_shower.tres")
const RUBBER := preload("res://materials/props/dark_rubber.tres")
var _body: StaticBody3D

func _ready() -> void:
	add_to_group("campus_furnishing_fixtures")
	set_meta("fixture_kind", fixture_kind)
	_body = StaticBody3D.new()
	_body.name = "Collision"
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	match fixture_kind:
		"shower_bank": _showers()
		"toilet_bank": _toilets()
		"urinal_bank": _urinals()
		"clinical_bed_bay": _bed_bay()
		"serving_line": _serving()
		"visitation_booths": _visitation()
		"secure_cell_furniture": _cell()
		"laundry_machine": _laundry()
		"plant_skid": _plant()
		"server_cabinet": _server()

func _box(part: String, at: Vector3, size: Vector3, material: Material, collision := true) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = part
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	if collision:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = at
		_body.add_child(shape)
	return visual

func _cylinder(part: String, at: Vector3, radius: float, height: float, material: Material, turn := Vector3.ZERO) -> void:
	var visual := MeshInstance3D.new()
	visual.name = part
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	visual.rotation = turn
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)

func _prop(scene_path: String, at: Vector3, turn := 0.0) -> Node3D:
	var prop := load("res://scenes/props/" + scene_path + ".tscn").instantiate() as Node3D
	prop.position = at
	prop.rotation.y = turn
	add_child(prop)
	return prop

func _sign(message: String, at: Vector3) -> void:
	_box("SignBack", at, Vector3(1.3, 0.28, 0.04), DARK, false)
	var label := Label3D.new()
	label.text = message
	label.font_size = 28
	label.pixel_size = 0.004
	label.position = at + Vector3(0, 0, 0.025)
	label.no_depth_test = false
	add_child(label)

func _showers() -> void:
	for i in range(count):
		var x := (i - (count - 1) * 0.5) * bay_width
		var shower := _prop("prison/ShowerFixture", Vector3(x, 0, 0))
		shower.add_to_group("campus_shower_heads")
		# Two clips visibly fasten exposed pipes to the actual rear wall.
		for y in [0.7, 2.15]:
			_box("PipeClip", Vector3(x, y, 0.035), Vector3(0.15, 0.08, 0.09), STEEL, false)
		_prop("prison/FloorDrain", Vector3(x, 0, 0.7))
	for i in range(count + 1):
		var x := (i - count * 0.5) * bay_width
		_box("ShowerDivider", Vector3(x, 1.05, 0.73), Vector3(0.1, 2.1, 1.46), TILE)
		_box("DividerCap", Vector3(x, 2.13, 0.73), Vector3(0.13, 0.06, 1.46), STEEL, false)

func _toilets() -> void:
	# Open cubicle entries are intentional: short return panels screen the bowl,
	# with 0.95m clear entrance width and no decorative leaf blocking circulation.
	for i in range(count):
		var x := (i - (count - 1) * 0.5) * bay_width
		var toilet := _prop("prison/Toilet", Vector3(x, 0, 0.32))
		toilet.add_to_group("campus_toilets")
		_box("CisternWallMount", Vector3(x, 0.88, 0.04), Vector3(0.48, 0.17, 0.08), STEEL, false)
		var return_width := maxf(0.05, bay_width - 1.0)
		_box("CubicleEntryScreen", Vector3(x - bay_width * 0.5 + return_width * 0.5, 1.05, 1.65), Vector3(return_width, 2.1, 0.08), WHITE)
	for i in range(count + 1):
		var x := (i - count * 0.5) * bay_width
		_box("ToiletPartition", Vector3(x, 1.05, 0.84), Vector3(0.08, 2.1, 1.68), WHITE)
		_box("PartitionCap", Vector3(x, 2.13, 0.84), Vector3(0.1, 0.06, 1.68), STEEL, false)

func _urinals() -> void:
	for i in range(count):
		var x := (i - (count - 1) * 0.5) * bay_width
		var urinal := _prop("prison/Urinal", Vector3(x, 0, 0))
		urinal.add_to_group("campus_urinals")
	for i in range(count + 1):
		var x := (i - count * 0.5) * bay_width
		_prop("prison/UrinalDivider", Vector3(x, 0, 0))
		# The divider's root is wall supported rather than floating on nothing.
		for y in [0.6, 1.65]:
			_box("DividerBracket", Vector3(x, y, 0.06), Vector3(0.18, 0.09, 0.16), STEEL, false)

func _bed_bay() -> void:
	_prop("medical/HospitalBed", Vector3.ZERO)
	_prop("medical/BedsideTable", Vector3(0.96, 0, -0.67))
	_prop("medical/IVStand", Vector3(-0.94, 0, -0.55))
	add_to_group("campus_clinical_bed_bays")

func _serving() -> void:
	# A 6m architectural hatch uses three 2m modules. Counter is floor-supported;
	# transparent service space remains physically open above the counter.
	for i in range(count):
		var x := (i - (count - 1) * 0.5) * bay_width
		_box("ServingTop", Vector3(x, 0.98, 0.42), Vector3(bay_width - 0.08, 0.12, 0.84), STEEL)
		for side in [-1.0, 1.0]:
			var px: float = x + side * (bay_width * 0.5 - 0.18)
			_box("CounterLeg", Vector3(px, 0.46, 0.4), Vector3(0.12, 0.92, 0.66), METAL)
			_box("WindowUpright", Vector3(px, 1.67, 0.06), Vector3(0.07, 1.28, 0.07), METAL, false)
		_box("TrayShelf", Vector3(x, 0.85, 0.94), Vector3(bay_width - 0.1, 0.07, 0.3), STEEL)
		for side in [-1.0, 1.0]:
			_box("ShelfBracket", Vector3(x + side * 0.55, 0.8, 0.77), Vector3(0.07, 0.1, 0.65), METAL, false)
		for side in [-1.0, 1.0]:
			_box("FoodPan", Vector3(x + side * 0.38, 1.09, 0.32), Vector3(0.6, 0.1, 0.4), WHITE, false)
		_sign("DIETARY / MEDICAL" if i == 2 else "SERVING %d" % (i + 1), Vector3(x, 2.34, 0.06))
	add_to_group("campus_serving_lines")

func _visitation() -> void:
	var width := count * bay_width
	# Full collision partition with visible glazing and a fixed counter. Both
	# side aisles remain distinct; no hidden traverse opening between booths.
	_box("BoothCounter", Vector3(0, 0.78, 0), Vector3(width, 0.14, 1.25), METAL)
	_box("LowerSeparation", Vector3(0, 0.36, 0), Vector3(width, 0.72, 0.12), DARK)
	var glazing := StandardMaterial3D.new()
	glazing.albedo_color = Color(0.47, 0.59, 0.56, 0.28)
	glazing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glazing.metallic = 0.2
	glazing.roughness = 0.18
	_box("SecurityGlazing", Vector3(0, 1.77, 0), Vector3(width, 1.85, 0.07), glazing)
	for i in range(count + 1):
		var x := (i - count * 0.5) * bay_width
		_box("BoothPost", Vector3(x, 1.4, 0), Vector3(0.08, 2.8, 0.12), DARK)
		_box("PrivacyFin", Vector3(x, 1.25, 0), Vector3(0.07, 0.8, 1.3), METAL, false)
	for i in range(count):
		var x := (i - (count - 1) * 0.5) * bay_width
		# Central accessible booth stays clear of both entrance door sweeps.
		if i != int(count / 2.0):
			_prop("common/Chair", Vector3(x, 0, -1.15))
			_prop("common/Chair", Vector3(x, 0, 1.15), PI)
		for side in [-1.0, 1.0]:
			_box("PhoneCradle", Vector3(x + 0.4, 0.89, side * 0.4), Vector3(0.28, 0.08, 0.3), DARK, false)
			_box("Handset", Vector3(x + 0.4, 0.98, side * 0.4), Vector3(0.12, 0.1, 0.28), RUBBER, false)

func _cell() -> void:
	# 6.5x3.25m bay, origin at room centre, entrance on +X. Rotate PI for
	# opposite banks. A full 2m of the front end is free for the sliding door.
	_box("BedBackPlate", Vector3(-1.92, 0.48, -1.44), Vector3(2.12, 0.38, 0.07), METAL, false)
	_box("BedFrame", Vector3(-1.92, 0.46, -0.95), Vector3(2.1, 0.12, 0.98), DARK)
	_box("Mattress", Vector3(-1.92, 0.6, -0.95), Vector3(1.98, 0.16, 0.9), WHITE, false)
	_box("Pillow", Vector3(-2.58, 0.73, -0.95), Vector3(0.48, 0.12, 0.68), WHITE, false)
	for x in [-2.62, -1.22]:
		_box("WallBedBracket", Vector3(x, 0.35, -1.01), Vector3(0.1, 0.12, 0.92), METAL, false)
		_box("BracketReturn", Vector3(x, 0.3, -1.4), Vector3(0.14, 0.42, 0.12), METAL, false)
	_prop("prison/Toilet", Vector3(-2.58, 0, 1.1), PI)
	_prop("prison/WashBasin", Vector3(-1.44, 0, 1.46), PI)
	_box("SanitaryPrivacyWall", Vector3(-2.12, 0.7, 0.14), Vector3(1.85, 1.4, 0.1), TILE)
	_prop("common/Locker", Vector3(0, 0, -1.08))
	_prop("common/Chair", Vector3(0, 0, 0.86), PI)

func _laundry() -> void:
	_box("MachineBody", Vector3(0, 0.7, 0), Vector3(1.35, 1.32, 1.12), WHITE)
	for x in [-0.5, 0.5]:
		for z in [-0.4, 0.4]:
			_box("LevelingFoot", Vector3(x, 0.035, z), Vector3(0.16, 0.07, 0.16), RUBBER, false)
	_cylinder("DoorRim", Vector3(0, 0.68, 0.59), 0.43, 0.08, STEEL, Vector3(PI * 0.5, 0, 0))
	_cylinder("DrumWindow", Vector3(0, 0.68, 0.64), 0.34, 0.035, DARK, Vector3(PI * 0.5, 0, 0))
	_box("DoorLatch", Vector3(0.46, 0.7, 0.66), Vector3(0.08, 0.25, 0.12), DARK, false)
	_box("ControlStrip", Vector3(0, 1.23, 0.58), Vector3(1.17, 0.19, 0.06), METAL, false)
	_cylinder("ProgramDial", Vector3(0.36, 1.23, 0.63), 0.06, 0.06, DARK, Vector3(PI * 0.5, 0, 0))
	_sign(display_label if not display_label.is_empty() else "INDUSTRIAL WASH", Vector3(0, 1.6, -0.46))
	_box("SignSupport", Vector3(0, 1.44, -0.48), Vector3(0.06, 0.35, 0.06), METAL, false)

func _plant() -> void:
	_box("EquipmentSkid", Vector3(0, 0.14, 0), Vector3(2.2, 0.28, 1.5), METAL)
	_box("TankCollision", Vector3(-0.4, 1.22, 0), Vector3(0.85, 1.9, 0.85), METAL)
	_cylinder("PressureVessel", Vector3(-0.4, 1.22, 0), 0.6, 1.95, STEEL)
	_box("PumpMotor", Vector3(0.72, 0.55, 0.12), Vector3(0.6, 0.58, 0.72), DARK)
	_box("Manifold", Vector3(0.35, 0.88, 0.12), Vector3(0.9, 0.12, 0.12), STEEL, false)
	_box("Riser", Vector3(0.13, 1.1, 0.12), Vector3(0.12, 0.56, 0.12), STEEL, false)
	_cylinder("PressureGauge", Vector3(-0.38, 1.72, 0.62), 0.15, 0.08, WHITE, Vector3(PI * 0.5, 0, 0))
	_sign(display_label if not display_label.is_empty() else "PLANT / ISOLATE", Vector3(-0.35, 1.1, 0.64))

func _server() -> void:
	_box("RackPlinth", Vector3(0, 0.08, 0), Vector3(0.78, 0.16, 0.85), DARK)
	_box("RackBody", Vector3(0, 1.18, 0), Vector3(0.74, 2.05, 0.82), DARK)
	for y in range(9):
		_box("RackUnit", Vector3(0, 0.38 + y * 0.2, 0.43), Vector3(0.65, 0.16, 0.035), METAL, false)
		_box("Vent", Vector3(-0.04, 0.38 + y * 0.2, 0.455), Vector3(0.44, 0.07, 0.02), DARK, false)
		_box("Status", Vector3(0.27, 0.38 + y * 0.2, 0.46), Vector3(0.035, 0.035, 0.02), WHITE, false)
	for x in [-0.37, 0.37]:
		_box("FrameRail", Vector3(x, 1.17, 0.44), Vector3(0.045, 2.0, 0.05), STEEL, false)
