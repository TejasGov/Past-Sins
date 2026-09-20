extends Node3D
class_name EnvironmentalProp

## Lightweight primitive prop shared by the independently placeable prop scenes.
## Floor-standing scenes use their root as floor contact. Wall props use the root
## at floor/wall intersection and project toward local +Z.

enum PropKind {
	TRASH_BIN,
	WALL_TRASH_BIN,
	BENCH,
	TABLE,
	CHAIR,
	METAL_SHELVING,
	STORAGE_RACK,
	STORAGE_CRATE,
	UTILITY_CART,
	LOCKER,
	FILING_CABINET,
	WALL_CLOCK,
	NOTICE_BOARD,
	FIRE_EXTINGUISHER_CABINET,
	CAFETERIA_TABLE_SET,
	WEIGHT_BENCH,
	EXAM_TABLE,
	PREP_COUNTER,
	SECURITY_CONSOLE,
	PRISON_BUNK,
	LAB_WORKBENCH,
	WORKSHOP_BENCH,
	YARD_BENCH,
}

const PAINTED_METAL := preload("res://materials/props/painted_metal.tres")
const STAINLESS_STEEL := preload("res://materials/props/stainless_steel.tres")
const CONCRETE := preload("res://materials/props/concrete.tres")
const INSTITUTIONAL_PLASTIC := preload("res://materials/props/institutional_plastic.tres")
const DARK_RUBBER := preload("res://materials/props/dark_rubber.tres")
const DIRTY_OFF_WHITE := preload("res://materials/props/dirty_off_white.tres")
const SECURITY_DARK := preload("res://materials/props/security_dark.tres")
const WOOD_FURNITURE := preload("res://materials/props/wood_furniture.tres")

@export var prop_kind: PropKind = PropKind.TRASH_BIN
@export_flags_3d_render var visual_layer_mask := 1

var _collision_root: StaticBody3D


func _ready() -> void:
	add_to_group("environmental_props")
	set_meta("prop_kind", PropKind.keys()[prop_kind].to_lower())
	_collision_root = StaticBody3D.new()
	_collision_root.name = "Collision"
	_collision_root.collision_layer = 1
	_collision_root.collision_mask = 0
	add_child(_collision_root)
	_build_prop()


func _build_prop() -> void:
	match prop_kind:
		PropKind.TRASH_BIN: _build_trash_bin()
		PropKind.WALL_TRASH_BIN: _build_wall_trash_bin()
		PropKind.BENCH: _build_bench(false)
		PropKind.TABLE: _build_table()
		PropKind.CHAIR: _build_chair()
		PropKind.METAL_SHELVING: _build_shelving(false)
		PropKind.STORAGE_RACK: _build_shelving(true)
		PropKind.STORAGE_CRATE: _build_crate()
		PropKind.UTILITY_CART: _build_utility_cart()
		PropKind.LOCKER: _build_locker()
		PropKind.FILING_CABINET: _build_filing_cabinet()
		PropKind.WALL_CLOCK: _build_wall_clock()
		PropKind.NOTICE_BOARD: _build_notice_board()
		PropKind.FIRE_EXTINGUISHER_CABINET: _build_extinguisher_cabinet()
		PropKind.CAFETERIA_TABLE_SET: _build_cafeteria_table()
		PropKind.WEIGHT_BENCH: _build_weight_bench()
		PropKind.EXAM_TABLE: _build_exam_table()
		PropKind.PREP_COUNTER: _build_prep_counter()
		PropKind.SECURITY_CONSOLE: _build_security_console()
		PropKind.PRISON_BUNK: _build_prison_bunk()
		PropKind.LAB_WORKBENCH: _build_lab_workbench()
		PropKind.WORKSHOP_BENCH: _build_workshop_bench()
		PropKind.YARD_BENCH: _build_bench(true)


func _box(part_name: String, center: Vector3, size: Vector3, material: Material, collision := true, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = center
	mesh_instance.rotation = rotation
	mesh_instance.layers = visual_layer_mask
	add_child(mesh_instance)
	if collision:
		var shape_node := CollisionShape3D.new()
		shape_node.name = "%sShape" % part_name
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		shape_node.position = center
		shape_node.rotation = rotation
		_collision_root.add_child(shape_node)
	return mesh_instance


func _cylinder(part_name: String, center: Vector3, radius: float, height: float, material: Material, collision := true, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = center
	mesh_instance.rotation = rotation
	mesh_instance.layers = visual_layer_mask
	add_child(mesh_instance)
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
	return mesh_instance


func _four_legs(prefix: String, half_x: float, half_z: float, height: float, material: Material, width := 0.1) -> void:
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			_box("%sLeg_%s_%s" % [prefix, int(x_sign), int(z_sign)], Vector3(x_sign * half_x, height * 0.5, z_sign * half_z), Vector3(width, height, width), material)


func _build_trash_bin() -> void:
	_cylinder("BinBody", Vector3(0, 0.36, 0), 0.32, 0.72, PAINTED_METAL)
	_cylinder("BinRim", Vector3(0, 0.735, 0), 0.35, 0.06, SECURITY_DARK, false)
	_cylinder("BinLid", Vector3(0, 0.775, 0), 0.31, 0.035, SECURITY_DARK, false)
	_box("FootPedal", Vector3(0, 0.07, 0.31), Vector3(0.22, 0.08, 0.16), DARK_RUBBER, false)


func _build_wall_trash_bin() -> void:
	_box("MountingPlate", Vector3(0, 0.92, 0.035), Vector3(0.64, 0.9, 0.07), SECURITY_DARK, false)
	_box("BinBody", Vector3(0, 0.68, 0.22), Vector3(0.58, 0.62, 0.38), PAINTED_METAL)
	_box("SlopedLid", Vector3(0, 1.02, 0.22), Vector3(0.62, 0.08, 0.42), SECURITY_DARK, false, Vector3(deg_to_rad(-8), 0, 0))


func _build_bench(outdoor: bool) -> void:
	var seat_material: Material = CONCRETE if outdoor else INSTITUTIONAL_PLASTIC
	var frame_material: Material = PAINTED_METAL
	_box("Seat", Vector3(0, 0.49, 0), Vector3(1.9, 0.14, 0.52), seat_material)
	_box("Back", Vector3(0, 0.91, -0.23), Vector3(1.9, 0.58, 0.12), seat_material)
	for x in [-0.7, 0.7]:
		_box("FrameLeg%s" % x, Vector3(x, 0.24, 0), Vector3(0.12, 0.48, 0.46), frame_material)
		_box("BackPost%s" % x, Vector3(x, 0.72, -0.23), Vector3(0.1, 0.88, 0.1), frame_material, false)
	_box("UnderSeatBrace", Vector3(0, 0.36, 0), Vector3(1.55, 0.09, 0.09), frame_material, false)


func _build_table() -> void:
	_box("Tabletop", Vector3(0, 0.78, 0), Vector3(1.65, 0.14, 0.9), WOOD_FURNITURE)
	_four_legs("Table", 0.66, 0.3, 0.71, PAINTED_METAL, 0.11)
	_box("LongBrace", Vector3(0, 0.58, 0), Vector3(1.35, 0.08, 0.08), PAINTED_METAL, false)


func _build_chair() -> void:
	_box("Seat", Vector3(0, 0.48, 0), Vector3(0.52, 0.12, 0.52), INSTITUTIONAL_PLASTIC)
	_box("Back", Vector3(0, 0.87, -0.235), Vector3(0.52, 0.62, 0.1), INSTITUTIONAL_PLASTIC)
	_four_legs("Chair", 0.2, 0.2, 0.43, PAINTED_METAL, 0.075)
	for x in [-0.2, 0.2]:
		_box("BackPost%s" % x, Vector3(x, 0.68, -0.2), Vector3(0.07, 0.72, 0.07), PAINTED_METAL, false)


func _build_shelving(heavy: bool) -> void:
	var width := 2.3 if heavy else 1.55
	var height := 2.25 if heavy else 1.9
	var depth := 0.72 if heavy else 0.52
	var upright := 0.11 if heavy else 0.08
	for x in [-width * 0.5 + upright * 0.5, width * 0.5 - upright * 0.5]:
		for z in [-depth * 0.5 + upright * 0.5, depth * 0.5 - upright * 0.5]:
			_box("Upright_%s_%s" % [x, z], Vector3(x, height * 0.5, z), Vector3(upright, height, upright), PAINTED_METAL)
	for index in range(4):
		var shelf_y := 0.12 + index * ((height - 0.18) / 3.0)
		_box("Shelf%02d" % index, Vector3(0, shelf_y, 0), Vector3(width, 0.09, depth), STAINLESS_STEEL)
	if heavy:
		_box("RearCrossBrace", Vector3(0, height * 0.5, -depth * 0.48), Vector3(width - 0.18, 0.07, 0.06), SECURITY_DARK, false, Vector3(0, 0, deg_to_rad(30)))


func _build_crate() -> void:
	_box("CrateBody", Vector3(0, 0.39, 0), Vector3(0.92, 0.78, 0.72), PAINTED_METAL)
	for y in [0.08, 0.7]:
		_box("BandY%s" % y, Vector3(0, y, 0.37), Vector3(0.98, 0.09, 0.06), SECURITY_DARK, false)
	for x in [-0.42, 0.42]:
		_box("Corner%s" % x, Vector3(x, 0.39, 0.37), Vector3(0.08, 0.7, 0.06), SECURITY_DARK, false)
	_box("RecessedPanel", Vector3(0, 0.39, 0.395), Vector3(0.62, 0.42, 0.035), SECURITY_DARK, false)


func _build_utility_cart() -> void:
	for y in [0.28, 0.82]:
		_box("CartShelf%s" % y, Vector3(0, y, 0), Vector3(1.15, 0.1, 0.62), STAINLESS_STEEL)
	for x in [-0.5, 0.5]:
		for z in [-0.24, 0.24]:
			_box("CartPost_%s_%s" % [x, z], Vector3(x, 0.53, z), Vector3(0.07, 0.56, 0.07), PAINTED_METAL, false)
	for x in [-0.47, 0.47]:
		for z in [-0.22, 0.22]:
			_cylinder("Caster_%s_%s" % [x, z], Vector3(x, 0.1, z), 0.09, 0.06, DARK_RUBBER, false, Vector3(0, 0, deg_to_rad(90)))
	_box("Handle", Vector3(0, 1.05, -0.29), Vector3(1.12, 0.07, 0.07), PAINTED_METAL, false)
	for x in [-0.52, 0.52]:
		_box("HandlePost%s" % x, Vector3(x, 0.94, -0.29), Vector3(0.07, 0.28, 0.07), PAINTED_METAL, false)


func _build_locker() -> void:
	_box("LockerBody", Vector3(0, 0.95, 0), Vector3(0.64, 1.9, 0.58), PAINTED_METAL)
	_box("DoorInset", Vector3(0, 0.98, 0.305), Vector3(0.54, 1.72, 0.035), DIRTY_OFF_WHITE, false)
	for y in [1.55, 1.65, 1.75]:
		_box("Vent%s" % y, Vector3(0, y, 0.33), Vector3(0.28, 0.025, 0.02), SECURITY_DARK, false)
	_box("Handle", Vector3(0.21, 0.96, 0.34), Vector3(0.045, 0.22, 0.04), SECURITY_DARK, false)
	_box("ToeKick", Vector3(0, 0.07, 0.31), Vector3(0.56, 0.12, 0.05), SECURITY_DARK, false)


func _build_filing_cabinet() -> void:
	_box("CabinetBody", Vector3(0, 0.65, 0), Vector3(0.7, 1.3, 0.58), PAINTED_METAL)
	for index in range(4):
		var y := 0.19 + index * 0.31
		_box("Drawer%02d" % index, Vector3(0, y, 0.305), Vector3(0.61, 0.27, 0.035), DIRTY_OFF_WHITE, false)
		_box("Handle%02d" % index, Vector3(0, y + 0.04, 0.335), Vector3(0.22, 0.04, 0.035), SECURITY_DARK, false)


func _build_wall_clock() -> void:
	_cylinder("ClockCase", Vector3(0, 1.85, 0.055), 0.34, 0.11, SECURITY_DARK, false, Vector3(deg_to_rad(90), 0, 0))
	_cylinder("ClockFace", Vector3(0, 1.85, 0.115), 0.29, 0.018, DIRTY_OFF_WHITE, false, Vector3(deg_to_rad(90), 0, 0))
	_box("HourHand", Vector3(-0.035, 1.9, 0.132), Vector3(0.045, 0.18, 0.018), SECURITY_DARK, false, Vector3(0, 0, deg_to_rad(-32)))
	_box("MinuteHand", Vector3(0.075, 1.86, 0.134), Vector3(0.23, 0.035, 0.018), SECURITY_DARK, false, Vector3(0, 0, deg_to_rad(12)))


func _build_notice_board() -> void:
	_box("Board", Vector3(0, 1.55, 0.055), Vector3(1.5, 0.95, 0.1), CONCRETE, false)
	_box("PaperA", Vector3(-0.38, 1.62, 0.115), Vector3(0.45, 0.58, 0.018), DIRTY_OFF_WHITE, false, Vector3(0, 0, deg_to_rad(-3)))
	_box("PaperB", Vector3(0.35, 1.48, 0.117), Vector3(0.48, 0.45, 0.018), DIRTY_OFF_WHITE, false, Vector3(0, 0, deg_to_rad(2)))
	_box("FrameTop", Vector3(0, 2.05, 0.08), Vector3(1.6, 0.07, 0.08), PAINTED_METAL, false)
	_box("FrameBottom", Vector3(0, 1.05, 0.08), Vector3(1.6, 0.07, 0.08), PAINTED_METAL, false)
	for x in [-0.765, 0.765]:
		_box("FrameSide%s" % x, Vector3(x, 1.55, 0.08), Vector3(0.07, 1.0, 0.08), PAINTED_METAL, false)


func _build_extinguisher_cabinet() -> void:
	_box("CabinetBack", Vector3(0, 1.15, 0.045), Vector3(0.72, 1.25, 0.09), DIRTY_OFF_WHITE, false)
	_box("CabinetBase", Vector3(0, 0.55, 0.2), Vector3(0.72, 0.08, 0.38), PAINTED_METAL)
	for x in [-0.34, 0.34]:
		_box("CabinetSide%s" % x, Vector3(x, 1.15, 0.2), Vector3(0.06, 1.25, 0.38), PAINTED_METAL, false)
	_box("CabinetTop", Vector3(0, 1.77, 0.2), Vector3(0.72, 0.07, 0.38), PAINTED_METAL, false)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("9f2f29")
	red.roughness = 0.72
	_cylinder("Extinguisher", Vector3(0, 1.05, 0.23), 0.18, 0.72, red, false)
	_box("Valve", Vector3(0, 1.47, 0.23), Vector3(0.16, 0.12, 0.1), SECURITY_DARK, false)


func _build_cafeteria_table() -> void:
	_box("Tabletop", Vector3(0, 0.78, 0), Vector3(2.55, 0.16, 0.92), DIRTY_OFF_WHITE)
	for z in [-0.88, 0.88]:
		_box("BenchSeat%s" % z, Vector3(0, 0.46, z), Vector3(2.55, 0.14, 0.42), INSTITUTIONAL_PLASTIC)
	for x in [-0.88, 0.88]:
		_box("Frame%s" % x, Vector3(x, 0.34, 0), Vector3(0.12, 0.68, 2.05), PAINTED_METAL)
	_box("TableBrace", Vector3(0, 0.57, 0), Vector3(2.2, 0.1, 0.1), PAINTED_METAL, false)


func _build_weight_bench() -> void:
	_box("PaddedBench", Vector3(0, 0.54, 0.18), Vector3(0.58, 0.16, 1.65), DARK_RUBBER)
	_box("MainRail", Vector3(0, 0.35, 0.18), Vector3(0.12, 0.16, 1.5), PAINTED_METAL, false)
	for z in [-0.5, 0.72]:
		_box("Foot%s" % z, Vector3(0, 0.12, z), Vector3(0.9, 0.12, 0.14), PAINTED_METAL)
		_box("Post%s" % z, Vector3(0, 0.3, z), Vector3(0.12, 0.48, 0.12), PAINTED_METAL, false)
	for x in [-0.55, 0.55]:
		_box("RackPost%s" % x, Vector3(x, 0.9, -0.7), Vector3(0.11, 1.8, 0.11), PAINTED_METAL)
	_box("Barbell", Vector3(0, 1.65, -0.7), Vector3(1.55, 0.07, 0.07), STAINLESS_STEEL, false)


func _build_exam_table() -> void:
	_box("Mattress", Vector3(0, 0.79, 0), Vector3(0.78, 0.18, 1.92), INSTITUTIONAL_PLASTIC)
	_box("Frame", Vector3(0, 0.64, 0), Vector3(0.7, 0.12, 1.78), STAINLESS_STEEL, false)
	_four_legs("Exam", 0.28, 0.72, 0.58, STAINLESS_STEEL, 0.09)
	_box("Headrest", Vector3(0, 0.9, -0.75), Vector3(0.72, 0.16, 0.42), DIRTY_OFF_WHITE, false, Vector3(deg_to_rad(-12), 0, 0))
	_box("LowerShelf", Vector3(0, 0.24, 0), Vector3(0.62, 0.08, 1.4), STAINLESS_STEEL, false)


func _build_prep_counter() -> void:
	_box("Worktop", Vector3(0, 0.95, 0), Vector3(2.2, 0.14, 0.78), STAINLESS_STEEL)
	for x in [-0.9, 0.9]:
		_box("Pedestal%s" % x, Vector3(x, 0.44, 0), Vector3(0.24, 0.88, 0.68), PAINTED_METAL)
	_box("LowerShelf", Vector3(0, 0.28, 0), Vector3(1.7, 0.09, 0.64), STAINLESS_STEEL, false)
	_box("Backsplash", Vector3(0, 1.1, -0.34), Vector3(2.2, 0.3, 0.08), STAINLESS_STEEL, false)


func _build_security_console() -> void:
	_box("DeskTop", Vector3(0, 0.83, 0), Vector3(1.9, 0.14, 0.82), SECURITY_DARK)
	for x in [-0.72, 0.72]:
		_box("DeskPedestal%s" % x, Vector3(x, 0.39, 0), Vector3(0.26, 0.78, 0.7), PAINTED_METAL)
	_box("Monitor", Vector3(0, 1.28, -0.25), Vector3(1.15, 0.62, 0.09), SECURITY_DARK, false, Vector3(deg_to_rad(-8), 0, 0))
	_box("MonitorFace", Vector3(0, 1.28, -0.195), Vector3(1.02, 0.49, 0.018), INSTITUTIONAL_PLASTIC, false, Vector3(deg_to_rad(-8), 0, 0))
	_box("MonitorStand", Vector3(0, 0.98, -0.25), Vector3(0.1, 0.28, 0.1), PAINTED_METAL, false)
	_box("Keyboard", Vector3(0, 0.93, 0.14), Vector3(0.72, 0.05, 0.25), PAINTED_METAL, false, Vector3(deg_to_rad(-7), 0, 0))


func _build_prison_bunk() -> void:
	for y in [0.48, 1.52]:
		_box("BedFrame%s" % y, Vector3(0, y, 0), Vector3(0.92, 0.12, 2.0), SECURITY_DARK)
		_box("Mattress%s" % y, Vector3(0, y + 0.14, 0), Vector3(0.84, 0.18, 1.88), DIRTY_OFF_WHITE)
	for x in [-0.41, 0.41]:
		for z in [-0.91, 0.91]:
			_box("BunkPost_%s_%s" % [x, z], Vector3(x, 0.92, z), Vector3(0.09, 1.84, 0.09), PAINTED_METAL)


func _build_lab_workbench() -> void:
	_box("BenchTop", Vector3(0, 0.94, 0), Vector3(2.35, 0.14, 0.82), STAINLESS_STEEL)
	for x in [-0.92, 0.92]:
		_box("Cabinet%s" % x, Vector3(x, 0.43, 0), Vector3(0.34, 0.86, 0.7), DIRTY_OFF_WHITE)
	_box("RearShelf", Vector3(0, 1.52, -0.31), Vector3(2.25, 0.1, 0.35), STAINLESS_STEEL, false)
	for x in [-1.02, 1.02]:
		_box("ShelfPost%s" % x, Vector3(x, 1.25, -0.31), Vector3(0.07, 0.62, 0.07), PAINTED_METAL, false)
	_box("InstrumentA", Vector3(-0.5, 1.08, -0.12), Vector3(0.48, 0.28, 0.35), INSTITUTIONAL_PLASTIC, false)
	_box("InstrumentB", Vector3(0.35, 1.05, -0.12), Vector3(0.32, 0.22, 0.3), SECURITY_DARK, false)


func _build_workshop_bench() -> void:
	_box("Worktop", Vector3(0, 0.91, 0), Vector3(2.4, 0.18, 0.82), WOOD_FURNITURE)
	_four_legs("Workshop", 1.0, 0.31, 0.82, SECURITY_DARK, 0.12)
	_box("LowerShelf", Vector3(0, 0.3, 0), Vector3(2.0, 0.1, 0.62), PAINTED_METAL)
	_box("Pegboard", Vector3(0, 1.52, -0.36), Vector3(2.3, 1.0, 0.08), CONCRETE, false)
	for x in [-0.65, 0.0, 0.65]:
		_box("Tool%s" % x, Vector3(x, 1.55, -0.305), Vector3(0.08, 0.48, 0.04), STAINLESS_STEEL, false, Vector3(0, 0, deg_to_rad(18 * x)))
