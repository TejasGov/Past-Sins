


extends RefCounted

const CCTV_CAMERA_SCENE := preload("res://scenes/props/security/CCTVCamera.tscn")
const METAL_DETECTOR_SCENE := preload("res://scenes/props/security/MetalDetector.tscn")

var _root: Node3D
var _collision_root: StaticBody3D
var _visual_layer_mask: int
var _materials: Dictionary = {}
var _emissive_materials: Dictionary = {}
var _box_meshes: Dictionary = {}


func _init(root: Node3D, visual_layer_mask := 1) -> void:
	_root = root
	_visual_layer_mask = visual_layer_mask
	_collision_root = StaticBody3D.new()
	_collision_root.name = "Collision"
	_root.add_child(_collision_root)


func box(piece_name: String, center: Vector3, size: Vector3, color: Color, collision := true) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = piece_name
	visual.mesh = _box_mesh(size)
	visual.position = center
	visual.material_override = _material(color)
	visual.layers = _visual_layer_mask
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(visual)
	if collision:
		_add_box_collision(center, size, Basis.IDENTITY)
	return visual


func oriented_box(piece_name: String, transform: Transform3D, size: Vector3, color: Color, collision := true) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = piece_name
	visual.mesh = _box_mesh(size)
	visual.transform = transform
	visual.material_override = _material(color)
	visual.layers = _visual_layer_mask
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(visual)
	if collision:
		_add_box_collision(transform.origin, size, transform.basis)
	return visual


func cylinder(piece_name: String, center: Vector3, radius: float, height: float, color: Color, collision := true, rotation := Vector3.ZERO) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = piece_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	visual.mesh = mesh
	visual.position = center
	visual.rotation = rotation
	visual.material_override = _material(color)
	visual.layers = _visual_layer_mask
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(visual)
	if collision:
		var shape_node := CollisionShape3D.new()
		shape_node.name = "Shape"
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		shape_node.shape = shape
		shape_node.position = center
		shape_node.rotation = rotation
		_collision_root.add_child(shape_node)
	return visual


func emissive_box(piece_name: String, center: Vector3, size: Vector3, color: Color, energy := 1.0) -> MeshInstance3D:
	var visual := box(piece_name, center, size, color.darkened(0.45), false)
	visual.material_override = _emissive_material(color, energy)
	return visual


func ceiling_light(piece_name: String, center: Vector3, color: Color, energy := 1.0, light_range := 7.0, fixture_size := Vector3(2.4, 0.08, 0.3)) -> OmniLight3D:
	# One unshadowed omni per fixture is cheap enough for the greybox and works in
	# the Compatibility renderer. The emissive mesh keeps the fixture readable
	# when it is outside the active per-object light budget.
	emissive_box("%sFixture" % piece_name, center, fixture_size, color, 0.85)
	# Floors are spaced four metres apart and the slab underside is at y=3.8.
	# Size each stem from the fixture top to that underside; this also supports
	# deliberately lower interrogation fixtures without leaving a visible gap.
	var fixture_top := center.y + fixture_size.y * 0.5
	var mount_height := maxf(0.12, 3.8 - fixture_top)
	var mount_center := fixture_top + mount_height * 0.5
	box("%sMount" % piece_name, Vector3(center.x, mount_center, center.z), Vector3(0.12, mount_height, 0.12), color.darkened(0.45), false)
	var light := OmniLight3D.new()
	light.name = piece_name
	light.position = center + Vector3.DOWN * 0.18
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 2.0
	light.light_cull_mask = _visual_layer_mask
	light.shadow_enabled = false
	_root.add_child(light)
	light.add_to_group("campus_indoor_lights")
	light.set_meta("automatic_night_light", true)
	return light


func supported_surface(piece_name: String, base_center: Vector3, top_size: Vector2, surface_height: float, top_thickness: float, surface_color: Color, support_color: Color) -> void:
	# Two inset pedestal frames give tables, counters, desks, and benches a clear
	# silhouette and useful knee space without the node cost of four detailed legs.
	var top := box("%sTop" % piece_name, base_center + Vector3.UP * (surface_height - top_thickness * 0.5), Vector3(top_size.x, top_thickness, top_size.y), surface_color)
	_tag_furniture(top, piece_name, "surface", false)
	var support_height := maxf(0.12, surface_height - top_thickness)
	var support_width := clampf(top_size.x * 0.07, 0.12, 0.2)
	var support_depth := maxf(0.18, top_size.y * 0.62)
	var support_offset := maxf(0.0, top_size.x * 0.5 - maxf(0.3, top_size.x * 0.2))
	for side in [-1.0, 1.0]:
		var support := box("%sSupport" % piece_name, base_center + Vector3(side * support_offset, support_height * 0.5, 0), Vector3(support_width, support_height, support_depth), support_color)
		_tag_furniture(support, piece_name, "support", true)


func prison_table_set(piece_name: String, base_center: Vector3, table_width: float, table_depth: float, bench_offset: float, surface_color: Color, frame_color: Color) -> void:
	# End-mounted steel plates support both benches and the tabletop. The open bay
	# between them leaves leg room for later seated prisoner NPCs.
	var table_height := 0.88
	var table_thickness := 0.16
	var seat_height := 0.54
	var seat_thickness := 0.16
	var bench_depth := 0.4
	var tabletop := box("%sTabletop" % piece_name, base_center + Vector3.UP * (table_height - table_thickness * 0.5), Vector3(table_width, table_thickness, table_depth), surface_color)
	_tag_furniture(tabletop, piece_name, "surface", false)
	for side in [-1.0, 1.0]:
		var seat := box("%sBenchSeat" % piece_name, base_center + Vector3(0, seat_height - seat_thickness * 0.5, side * bench_offset), Vector3(table_width, seat_thickness, bench_depth), surface_color.darkened(0.08))
		_tag_furniture(seat, piece_name, "seat", false)
	var frame_height := table_height - table_thickness
	var frame_span := bench_offset * 2.0 + bench_depth
	var frame_offset := maxf(0.35, table_width * 0.32)
	for side in [-1.0, 1.0]:
		var frame := box("%sSteelFrame" % piece_name, base_center + Vector3(side * frame_offset, frame_height * 0.5, 0), Vector3(0.14, frame_height, frame_span), frame_color)
		_tag_furniture(frame, piece_name, "support", true)


func prison_bunk(piece_name: String, base_center: Vector3, bed_size: Vector2, mattress_color: Color, frame_color: Color) -> void:
	var frame := box("%sFrame" % piece_name, base_center + Vector3.UP * 0.3, Vector3(bed_size.x, 0.12, bed_size.y), frame_color)
	_tag_furniture(frame, piece_name, "frame", false)
	var mattress := box("%sMattress" % piece_name, base_center + Vector3.UP * 0.46, Vector3(bed_size.x - 0.1, 0.2, bed_size.y - 0.1), mattress_color)
	_tag_furniture(mattress, piece_name, "surface", false)
	for side in [-1.0, 1.0]:
		var support := box("%sEndSupport" % piece_name, base_center + Vector3(0, 0.14, side * (bed_size.y * 0.5 - 0.08)), Vector3(bed_size.x, 0.28, 0.12), frame_color)
		_tag_furniture(support, piece_name, "support", true)


func storage_shelf(piece_name: String, base_center: Vector3, size: Vector3, color: Color) -> void:
	var upright_width := 0.12
	for side in [-1.0, 1.0]:
		var upright := box("%sUpright" % piece_name, base_center + Vector3(side * (size.x * 0.5 - upright_width * 0.5), size.y * 0.5, 0), Vector3(upright_width, size.y, size.z), color)
		_tag_furniture(upright, piece_name, "support", true)
	for ratio in [0.04, 0.36, 0.68, 0.96]:
		var shelf_y: float = clampf(size.y * ratio, 0.07, size.y - 0.07)
		var shelf := box("%sShelf" % piece_name, base_center + Vector3.UP * shelf_y, Vector3(size.x, 0.1, size.z), color.lightened(0.04))
		_tag_furniture(shelf, piece_name, "surface", false)


func simple_chair(piece_name: String, base_center: Vector3, color: Color, frame_color: Color) -> void:
	var seat := box("%sSeat" % piece_name, base_center + Vector3.UP * 0.5, Vector3(0.62, 0.12, 0.62), color)
	_tag_furniture(seat, piece_name, "seat", false)
	for side in [-1.0, 1.0]:
		var support := box("%sSideSupport" % piece_name, base_center + Vector3(side * 0.23, 0.22, 0), Vector3(0.1, 0.44, 0.48), frame_color)
		_tag_furniture(support, piece_name, "support", true)
	var back := box("%sBack" % piece_name, base_center + Vector3(0, 0.9, 0.27), Vector3(0.62, 0.78, 0.1), color)
	_tag_furniture(back, piece_name, "back", false)


func wall_segment(piece_name: String, base_center: Vector3, length: float, runs_along_x: bool, color: Color, height := 3.3, thickness := 0.22) -> MeshInstance3D:
	var size := Vector3(length, height, thickness) if runs_along_x else Vector3(thickness, height, length)
	return box(piece_name, base_center + Vector3.UP * (height * 0.5), size, color)


func room_divider(piece_name: String, base_center: Vector3, length: float, runs_along_x: bool, color: Color, height := 3.3, thickness := 0.22) -> MeshInstance3D:
	return wall_segment(piece_name, base_center, length, runs_along_x, color, height, thickness)


func partition_with_door(piece_name: String, base_center: Vector3, length: float, runs_along_x: bool, door_offset: float, door_width: float, color: Color, height := 3.3, door_height := 2.4, thickness := 0.22) -> void:
	var half_length := length * 0.5
	var half_door := minf(door_width * 0.5, half_length - 0.2)
	var opening_center := clampf(door_offset, -half_length + half_door + 0.1, half_length - half_door - 0.1)
	var opening_min := opening_center - half_door
	var opening_max := opening_center + half_door
	var first_length := opening_min + half_length
	var second_length := half_length - opening_max
	var axis := Vector3.RIGHT if runs_along_x else Vector3.BACK
	if first_length > 0.05:
		var first_offset := (-half_length + opening_min) * 0.5
		wall_segment("%sWallA" % piece_name, base_center + axis * first_offset, first_length, runs_along_x, color, height, thickness)
	if second_length > 0.05:
		var second_offset := (opening_max + half_length) * 0.5
		wall_segment("%sWallB" % piece_name, base_center + axis * second_offset, second_length, runs_along_x, color, height, thickness)
	var header_height := maxf(0.12, height - door_height)
	var header_center := base_center + axis * opening_center + Vector3.UP * (door_height + header_height * 0.5)
	var header_size := Vector3(door_width, header_height, thickness) if runs_along_x else Vector3(thickness, header_height, door_width)
	box("%sDoorHeader" % piece_name, header_center, header_size, color)


func door_frame(piece_name: String, base_center: Vector3, runs_along_x: bool, color: Color, door_width := 1.5, door_height := 2.4, frame_width := 0.14, depth := 0.3) -> void:
	var axis := Vector3.RIGHT if runs_along_x else Vector3.BACK
	var jamb_size := Vector3(frame_width, door_height, depth) if runs_along_x else Vector3(depth, door_height, frame_width)
	for side in [-1.0, 1.0]:
		box("%sJamb" % piece_name, base_center + axis * (side * (door_width + frame_width) * 0.5) + Vector3.UP * (door_height * 0.5), jamb_size, color)
	var header_size := Vector3(door_width + frame_width * 2.0, frame_width, depth) if runs_along_x else Vector3(depth, frame_width, door_width + frame_width * 2.0)
	box("%sHeader" % piece_name, base_center + Vector3.UP * (door_height + frame_width * 0.5), header_size, color)


func corridor_section(piece_name: String, base_center: Vector3, length: float, width: float, runs_along_z: bool, door_offset: float, door_width: float, color: Color, height := 3.3, thickness := 0.22) -> void:
	var side_axis := Vector3.RIGHT if runs_along_z else Vector3.BACK
	var walls_run_along_x := not runs_along_z
	for side in [-1.0, 1.0]:
		partition_with_door("%sSide%s" % [piece_name, "A" if side < 0.0 else "B"], base_center + side_axis * (width * 0.5), length, walls_run_along_x, door_offset, door_width, color, height, 2.4, thickness)


func security_gate(piece_name: String, base_center: Vector3, length: float, runs_along_x: bool, door_offset: float, door_width: float, color: Color, height := 2.8, spacing := 0.62) -> void:
	var axis := Vector3.RIGHT if runs_along_x else Vector3.BACK
	var half_length := length * 0.5
	var opening_center := clampf(door_offset, -half_length + door_width * 0.5, half_length - door_width * 0.5)
	var opening_min := opening_center - door_width * 0.5
	var opening_max := opening_center + door_width * 0.5
	var bar_size := Vector3(0.1, height, 0.18) if runs_along_x else Vector3(0.18, height, 0.1)
	var bar_position := -half_length + 0.12
	var index := 0
	while bar_position <= half_length - 0.12:
		if bar_position < opening_min - 0.05 or bar_position > opening_max + 0.05:
			box("%sBar%02d" % [piece_name, index], base_center + axis * bar_position + Vector3.UP * (height * 0.5), bar_size, color)
		index += 1
		bar_position += spacing
	var top_size := Vector3(length, 0.14, 0.22) if runs_along_x else Vector3(0.22, 0.14, length)
	box("%sTopRail" % piece_name, base_center + Vector3.UP * height, top_size, color)
	door_frame("%sOpening" % piece_name, base_center + axis * opening_center, runs_along_x, color, door_width, 2.4, 0.14, 0.26)


func sign(text: String, position: Vector3, rotation_degrees: Vector3, color := Color("b8c8ca"), pixel_size := 0.006) -> Label3D:
	var label := Label3D.new()
	label.name = ("Sign_%s" % text).validate_node_name()
	label.text = text
	label.position = position
	label.rotation_degrees = rotation_degrees
	label.font_size = 48
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 5
	label.no_depth_test = false
	label.layers = _visual_layer_mask
	_root.add_child(label)
	return label


func outer_walls(width: float, depth: float, height: float, color: Color) -> void:
	var y := height * 0.5
	box("NorthWall", Vector3(0, y, -depth * 0.5), Vector3(width, height, 0.3), color)
	box("SouthWall", Vector3(0, y, depth * 0.5), Vector3(width, height, 0.3), color)
	box("WestWall", Vector3(-width * 0.5, y, 0), Vector3(0.3, height, depth), color)
	box("EastWall", Vector3(width * 0.5, y, 0), Vector3(0.3, height, depth), color)


func floor_with_stairwell(width: float, depth: float, color: Color) -> void:
	# Leaves a 3 x 8 metre opening at x=12..15, z=12..20.
	var half_width := width * 0.5
	var half_depth := depth * 0.5
	var hole_min_x := half_width - 5.0
	var hole_max_x := half_width - 2.0
	var hole_min_z := half_depth - 9.0
	var hole_max_z := half_depth - 1.0
	var west_width := hole_min_x + half_width
	var east_width := half_width - hole_max_x
	box("FloorWest", Vector3(-half_width + west_width * 0.5, -0.2, 0), Vector3(west_width, 0.4, depth), color)
	box("FloorEast", Vector3(hole_max_x + east_width * 0.5, -0.2, 0), Vector3(east_width, 0.4, depth), color)
	box("FloorStairNorth", Vector3((hole_min_x + hole_max_x) * 0.5, -0.2, (-half_depth + hole_min_z) * 0.5), Vector3(hole_max_x - hole_min_x, 0.4, hole_min_z + half_depth), color)
	box("FloorStairSouth", Vector3((hole_min_x + hole_max_x) * 0.5, -0.2, (hole_max_z + half_depth) * 0.5), Vector3(hole_max_x - hole_min_x, 0.4, half_depth - hole_max_z), color)


func stairs(piece_name: String, start: Vector3, direction: Vector3, run: float, rise: float, width: float, steps := 16, color := Color("4a5256")) -> void:
	var travel := Vector3(direction.x, 0.0, direction.z).normalized()
	var step_depth := run / float(steps)
	var step_height := rise / float(steps)
	var yaw := atan2(travel.x, travel.z)
	for index in range(steps):
		# Thin metal treads avoid the enormous solid wedges produced by stacking
		# full-height boxes. Traversal still uses the single smooth ramp below.
		var tread_height := step_height * float(index + 1)
		var center := start + travel * (step_depth * (float(index) + 0.5)) + Vector3.UP * (tread_height - 0.06)
		var basis := Basis(Vector3.UP, yaw)
		oriented_box("%sStep%02d" % [piece_name, index], Transform3D(basis, center), Vector3(width, 0.12, step_depth + 0.025), color, false)

	# A single smooth collision ramp keeps the stairs reliable for CharacterBody3D.
	var slope_direction := (travel * run + Vector3.UP * rise).normalized()
	var right := Vector3.UP.cross(travel).normalized()
	var slope_up := slope_direction.cross(right).normalized()
	var ramp_basis := Basis(right, slope_up, slope_direction)
	var ramp_center := start + travel * (run * 0.5) + Vector3.UP * (rise * 0.5 - 0.06)
	_add_box_collision(ramp_center, Vector3(width, 0.12, sqrt(run * run + rise * rise)), ramp_basis)

	var side := right * (width * 0.5 - 0.06)
	bar_between("%sLeftRail" % piece_name, start + side + Vector3.UP, start + travel * run + side + Vector3.UP * (rise + 1.0), color)
	bar_between("%sRightRail" % piece_name, start - side + Vector3.UP, start + travel * run - side + Vector3.UP * (rise + 1.0), color)


func bridge_x(piece_name: String, z: float, half_span: float, width: float, color: Color) -> void:
	box(piece_name, Vector3(0, -0.08, z), Vector3(half_span * 2.0, 0.16, width), color)
	railing(Vector3(-half_span, 0, z - width * 0.5), Vector3(half_span, 0, z - width * 0.5), color, false)
	railing(Vector3(-half_span, 0, z + width * 0.5), Vector3(half_span, 0, z + width * 0.5), color, false)


func railing(start: Vector3, end: Vector3, color: Color, add_posts := true) -> void:
	bar_between("TopRail", start + Vector3.UP * 1.05, end + Vector3.UP * 1.05, color)
	bar_between("MidRail", start + Vector3.UP * 0.55, end + Vector3.UP * 0.55, color)
	if not add_posts:
		box("RailPostA", start + Vector3.UP * 0.525, Vector3(0.09, 1.05, 0.09), color)
		box("RailPostB", end + Vector3.UP * 0.525, Vector3(0.09, 1.05, 0.09), color)
		return
	var length := start.distance_to(end)
	var post_count := maxi(2, ceili(length / 3.0) + 1)
	for index in range(post_count):
		var point := start.lerp(end, float(index) / float(post_count - 1))
		box("RailPost", point + Vector3.UP * 0.525, Vector3(0.09, 1.05, 0.09), color)


func bar_between(piece_name: String, start: Vector3, end: Vector3, color: Color, thickness := 0.09) -> void:
	var delta := end - start
	if delta.length_squared() < 0.001:
		return
	var forward := delta.normalized()
	var right := Vector3.UP.cross(forward)
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var up := forward.cross(right).normalized()
	var basis := Basis(right, up, forward)
	oriented_box(piece_name, Transform3D(basis, (start + end) * 0.5), Vector3(thickness, thickness, delta.length()), color)


func _add_box_collision(center: Vector3, size: Vector3, basis: Basis) -> void:
	var shape_node := CollisionShape3D.new()
	shape_node.name = "Shape"
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.transform = Transform3D(basis, center)
	_collision_root.add_child(shape_node)


func _tag_furniture(part: MeshInstance3D, assembly_name: String, role: String, touches_floor: bool) -> void:
	part.set_meta("furniture_assembly", assembly_name)
	part.set_meta("furniture_role", role)
	part.set_meta("furniture_touches_floor", touches_floor)


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	_materials[key] = material
	return material


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var key := "%s:%0.2f" % [color.to_html(true), energy]
	if _emissive_materials.has(key):
		return _emissive_materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.45)
	material.roughness = 0.8
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	_emissive_materials[key] = material
	return material


func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "%0.3f,%0.3f,%0.3f" % [size.x, size.y, size.z]
	if _box_meshes.has(key):
		return _box_meshes[key] as BoxMesh
	var mesh := BoxMesh.new()
	mesh.size = size
	_box_meshes[key] = mesh
	return mesh


func cctv_camera(camera_name: String, position: Vector3, mount_type: int = 0, pan_deg: float = 0.0, tilt_deg: float = -20.0, root_yaw_deg: float = 0.0, pole_height: float = 3.4) -> CCTVCamera:
	var camera := CCTV_CAMERA_SCENE.instantiate() as CCTVCamera
	camera.name = camera_name
	camera.position = position
	camera.rotation_degrees.y = root_yaw_deg
	camera.mount_type = mount_type as CCTVCamera.MountType
	camera.pan_degrees = pan_deg
	camera.tilt_degrees = tilt_deg
	camera.pole_height = pole_height
	camera.visual_layer_mask = _visual_layer_mask
	_root.add_child(camera)
	return camera


func metal_detector(detector_name: String, position: Vector3, rotation_y_deg: float = 0.0) -> MetalDetector:
	var detector := METAL_DETECTOR_SCENE.instantiate() as MetalDetector
	detector.name = detector_name
	detector.position = position
	detector.rotation_degrees.y = rotation_y_deg
	detector.visual_layer_mask = _visual_layer_mask
	_root.add_child(detector)
	return detector


func server_rack(piece_name: String, center: Vector3, size := Vector3(0.9, 2.2, 0.95), color := Color("1c2225")) -> void:
	box(piece_name, center, size, color)
	box("%sGlassDoor" % piece_name, center + Vector3(0, 0, size.z * 0.5 + 0.01), Vector3(size.x - 0.1, size.y - 0.2, 0.02), Color("12242b"), false)
	for index in range(5):
		var y_off := -0.8 + float(index) * 0.4
		var led_color := Color("00ff66") if index % 2 == 0 else Color("ff9900")
		emissive_box("%sLED_%s" % [piece_name, index], center + Vector3(size.x * 0.38, y_off, size.z * 0.5 + 0.02), Vector3(0.04, 0.03, 0.02), led_color, 1.8)


func security_map_board(piece_name: String, position: Vector3, rotation_degrees: Vector3, size := Vector3(2.4, 1.4, 0.08)) -> void:
	var frame := box(piece_name, position, size, Color("202628"))
	frame.rotation_degrees = rotation_degrees
	var emissive_map := emissive_box("%sMapDisplay" % piece_name, position + Vector3(0, 0, 0.02), Vector3(size.x - 0.1, size.y - 0.1, 0.02), Color("0d332e"), 1.2)
	emissive_map.rotation_degrees = rotation_degrees
	self.sign("FACILITY SECURITY MAP", position + Vector3(0, size.y * 0.35, 0.06), rotation_degrees, Color("4ff0d0"), 0.004)


func monitor_wall_screen(piece_name: String, center: Vector3, size: Vector3, camera_label: String, screen_color := Color("183e42")) -> MeshInstance3D:
	box("%sFrame" % piece_name, center, Vector3(size.x + 0.08, size.y + 0.08, 0.1), Color("161a1c"))
	var display := emissive_box(piece_name, center + Vector3(0, 0, 0.05), size, screen_color, 0.95)
	if not camera_label.is_empty():
		self.sign(camera_label, center + Vector3(0, 0, 0.07), Vector3.ZERO, Color("76f5ff"), 0.0035)
	return display
