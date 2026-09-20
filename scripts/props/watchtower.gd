extends Node3D
class_name Watchtower

@export var tower_height: float = 7.0
@export var light_enabled: bool = false
@export var ladder_rotation_y: float = 0.0
@export var searchlight_yaw_degrees: float = 0.0
@export_range(20.0, 65.0, 1.0) var searchlight_depression_degrees := 32.0
@export_range(12.0, 35.0, 1.0) var searchlight_cone_degrees := 24.0
@export_range(15.0, 50.0, 1.0) var searchlight_range := 38.0
@export_flags_3d_render var visual_layer_mask: int = 1

const SECURITY_DARK := preload("res://materials/props/security_dark.tres")
const PAINTED_METAL := preload("res://materials/props/painted_metal.tres")
const CONCRETE_BASE := preload("res://materials/props/concrete.tres")
const STAINLESS_STEEL := preload("res://materials/props/stainless_steel.tres")
const HAZARD_YELLOW := preload("res://materials/props/hazard_yellow.tres")

var _searchlight_fixture: Node3D
var _spotlight_node: SpotLight3D
var _lens_material: StandardMaterial3D
var _searchlight_active := false


func _ready() -> void:
	add_to_group("watchtowers")
	add_to_group("campus_searchlight_fixtures")
	add_to_group("environmental_props")
	set_meta("prop_kind", "watchtower")
	if not has_meta("placement_zone"):
		set_meta("placement_zone", "Perimeter")
	_build_watchtower()


func _build_watchtower() -> void:
	# 1. Four Concrete Foundation Footings at ground
	var footing_offset := 1.75
	for fx in [-footing_offset, footing_offset]:
		for fz in [-footing_offset, footing_offset]:
			var footing := _create_box_with_col("Footing_%s_%s" % [fx, fz], Vector3(fx, 0.2, fz), Vector3(0.8, 0.4, 0.8), CONCRETE_BASE)
			add_child(footing)

	# 2. Four Heavy Steel Stilt Legs
	var leg_height := tower_height
	for lx in [-footing_offset, footing_offset]:
		for lz in [-footing_offset, footing_offset]:
			var leg := _create_box_with_col("Leg_%s_%s" % [lx, lz], Vector3(lx, leg_height * 0.5 + 0.2, lz), Vector3(0.24, leg_height, 0.24), SECURITY_DARK)
			add_child(leg)

	# 3. Cross Bracing Struts
	for level in [tower_height * 0.35, tower_height * 0.7]:
		var strut_n := _create_box("StrutN_%s" % level, Vector3(0, level, footing_offset), Vector3(footing_offset * 2, 0.12, 0.12), PAINTED_METAL)
		var strut_s := _create_box("StrutS_%s" % level, Vector3(0, level, -footing_offset), Vector3(footing_offset * 2, 0.12, 0.12), PAINTED_METAL)
		var strut_e := _create_box("StrutE_%s" % level, Vector3(footing_offset, level, 0), Vector3(0.12, 0.12, footing_offset * 2), PAINTED_METAL)
		var strut_w := _create_box("StrutW_%s" % level, Vector3(-footing_offset, level, 0), Vector3(0.12, 0.12, footing_offset * 2), PAINTED_METAL)
		add_child(strut_n)
		add_child(strut_s)
		add_child(strut_e)
		add_child(strut_w)

	# 4. Elevated Cabin Deck Platform
	var deck_y := tower_height + 0.2
	var platform := _create_box_with_col("DeckPlatform", Vector3(0, deck_y, 0), Vector3(4.5, 0.25, 4.5), SECURITY_DARK)
	add_child(platform)

	# Deck Edge Safety Railing
	_build_deck_railings(deck_y + 0.125)

	# 5. Enclosed Guard Observation Cabin
	var cabin_y := deck_y + 0.25 + 1.25
	var cabin_body := _create_octagonal_with_col("CabinBody", Vector3(0, cabin_y, 0), 1.75, 2.5, PAINTED_METAL)
	add_child(cabin_body)

	# Observation Slits (Dark Glass look on all 4 sides)
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color("102028")
	glass_mat.metallic = 0.9
	glass_mat.roughness = 0.1
	glass_mat.uv1_triplanar = true
	glass_mat.uv1_scale = Vector3.ONE * 0.5
	for angle in [0, 90, 180, 270]:
		var radians := deg_to_rad(float(angle))
		var slit_position := Vector3(sin(radians) * 1.61, cabin_y + 0.3, cos(radians) * 1.61)
		var slit := _create_box("ObservationSlit_%d" % angle, slit_position, Vector3(2.4, 0.65, 0.05), glass_mat, Vector3(0, radians, 0))
		add_child(slit)

	# 6. Cabin Roof with Overhang
	var roof_y := cabin_y + 1.35
	var roof := _create_box_with_col("CabinRoof", Vector3(0, roof_y, 0), Vector3(3.8, 0.2, 3.8), SECURITY_DARK)
	add_child(roof)
	_build_cabin_details(cabin_y, roof_y)

	# 7. Access Ladder / Cage
	_build_ladder(ladder_rotation_y, tower_height)

	# 8. Roof Searchlight Fixture
	_build_searchlight(roof_y + 0.1)


func _build_cabin_details(cabin_y: float, roof_y: float) -> void:
	# Low-cost silhouette detail: a supported operator shelf is visible through
	# the front slit, while the aerial is visibly fixed to the cabin roof.
	var console := _create_box("OperatorConsole", Vector3(0, cabin_y - 0.72, -1.38), Vector3(1.7, 0.16, 0.5), SECURITY_DARK)
	add_child(console)
	for x in [-0.68, 0.68]:
		var support := _create_box("ConsoleSupport%s" % x, Vector3(x, cabin_y - 1.05, -1.38), Vector3(0.1, 0.66, 0.1), PAINTED_METAL)
		add_child(support)
	for x in [-0.48, 0.0, 0.48]:
		var screen := _create_box("ObservationMonitor%s" % x, Vector3(x, cabin_y - 0.42, -1.33), Vector3(0.4, 0.32, 0.06), SECURITY_DARK, Vector3(deg_to_rad(-8), 0, 0))
		add_child(screen)
	var aerial_base := _create_cylinder("AerialBase", Vector3(0.95, roof_y + 0.17, 0.7), 0.11, 0.24, PAINTED_METAL)
	add_child(aerial_base)
	var aerial := _create_cylinder("RadioAerial", Vector3(0.95, roof_y + 0.92, 0.7), 0.025, 1.5, SECURITY_DARK)
	add_child(aerial)
	for y in [roof_y + 0.55, roof_y + 1.05]:
		var radial := _create_box("AerialCrossbar%s" % y, Vector3(0.95, y, 0.7), Vector3(0.65, 0.035, 0.035), STAINLESS_STEEL)
		add_child(radial)


func _build_deck_railings(deck_top_y: float) -> void:
	var rail_height := 1.05
	var half_w := 2.2
	for angle in [0, 90, 180, 270]:
		var rot := Vector3(0, deg_to_rad(float(angle)), 0)
		var top_rail := _create_box("RailingTop_%d" % angle, Vector3(0, deck_top_y + rail_height, half_w).rotated(Vector3.UP, rot.y), Vector3(4.4, 0.06, 0.06), PAINTED_METAL, rot)
		var mid_rail := _create_box("RailingMid_%d" % angle, Vector3(0, deck_top_y + rail_height * 0.5, half_w).rotated(Vector3.UP, rot.y), Vector3(4.4, 0.04, 0.04), PAINTED_METAL, rot)
		add_child(top_rail)
		add_child(mid_rail)
		for px in [-2.1, 0, 2.1]:
			var post := _create_box("RailPost_%d_%s" % [angle, px], Vector3(px, deck_top_y + rail_height * 0.5, half_w).rotated(Vector3.UP, rot.y), Vector3(0.06, rail_height, 0.06), PAINTED_METAL, rot)
			add_child(post)


func _build_ladder(rot_deg: float, height: float) -> void:
	var ladder_root := Node3D.new()
	ladder_root.name = "AccessLadder"
	ladder_root.rotation_degrees.y = rot_deg
	add_child(ladder_root)

	var ladder_z := 1.75
	var stringer_l := _create_box("LadderStringerL", Vector3(-0.25, height * 0.5, ladder_z), Vector3(0.05, height, 0.08), SECURITY_DARK)
	var stringer_r := _create_box("LadderStringerR", Vector3(0.25, height * 0.5, ladder_z), Vector3(0.05, height, 0.08), SECURITY_DARK)
	ladder_root.add_child(stringer_l)
	ladder_root.add_child(stringer_r)

	var rung_count := int(height / 0.35)
	for i in range(rung_count):
		var rung_y := 0.35 * (i + 1)
		var rung := _create_box("Rung_%02d" % i, Vector3(0, rung_y, ladder_z), Vector3(0.46, 0.035, 0.035), STAINLESS_STEEL)
		ladder_root.add_child(rung)

	# Safety cage rings on upper portion
	for i in range(int(rung_count * 0.4), rung_count):
		var ring_y := 0.35 * (i + 1)
		var cage := _create_box("CageRing_%02d" % i, Vector3(0, ring_y, ladder_z + 0.35), Vector3(0.75, 0.03, 0.7), HAZARD_YELLOW)
		ladder_root.add_child(cage)


func _build_searchlight(base_y: float) -> void:
	_searchlight_fixture = Node3D.new()
	_searchlight_fixture.name = "SearchlightFixture"
	var yaw := deg_to_rad(searchlight_yaw_degrees)
	var forward := Vector3(sin(yaw), 0, cos(yaw))
	# Seat the pedestal on the roof edge, with its lens just past the overhang.
	# A centrally mounted downward beam otherwise hits its own opaque roof.
	var edge_distance := 1.9 / maxf(absf(forward.x), absf(forward.z)) - 0.12
	_searchlight_fixture.position = forward * edge_distance + Vector3(0, base_y, 0)
	_searchlight_fixture.rotation_degrees.y = searchlight_yaw_degrees
	add_child(_searchlight_fixture)

	var pedestal := _create_cylinder("Pedestal", Vector3(0, 0.15, 0), 0.12, 0.3, SECURITY_DARK)
	_searchlight_fixture.add_child(pedestal)

	# Lens, housing and actual beam share one downward-facing gimbal. Godot
	# spotlights emit along -Z; this prop's lens faces +Z. Keeping that explicit
	# prevents the old horizontal/backward beam from lighting the sky/roof.
	var gimbal := Node3D.new()
	gimbal.name = "LampGimbal"
	gimbal.position.y = 0.45
	gimbal.rotation_degrees.x = searchlight_depression_degrees
	_searchlight_fixture.add_child(gimbal)
	var housing := _create_box("LampHousing", Vector3.ZERO, Vector3(0.45, 0.45, 0.55), PAINTED_METAL)
	gimbal.add_child(housing)

	_lens_material = StandardMaterial3D.new()
	_lens_material.albedo_color = Color("c8c0a3")
	_lens_material.emission_enabled = true
	_lens_material.emission = Color("ffe2aa")
	_lens_material.emission_energy_multiplier = 0.15
	_lens_material.uv1_triplanar = true
	_lens_material.uv1_scale = Vector3.ONE * 0.5
	var lens := _create_cylinder("LampLens", Vector3(0, 0, 0.28), 0.18, 0.04, _lens_material, Vector3(deg_to_rad(90), 0, 0))
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gimbal.add_child(lens)

	if light_enabled:
		_spotlight_node = SpotLight3D.new()
		_spotlight_node.name = "SearchlightBeam"
		_spotlight_node.position = Vector3(0, 0, 0.32)
		_spotlight_node.rotation.y = PI
		_spotlight_node.light_color = Color("ffe1ac")
		_spotlight_node.light_energy = 5.0
		_spotlight_node.spot_range = searchlight_range
		_spotlight_node.spot_angle = searchlight_cone_degrees
		_spotlight_node.spot_attenuation = 0.6
		_spotlight_node.spot_angle_attenuation = 1.5
		_spotlight_node.shadow_enabled = true
		_spotlight_node.shadow_bias = 0.035
		_spotlight_node.add_to_group("campus_security_floodlights")
		_spotlight_node.light_cull_mask = visual_layer_mask
		_spotlight_node.visible = false
		gimbal.add_child(_spotlight_node)


func set_searchlight_active(active: bool) -> void:
	_searchlight_active = active
	if _spotlight_node:
		_spotlight_node.visible = active
	if _lens_material:
		# Every tower reads as staffed after dark; only designated fixtures own a
		# real SpotLight3D, preserving the campus Web lighting budget.
		_lens_material.emission_energy_multiplier = 2.4 if active and light_enabled else (0.4 if active else 0.0)

func set_searchlight_shadow_enabled(enabled: bool) -> void:
	## The beam remains visible on every staffed tower, but only the nearest
	## exterior tower needs a real shadow map. Interior views keep these remote
	## floodlights lit without paying for shadow passes through the whole campus.
	if _spotlight_node:
		_spotlight_node.shadow_enabled = enabled


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


func _create_box_with_col(part_name: String, center: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = part_name
	body.position = center

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Visual"
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = material
	mesh_inst.layers = visual_layer_mask
	body.add_child(mesh_inst)

	var shape_inst := CollisionShape3D.new()
	shape_inst.name = "Collision"
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape_inst.shape = box_shape
	body.add_child(shape_inst)

	return body


func _create_octagonal_with_col(part_name: String, center: Vector3, radius: float, height: float, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = part_name
	body.position = center

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Visual"
	var cabin_mesh := CylinderMesh.new()
	cabin_mesh.top_radius = radius
	cabin_mesh.bottom_radius = radius
	cabin_mesh.height = height
	cabin_mesh.radial_segments = 8
	mesh_inst.mesh = cabin_mesh
	mesh_inst.material_override = material
	mesh_inst.layers = visual_layer_mask
	body.add_child(mesh_inst)

	var shape_inst := CollisionShape3D.new()
	shape_inst.name = "Collision"
	var cabin_shape := CylinderShape3D.new()
	cabin_shape.radius = radius
	cabin_shape.height = height
	shape_inst.shape = cabin_shape
	body.add_child(shape_inst)

	return body
