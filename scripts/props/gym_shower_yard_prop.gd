extends Node3D
class_name GymShowerYardProp

## Primitive gym, washroom, and yard equipment. Floor props use y=0 as floor
## contact; wall fixtures project toward local +Z.

enum PropKind {
	FLAT_BENCH_PRESS,
	SQUAT_RACK,
	BARBELL,
	WEIGHT_PLATE_STACK,
	DUMBBELL_RACK,
	PULL_UP_BAR,
	EXERCISE_MAT,
	EXERCISE_BIKE,
	CABLE_MACHINE,
	PUNCHING_BAG,
	SHOWER_FLOOR,
	SHOWER_FIXTURE,
	SHOWER_HALF_WALL,
	FLOOR_DRAIN,
	TOWEL_HOOKS,
	WASH_BASIN,
	MIRROR,
	TOILET,
	PARALLEL_BARS,
	BASKETBALL_HOOP,
	SHRUB,
	SMALL_TREE,
	CCTV_CAMERA,
	SEARCHLIGHT,
	OBSERVATION_POST,
	URINAL,
	URINAL_DIVIDER,
	FLOWER_CLUSTER,
	OFFICER_GAZEBO,
	YARD_SECURITY_POST,
}

const PAINTED_METAL := preload("res://materials/props/painted_metal.tres")
const STAINLESS_STEEL := preload("res://materials/props/stainless_steel.tres")
const CONCRETE := preload("res://materials/props/concrete.tres")
const INSTITUTIONAL_PLASTIC := preload("res://materials/props/institutional_plastic.tres")
const DARK_RUBBER := preload("res://materials/props/dark_rubber.tres")
const DIRTY_OFF_WHITE := preload("res://materials/props/dirty_off_white.tres")
const SECURITY_DARK := preload("res://materials/props/security_dark.tres")
const SHOWER_TILE := preload("res://materials/props/shower_tile.tres")
const YARD_GREEN := preload("res://materials/props/yard_green.tres")

@export var prop_kind: PropKind = PropKind.FLAT_BENCH_PRESS
@export_flags_3d_render var visual_layer_mask := 1

var _collision_root: StaticBody3D


func _ready() -> void:
	add_to_group("environmental_props")
	add_to_group("gym_shower_yard_props")
	set_meta("prop_kind", PropKind.keys()[prop_kind].to_lower())
	_collision_root = StaticBody3D.new()
	_collision_root.name = "Collision"
	_collision_root.collision_layer = 1
	_collision_root.collision_mask = 0
	add_child(_collision_root)
	_build_prop()


func _build_prop() -> void:
	match prop_kind:
		PropKind.FLAT_BENCH_PRESS: _build_flat_bench_press()
		PropKind.SQUAT_RACK: _build_squat_rack()
		PropKind.BARBELL: _build_barbell()
		PropKind.WEIGHT_PLATE_STACK: _build_weight_plates()
		PropKind.DUMBBELL_RACK: _build_dumbbell_rack()
		PropKind.PULL_UP_BAR: _build_pull_up_bar()
		PropKind.EXERCISE_MAT: _build_exercise_mat()
		PropKind.EXERCISE_BIKE: _build_exercise_bike()
		PropKind.CABLE_MACHINE: _build_cable_machine()
		PropKind.PUNCHING_BAG: _build_punching_bag()
		PropKind.SHOWER_FLOOR: _build_shower_floor()
		PropKind.SHOWER_FIXTURE: _build_shower_fixture()
		PropKind.SHOWER_HALF_WALL: _build_shower_half_wall()
		PropKind.FLOOR_DRAIN: _build_floor_drain()
		PropKind.TOWEL_HOOKS: _build_towel_hooks()
		PropKind.WASH_BASIN: _build_wash_basin()
		PropKind.MIRROR: _build_mirror()
		PropKind.TOILET: _build_toilet()
		PropKind.PARALLEL_BARS: _build_parallel_bars()
		PropKind.BASKETBALL_HOOP: _build_basketball_hoop()
		PropKind.SHRUB: _build_shrub()
		PropKind.SMALL_TREE: _build_small_tree()
		PropKind.CCTV_CAMERA: _build_cctv()
		PropKind.SEARCHLIGHT: _build_searchlight()
		PropKind.OBSERVATION_POST: _build_observation_post()
		PropKind.URINAL: _build_urinal()
		PropKind.URINAL_DIVIDER: _build_urinal_divider()
		PropKind.FLOWER_CLUSTER: _build_flower_cluster()
		PropKind.OFFICER_GAZEBO: _build_officer_gazebo()
		PropKind.YARD_SECURITY_POST: _build_yard_security_post()


func _box(part_name: String, center: Vector3, size: Vector3, material: Material, collision := true, rotation := Vector3.ZERO) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	visual.position = center
	visual.rotation = rotation
	visual.layers = visual_layer_mask
	add_child(visual)
	if collision:
		var shape_node := CollisionShape3D.new()
		shape_node.name = "%sShape" % part_name
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		shape_node.position = center
		shape_node.rotation = rotation
		_collision_root.add_child(shape_node)
	return visual


func _cylinder(part_name: String, center: Vector3, radius: float, height: float, material: Material, collision := true, rotation := Vector3.ZERO) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	visual.mesh = mesh
	visual.material_override = material
	visual.position = center
	visual.rotation = rotation
	visual.layers = visual_layer_mask
	add_child(visual)
	if collision:
		var shape_node := CollisionShape3D.new()
		shape_node.name = "%sShape" % part_name
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		shape_node.shape = shape
		shape_node.position = center
		shape_node.rotation = rotation
		_collision_root.add_child(shape_node)
	return visual


func _build_flat_bench_press() -> void:
	_box("BenchPad", Vector3(0, 0.5, 0.18), Vector3(0.58, 0.14, 1.65), DARK_RUBBER)
	_box("CenterRail", Vector3(0, 0.31, 0.18), Vector3(0.12, 0.14, 1.5), PAINTED_METAL, false)
	for z in [-0.55, 0.75]:
		_box("Base%s" % z, Vector3(0, 0.1, z), Vector3(0.92, 0.12, 0.14), PAINTED_METAL)
		_box("BenchPost%s" % z, Vector3(0, 0.28, z), Vector3(0.11, 0.45, 0.11), PAINTED_METAL, false)
	for x in [-0.58, 0.58]:
		_box("RackPost%s" % x, Vector3(x, 0.9, -0.7), Vector3(0.11, 1.8, 0.11), PAINTED_METAL)
	_box("Barbell", Vector3(0, 1.58, -0.7), Vector3(1.55, 0.07, 0.07), STAINLESS_STEEL, false)
	for x in [-0.68, 0.68]:
		_cylinder("Plate%s" % x, Vector3(x, 1.58, -0.7), 0.2, 0.1, SECURITY_DARK, false, Vector3(0, 0, deg_to_rad(90)))


func _build_squat_rack() -> void:
	for x in [-0.72, 0.72]:
		_box("RackUpright%s" % x, Vector3(x, 1.2, -0.35), Vector3(0.12, 2.4, 0.12), PAINTED_METAL)
		_box("RackFoot%s" % x, Vector3(x, 0.08, 0), Vector3(0.18, 0.12, 1.2), PAINTED_METAL)
		_box("SafetyArm%s" % x, Vector3(x, 1.05, 0.05), Vector3(0.1, 0.1, 0.75), STAINLESS_STEEL, false)
	_box("TopBrace", Vector3(0, 2.35, -0.35), Vector3(1.55, 0.12, 0.12), PAINTED_METAL, false)
	_box("RackBarbell", Vector3(0, 1.75, -0.25), Vector3(1.9, 0.07, 0.07), STAINLESS_STEEL, false)


func _build_barbell() -> void:
	_box("Bar", Vector3(0, 0.12, 0), Vector3(1.9, 0.065, 0.065), STAINLESS_STEEL)
	for x in [-0.72, 0.72]:
		_cylinder("Weight%s" % x, Vector3(x, 0.12, 0), 0.21, 0.1, SECURITY_DARK, false, Vector3(0, 0, deg_to_rad(90)))


func _build_weight_plates() -> void:
	_box("PlateStand", Vector3(0, 0.42, 0), Vector3(0.1, 0.84, 0.1), PAINTED_METAL)
	_box("StandBase", Vector3(0, 0.07, 0), Vector3(0.75, 0.12, 0.55), PAINTED_METAL)
	for index in range(5):
		_cylinder("Plate%02d" % index, Vector3(-0.24 + index * 0.12, 0.3, 0), 0.27 - index * 0.018, 0.08, SECURITY_DARK, false, Vector3(0, 0, deg_to_rad(90)))


func _build_dumbbell_rack() -> void:
	for y in [0.42, 0.82]:
		_box("RackShelf%s" % y, Vector3(0, y, 0), Vector3(2.0, 0.1, 0.52), PAINTED_METAL)
	for x in [-0.85, 0.85]:
		_box("RackLeg%s" % x, Vector3(x, 0.42, 0), Vector3(0.11, 0.84, 0.42), PAINTED_METAL)
	for row in range(2):
		for index in range(5):
			var x := -0.72 + index * 0.36
			var y := 0.56 + row * 0.4
			_box("Handle_%s_%s" % [row, index], Vector3(x, y, 0.02), Vector3(0.22, 0.055, 0.055), STAINLESS_STEEL, false)
			for side in [-0.12, 0.12]:
				_cylinder("Bell_%s_%s_%s" % [row, index, side], Vector3(x + side, y, 0.02), 0.09, 0.07, SECURITY_DARK, false, Vector3(0, 0, deg_to_rad(90)))


func _build_pull_up_bar() -> void:
	for x in [-1.0, 1.0]:
		_box("Upright%s" % x, Vector3(x, 1.25, 0), Vector3(0.12, 2.5, 0.12), PAINTED_METAL)
		_box("Foot%s" % x, Vector3(x, 0.07, 0), Vector3(0.48, 0.12, 0.72), PAINTED_METAL)
	_box("PullUpRail", Vector3(0, 2.35, 0), Vector3(2.12, 0.08, 0.08), STAINLESS_STEEL)


func _build_exercise_mat() -> void:
	_box("Mat", Vector3(0, 0.025, 0), Vector3(1.05, 0.05, 2.15), DARK_RUBBER, false)
	_box("MatEdgeNorth", Vector3(0, 0.052, -1.04), Vector3(1.05, 0.025, 0.06), INSTITUTIONAL_PLASTIC, false)
	_box("MatEdgeSouth", Vector3(0, 0.052, 1.04), Vector3(1.05, 0.025, 0.06), INSTITUTIONAL_PLASTIC, false)


func _build_exercise_bike() -> void:
	_box("BikeBase", Vector3(0, 0.08, 0), Vector3(0.72, 0.12, 1.25), PAINTED_METAL)
	_box("FrameBeam", Vector3(0, 0.62, 0.05), Vector3(0.12, 1.2, 0.12), PAINTED_METAL, false, Vector3(deg_to_rad(18), 0, 0))
	_cylinder("Flywheel", Vector3(0, 0.48, 0.28), 0.34, 0.16, SECURITY_DARK, false, Vector3(0, 0, deg_to_rad(90)))
	_box("SeatPost", Vector3(0, 0.98, 0.35), Vector3(0.09, 0.72, 0.09), PAINTED_METAL, false)
	_box("Seat", Vector3(0, 1.3, 0.35), Vector3(0.38, 0.1, 0.3), DARK_RUBBER)
	_box("HandlePost", Vector3(0, 1.08, -0.38), Vector3(0.08, 0.9, 0.08), PAINTED_METAL, false, Vector3(deg_to_rad(-14), 0, 0))
	_box("Handlebar", Vector3(0, 1.46, -0.47), Vector3(0.68, 0.07, 0.07), DARK_RUBBER, false)


func _build_cable_machine() -> void:
	for x in [-0.72, 0.72]:
		_box("Tower%s" % x, Vector3(x, 1.15, 0), Vector3(0.28, 2.3, 0.68), PAINTED_METAL)
		for index in range(6):
			_box("Weight_%s_%s" % [x, index], Vector3(x, 0.3 + index * 0.16, 0.36), Vector3(0.22, 0.1, 0.08), SECURITY_DARK, false)
	_box("TopCrossbar", Vector3(0, 2.25, 0), Vector3(1.65, 0.14, 0.18), PAINTED_METAL)
	_box("Cable", Vector3(0, 1.55, 0.14), Vector3(0.025, 1.25, 0.025), SECURITY_DARK, false)
	_box("Handle", Vector3(0, 0.95, 0.14), Vector3(0.48, 0.06, 0.06), DARK_RUBBER, false)


func _build_punching_bag() -> void:
	for x in [-0.75, 0.75]:
		_box("FramePost%s" % x, Vector3(x, 1.25, 0), Vector3(0.12, 2.5, 0.12), PAINTED_METAL)
		_box("FrameFoot%s" % x, Vector3(x, 0.07, 0), Vector3(0.45, 0.12, 0.8), PAINTED_METAL)
	_box("FrameTop", Vector3(0, 2.4, 0), Vector3(1.62, 0.12, 0.12), PAINTED_METAL)
	_box("Chain", Vector3(0, 2.13, 0), Vector3(0.045, 0.48, 0.045), STAINLESS_STEEL, false)
	_cylinder("HeavyBag", Vector3(0, 1.25, 0), 0.3, 1.55, DARK_RUBBER)
	_box("BagBand", Vector3(0, 1.7, 0), Vector3(0.62, 0.1, 0.62), PAINTED_METAL, false)


func _build_shower_floor() -> void:
	_box("TileField", Vector3(0, 0.018, 0), Vector3(20.5, 0.036, 8.2), SHOWER_TILE, false)
	for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		_box("TileJointX%s" % x, Vector3(x, 0.039, 0), Vector3(0.025, 0.01, 8.1), SECURITY_DARK, false)
	for z in [-2.7, 0.0, 2.7]:
		_box("TileJointZ%s" % z, Vector3(0, 0.04, z), Vector3(12.4, 0.01, 0.025), SECURITY_DARK, false)


func _build_shower_fixture() -> void:
	_box("Pipe", Vector3(0, 1.55, 0.08), Vector3(0.07, 2.45, 0.07), STAINLESS_STEEL, false)
	_box("ShowerArm", Vector3(0, 2.55, 0.27), Vector3(0.07, 0.07, 0.45), STAINLESS_STEEL, false)
	_cylinder("ShowerHead", Vector3(0, 2.48, 0.5), 0.14, 0.1, PAINTED_METAL, false, Vector3(deg_to_rad(72), 0, 0))
	_cylinder("Control", Vector3(0, 1.25, 0.15), 0.12, 0.08, PAINTED_METAL, false, Vector3(deg_to_rad(90), 0, 0))
	_box("ControlHandle", Vector3(0, 1.25, 0.22), Vector3(0.28, 0.045, 0.045), SECURITY_DARK, false)


func _build_shower_half_wall() -> void:
	_box("HalfWall", Vector3(0, 1.05, 0), Vector3(0.15, 2.1, 3.0), SHOWER_TILE)
	_box("WallCap", Vector3(0, 2.14, 0), Vector3(0.22, 0.08, 3.05), STAINLESS_STEEL, false)


func _build_floor_drain() -> void:
	_cylinder("Drain", Vector3(0, 0.025, 0), 0.16, 0.05, SECURITY_DARK, false)
	for x in [-0.09, -0.03, 0.03, 0.09]:
		_box("DrainSlot%s" % x, Vector3(x, 0.054, 0), Vector3(0.018, 0.012, 0.22), STAINLESS_STEEL, false)


func _build_towel_hooks() -> void:
	_box("MountingRail", Vector3(0, 1.65, 0.06), Vector3(1.25, 0.12, 0.1), PAINTED_METAL, false)
	for x in [-0.45, -0.15, 0.15, 0.45]:
		_box("HookStem%s" % x, Vector3(x, 1.58, 0.14), Vector3(0.055, 0.18, 0.055), STAINLESS_STEEL, false)
		_box("HookLip%s" % x, Vector3(x, 1.5, 0.2), Vector3(0.055, 0.055, 0.16), STAINLESS_STEEL, false)


func _build_wash_basin() -> void:
	_box("BasinSupport", Vector3(0, 0.57, 0.12), Vector3(0.44, 1.14, 0.28), PAINTED_METAL)
	_box("Basin", Vector3(0, 0.94, 0.28), Vector3(0.78, 0.18, 0.58), DIRTY_OFF_WHITE)
	_box("BowlInset", Vector3(0, 1.05, 0.28), Vector3(0.52, 0.035, 0.36), SECURITY_DARK, false)
	_cylinder("Tap", Vector3(0, 1.17, 0.08), 0.04, 0.28, STAINLESS_STEEL, false)


func _build_mirror() -> void:
	_box("MirrorBacking", Vector3(0, 1.68, 0.04), Vector3(0.82, 1.05, 0.08), SECURITY_DARK, false)
	_box("MirrorFace", Vector3(0, 1.68, 0.09), Vector3(0.68, 0.9, 0.025), STAINLESS_STEEL, false)


func _build_toilet() -> void:
	_box("ToiletBase", Vector3(0, 0.3, 0.05), Vector3(0.52, 0.6, 0.58), DIRTY_OFF_WHITE)
	_cylinder("Bowl", Vector3(0, 0.52, 0.26), 0.31, 0.18, DIRTY_OFF_WHITE)
	_cylinder("BowlInset", Vector3(0, 0.62, 0.26), 0.21, 0.025, SECURITY_DARK, false)
	_box("Tank", Vector3(0, 0.83, -0.16), Vector3(0.58, 0.62, 0.28), DIRTY_OFF_WHITE)
	_box("Flush", Vector3(0.2, 1.04, 0), Vector3(0.08, 0.08, 0.08), STAINLESS_STEEL, false)


func _build_parallel_bars() -> void:
	for x in [-0.52, 0.52]:
		for z in [-1.0, 1.0]:
			_cylinder("Post_%s_%s" % [x, z], Vector3(x, 0.62, z), 0.06, 1.24, PAINTED_METAL)
		_box("Bar%s" % x, Vector3(x, 1.18, 0), Vector3(0.1, 0.1, 2.1), STAINLESS_STEEL)


func _build_basketball_hoop() -> void:
	_box("Pole", Vector3(0, 1.75, 0), Vector3(0.18, 3.5, 0.18), PAINTED_METAL)
	_box("PoleBase", Vector3(0, 0.12, 0), Vector3(0.8, 0.24, 0.8), CONCRETE)
	_box("SupportArm", Vector3(0, 3.25, 0.65), Vector3(0.14, 0.14, 1.35), PAINTED_METAL, false)
	_box("Backboard", Vector3(0, 3.25, 1.3), Vector3(1.8, 1.05, 0.1), DIRTY_OFF_WHITE, false)
	# Four thin rails form a readable open rim without a high-segment torus.
	_box("RimFront", Vector3(0, 2.95, 1.88), Vector3(0.52, 0.055, 0.055), PAINTED_METAL, false)
	_box("RimBack", Vector3(0, 2.95, 1.42), Vector3(0.52, 0.055, 0.055), PAINTED_METAL, false)
	_box("RimLeft", Vector3(-0.23, 2.95, 1.65), Vector3(0.055, 0.055, 0.52), PAINTED_METAL, false)
	_box("RimRight", Vector3(0.23, 2.95, 1.65), Vector3(0.055, 0.055, 0.52), PAINTED_METAL, false)
	for x in [-0.18, 0.0, 0.18]:
		_box("Net%s" % x, Vector3(x, 2.65, 1.65), Vector3(0.025, 0.52, 0.025), DIRTY_OFF_WHITE, false)


func _build_shrub() -> void:
	_box("Planter", Vector3(0, 0.2, 0), Vector3(0.85, 0.4, 0.85), CONCRETE)
	_cylinder("ShrubCore", Vector3(0, 0.72, 0), 0.48, 0.9, YARD_GREEN, false)
	for offset in [Vector3(-0.28, 0.78, 0), Vector3(0.25, 0.7, 0.18), Vector3(0.05, 0.9, -0.24)]:
		_cylinder("ShrubPart%s" % offset.x, offset, 0.3, 0.58, YARD_GREEN, false)


func _build_small_tree() -> void:
	_cylinder("Trunk", Vector3(0, 1.25, 0), 0.16, 2.5, PAINTED_METAL)
	_cylinder("CanopyCenter", Vector3(0, 2.85, 0), 0.72, 1.2, YARD_GREEN, false)
	for offset in [Vector3(-0.55, 2.75, 0), Vector3(0.52, 2.78, 0.18), Vector3(0, 3.05, -0.48)]:
		_cylinder("Canopy%s" % offset.x, offset, 0.48, 0.86, YARD_GREEN, false)


func _build_cctv() -> void:
	_box("WallBracket", Vector3(0, 2.7, 0.08), Vector3(0.18, 0.35, 0.16), PAINTED_METAL, false)
	_box("CameraArm", Vector3(0, 2.63, 0.3), Vector3(0.08, 0.08, 0.5), PAINTED_METAL, false)
	_box("CameraBody", Vector3(0, 2.55, 0.62), Vector3(0.32, 0.24, 0.55), DIRTY_OFF_WHITE, false, Vector3(deg_to_rad(-12), 0, 0))
	_cylinder("Lens", Vector3(0, 2.48, 0.91), 0.09, 0.06, SECURITY_DARK, false, Vector3(deg_to_rad(90), 0, 0))


func _build_searchlight() -> void:
	_box("SearchlightPost", Vector3(0, 1.5, 0), Vector3(0.16, 3.0, 0.16), PAINTED_METAL)
	_box("Pivot", Vector3(0, 2.93, 0), Vector3(0.55, 0.16, 0.16), PAINTED_METAL, false)
	_cylinder("LampHousing", Vector3(0, 3.15, 0.2), 0.35, 0.55, SECURITY_DARK, false, Vector3(deg_to_rad(75), 0, 0))
	_cylinder("LampFace", Vector3(0, 3.05, 0.48), 0.29, 0.035, DIRTY_OFF_WHITE, false, Vector3(deg_to_rad(75), 0, 0))


func _build_observation_post() -> void:
	for x in [-0.75, 0.75]:
		for z in [-0.75, 0.75]:
			_box("TowerLeg_%s_%s" % [x, z], Vector3(x, 1.4, z), Vector3(0.14, 2.8, 0.14), PAINTED_METAL)
	_box("Platform", Vector3(0, 2.7, 0), Vector3(1.8, 0.18, 1.8), PAINTED_METAL)
	_box("Shelter", Vector3(0, 3.35, 0), Vector3(1.65, 1.2, 1.65), SECURITY_DARK, false)
	_box("Roof", Vector3(0, 4.05, 0), Vector3(2.0, 0.14, 2.0), PAINTED_METAL, false)


func _build_urinal() -> void:
	_box("WallPlate", Vector3(0, 0.92, 0.05), Vector3(0.52, 1.25, 0.1), PAINTED_METAL)
	_box("BasinBody", Vector3(0, 0.72, 0.22), Vector3(0.5, 0.72, 0.38), DIRTY_OFF_WHITE)
	_cylinder("Bowl", Vector3(0, 0.58, 0.38), 0.22, 0.12, DIRTY_OFF_WHITE, false)
	_box("FlushPipe", Vector3(0, 1.42, 0.11), Vector3(0.055, 0.42, 0.055), STAINLESS_STEEL, false)
	_box("FlushValve", Vector3(0, 1.61, 0.13), Vector3(0.16, 0.13, 0.11), STAINLESS_STEEL, false)


func _build_urinal_divider() -> void:
	_box("DividerPanel", Vector3(0, 1.15, 0.42), Vector3(0.08, 1.65, 0.84), SHOWER_TILE)
	_box("DividerCap", Vector3(0, 2.0, 0.42), Vector3(0.12, 0.08, 0.88), STAINLESS_STEEL, false)


func _build_flower_cluster() -> void:
	var flower_material := StandardMaterial3D.new()
	flower_material.albedo_color = Color("b85d72")
	flower_material.roughness = 0.82
	_box("FlowerBed", Vector3(0, 0.12, 0), Vector3(1.4, 0.24, 0.72), CONCRETE)
	for index in range(6):
		var x := -0.52 + (index % 3) * 0.52
		var z := -0.2 + (index / 3) * 0.4
		_cylinder("Stem%02d" % index, Vector3(x, 0.42, z), 0.025, 0.55, YARD_GREEN, false)
		_cylinder("Flower%02d" % index, Vector3(x, 0.72, z), 0.12, 0.08, flower_material, false)


func _build_officer_gazebo() -> void:
	_box("GazeboSlab", Vector3(0, 0.1, 0), Vector3(5.2, 0.2, 4.2), CONCRETE)
	for x in [-2.35, 2.35]:
		for z in [-1.85, 1.85]:
			_box("GazeboPost_%s_%s" % [x, z], Vector3(x, 1.55, z), Vector3(0.16, 3.0, 0.16), PAINTED_METAL)
	_box("GazeboRoof", Vector3(0, 3.15, 0), Vector3(5.6, 0.22, 4.6), SECURITY_DARK)
	for z in [-1.25, 1.25]:
		_box("GazeboBench%s" % z, Vector3(0, 0.55, z), Vector3(3.5, 0.16, 0.5), PAINTED_METAL)
		for x in [-1.45, 1.45]:
			_box("GazeboBenchLeg_%s_%s" % [x, z], Vector3(x, 0.28, z), Vector3(0.12, 0.55, 0.34), PAINTED_METAL)


func _build_yard_security_post() -> void:
	_box("PostFoundation", Vector3(0, 0.1, 0), Vector3(3.4, 0.2, 3.0), CONCRETE)
	_box("PostRearWall", Vector3(0, 1.5, -1.35), Vector3(3.2, 2.8, 0.16), SECURITY_DARK)
	for x in [-1.5, 1.5]:
		_box("PostSide%s" % x, Vector3(x, 1.5, 0), Vector3(0.16, 2.8, 2.8), SECURITY_DARK)
	_box("PostFrontLower", Vector3(0, 0.58, 1.35), Vector3(3.2, 1.0, 0.16), PAINTED_METAL)
	_box("PostWindow", Vector3(0, 1.75, 1.35), Vector3(2.65, 0.95, 0.08), STAINLESS_STEEL, false)
	_box("PostRoof", Vector3(0, 3.0, 0), Vector3(3.7, 0.2, 3.3), SECURITY_DARK)
	_box("PostDesk", Vector3(0, 0.9, 0.75), Vector3(2.3, 0.14, 0.55), PAINTED_METAL)
