extends Node3D
class_name CampusDetailProp

## Small, configurable environmental details shared by campus room recipes.
## The root is either floor/support contact or the wall/floor intersection.
## These are visual-only unless they are large enough to affect movement.
enum DetailKind {
	BOOK_STACK,
	FOLDED_CLOTHING,
	CUP,
	PAPERWORK,
	CLEANING_SUPPLIES,
	ELECTRICAL_BOX,
	UTILITY_PIPE_RUN,
	SECURITY_SIGN,
	MONITOR_WALL,
	RADIO_SET,
	KEY_CABINET,
	INCIDENT_BOARD,
	SECURITY_MAP,
	TOOL_BOARD,
	MECHANICAL_PARTS,
	ELECTRICAL_PANEL,
	FOOD_CONTAINERS,
	FENCE_SIGN,
}

@export var detail_kind: DetailKind = DetailKind.PAPERWORK
@export var display_text := "AUTHORIZED PERSONNEL"
@export_flags_3d_render var visual_layer_mask := 1

const METAL := preload("res://materials/props/painted_metal.tres")
const STEEL := preload("res://materials/props/stainless_steel.tres")
const DARK := preload("res://materials/props/security_dark.tres")
const WHITE := preload("res://materials/props/dirty_off_white.tres")
const PLASTIC := preload("res://materials/props/institutional_plastic.tres")
const RUBBER := preload("res://materials/props/dark_rubber.tres")


func _ready() -> void:
	add_to_group("campus_detail_props")
	add_to_group("environmental_props")
	set_meta("detail_kind", DetailKind.keys()[detail_kind].to_lower())
	_build()


func _build() -> void:
	match detail_kind:
		DetailKind.BOOK_STACK: _books()
		DetailKind.FOLDED_CLOTHING: _clothes()
		DetailKind.CUP: _cup()
		DetailKind.PAPERWORK: _paperwork()
		DetailKind.CLEANING_SUPPLIES: _cleaning()
		DetailKind.ELECTRICAL_BOX: _electrical_box()
		DetailKind.UTILITY_PIPE_RUN: _utility_pipes()
		DetailKind.SECURITY_SIGN: _sign(false)
		DetailKind.MONITOR_WALL: _monitor_wall()
		DetailKind.RADIO_SET: _radio()
		DetailKind.KEY_CABINET: _key_cabinet()
		DetailKind.INCIDENT_BOARD: _incident_board()
		DetailKind.SECURITY_MAP: _security_map()
		DetailKind.TOOL_BOARD: _tool_board()
		DetailKind.MECHANICAL_PARTS: _mechanical_parts()
		DetailKind.ELECTRICAL_PANEL: _electrical_panel()
		DetailKind.FOOD_CONTAINERS: _food_containers()
		DetailKind.FENCE_SIGN: _sign(true)


func _box(part: String, at: Vector3, size: Vector3, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = part
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	visual.rotation = rotation
	visual.layers = visual_layer_mask
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	return visual


func _cylinder(part: String, at: Vector3, radius: float, height: float, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = part
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	visual.rotation = rotation
	visual.layers = visual_layer_mask
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	return visual


func _label(at: Vector3, text: String, size := 24) -> void:
	var label := Label3D.new()
	label.name = "Label"
	label.text = text
	label.font_size = size
	label.pixel_size = 0.0032
	label.position = at
	label.no_depth_test = false
	add_child(label)


func _books() -> void:
	var colors := [Color("66563f"), Color("435764"), Color("6f493d")]
	for index in range(3):
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[index]
		_box("Book%02d" % index, Vector3(0.02 * index, 0.035 + 0.07 * index, 0), Vector3(0.42 - 0.025 * index, 0.065, 0.27), material, Vector3(0, deg_to_rad(-3 + index * 4), 0))


func _clothes() -> void:
	for index in range(3):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("5c6260").lightened(index * 0.055)
		_box("FoldedGarment%02d" % index, Vector3(0, 0.035 + index * 0.065, 0), Vector3(0.46 - index * 0.025, 0.06, 0.32), material)
	_box("FoldEdge", Vector3(0, 0.105, 0.165), Vector3(0.25, 0.035, 0.02), DARK)


func _cup() -> void:
	_cylinder("CupBody", Vector3(0, 0.085, 0), 0.07, 0.17, STEEL)
	_cylinder("CupRim", Vector3(0, 0.173, 0), 0.075, 0.018, DARK)
	_box("Handle", Vector3(0.085, 0.09, 0), Vector3(0.055, 0.08, 0.035), STEEL)


func _paperwork() -> void:
	for index in range(4):
		_box("Document%02d" % index, Vector3(0.015 * index, 0.006 + index * 0.008, -0.008 * index), Vector3(0.43, 0.008, 0.3), WHITE, Vector3(0, deg_to_rad(index * 2 - 3), 0))
	_box("FileFolder", Vector3(-0.03, 0.052, 0), Vector3(0.48, 0.025, 0.33), PLASTIC, Vector3(0, deg_to_rad(-4), 0))


func _cleaning() -> void:
	_cylinder("Bucket", Vector3(-0.2, 0.16, 0), 0.2, 0.32, PLASTIC)
	_cylinder("Bottle", Vector3(-0.2, 0.39, 0), 0.055, 0.18, WHITE)
	_cylinder("BroomHandle", Vector3(0.16, 0.72, 0), 0.025, 1.44, METAL, Vector3(0, 0, deg_to_rad(-8)))
	_box("BroomHead", Vector3(0.06, 0.055, 0), Vector3(0.42, 0.11, 0.14), RUBBER, Vector3(0, deg_to_rad(8), 0))
	_box("WallRetainingClip", Vector3(0.13, 1.16, -0.04), Vector3(0.16, 0.08, 0.08), METAL)


func _electrical_box() -> void:
	_box("WallBackplate", Vector3(0, 1.35, 0.025), Vector3(0.82, 1.0, 0.05), DARK)
	_box("Enclosure", Vector3(0, 1.35, 0.14), Vector3(0.72, 0.9, 0.22), METAL)
	_box("DoorInset", Vector3(0, 1.35, 0.26), Vector3(0.61, 0.79, 0.025), WHITE)
	_box("Latch", Vector3(0.24, 1.35, 0.285), Vector3(0.06, 0.2, 0.035), DARK)
	_label(Vector3(0, 1.68, 0.29), "ELECTRICAL", 18)


func _utility_pipes() -> void:
	for index in range(3):
		var x := (index - 1) * 0.22
		_cylinder("Pipe%02d" % index, Vector3(x, 1.35, 0.11), 0.045 + index * 0.006, 2.7, STEEL)
		for y in [0.35, 1.35, 2.35]:
			_box("PipeClip%02d_%s" % [index, y], Vector3(x, y, 0.04), Vector3(0.14, 0.08, 0.09), METAL)
	for x in [-0.22, 0.0, 0.22]:
		_cylinder("Valve%s" % x, Vector3(x, 1.0, 0.18), 0.09, 0.035, DARK, Vector3(PI * 0.5, 0, 0))


func _sign(fence: bool) -> void:
	var y := 1.65 if fence else 2.05
	var size := Vector3(1.65, 0.55, 0.045) if fence else Vector3(1.8, 0.48, 0.05)
	_box("SignBack", Vector3(0, y, 0.045), size, DARK)
	for x in [-size.x * 0.45, size.x * 0.45]:
		_box("Mount%s" % x, Vector3(x, y, 0), Vector3(0.06, size.y + 0.14, 0.08), METAL)
	_label(Vector3(0, y, 0.078), display_text, 22 if display_text.length() < 24 else 16)


func _monitor_wall() -> void:
	_box("WallRail", Vector3(0, 1.62, 0.04), Vector3(3.0, 1.35, 0.08), DARK)
	for row in range(2):
		for column in range(3):
			var x := (column - 1) * 0.92
			var y := 1.32 + row * 0.62
			_box("ScreenCase%d_%d" % [row, column], Vector3(x, y, 0.105), Vector3(0.82, 0.52, 0.1), METAL)
			var screen_mat := StandardMaterial3D.new()
			screen_mat.albedo_color = Color("213f43")
			screen_mat.emission_enabled = true
			screen_mat.emission = Color("275b60")
			screen_mat.emission_energy_multiplier = 0.45
			_box("Screen%d_%d" % [row, column], Vector3(x, y, 0.162), Vector3(0.7, 0.4, 0.018), screen_mat)


func _radio() -> void:
	_box("RadioBody", Vector3(0, 0.13, 0), Vector3(0.36, 0.26, 0.28), DARK)
	_box("Speaker", Vector3(-0.07, 0.14, 0.15), Vector3(0.15, 0.13, 0.02), METAL)
	_cylinder("ControlDial", Vector3(0.1, 0.16, 0.16), 0.035, 0.025, STEEL, Vector3(PI * 0.5, 0, 0))
	_cylinder("Antenna", Vector3(-0.13, 0.48, 0), 0.012, 0.7, DARK, Vector3(0, 0, deg_to_rad(-7)))


func _key_cabinet() -> void:
	_box("CabinetBack", Vector3(0, 1.48, 0.04), Vector3(1.25, 1.5, 0.08), DARK)
	_box("CabinetBody", Vector3(0, 1.48, 0.17), Vector3(1.12, 1.38, 0.24), METAL)
	for row in range(5):
		for column in range(6):
			var x := -0.43 + column * 0.17
			var y := 1.0 + row * 0.22
			_box("KeyHook%d_%d" % [row, column], Vector3(x, y, 0.305), Vector3(0.025, 0.08, 0.025), STEEL)
	_box("Lock", Vector3(0.44, 1.48, 0.315), Vector3(0.07, 0.18, 0.03), DARK)
	_label(Vector3(0, 2.05, 0.32), "CONTROLLED KEYS", 18)


func _incident_board() -> void:
	_box("Board", Vector3(0, 1.52, 0.055), Vector3(2.4, 1.3, 0.1), DARK)
	for index in range(6):
		var x := -0.78 + (index % 3) * 0.78
		var y := 1.25 + int(index / 3.0) * 0.48
		_box("IncidentCard%02d" % index, Vector3(x, y, 0.115), Vector3(0.54, 0.32, 0.015), WHITE, Vector3(0, 0, deg_to_rad(index % 3 - 1)))
	_label(Vector3(0, 2.02, 0.125), display_text, 20)


func _security_map() -> void:
	_box("MapFrame", Vector3(0, 1.52, 0.055), Vector3(2.2, 1.35, 0.1), METAL)
	_box("MapField", Vector3(0, 1.52, 0.115), Vector3(2.05, 1.2, 0.018), WHITE)
	for x in [-0.72, 0.0, 0.72]:
		_box("MapBlockX%s" % x, Vector3(x, 1.55, 0.132), Vector3(0.42, 0.58, 0.012), PLASTIC)
	for z in [-0.36, 0.36]:
		_box("Route%s" % z, Vector3(0, 1.52 + z, 0.14), Vector3(1.7, 0.035, 0.012), DARK)
	_label(Vector3(0, 2.25, 0.14), display_text, 18)


func _tool_board() -> void:
	_box("Pegboard", Vector3(0, 1.38, 0.05), Vector3(2.2, 1.2, 0.1), METAL)
	for index in range(7):
		var x := -0.86 + index * 0.28
		var length := 0.34 + (index % 3) * 0.1
		_box("Tool%02d" % index, Vector3(x, 1.42, 0.13), Vector3(0.06, length, 0.045), STEEL, Vector3(0, 0, deg_to_rad(-12 + index * 4)))
	_box("LowerRail", Vector3(0, 0.82, 0.11), Vector3(2.0, 0.08, 0.1), DARK)


func _mechanical_parts() -> void:
	_box("FloorPallet", Vector3(0, 0.07, 0), Vector3(1.35, 0.14, 0.85), METAL)
	for index in range(4):
		_cylinder("GearBlank%02d" % index, Vector3(-0.42 + index * 0.28, 0.24 + (index % 2) * 0.1, 0), 0.16, 0.13, STEEL, Vector3(0, 0, PI * 0.5))
	_box("MotorHousing", Vector3(0.38, 0.29, 0.18), Vector3(0.5, 0.42, 0.38), DARK)


func _electrical_panel() -> void:
	_box("PanelBack", Vector3(0, 1.38, 0.05), Vector3(1.25, 1.75, 0.1), DARK)
	_box("PanelDoor", Vector3(0, 1.38, 0.15), Vector3(1.1, 1.58, 0.12), METAL)
	for row in range(5):
		for column in range(4):
			_box("Breaker%d_%d" % [row, column], Vector3(-0.36 + column * 0.24, 0.92 + row * 0.23, 0.225), Vector3(0.12, 0.09, 0.035), DARK)
	_label(Vector3(0, 2.08, 0.225), display_text, 17)


func _food_containers() -> void:
	for index in range(3):
		var x := (index - 1) * 0.34
		_cylinder("FoodPot%02d" % index, Vector3(x, 0.12, 0), 0.14, 0.24, STEEL)
		_cylinder("Lid%02d" % index, Vector3(x, 0.25, 0), 0.15, 0.025, DARK)
		_box("Handle%02d" % index, Vector3(x, 0.3, 0), Vector3(0.12, 0.045, 0.045), DARK)
