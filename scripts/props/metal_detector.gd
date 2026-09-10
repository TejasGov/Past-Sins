extends Node3D
class_name MetalDetector

@export var frame_width: float = 1.3
@export var frame_height: float = 2.4
@export var frame_depth: float = 0.6
@export_flags_3d_render var visual_layer_mask: int = 1

const SECURITY_DARK := preload("res://materials/props/security_dark.tres")
const PAINTED_METAL := preload("res://materials/props/painted_metal.tres")
const STAINLESS_STEEL := preload("res://materials/props/stainless_steel.tres")
const INSTITUTIONAL_PLASTIC := preload("res://materials/props/institutional_plastic.tres")

var _collision_root: StaticBody3D


func _ready() -> void:
	add_to_group("metal_detectors")
	add_to_group("environmental_props")
	set_meta("prop_kind", "metal_detector")
	_collision_root = StaticBody3D.new()
	_collision_root.name = "Collision"
	_collision_root.collision_layer = 1
	_collision_root.collision_mask = 0
	add_child(_collision_root)
	_build_metal_detector()


func _build_metal_detector() -> void:
	var pillar_width: float = 0.18
	var pillar_depth: float = frame_depth
	var pillar_height: float = frame_height

	# Left and Right Vertical Pillars
	for side in [-1.0, 1.0]:
		var side_val: float = float(side)
		var x_pos: float = side_val * (frame_width * 0.5 - pillar_width * 0.5)
		_create_box("Pillar_%s" % side_val, Vector3(x_pos, pillar_height * 0.5, 0), Vector3(pillar_width, pillar_height, pillar_depth), PAINTED_METAL)
		# Inner Sensor Panels (greyish institutional plastic facing inward)
		_create_box("SensorPanel_%s" % side_val, Vector3(x_pos - side_val * 0.08, pillar_height * 0.5, 0), Vector3(0.02, pillar_height * 0.8, pillar_depth * 0.8), INSTITUTIONAL_PLASTIC, false)

	# Top Overhead Header Box
	var header_height: float = 0.28
	var header_center_y: float = frame_height + header_height * 0.5
	_create_box("HeaderBox", Vector3(0, header_center_y, 0), Vector3(frame_width, header_height, frame_depth), SECURITY_DARK)

	# Top Status Indicator Bar (green emissive ready status)
	var status_mat := StandardMaterial3D.new()
	status_mat.albedo_color = Color("00e544")
	status_mat.emission_enabled = true
	status_mat.emission = Color("00e544")
	status_mat.emission_energy_multiplier = 1.8
	_create_box("StatusIndicator", Vector3(0, header_center_y, frame_depth * 0.5 + 0.01), Vector3(frame_width * 0.4, 0.06, 0.02), status_mat, false)

	# Side LED Meter Bars (stacked vertical status LEDs on front of pillars)
	for side in [-1.0, 1.0]:
		var side_val: float = float(side)
		var x_pos: float = side_val * (frame_width * 0.5 - pillar_width * 0.5)
		for index in range(5):
			var led_y: float = 0.6 + float(index) * 0.3
			var led_mat := StandardMaterial3D.new()
			var is_green: bool = index < 3
			var led_color: Color = Color("00cc44") if is_green else Color("224422")
			led_mat.albedo_color = led_color
			led_mat.emission_enabled = is_green
			led_mat.emission = led_color
			led_mat.emission_energy_multiplier = 1.2 if is_green else 0.0
			_create_box("PillarLED_%s_%02d" % [side_val, index], Vector3(x_pos, led_y, frame_depth * 0.5 + 0.01), Vector3(0.08, 0.04, 0.02), led_mat, false)

	# Base Threshold Ramp / Floor Plate
	_create_box("FloorRamp", Vector3(0, 0.02, 0), Vector3(frame_width, 0.04, frame_depth + 0.2), STAINLESS_STEEL, false)


func _create_box(part_name: String, center: Vector3, size: Vector3, material: Material, collision := true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	instance.mesh = box_mesh
	instance.material_override = material
	instance.position = center
	instance.layers = visual_layer_mask
	add_child(instance)

	if collision:
		var shape_node := CollisionShape3D.new()
		shape_node.name = "%sShape" % part_name
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		shape_node.position = center
		_collision_root.add_child(shape_node)

	return instance
