extends Node3D
class_name CCTVCamera

enum MountType {
	WALL,
	CEILING,
	POLE
}

@export var mount_type: MountType = MountType.WALL
@export var pole_height: float = 3.4
@export var tilt_degrees: float = -20.0
@export var pan_degrees: float = 0.0
@export var is_active: bool = true
@export_flags_3d_render var visual_layer_mask: int = 1

const SECURITY_DARK := preload("res://materials/props/security_dark.tres")
const PAINTED_METAL := preload("res://materials/props/painted_metal.tres")
const STAINLESS_STEEL := preload("res://materials/props/stainless_steel.tres")
const DIRTY_OFF_WHITE := preload("res://materials/props/dirty_off_white.tres")

var _mount_node: Node3D
var _head_node: Node3D
var _status_led_mesh: MeshInstance3D
var _led_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("cctv_cameras")
	add_to_group("environmental_props")
	set_meta("prop_kind", "cctv_camera")
	if not has_meta("placement_zone"):
		set_meta("placement_zone", "Security")
	_build_camera_visuals()


func set_mount_type(type: MountType) -> void:
	mount_type = type
	_rebuild()


func set_active(active: bool) -> void:
	is_active = active
	_update_led()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_build_camera_visuals()


func _build_camera_visuals() -> void:
	_mount_node = Node3D.new()
	_mount_node.name = "Mount"
	add_child(_mount_node)

	_head_node = Node3D.new()
	_head_node.name = "CameraHead"
	add_child(_head_node)

	# Build Mounting Structure
	if mount_type == MountType.WALL:
		# Wall mount plate at local +Z (against wall surface), extending into -Z (into room)
		var base_plate := _create_box("BasePlate", Vector3(0, 0, 0.02), Vector3(0.18, 0.22, 0.04), SECURITY_DARK)
		_mount_node.add_child(base_plate)
		var arm := _create_box("Arm", Vector3(0, 0.05, -0.14), Vector3(0.06, 0.06, 0.28), PAINTED_METAL)
		_mount_node.add_child(arm)
		var swivel := _create_cylinder("Swivel", Vector3(0, -0.02, -0.28), 0.04, 0.08, STAINLESS_STEEL)
		_mount_node.add_child(swivel)
		_head_node.position = Vector3(0, -0.06, -0.28)
	elif mount_type == MountType.CEILING:
		# Ceiling mount stem hanging down along -Y
		var ceiling_plate := _create_cylinder("CeilingPlate", Vector3(0, 0.02, 0), 0.12, 0.04, SECURITY_DARK)
		_mount_node.add_child(ceiling_plate)
		var stem := _create_cylinder("Stem", Vector3(0, -0.15, 0), 0.03, 0.3, PAINTED_METAL)
		_mount_node.add_child(stem)
		var swivel := _create_cylinder("Swivel", Vector3(0, -0.32, 0), 0.04, 0.06, STAINLESS_STEEL)
		_mount_node.add_child(swivel)
		_head_node.position = Vector3(0, -0.35, 0)
	else:
		# Pole mount: Structural pole anchored to floor at -pole_height
		var floor_flange := _create_cylinder("FloorFlange", Vector3(0, -pole_height + 0.02, 0), 0.16, 0.04, SECURITY_DARK)
		_mount_node.add_child(floor_flange)
		var vertical_pole := _create_cylinder("SupportPole", Vector3(0, -pole_height * 0.5, 0), 0.04, pole_height, PAINTED_METAL)
		_mount_node.add_child(vertical_pole)
		var top_cap := _create_cylinder("TopCap", Vector3(0, 0.0, 0), 0.06, 0.08, SECURITY_DARK)
		_mount_node.add_child(top_cap)
		var arm := _create_box("PoleArm", Vector3(0, 0.04, -0.14), Vector3(0.06, 0.06, 0.28), PAINTED_METAL)
		_mount_node.add_child(arm)
		var swivel := _create_cylinder("Swivel", Vector3(0, -0.02, -0.28), 0.04, 0.08, STAINLESS_STEEL)
		_mount_node.add_child(swivel)
		_head_node.position = Vector3(0, -0.06, -0.28)

	# Apply Pan & Tilt to Camera Head
	_head_node.rotation_degrees.y = pan_degrees
	_head_node.rotation_degrees.x = tilt_degrees

	# Camera Body Housing (cylinder lying along Z-axis)
	var body_housing := _create_cylinder("CameraBody", Vector3(0, 0, 0), 0.09, 0.26, DIRTY_OFF_WHITE, Vector3(deg_to_rad(90), 0, 0))
	_head_node.add_child(body_housing)

	# Protective Sunhood / Shield on top
	var shield := _create_box("SunShield", Vector3(0, 0.07, 0.01), Vector3(0.2, 0.03, 0.28), SECURITY_DARK)
	_head_node.add_child(shield)

	# Front Lens Rim & Glass Element (facing local -Z)
	var lens_rim := _create_cylinder("LensRim", Vector3(0, 0, -0.135), 0.085, 0.03, SECURITY_DARK, Vector3(deg_to_rad(90), 0, 0))
	_head_node.add_child(lens_rim)

	var lens_glass_mat := StandardMaterial3D.new()
	lens_glass_mat.albedo_color = Color("050914")
	lens_glass_mat.metallic = 0.95
	lens_glass_mat.roughness = 0.05
	var lens_glass := _create_cylinder("LensGlass", Vector3(0, 0, -0.145), 0.07, 0.01, lens_glass_mat, Vector3(deg_to_rad(90), 0, 0))
	_head_node.add_child(lens_glass)

	# Small Status LED Indicator
	_led_material = StandardMaterial3D.new()
	_update_led()
	_status_led_mesh = _create_box("StatusLED", Vector3(0.06, 0.06, -0.13), Vector3(0.025, 0.025, 0.025), _led_material)
	_head_node.add_child(_status_led_mesh)

	# Forward Direction Marker (invisible, for future detection logic)
	var forward_marker := Marker3D.new()
	forward_marker.name = "ForwardMarker"
	forward_marker.position = Vector3(0, 0, -0.5)
	_head_node.add_child(forward_marker)


func _update_led() -> void:
	if not _led_material:
		return
	var led_color := Color("00ff44") if is_active else Color("ff2222")
	_led_material.albedo_color = led_color
	_led_material.emission_enabled = true
	_led_material.emission = led_color
	_led_material.emission_energy_multiplier = 2.0


func _create_box(part_name: String, center: Vector3, size: Vector3, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	instance.mesh = box_mesh
	instance.material_override = material
	instance.position = center
	instance.rotation = rotation
	instance.layers = visual_layer_mask
	return instance


func _create_cylinder(part_name: String, center: Vector3, radius: float, height: float, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	var cyl_mesh := CylinderMesh.new()
	cyl_mesh.top_radius = radius
	cyl_mesh.bottom_radius = radius
	cyl_mesh.height = height
	cyl_mesh.radial_segments = 12
	instance.mesh = cyl_mesh
	instance.material_override = material
	instance.position = center
	instance.rotation = rotation
	instance.layers = visual_layer_mask
	return instance
