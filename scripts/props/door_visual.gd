extends Node3D
class_name InstitutionalDoorVisual

## Independently reusable cosmetic leaf. No collision, access or animation logic.
## Attach to a moving leaf; all hardware stays attached to the painted panel.
const PAINT := preload("res://materials/props/door_paint.tres")
const TRIM := preload("res://materials/props/door_trim.tres")
const STEEL := preload("res://materials/props/door_hardware.tres")
@export var width := 1.35
@export var height := 2.35
@export var thickness := 0.14
@export var caption := "DOOR"
@export var sealed := false
@export_enum("Hinged", "Lift", "Shutter") var style := 0

func _ready() -> void:
	add_to_group("detailed_door_visuals")
	if style != 0:
		_build_service_panel()
		preload("res://scripts/levels/campus/furnishing/campus_furniture_batcher.gd").consolidate(self)
		return
	_box(Vector3(0, height * 0.5, 0), Vector3(width, height, thickness), PAINT)
	for side in [-1.0, 1.0]:
		var face: float = side * (thickness * 0.5 + 0.008)
		_box(Vector3(0, 0.19, face), Vector3(width - 0.12, 0.32, 0.016), STEEL)
		for x in [-width * 0.5 + 0.065, width * 0.5 - 0.065]:
			_box(Vector3(x, height * 0.5, face), Vector3(0.045, height - 0.12, 0.016), TRIM)
		for y in [0.07, height - 0.07]:
			_box(Vector3(0, y, face), Vector3(width - 0.09, 0.045, 0.018), TRIM)
		_box(Vector3(0, height - 0.55, face), Vector3(width * 0.76, 0.28, 0.02), TRIM)
		var label := Label3D.new()
		label.name = "FaceLabel"
		label.text = caption.to_upper().replace("\n", " / ") + ("\nOFFLINE" if sealed else "")
		label.font_size = 28
		label.pixel_size = 0.002
		label.width = width * 0.70 / label.pixel_size
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.position = Vector3(0, height - 0.55, face + side * 0.018)
		label.rotation.y = PI if side < 0 else 0.0
		label.modulate = Color("edf0e7")
		add_child(label)
		var handle_x := width * 0.5 - 0.16
		_box(Vector3(handle_x, 1.05, face + side * 0.012), Vector3(0.10, 0.25, 0.03), STEEL)
		_box(Vector3(handle_x - 0.08, 1.1, face + side * 0.045), Vector3(0.20, 0.035, 0.07), STEEL)
		for y in [0.3, height - 0.3]:
			_box(Vector3(-width * 0.5 + 0.025, y, face), Vector3(0.07, 0.17, 0.045), STEEL)
	preload("res://scripts/levels/campus/furnishing/campus_furniture_batcher.gd").consolidate(self)

func _build_service_panel() -> void:
	_box(Vector3(0, height * 0.5, 0), Vector3(width, height, thickness), STEEL)
	for side in [-1.0, 1.0]:
		var face: float = side * (thickness * 0.5 + 0.01)
		for x in [-width * 0.5 + 0.04, width * 0.5 - 0.04]:
			_box(Vector3(x, height * 0.5, face), Vector3(0.08, height, 0.03), TRIM)
		if style == 1:
			# Paired landing doors have a centre seam, never a swing-door lever.
			_box(Vector3(0, height * 0.5, face), Vector3(0.025, height, 0.025), TRIM)
			for x in [-width * 0.25, width * 0.25]:
				_box(Vector3(x, height * 0.5, face), Vector3(width * 0.5 - 0.10, height - 0.16, 0.018), PAINT)
		else:
			# Industrial roller/slat shutter, visibly continuous and sealed.
			for index in range(ceili(height / 0.22)):
				_box(Vector3(0, minf(height - 0.02, index * 0.22 + 0.03), face), Vector3(width - 0.08, 0.035, 0.035), TRIM)
			_box(Vector3(0, height + 0.1, 0), Vector3(width + 0.12, 0.2, 0.35), TRIM)
		_box(Vector3(0, height - 0.65, face + side * 0.025), Vector3(minf(width - 0.2, 3.5), 0.38, 0.04), TRIM)
		var label := Label3D.new()
		label.text = caption.to_upper()
		label.font_size = 28
		label.pixel_size = 0.0026
		label.position = Vector3(0, height - 0.65, face + side * 0.055)
		label.rotation.y = PI if side < 0 else 0.0
		label.width = (width - 0.2) / label.pixel_size
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(label)

func _box(at: Vector3, size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
