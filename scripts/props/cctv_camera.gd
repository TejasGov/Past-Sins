extends Node3D
class_name CCTVCamera

signal detection_changed(in_view: bool, strength: float)

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

@export_group("Sweep")
@export_range(0.0, 180.0, 1.0) var sweep_range_degrees: float = 45.0
## Tuning factor, not radians/second: 0.15 gives a ~10.5-second round trip.
## Zero speed freezes the sweep; zero range keeps a fixed camera direction.
@export_range(0.0, 2.0, 0.01) var sweep_speed: float = 0.15

@export_group("Detection Data")
@export_range(0.0, 100.0, 0.5) var view_distance: float = 10.0
## Maximum angle away from forward (half-angle, not the full cone width).
@export_range(0.0, 89.0, 1.0) var view_angle_degrees: float = 40.0
@export var debug_draw: bool = false

## Geometric cone data only. No occlusion, suspicion or gameplay side effects.
var player_in_view: bool = false
var view_strength: float = 0.0

const DETECTION_INTERVAL: float = 0.1
const SWEEP_PHASE_RATE: float = 4.0
const DEBUG_CONE_SEGMENTS: int = 8

const SECURITY_DARK := preload("res://materials/props/security_dark.tres")
const PAINTED_METAL := preload("res://materials/props/painted_metal.tres")
const STAINLESS_STEEL := preload("res://materials/props/stainless_steel.tres")
const DIRTY_OFF_WHITE := preload("res://materials/props/dirty_off_white.tres")

var _mount_node: Node3D
var _head_node: Node3D
var _status_led_mesh: MeshInstance3D
var _led_material: StandardMaterial3D
var _sweep_phase: float = 0.0
var _detection_elapsed: float = DETECTION_INTERVAL
var _player: Node3D
var _debug_visual: MeshInstance3D
var _debug_mesh: ImmediateMesh
var _debug_dimensions := Vector2(-1.0, -1.0)


func _ready() -> void:
	add_to_group("cctv_cameras")
	add_to_group("environmental_props")
	set_meta("prop_kind", "cctv_camera")
	if not has_meta("placement_zone"):
		set_meta("placement_zone", "Security")
	_build_camera_visuals()


func _process(delta: float) -> void:
	if is_active:
		_sweep_phase = fposmod(_sweep_phase + delta * maxf(sweep_speed, 0.0) * SWEEP_PHASE_RATE, TAU)
		_update_head_rotation()
		_detection_elapsed += delta
		if _detection_elapsed >= DETECTION_INTERVAL:
			_detection_elapsed = fposmod(_detection_elapsed, DETECTION_INTERVAL)
			_update_detection()
	else:
		_set_detection(false, 0.0)
	_update_debug_visual()


func _update_head_rotation() -> void:
	_head_node.rotation_degrees.y = pan_degrees + sin(_sweep_phase) * maxf(sweep_range_degrees, 0.0)
	_head_node.rotation_degrees.x = tilt_degrees


func _update_detection() -> void:
	if not is_active or view_distance <= 0.0:
		_set_detection(false, 0.0)
		return
	if not is_instance_valid(_player) or not _player.is_inside_tree() or not _player.is_in_group("player"):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(_player):
		_set_detection(false, 0.0)
		return
	var to_player := _player.global_position - _head_node.global_position
	var distance_squared := to_player.length_squared()
	if distance_squared > view_distance * view_distance:
		_set_detection(false, 0.0)
		return
	if distance_squared <= 0.000001:
		_set_detection(true, 1.0)
		return
	var distance := sqrt(distance_squared)
	var forward := -_head_node.global_basis.z.normalized()
	var forward_dot := clampf(forward.dot(to_player / distance), -1.0, 1.0)
	var edge_dot := cos(deg_to_rad(clampf(view_angle_degrees, 0.0, 89.0)))
	if forward_dot < edge_dot:
		_set_detection(false, 0.0)
		return
	var centering := clampf((forward_dot - edge_dot) / maxf(1.0 - edge_dot, 0.000001), 0.0, 1.0)
	# A zero-angle cone still has full centering strength on its exact axis.
	if is_equal_approx(edge_dot, 1.0):
		centering = 1.0
	_set_detection(true, centering * (1.0 - distance / view_distance))


func _set_detection(in_view: bool, strength: float) -> void:
	var bounded_strength := clampf(strength, 0.0, 1.0) if in_view else 0.0
	var changed := player_in_view != in_view or not is_equal_approx(view_strength, bounded_strength)
	player_in_view = in_view
	view_strength = bounded_strength
	if changed:
		_update_debug_visual()
		detection_changed.emit(player_in_view, view_strength)


func _update_debug_visual() -> void:
	var draw_cone := debug_draw and is_active and player_in_view and view_distance > 0.0
	if not draw_cone:
		if is_instance_valid(_debug_visual):
			_debug_visual.visible = false
		return
	if not is_instance_valid(_debug_visual):
		_debug_visual = MeshInstance3D.new()
		_debug_visual.name = "DetectionDebugCone"
		_debug_mesh = ImmediateMesh.new()
		_debug_visual.mesh = _debug_mesh
		_debug_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.25, 1.0, 0.4)
		_debug_visual.material_override = material
		_head_node.add_child(_debug_visual)
	_debug_visual.layers = visual_layer_mask
	var dimensions := Vector2(view_distance, clampf(view_angle_degrees, 0.0, 89.0))
	if not dimensions.is_equal_approx(_debug_dimensions):
		_debug_dimensions = dimensions
		_debug_mesh.clear_surfaces()
		_debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		var angle := deg_to_rad(dimensions.y)
		var radius := dimensions.x * sin(angle)
		var depth := dimensions.x * cos(angle)
		for index in range(DEBUG_CONE_SEGMENTS):
			var azimuth := TAU * float(index) / DEBUG_CONE_SEGMENTS
			var next_azimuth := TAU * float(index + 1) / DEBUG_CONE_SEGMENTS
			var edge := Vector3(cos(azimuth) * radius, sin(azimuth) * radius, -depth)
			var next_edge := Vector3(cos(next_azimuth) * radius, sin(next_azimuth) * radius, -depth)
			_debug_mesh.surface_add_vertex(Vector3.ZERO)
			_debug_mesh.surface_add_vertex(edge)
			_debug_mesh.surface_add_vertex(edge)
			_debug_mesh.surface_add_vertex(next_edge)
		_debug_mesh.surface_add_vertex(Vector3.ZERO)
		_debug_mesh.surface_add_vertex(Vector3(0.0, 0.0, -dimensions.x))
		_debug_mesh.surface_end()
	_debug_visual.visible = true


func set_mount_type(type: MountType) -> void:
	mount_type = type
	_rebuild()


func set_active(active: bool) -> void:
	is_active = active
	_update_led()
	if not active:
		_set_detection(false, 0.0)
		_update_debug_visual()
	else:
		# Refresh immediately on reactivation, even before the next timed sample.
		_detection_elapsed = DETECTION_INTERVAL


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_debug_visual = null
	_debug_mesh = null
	_debug_dimensions = Vector2(-1.0, -1.0)
	_build_camera_visuals()
	_detection_elapsed = DETECTION_INTERVAL


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
	_update_head_rotation()

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
