extends Node3D
class_name CafeteriaKitchenProp

## Focused, Web-friendly cafeteria and kitchen silhouettes. Like the common prop
## library, floor props use y=0 as floor contact and wall fixtures project toward
## local +Z. Labels are geometry-local so scenes remain independently reusable.

enum PropKind {
	SERVING_STALL,
	FOOD_TRAY,
	TRAY_RETURN,
	WATER_DISPENSER,
	QUEUE_RAILING,
	CONDIMENT_STATION,
	DRINKING_FOUNTAIN,
	CLEANING_CART,
	COOKING_RANGE,
	OVEN,
	INDUSTRIAL_SINK,
	REFRIGERATOR,
	FREEZER,
	DISHWASHING_STATION,
	EXTRACTOR_HOOD,
	COOKING_VESSEL,
	TOOL_RACK,
	FOOD_SACK_STACK,
}

const PAINTED_METAL := preload("res://materials/props/painted_metal.tres")
const STAINLESS_STEEL := preload("res://materials/props/stainless_steel.tres")
const INSTITUTIONAL_PLASTIC := preload("res://materials/props/institutional_plastic.tres")
const DARK_RUBBER := preload("res://materials/props/dark_rubber.tres")
const DIRTY_OFF_WHITE := preload("res://materials/props/dirty_off_white.tres")
const SECURITY_DARK := preload("res://materials/props/security_dark.tres")

@export var prop_kind: PropKind = PropKind.SERVING_STALL
@export var display_label := ""
@export_flags_3d_render var visual_layer_mask := 1

var _collision_root: StaticBody3D


func _ready() -> void:
	add_to_group("environmental_props")
	add_to_group("cafeteria_kitchen_props")
	set_meta("prop_kind", PropKind.keys()[prop_kind].to_lower())
	_collision_root = StaticBody3D.new()
	_collision_root.name = "Collision"
	_collision_root.collision_layer = 1
	_collision_root.collision_mask = 0
	add_child(_collision_root)
	_build_prop()


func _build_prop() -> void:
	match prop_kind:
		PropKind.SERVING_STALL: _build_serving_stall()
		PropKind.FOOD_TRAY: _build_food_tray()
		PropKind.TRAY_RETURN: _build_tray_return()
		PropKind.WATER_DISPENSER: _build_water_dispenser()
		PropKind.QUEUE_RAILING: _build_queue_railing()
		PropKind.CONDIMENT_STATION: _build_condiment_station()
		PropKind.DRINKING_FOUNTAIN: _build_drinking_fountain()
		PropKind.CLEANING_CART: _build_cleaning_cart()
		PropKind.COOKING_RANGE: _build_cooking_range()
		PropKind.OVEN: _build_oven()
		PropKind.INDUSTRIAL_SINK: _build_industrial_sink()
		PropKind.REFRIGERATOR: _build_refrigerator(false)
		PropKind.FREEZER: _build_refrigerator(true)
		PropKind.DISHWASHING_STATION: _build_dishwashing_station()
		PropKind.EXTRACTOR_HOOD: _build_extractor_hood()
		PropKind.COOKING_VESSEL: _build_cooking_vessel()
		PropKind.TOOL_RACK: _build_tool_rack()
		PropKind.FOOD_SACK_STACK: _build_food_sacks()


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


func _label(text: String, position: Vector3, pixel_size := 0.0035) -> void:
	var label := Label3D.new()
	label.name = "Sign"
	label.text = text
	label.position = position
	label.pixel_size = pixel_size
	label.font_size = 48
	label.modulate = Color("d8d2ad")
	label.outline_size = 6
	label.no_depth_test = false
	label.layers = visual_layer_mask
	add_child(label)


func _four_legs(prefix: String, half_x: float, half_z: float, height: float, material: Material, width := 0.1) -> void:
	for x in [-half_x, half_x]:
		for z in [-half_z, half_z]:
			_box("%sLeg_%s_%s" % [prefix, x, z], Vector3(x, height * 0.5, z), Vector3(width, height, width), material)


func _build_serving_stall() -> void:
	_box("Counter", Vector3(0, 0.84, 0.18), Vector3(3.6, 0.18, 0.88), STAINLESS_STEEL)
	for x in [-1.45, 1.45]:
		_box("CounterPedestal%s" % x, Vector3(x, 0.39, 0.05), Vector3(0.28, 0.78, 0.62), PAINTED_METAL)
		_box("WindowPost%s" % x, Vector3(x, 1.72, -0.22), Vector3(0.13, 1.7, 0.13), PAINTED_METAL, false)
	_box("ServiceOpening", Vector3(0, 1.72, -0.31), Vector3(2.75, 1.25, 0.05), SECURITY_DARK, false)
	_box("Header", Vector3(0, 2.55, -0.2), Vector3(3.6, 0.22, 0.32), PAINTED_METAL, false)
	_box("TrayShelf", Vector3(0, 1.04, 0.58), Vector3(3.25, 0.08, 0.3), STAINLESS_STEEL, false)
	for x in [-0.9, 0.0, 0.9]:
		_box("FoodPan%s" % x, Vector3(x, 1.02, 0.05), Vector3(0.62, 0.18, 0.46), STAINLESS_STEEL, false)
	_label(display_label if not display_label.is_empty() else "SERVING", Vector3(0, 2.66, 0.02))


func _build_food_tray() -> void:
	_box("Tray", Vector3(0, 0.035, 0), Vector3(0.48, 0.07, 0.34), STAINLESS_STEEL)
	_box("MainCompartment", Vector3(-0.09, 0.077, 0.02), Vector3(0.24, 0.025, 0.22), SECURITY_DARK, false)
	for z in [-0.09, 0.09]:
		_box("SideCompartment%s" % z, Vector3(0.14, 0.077, z), Vector3(0.13, 0.025, 0.12), SECURITY_DARK, false)


func _build_tray_return() -> void:
	_box("ReturnBody", Vector3(0, 0.57, 0), Vector3(1.35, 1.14, 0.72), PAINTED_METAL)
	_box("ReturnTop", Vector3(0, 1.18, 0), Vector3(1.48, 0.1, 0.8), STAINLESS_STEEL)
	for y in [0.28, 0.53, 0.78]:
		_box("TraySlot%s" % y, Vector3(0, y, 0.385), Vector3(1.08, 0.13, 0.05), SECURITY_DARK, false)
	_box("ReturnOpening", Vector3(0, 0.98, 0.385), Vector3(1.08, 0.22, 0.05), SECURITY_DARK, false)
	_label(display_label if not display_label.is_empty() else "TRAY RETURN", Vector3(0, 1.48, 0.24), 0.003)


func _build_water_dispenser() -> void:
	_box("DispenserBody", Vector3(0, 0.57, 0), Vector3(0.68, 1.14, 0.58), DIRTY_OFF_WHITE)
	_cylinder("WaterBottle", Vector3(0, 1.47, 0), 0.24, 0.72, INSTITUTIONAL_PLASTIC, false)
	_box("ControlPanel", Vector3(0, 0.82, 0.31), Vector3(0.48, 0.26, 0.04), SECURITY_DARK, false)
	for x in [-0.12, 0.12]:
		_box("Tap%s" % x, Vector3(x, 0.8, 0.37), Vector3(0.07, 0.12, 0.1), PAINTED_METAL, false)
	_box("DripTray", Vector3(0, 0.58, 0.36), Vector3(0.42, 0.05, 0.18), STAINLESS_STEEL, false)


func _build_queue_railing() -> void:
	for x in [-1.5, 1.5]:
		_cylinder("FloorPlate%s" % x, Vector3(x, 0.025, 0), 0.2, 0.05, SECURITY_DARK)
		_cylinder("Post%s" % x, Vector3(x, 0.58, 0), 0.055, 1.16, STAINLESS_STEEL)
	for y in [0.55, 1.05]:
		_box("Rail%s" % y, Vector3(0, y, 0), Vector3(3.0, 0.07, 0.07), STAINLESS_STEEL)


func _build_condiment_station() -> void:
	_box("Countertop", Vector3(0, 0.82, 0), Vector3(1.4, 0.12, 0.66), STAINLESS_STEEL)
	_four_legs("Condiment", 0.56, 0.23, 0.76, PAINTED_METAL, 0.09)
	_box("LowerShelf", Vector3(0, 0.28, 0), Vector3(1.15, 0.08, 0.5), PAINTED_METAL, false)
	for x in [-0.4, 0.0, 0.4]:
		_cylinder("Dispenser%s" % x, Vector3(x, 1.02, -0.08), 0.09, 0.34, INSTITUTIONAL_PLASTIC, false)
		_box("Pump%s" % x, Vector3(x, 1.22, -0.04), Vector3(0.08, 0.08, 0.18), SECURITY_DARK, false)


func _build_drinking_fountain() -> void:
	_box("WallMount", Vector3(0, 0.86, 0.05), Vector3(0.72, 0.72, 0.1), PAINTED_METAL, false)
	_box("Basin", Vector3(0, 0.88, 0.28), Vector3(0.72, 0.18, 0.52), STAINLESS_STEEL)
	_box("BasinInset", Vector3(0, 0.98, 0.28), Vector3(0.5, 0.035, 0.34), SECURITY_DARK, false)
	_cylinder("Bubbler", Vector3(-0.2, 1.09, 0.22), 0.045, 0.18, PAINTED_METAL, false)
	_box("Drain", Vector3(0.12, 1.0, 0.28), Vector3(0.12, 0.02, 0.12), SECURITY_DARK, false)


func _build_cleaning_cart() -> void:
	_box("CartBase", Vector3(0, 0.19, 0), Vector3(1.0, 0.16, 0.64), PAINTED_METAL)
	for x in [-0.42, 0.42]:
		for z in [-0.23, 0.23]:
			_cylinder("Wheel_%s_%s" % [x, z], Vector3(x, 0.09, z), 0.09, 0.06, DARK_RUBBER, false, Vector3(0, 0, deg_to_rad(90)))
	_box("Bucket", Vector3(-0.18, 0.52, 0), Vector3(0.54, 0.5, 0.48), INSTITUTIONAL_PLASTIC)
	_box("Wringer", Vector3(-0.18, 0.84, 0), Vector3(0.46, 0.18, 0.4), SECURITY_DARK, false)
	_box("Handle", Vector3(0.42, 0.88, -0.26), Vector3(0.08, 1.45, 0.08), PAINTED_METAL, false, Vector3(0, 0, deg_to_rad(-10)))
	_box("MopHead", Vector3(0.32, 0.08, 0.18), Vector3(0.34, 0.12, 0.22), DIRTY_OFF_WHITE, false)


func _build_cooking_range() -> void:
	_box("RangeBody", Vector3(0, 0.48, 0), Vector3(2.35, 0.96, 0.86), PAINTED_METAL)
	_box("Cooktop", Vector3(0, 1.0, 0), Vector3(2.45, 0.1, 0.92), STAINLESS_STEEL)
	for x in [-0.78, 0.0, 0.78]:
		for z in [-0.23, 0.23]:
			_cylinder("Burner_%s_%s" % [x, z], Vector3(x, 1.06, z), 0.16, 0.025, SECURITY_DARK, false)
	for x in [-0.8, -0.4, 0.0, 0.4, 0.8]:
		_cylinder("Knob%s" % x, Vector3(x, 0.73, 0.455), 0.06, 0.06, SECURITY_DARK, false, Vector3(deg_to_rad(90), 0, 0))
	_box("ToeKick", Vector3(0, 0.08, 0.43), Vector3(2.1, 0.12, 0.06), SECURITY_DARK, false)


func _build_oven() -> void:
	_box("OvenBody", Vector3(0, 0.9, 0), Vector3(1.08, 1.8, 0.82), PAINTED_METAL)
	for y in [0.52, 1.25]:
		_box("OvenDoor%s" % y, Vector3(0, y, 0.43), Vector3(0.9, 0.58, 0.05), SECURITY_DARK, false)
		_box("OvenWindow%s" % y, Vector3(0, y, 0.465), Vector3(0.68, 0.34, 0.025), DARK_RUBBER, false)
		_box("OvenHandle%s" % y, Vector3(0, y + 0.25, 0.5), Vector3(0.68, 0.06, 0.08), STAINLESS_STEEL, false)
	_box("ControlStrip", Vector3(0, 1.67, 0.44), Vector3(0.9, 0.15, 0.05), DIRTY_OFF_WHITE, false)


func _build_industrial_sink() -> void:
	_box("SinkTop", Vector3(0, 0.94, 0), Vector3(2.2, 0.12, 0.76), STAINLESS_STEEL)
	_four_legs("Sink", 0.92, 0.28, 0.88, STAINLESS_STEEL, 0.09)
	for x in [-0.52, 0.52]:
		_box("Basin%s" % x, Vector3(x, 0.97, 0), Vector3(0.82, 0.05, 0.55), SECURITY_DARK, false)
		_cylinder("FaucetStem%s" % x, Vector3(x, 1.25, -0.31), 0.035, 0.5, STAINLESS_STEEL, false)
		_box("FaucetArm%s" % x, Vector3(x, 1.48, -0.16), Vector3(0.07, 0.07, 0.35), STAINLESS_STEEL, false)
	_box("LowerBrace", Vector3(0, 0.3, 0), Vector3(1.9, 0.08, 0.08), PAINTED_METAL, false)


func _build_refrigerator(freezer: bool) -> void:
	var body_material: Material = SECURITY_DARK if freezer else DIRTY_OFF_WHITE
	_box("ColdBody", Vector3(0, 1.08, 0), Vector3(1.18, 2.16, 0.82), body_material)
	for x in [-0.29, 0.29]:
		_box("Door%s" % x, Vector3(x, 1.08, 0.43), Vector3(0.55, 1.92, 0.05), STAINLESS_STEEL, false)
		_box("Handle%s" % x, Vector3(x * 0.42, 1.12, 0.49), Vector3(0.055, 0.72, 0.07), SECURITY_DARK, false)
	_box("TopVent", Vector3(0, 2.05, 0.43), Vector3(0.78, 0.1, 0.05), SECURITY_DARK, false)
	_label(display_label if not display_label.is_empty() else ("FREEZER" if freezer else "COLD"), Vector3(0, 2.32, 0.28), 0.0028)


func _build_dishwashing_station() -> void:
	_box("DishBody", Vector3(0, 0.48, 0), Vector3(2.5, 0.96, 0.82), PAINTED_METAL)
	_box("DishTop", Vector3(0, 1.0, 0), Vector3(2.6, 0.1, 0.88), STAINLESS_STEEL)
	_box("WashBasin", Vector3(-0.55, 1.06, 0), Vector3(0.9, 0.035, 0.58), SECURITY_DARK, false)
	_box("MachineDoor", Vector3(0.62, 0.54, 0.43), Vector3(0.92, 0.65, 0.05), SECURITY_DARK, false)
	_box("RackShelf", Vector3(0, 1.68, -0.25), Vector3(2.3, 0.09, 0.38), STAINLESS_STEEL, false)
	for x in [-1.02, 1.02]:
		_box("RackPost%s" % x, Vector3(x, 1.38, -0.25), Vector3(0.07, 0.7, 0.07), STAINLESS_STEEL, false)


func _build_extractor_hood() -> void:
	_box("HoodCanopy", Vector3(0, 2.15, 0.25), Vector3(2.7, 0.36, 1.02), STAINLESS_STEEL, false, Vector3(deg_to_rad(-5), 0, 0))
	_box("HoodLip", Vector3(0, 1.95, 0.54), Vector3(2.75, 0.12, 0.18), PAINTED_METAL, false)
	_box("VentStack", Vector3(0, 2.8, -0.02), Vector3(1.3, 1.0, 0.55), PAINTED_METAL, false)
	for x in [-0.75, 0.0, 0.75]:
		_box("Filter%s" % x, Vector3(x, 2.0, 0.34), Vector3(0.58, 0.05, 0.5), SECURITY_DARK, false, Vector3(deg_to_rad(-5), 0, 0))


func _build_cooking_vessel() -> void:
	_cylinder("PotBody", Vector3(0, 0.23, 0), 0.32, 0.46, STAINLESS_STEEL)
	_cylinder("PotLid", Vector3(0, 0.49, 0), 0.34, 0.06, PAINTED_METAL, false)
	_cylinder("LidHandle", Vector3(0, 0.56, 0), 0.06, 0.1, SECURITY_DARK, false)
	for x in [-0.37, 0.37]:
		_box("PotHandle%s" % x, Vector3(x, 0.32, 0), Vector3(0.18, 0.07, 0.12), SECURITY_DARK, false)


func _build_tool_rack() -> void:
	_box("ToolBoard", Vector3(0, 1.55, 0.055), Vector3(1.75, 0.85, 0.1), PAINTED_METAL, false)
	for index in range(5):
		var x := -0.64 + index * 0.32
		_box("Tool%02d" % index, Vector3(x, 1.55, 0.125), Vector3(0.07, 0.5 - index * 0.035, 0.045), STAINLESS_STEEL, false, Vector3(0, 0, deg_to_rad(-8 + index * 4)))
		_box("Hook%02d" % index, Vector3(x, 1.83, 0.14), Vector3(0.09, 0.04, 0.1), SECURITY_DARK, false)


func _build_food_sacks() -> void:
	for item in [[-0.42, 0.28, 0.0], [0.42, 0.28, 0.02], [0.0, 0.82, -0.03]]:
		var x: float = item[0]
		var y: float = item[1]
		var z: float = item[2]
		_cylinder("Sack%s" % x, Vector3(x, y, z), 0.28, 0.78, DIRTY_OFF_WHITE, true, Vector3(0, 0, deg_to_rad(90)))
		_box("SackBand%s" % x, Vector3(x, y, z + 0.29), Vector3(0.28, 0.08, 0.03), PAINTED_METAL, false)
