extends Node3D
class_name MedicalLabProp

## Reusable clinical, blacksite laboratory, safe, and interrogation silhouettes.
## Floor props use y=0 as floor contact; wall fixtures project toward local +Z.

enum PropKind {
	HOSPITAL_BED,
	BEDSIDE_TABLE,
	MEDICAL_CART,
	IV_STAND,
	PRIVACY_DIVIDER,
	MEDICINE_CABINET,
	MEDICAL_SINK,
	DOCTOR_DESK,
	STOOL,
	EQUIPMENT_TABLE,
	MEDICAL_DISPLAY,
	DIAGNOSTIC_MACHINE,
	WHEELCHAIR,
	BIOHAZARD_BIN,
	SECURE_MEDICINE_STORAGE,
	SMALL_WALL_SAFE,
	MEDIUM_SAFE,
	LARGE_SAFE,
	LAB_SINK,
	CHEMICAL_CABINET,
	MICROSCOPE,
	CENTRIFUGE,
	SAMPLE_RACK,
	LAB_GLASSWARE,
	COMPUTER_TERMINAL,
	LAB_REFRIGERATOR,
	HAZMAT_CABINET,
	EMERGENCY_SHOWER,
	NIDRA_TERMINAL,
	LAB_SIGN,
	SUBJECT_STORAGE,
	RESTRAINT_CHAIR,
	METAL_EXAM_TABLE,
	RECORDING_CAMERA,
	EXAMINATION_LIGHT,
	CONTROL_PANEL,
	MONITORING_EQUIPMENT,
	EQUIPMENT_TROLLEY,
}

const PAINTED_METAL := preload("res://materials/props/painted_metal.tres")
const STAINLESS_STEEL := preload("res://materials/props/stainless_steel.tres")
const CONCRETE := preload("res://materials/props/concrete.tres")
const INSTITUTIONAL_PLASTIC := preload("res://materials/props/institutional_plastic.tres")
const DARK_RUBBER := preload("res://materials/props/dark_rubber.tres")
const DIRTY_OFF_WHITE := preload("res://materials/props/dirty_off_white.tres")
const SECURITY_DARK := preload("res://materials/props/security_dark.tres")
const MEDICAL_BLUE := preload("res://materials/props/medical_blue.tres")
const HAZARD_YELLOW := preload("res://materials/props/hazard_yellow.tres")
const NIDRA_CYAN := preload("res://materials/props/nidra_cyan.tres")
const RESTRAINT_LEATHER := preload("res://materials/props/restraint_leather.tres")

@export var prop_kind: PropKind = PropKind.HOSPITAL_BED
@export var display_label := ""
@export_flags_3d_render var visual_layer_mask := 1

var _collision_root: StaticBody3D


func _ready() -> void:
	add_to_group("environmental_props")
	add_to_group("medical_lab_props")
	set_meta("prop_kind", PropKind.keys()[prop_kind].to_lower())
	if prop_kind in [PropKind.SMALL_WALL_SAFE, PropKind.MEDIUM_SAFE, PropKind.LARGE_SAFE]:
		add_to_group("secure_safe_props")
		set_meta("locked", true)
		set_meta("future_interactable", "safe")
	_collision_root = StaticBody3D.new()
	_collision_root.name = "Collision"
	_collision_root.collision_layer = 1
	_collision_root.collision_mask = 0
	add_child(_collision_root)
	_build_prop()


func _build_prop() -> void:
	match prop_kind:
		PropKind.HOSPITAL_BED: _build_hospital_bed()
		PropKind.BEDSIDE_TABLE: _build_bedside_table()
		PropKind.MEDICAL_CART: _build_medical_cart()
		PropKind.IV_STAND: _build_iv_stand()
		PropKind.PRIVACY_DIVIDER: _build_privacy_divider()
		PropKind.MEDICINE_CABINET: _build_medicine_cabinet()
		PropKind.MEDICAL_SINK: _build_medical_sink()
		PropKind.DOCTOR_DESK: _build_doctor_desk()
		PropKind.STOOL: _build_stool()
		PropKind.EQUIPMENT_TABLE: _build_equipment_table()
		PropKind.MEDICAL_DISPLAY: _build_medical_display()
		PropKind.DIAGNOSTIC_MACHINE: _build_diagnostic_machine()
		PropKind.WHEELCHAIR: _build_wheelchair()
		PropKind.BIOHAZARD_BIN: _build_biohazard_bin()
		PropKind.SECURE_MEDICINE_STORAGE: _build_secure_medicine_storage()
		PropKind.SMALL_WALL_SAFE: _build_safe(Vector3(0.85, 0.68, 0.38), 1.35)
		PropKind.MEDIUM_SAFE: _build_safe(Vector3(1.05, 1.35, 0.72), 0.675)
		PropKind.LARGE_SAFE: _build_safe(Vector3(1.75, 1.9, 0.92), 0.95)
		PropKind.LAB_SINK: _build_lab_sink()
		PropKind.CHEMICAL_CABINET: _build_chemical_cabinet(false)
		PropKind.MICROSCOPE: _build_microscope()
		PropKind.CENTRIFUGE: _build_centrifuge()
		PropKind.SAMPLE_RACK: _build_sample_rack()
		PropKind.LAB_GLASSWARE: _build_glassware()
		PropKind.COMPUTER_TERMINAL: _build_computer_terminal()
		PropKind.LAB_REFRIGERATOR: _build_lab_refrigerator()
		PropKind.HAZMAT_CABINET: _build_chemical_cabinet(true)
		PropKind.EMERGENCY_SHOWER: _build_emergency_shower()
		PropKind.NIDRA_TERMINAL: _build_nidra_terminal()
		PropKind.LAB_SIGN: _build_lab_sign()
		PropKind.SUBJECT_STORAGE: _build_subject_storage()
		PropKind.RESTRAINT_CHAIR: _build_restraint_chair()
		PropKind.METAL_EXAM_TABLE: _build_metal_exam_table()
		PropKind.RECORDING_CAMERA: _build_recording_camera()
		PropKind.EXAMINATION_LIGHT: _build_examination_light()
		PropKind.CONTROL_PANEL: _build_control_panel()
		PropKind.MONITORING_EQUIPMENT: _build_monitoring_equipment()
		PropKind.EQUIPMENT_TROLLEY: _build_equipment_trolley()


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
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


func _label(text: String, position: Vector3, pixel_size := 0.0032, color := Color("b9d4d0")) -> void:
	var label := Label3D.new()
	label.name = "Label"
	label.text = text
	label.position = position
	label.pixel_size = pixel_size
	label.font_size = 48
	label.modulate = color
	label.outline_size = 6
	label.layers = visual_layer_mask
	add_child(label)


func _four_legs(prefix: String, half_x: float, half_z: float, height: float, material: Material, width := 0.09) -> void:
	for x in [-half_x, half_x]:
		for z in [-half_z, half_z]:
			_box("%sLeg_%s_%s" % [prefix, x, z], Vector3(x, height * 0.5, z), Vector3(width, height, width), material)


func _build_hospital_bed() -> void:
	_box("BedFrame", Vector3(0, 0.56, 0), Vector3(1.02, 0.14, 2.15), STAINLESS_STEEL)
	_box("Mattress", Vector3(0, 0.72, 0), Vector3(0.94, 0.2, 2.02), MEDICAL_BLUE)
	_box("Pillow", Vector3(0, 0.86, -0.76), Vector3(0.72, 0.16, 0.4), DIRTY_OFF_WHITE, false, Vector3(deg_to_rad(-7), 0, 0))
	_four_legs("Bed", 0.42, 0.9, 0.49, STAINLESS_STEEL, 0.1)
	for z in [-1.04, 1.04]:
		_box("EndRail%s" % z, Vector3(0, 0.94, z), Vector3(1.06, 0.82, 0.08), PAINTED_METAL, false)
	for x in [-0.48, 0.48]:
		_box("SideRail%s" % x, Vector3(x, 0.92, 0.18), Vector3(0.06, 0.4, 1.3), STAINLESS_STEEL, false)


func _build_bedside_table() -> void:
	_box("Cabinet", Vector3(0, 0.38, 0), Vector3(0.55, 0.76, 0.5), DIRTY_OFF_WHITE)
	_box("Top", Vector3(0, 0.8, 0), Vector3(0.62, 0.09, 0.56), STAINLESS_STEEL)
	for y in [0.25, 0.52]:
		_box("Drawer%s" % y, Vector3(0, y, 0.265), Vector3(0.46, 0.2, 0.04), PAINTED_METAL, false)
		_box("Handle%s" % y, Vector3(0, y, 0.3), Vector3(0.18, 0.04, 0.04), SECURITY_DARK, false)


func _build_medical_cart() -> void:
	for y in [0.3, 0.68, 1.02]:
		_box("CartShelf%s" % y, Vector3(0, y, 0), Vector3(0.95, 0.09, 0.58), STAINLESS_STEEL, y == 0.3)
	for x in [-0.41, 0.41]:
		for z in [-0.23, 0.23]:
			_box("CartPost_%s_%s" % [x, z], Vector3(x, 0.62, z), Vector3(0.06, 0.72, 0.06), PAINTED_METAL, false)
	for x in [-0.4, 0.4]:
		for z in [-0.22, 0.22]:
			_cylinder("Caster_%s_%s" % [x, z], Vector3(x, 0.1, z), 0.085, 0.055, DARK_RUBBER, false, Vector3(0, 0, deg_to_rad(90)))
	_box("Handle", Vector3(0, 1.15, -0.28), Vector3(0.92, 0.06, 0.06), PAINTED_METAL, false)


func _build_iv_stand() -> void:
	_cylinder("Base", Vector3(0, 0.05, 0), 0.32, 0.1, PAINTED_METAL)
	_box("Pole", Vector3(0, 1.1, 0), Vector3(0.055, 2.15, 0.055), STAINLESS_STEEL)
	_box("HookBar", Vector3(0, 2.14, 0), Vector3(0.5, 0.05, 0.05), STAINLESS_STEEL, false)
	for x in [-0.2, 0.2]:
		_box("FluidBag%s" % x, Vector3(x, 1.85, 0), Vector3(0.18, 0.36, 0.08), MEDICAL_BLUE, false)
		_box("Hook%s" % x, Vector3(x, 2.02, 0), Vector3(0.035, 0.25, 0.035), STAINLESS_STEEL, false)


func _build_privacy_divider() -> void:
	_box("Screen", Vector3(0, 1.25, 0), Vector3(1.85, 1.75, 0.07), MEDICAL_BLUE, false)
	for x in [-0.88, 0.88]:
		_box("ScreenPost%s" % x, Vector3(x, 1.05, 0), Vector3(0.07, 2.1, 0.07), STAINLESS_STEEL)
		_box("BaseFoot%s" % x, Vector3(x, 0.07, 0), Vector3(0.5, 0.1, 0.45), STAINLESS_STEEL)


func _build_medicine_cabinet() -> void:
	_box("CabinetBody", Vector3(0, 1.45, 0.14), Vector3(1.1, 1.35, 0.28), DIRTY_OFF_WHITE)
	for x in [-0.275, 0.275]:
		_box("Door%s" % x, Vector3(x, 1.45, 0.3), Vector3(0.52, 1.18, 0.04), PAINTED_METAL, false)
		_box("Handle%s" % x, Vector3(x * 0.25, 1.45, 0.34), Vector3(0.045, 0.28, 0.045), SECURITY_DARK, false)
	_box("Lock", Vector3(0, 1.18, 0.35), Vector3(0.13, 0.13, 0.05), SECURITY_DARK, false)


func _build_medical_sink() -> void:
	_box("WallSupport", Vector3(0, 0.58, 0.12), Vector3(0.42, 1.16, 0.26), PAINTED_METAL)
	_box("Basin", Vector3(0, 0.94, 0.32), Vector3(0.82, 0.18, 0.62), DIRTY_OFF_WHITE)
	_box("BowlInset", Vector3(0, 1.05, 0.32), Vector3(0.58, 0.035, 0.38), SECURITY_DARK, false)
	_cylinder("Faucet", Vector3(0, 1.22, 0.12), 0.04, 0.32, STAINLESS_STEEL, false)
	_box("FaucetArm", Vector3(0, 1.35, 0.23), Vector3(0.07, 0.07, 0.28), STAINLESS_STEEL, false)


func _build_doctor_desk() -> void:
	_box("DeskTop", Vector3(0, 0.8, 0), Vector3(1.9, 0.14, 0.82), DIRTY_OFF_WHITE)
	for x in [-0.75, 0.75]:
		_box("DeskPedestal%s" % x, Vector3(x, 0.37, 0), Vector3(0.28, 0.74, 0.68), PAINTED_METAL)
	for index in range(2):
		_box("Drawer%02d" % index, Vector3(0.75, 0.32 + index * 0.28, 0.36), Vector3(0.2, 0.22, 0.04), DIRTY_OFF_WHITE, false)
	_box("DeskInset", Vector3(0, 0.58, 0.36), Vector3(0.9, 0.08, 0.05), MEDICAL_BLUE, false)


func _build_stool() -> void:
	_cylinder("Seat", Vector3(0, 0.56, 0), 0.29, 0.12, MEDICAL_BLUE)
	_cylinder("CenterPost", Vector3(0, 0.3, 0), 0.055, 0.52, STAINLESS_STEEL)
	for angle in [0.0, 120.0, 240.0]:
		var direction := Vector3(sin(deg_to_rad(angle)), 0, cos(deg_to_rad(angle)))
		_box("Foot%s" % angle, direction * 0.2 + Vector3.UP * 0.06, Vector3(0.08, 0.09, 0.42), STAINLESS_STEEL, false, Vector3(0, deg_to_rad(angle), 0))


func _build_equipment_table() -> void:
	_box("Tabletop", Vector3(0, 0.88, 0), Vector3(1.5, 0.12, 0.7), STAINLESS_STEEL)
	_four_legs("Equipment", 0.62, 0.26, 0.82, PAINTED_METAL)
	_box("LowerShelf", Vector3(0, 0.28, 0), Vector3(1.25, 0.08, 0.52), PAINTED_METAL, false)
	_box("Instrument", Vector3(-0.32, 1.08, 0), Vector3(0.48, 0.3, 0.42), MEDICAL_BLUE, false)
	_box("Readout", Vector3(0.34, 1.06, 0.1), Vector3(0.36, 0.24, 0.08), SECURITY_DARK, false)


func _build_medical_display() -> void:
	_box("Mount", Vector3(0, 1.65, 0.04), Vector3(1.5, 0.9, 0.08), SECURITY_DARK, false)
	_box("Screen", Vector3(0, 1.65, 0.095), Vector3(1.32, 0.72, 0.025), NIDRA_CYAN, false)
	for index in range(4):
		_box("Trace%02d" % index, Vector3(-0.4 + index * 0.27, 1.63 + (index % 2) * 0.1, 0.118), Vector3(0.22, 0.025, 0.012), DIRTY_OFF_WHITE, false, Vector3(0, 0, deg_to_rad(-12 + index * 8)))


func _build_diagnostic_machine() -> void:
	_box("MachineBody", Vector3(0, 0.62, 0), Vector3(0.72, 1.24, 0.62), DIRTY_OFF_WHITE)
	_box("ControlHead", Vector3(0, 1.4, -0.08), Vector3(0.86, 0.54, 0.5), PAINTED_METAL, false, Vector3(deg_to_rad(-8), 0, 0))
	_box("Display", Vector3(0, 1.47, 0.19), Vector3(0.62, 0.32, 0.025), NIDRA_CYAN, false, Vector3(deg_to_rad(-8), 0, 0))
	for x in [-0.26, 0.26]:
		for z in [-0.22, 0.22]:
			_cylinder("Wheel_%s_%s" % [x, z], Vector3(x, 0.08, z), 0.08, 0.055, DARK_RUBBER, false, Vector3(0, 0, deg_to_rad(90)))
	_box("ProbeCable", Vector3(0.46, 1.05, 0.02), Vector3(0.025, 0.7, 0.025), SECURITY_DARK, false)


func _build_wheelchair() -> void:
	for x in [-0.38, 0.38]:
		_cylinder("MainWheel%s" % x, Vector3(x, 0.43, 0.05), 0.42, 0.06, SECURITY_DARK, false, Vector3(0, 0, deg_to_rad(90)))
		_cylinder("WheelHub%s" % x, Vector3(x, 0.43, 0.05), 0.08, 0.08, STAINLESS_STEEL, false, Vector3(0, 0, deg_to_rad(90)))
	_box("Seat", Vector3(0, 0.57, 0.02), Vector3(0.68, 0.12, 0.65), MEDICAL_BLUE)
	_box("Back", Vector3(0, 0.98, -0.27), Vector3(0.68, 0.72, 0.1), MEDICAL_BLUE)
	for x in [-0.34, 0.34]:
		_box("Arm%s" % x, Vector3(x, 0.78, 0), Vector3(0.08, 0.08, 0.58), PAINTED_METAL, false)
		_box("Handle%s" % x, Vector3(x, 1.31, -0.36), Vector3(0.08, 0.08, 0.3), DARK_RUBBER, false)


func _build_biohazard_bin() -> void:
	_box("BinBody", Vector3(0, 0.38, 0), Vector3(0.48, 0.76, 0.48), HAZARD_YELLOW)
	_box("BinLid", Vector3(0, 0.79, 0), Vector3(0.54, 0.08, 0.54), SECURITY_DARK, false)
	_box("HazardMark", Vector3(0, 0.45, 0.255), Vector3(0.24, 0.24, 0.025), SECURITY_DARK, false, Vector3(0, 0, deg_to_rad(45)))


func _build_secure_medicine_storage() -> void:
	var wall_height := 2.75
	_box("RearWall", Vector3(0, wall_height * 0.5, 1.75), Vector3(4.0, wall_height, 0.18), DIRTY_OFF_WHITE)
	for x in [-1.91, 1.91]:
		_box("SideWall%s" % x, Vector3(x, wall_height * 0.5, 0), Vector3(0.18, wall_height, 3.5), DIRTY_OFF_WHITE)
	for x in [-1.32, 1.32]:
		_box("FrontWall%s" % x, Vector3(x, wall_height * 0.5, -1.75), Vector3(1.36, wall_height, 0.18), DIRTY_OFF_WHITE)
	_box("DoorHeader", Vector3(0, 2.55, -1.75), Vector3(1.3, 0.4, 0.18), PAINTED_METAL)
	_box("CageFloor", Vector3(0, 0.025, 0), Vector3(3.8, 0.05, 3.3), CONCRETE, false)
	_label("SECURED MEDICINE", Vector3(0, 2.35, -1.86), 0.0027, Color("8fc5bd"))


func _build_safe(size: Vector3, center_y: float) -> void:
	_box("ReinforcedBody", Vector3(0, center_y, 0), size, SECURITY_DARK)
	_box("SafeDoor", Vector3(0, center_y, size.z * 0.52), Vector3(size.x * 0.86, size.y * 0.84, 0.09), PAINTED_METAL, false)
	for y in [center_y - size.y * 0.29, center_y + size.y * 0.29]:
		_box("Hinge%s" % y, Vector3(-size.x * 0.39, y, size.z * 0.6), Vector3(0.09, size.y * 0.15, 0.09), STAINLESS_STEEL, false)
	_cylinder("Dial", Vector3(size.x * 0.12, center_y + size.y * 0.12, size.z * 0.63), size.x * 0.1, 0.08, SECURITY_DARK, false, Vector3(deg_to_rad(90), 0, 0))
	_box("HandleStem", Vector3(size.x * 0.14, center_y - size.y * 0.13, size.z * 0.65), Vector3(0.07, size.y * 0.28, 0.07), STAINLESS_STEEL, false)
	_box("Keypad", Vector3(-size.x * 0.16, center_y + size.y * 0.12, size.z * 0.64), Vector3(size.x * 0.18, size.y * 0.2, 0.04), NIDRA_CYAN, false)


func _build_lab_sink() -> void:
	_box("LabCounter", Vector3(0, 0.92, 0.12), Vector3(1.8, 0.14, 0.74), STAINLESS_STEEL)
	for x in [-0.7, 0.7]:
		_box("LabPedestal%s" % x, Vector3(x, 0.42, 0.1), Vector3(0.24, 0.84, 0.58), DIRTY_OFF_WHITE)
	_box("SinkInset", Vector3(0, 1.0, 0.12), Vector3(0.72, 0.035, 0.48), SECURITY_DARK, false)
	_cylinder("LabFaucet", Vector3(0, 1.28, -0.2), 0.04, 0.55, STAINLESS_STEEL, false)
	_box("FaucetArm", Vector3(0, 1.53, -0.05), Vector3(0.07, 0.07, 0.34), STAINLESS_STEEL, false)


func _build_chemical_cabinet(hazmat: bool) -> void:
	var body_material: Material = HAZARD_YELLOW if hazmat else PAINTED_METAL
	_box("CabinetBody", Vector3(0, 1.0, 0), Vector3(1.15, 2.0, 0.62), body_material)
	for x in [-0.285, 0.285]:
		_box("CabinetDoor%s" % x, Vector3(x, 1.03, 0.33), Vector3(0.54, 1.78, 0.05), body_material, false)
		_box("CabinetHandle%s" % x, Vector3(x * 0.32, 1.05, 0.38), Vector3(0.045, 0.35, 0.045), SECURITY_DARK, false)
	_box("Vent", Vector3(0, 0.35, 0.37), Vector3(0.58, 0.2, 0.04), SECURITY_DARK, false)
	if hazmat:
		_label("HAZMAT", Vector3(0, 1.42, 0.38), 0.0027, Color("241f12"))


func _build_microscope() -> void:
	_box("MicroscopeBase", Vector3(0, 0.05, 0), Vector3(0.42, 0.1, 0.38), SECURITY_DARK)
	_box("MicroscopeArm", Vector3(0, 0.28, -0.08), Vector3(0.09, 0.48, 0.09), PAINTED_METAL, false, Vector3(deg_to_rad(-18), 0, 0))
	_cylinder("LensBody", Vector3(0, 0.5, 0.02), 0.08, 0.28, STAINLESS_STEEL, false, Vector3(deg_to_rad(18), 0, 0))
	_box("SampleStage", Vector3(0, 0.25, 0.08), Vector3(0.34, 0.05, 0.3), PAINTED_METAL, false)
	_cylinder("Eyepiece", Vector3(0, 0.65, -0.05), 0.055, 0.14, DARK_RUBBER, false, Vector3(deg_to_rad(18), 0, 0))


func _build_centrifuge() -> void:
	_box("CentrifugeBase", Vector3(0, 0.18, 0), Vector3(0.62, 0.36, 0.54), DIRTY_OFF_WHITE)
	_cylinder("RotorHousing", Vector3(0, 0.42, -0.02), 0.26, 0.18, PAINTED_METAL, false)
	_cylinder("RotorLid", Vector3(0, 0.52, -0.02), 0.24, 0.035, SECURITY_DARK, false)
	_box("Controls", Vector3(0, 0.22, 0.29), Vector3(0.42, 0.18, 0.04), NIDRA_CYAN, false)


func _build_sample_rack() -> void:
	_box("RackBase", Vector3(0, 0.035, 0), Vector3(0.72, 0.07, 0.32), PAINTED_METAL)
	_box("RackTop", Vector3(0, 0.28, 0), Vector3(0.72, 0.06, 0.32), STAINLESS_STEEL, false)
	for row in range(2):
		for index in range(5):
			_cylinder("Sample_%s_%s" % [row, index], Vector3(-0.28 + index * 0.14, 0.22, -0.08 + row * 0.16), 0.035, 0.38, NIDRA_CYAN, false)


func _build_glassware() -> void:
	for index in range(4):
		var x := -0.34 + index * 0.23
		_cylinder("Container%02d" % index, Vector3(x, 0.18 + index * 0.025, 0), 0.07 + index * 0.008, 0.36 + index * 0.05, NIDRA_CYAN, false)
	_box("ContainerTray", Vector3(0, 0.025, 0), Vector3(1.0, 0.05, 0.34), STAINLESS_STEEL)


func _build_computer_terminal() -> void:
	_box("TerminalBase", Vector3(0, 0.06, 0), Vector3(0.72, 0.12, 0.45), SECURITY_DARK)
	_box("ScreenBody", Vector3(0, 0.48, -0.1), Vector3(0.78, 0.64, 0.1), SECURITY_DARK, false, Vector3(deg_to_rad(-8), 0, 0))
	_box("Screen", Vector3(0, 0.48, -0.04), Vector3(0.66, 0.52, 0.025), NIDRA_CYAN, false, Vector3(deg_to_rad(-8), 0, 0))
	_box("Keyboard", Vector3(0, 0.14, 0.18), Vector3(0.68, 0.05, 0.25), PAINTED_METAL, false, Vector3(deg_to_rad(-7), 0, 0))


func _build_lab_refrigerator() -> void:
	_box("ColdBody", Vector3(0, 1.0, 0), Vector3(0.95, 2.0, 0.68), DIRTY_OFF_WHITE)
	_box("UpperDoor", Vector3(0, 1.42, 0.36), Vector3(0.82, 0.92, 0.05), PAINTED_METAL, false)
	_box("LowerDoor", Vector3(0, 0.52, 0.36), Vector3(0.82, 0.78, 0.05), PAINTED_METAL, false)
	_box("Handle", Vector3(0.32, 1.02, 0.42), Vector3(0.055, 0.72, 0.06), SECURITY_DARK, false)
	_box("Status", Vector3(-0.24, 1.72, 0.42), Vector3(0.2, 0.16, 0.035), NIDRA_CYAN, false)
	_label("SAMPLES", Vector3(0, 2.15, 0.25), 0.0025)


func _build_emergency_shower() -> void:
	_box("ShowerPipe", Vector3(0, 1.5, 0.08), Vector3(0.08, 3.0, 0.08), HAZARD_YELLOW)
	_box("TopArm", Vector3(0, 2.85, 0.32), Vector3(0.08, 0.08, 0.56), HAZARD_YELLOW, false)
	_cylinder("ShowerHead", Vector3(0, 2.68, 0.58), 0.2, 0.14, STAINLESS_STEEL, false)
	_box("PullRod", Vector3(0.32, 1.75, 0.08), Vector3(0.04, 1.5, 0.04), STAINLESS_STEEL, false)
	_box("PullHandle", Vector3(0.32, 1.03, 0.08), Vector3(0.38, 0.05, 0.05), HAZARD_YELLOW, false)
	_box("DrainPan", Vector3(0, 0.035, 0.5), Vector3(1.0, 0.07, 1.0), STAINLESS_STEEL)


func _build_nidra_terminal() -> void:
	_box("TerminalCabinet", Vector3(0, 0.7, 0), Vector3(1.0, 1.4, 0.65), SECURITY_DARK)
	_box("AngledConsole", Vector3(0, 1.48, 0.1), Vector3(1.1, 0.52, 0.58), PAINTED_METAL, false, Vector3(deg_to_rad(-16), 0, 0))
	_box("NidraScreen", Vector3(0, 1.58, 0.405), Vector3(0.86, 0.3, 0.025), NIDRA_CYAN, false, Vector3(deg_to_rad(-16), 0, 0))
	for x in [-0.28, 0.0, 0.28]:
		_box("Control%s" % x, Vector3(x, 1.3, 0.39), Vector3(0.1, 0.06, 0.04), HAZARD_YELLOW, false, Vector3(deg_to_rad(-16), 0, 0))
	_label("NIDRA\nNEURAL RESPONSE", Vector3(0, 2.02, 0.2), 0.0028, Color("68d6d5"))


func _build_lab_sign() -> void:
	_box("SignBacking", Vector3(0, 1.75, 0.05), Vector3(1.8, 0.55, 0.1), SECURITY_DARK, false)
	_box("SignInset", Vector3(0, 1.75, 0.115), Vector3(1.64, 0.4, 0.025), PAINTED_METAL, false)
	_label(display_label if not display_label.is_empty() else "AUTHORIZED PERSONNEL", Vector3(0, 1.75, 0.14), 0.0028, Color("d9c66e"))


func _build_subject_storage() -> void:
	_box("PodBase", Vector3(0, 0.12, 0), Vector3(1.15, 0.24, 1.0), SECURITY_DARK)
	_box("PodBody", Vector3(0, 1.35, 0), Vector3(1.05, 2.45, 0.9), PAINTED_METAL)
	_box("ObservationPanel", Vector3(0, 1.5, 0.47), Vector3(0.7, 1.35, 0.04), NIDRA_CYAN, false)
	for y in [0.38, 2.5]:
		_box("Reinforcement%s" % y, Vector3(0, y, 0.5), Vector3(1.08, 0.12, 0.1), SECURITY_DARK, false)
	_box("StatusPanel", Vector3(0.34, 0.72, 0.53), Vector3(0.22, 0.34, 0.05), NIDRA_CYAN, false)
	_label("SUBJECT STORAGE", Vector3(0, 2.83, 0.32), 0.0025, Color("78ced0"))


func _build_restraint_chair() -> void:
	_box("Seat", Vector3(0, 0.58, 0.05), Vector3(0.72, 0.16, 0.72), RESTRAINT_LEATHER)
	_box("Back", Vector3(0, 1.16, -0.25), Vector3(0.72, 1.05, 0.16), RESTRAINT_LEATHER)
	for x in [-0.36, 0.36]:
		_box("ChairSide%s" % x, Vector3(x, 0.58, 0), Vector3(0.12, 1.16, 0.68), PAINTED_METAL)
		_box("Armrest%s" % x, Vector3(x, 0.9, 0.06), Vector3(0.12, 0.1, 0.72), RESTRAINT_LEATHER, false)
		_box("WristStrap%s" % x, Vector3(x, 0.96, 0.18), Vector3(0.16, 0.05, 0.22), HAZARD_YELLOW, false)
	_box("ChestRestraint", Vector3(0, 1.25, -0.15), Vector3(0.78, 0.14, 0.08), HAZARD_YELLOW, false)
	_box("FootPlate", Vector3(0, 0.12, 0.52), Vector3(0.72, 0.12, 0.5), PAINTED_METAL)


func _build_metal_exam_table() -> void:
	_box("ExamTop", Vector3(0, 0.82, 0), Vector3(0.9, 0.16, 2.05), STAINLESS_STEEL)
	_box("Pad", Vector3(0, 0.94, 0), Vector3(0.82, 0.1, 1.92), RESTRAINT_LEATHER, false)
	_four_legs("Exam", 0.36, 0.86, 0.74, SECURITY_DARK, 0.11)
	for z in [-0.62, 0.0, 0.62]:
		_box("Restraint%s" % z, Vector3(0, 1.01, z), Vector3(0.94, 0.07, 0.18), HAZARD_YELLOW, false)
	_box("LowerTray", Vector3(0, 0.3, 0), Vector3(0.68, 0.08, 1.55), PAINTED_METAL, false)


func _build_recording_camera() -> void:
	_box("CameraBracket", Vector3(0, 2.45, 0.1), Vector3(0.18, 0.32, 0.18), PAINTED_METAL, false)
	_box("CameraArm", Vector3(0, 2.38, 0.34), Vector3(0.08, 0.08, 0.5), PAINTED_METAL, false)
	_box("CameraBody", Vector3(0, 2.28, 0.66), Vector3(0.34, 0.26, 0.56), SECURITY_DARK, false, Vector3(deg_to_rad(-12), 0, 0))
	_cylinder("CameraLens", Vector3(0, 2.21, 0.96), 0.09, 0.06, NIDRA_CYAN, false, Vector3(deg_to_rad(90), 0, 0))
	_box("RecordLight", Vector3(0.11, 2.36, 0.94), Vector3(0.05, 0.05, 0.025), HAZARD_YELLOW, false)


func _build_examination_light() -> void:
	_cylinder("LightBase", Vector3(0, 0.07, 0), 0.38, 0.14, PAINTED_METAL)
	_box("LightStand", Vector3(0, 1.2, 0), Vector3(0.08, 2.3, 0.08), STAINLESS_STEEL)
	_box("LightArm", Vector3(0.42, 2.2, 0), Vector3(0.9, 0.08, 0.08), STAINLESS_STEEL, false, Vector3(0, 0, deg_to_rad(-14)))
	_cylinder("LampHousing", Vector3(0.85, 2.0, 0), 0.34, 0.18, SECURITY_DARK, false, Vector3(0, 0, deg_to_rad(90)))
	_cylinder("LampFace", Vector3(0.85, 1.9, 0), 0.28, 0.035, DIRTY_OFF_WHITE, false)


func _build_control_panel() -> void:
	_box("PanelHousing", Vector3(0, 1.5, 0.12), Vector3(1.15, 1.15, 0.24), SECURITY_DARK)
	_box("PanelScreen", Vector3(0, 1.68, 0.26), Vector3(0.86, 0.42, 0.035), NIDRA_CYAN, false)
	for index in range(6):
		var x := -0.35 + (index % 3) * 0.35
		var y := 1.23 + (index / 3) * 0.18
		_box("PanelButton%02d" % index, Vector3(x, y, 0.27), Vector3(0.1, 0.08, 0.04), HAZARD_YELLOW if index == 2 else PAINTED_METAL, false)


func _build_monitoring_equipment() -> void:
	_box("MonitorRack", Vector3(0, 0.9, 0), Vector3(1.05, 1.8, 0.62), SECURITY_DARK)
	for index in range(3):
		var y := 0.48 + index * 0.52
		_box("Monitor%02d" % index, Vector3(0, y, 0.33), Vector3(0.82, 0.36, 0.04), NIDRA_CYAN, false)
		_box("MonitorDivider%02d" % index, Vector3(0, y - 0.22, 0.35), Vector3(0.9, 0.05, 0.05), PAINTED_METAL, false)
	_box("CableLoom", Vector3(0.48, 0.72, -0.08), Vector3(0.06, 1.1, 0.06), HAZARD_YELLOW, false)


func _build_equipment_trolley() -> void:
	for y in [0.28, 0.72, 1.08]:
		_box("TrolleyShelf%s" % y, Vector3(0, y, 0), Vector3(1.05, 0.09, 0.62), STAINLESS_STEEL, y == 0.28)
	for x in [-0.46, 0.46]:
		for z in [-0.25, 0.25]:
			_box("TrolleyPost_%s_%s" % [x, z], Vector3(x, 0.66, z), Vector3(0.06, 0.82, 0.06), SECURITY_DARK, false)
	_box("InstrumentBox", Vector3(-0.22, 0.9, 0), Vector3(0.42, 0.28, 0.42), PAINTED_METAL, false)
	_cylinder("InstrumentDial", Vector3(-0.22, 0.92, 0.23), 0.07, 0.04, NIDRA_CYAN, false, Vector3(deg_to_rad(90), 0, 0))
	for x in [-0.43, 0.43]:
		for z in [-0.23, 0.23]:
			_cylinder("TrolleyWheel_%s_%s" % [x, z], Vector3(x, 0.1, z), 0.08, 0.05, DARK_RUBBER, false, Vector3(0, 0, deg_to_rad(90)))

