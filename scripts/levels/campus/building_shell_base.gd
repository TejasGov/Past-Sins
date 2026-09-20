extends Node3D
class_name BuildingShellBase

@export var building_title: String = "BUILDING"
@export var footprint_size: Vector3 = Vector3(30, 6, 30)
@export_flags_3d_render var visual_layer_mask: int = 1
@export var campus_blueprints_enabled := false

const CONCRETE_WALL := preload("res://materials/props/concrete.tres")
const SECURITY_DARK := preload("res://materials/props/security_dark.tres")
const PAINTED_METAL := preload("res://materials/props/painted_metal.tres")
const HAZARD_YELLOW := preload("res://materials/props/hazard_yellow.tres")


func _ready() -> void:
	add_to_group("campus_buildings")
	_build_shell()
	set_meta("building_title", building_title)
	set_meta("footprint_size", footprint_size)


func _build_shell() -> void:
	# Virtual method to be overridden by subclasses
	pass


func create_sealed_box_shell(width: float, height: float, depth: float, wall_thickness: float = 0.4, wall_mat: Material = CONCRETE_WALL, roof_mat: Material = SECURITY_DARK) -> void:
	create_shell_with_openings(width, height, depth, [], wall_thickness, wall_mat, roof_mat)


## Creates collision-backed walls with real openings rather than placing a
## decorative doorway over a continuous invisible wall. Each opening contains:
## side (north/south/east/west), offset, width, height, name, and label.
func create_shell_with_openings(width: float, height: float, depth: float, openings: Array[Dictionary], wall_thickness: float = 0.4, wall_mat: Material = CONCRETE_WALL, roof_mat: Material = SECURITY_DARK) -> void:
	footprint_size = Vector3(width, height, depth)
	var by_side := {"north": [], "south": [], "west": [], "east": []}
	for opening in openings:
		var side := String(opening.get("side", "")).to_lower()
		assert(by_side.has(side), "Unknown building-shell side: %s" % side)
		(by_side[side] as Array).append(opening)

	_build_wall_side("North", width, height, wall_thickness, -depth * 0.5 + wall_thickness * 0.5, true, by_side["north"], wall_mat)
	_build_wall_side("South", width, height, wall_thickness, depth * 0.5 - wall_thickness * 0.5, true, by_side["south"], wall_mat)
	_build_wall_side("West", depth, height, wall_thickness, -width * 0.5 + wall_thickness * 0.5, false, by_side["west"], wall_mat)
	_build_wall_side("East", depth, height, wall_thickness, width * 0.5 - wall_thickness * 0.5, false, by_side["east"], wall_mat)

	_create_box_col("RoofSlab", Vector3(0, height + 0.15, 0), Vector3(width + 0.6, 0.3, depth + 0.6), roof_mat)
	for opening in openings:
		var side := String(opening["side"]).to_lower()
		var offset := float(opening.get("offset", 0.0))
		var position := Vector3(offset, 0, -depth * 0.5) if side == "north" else Vector3(offset, 0, depth * 0.5)
		if side == "west":
			position = Vector3(-width * 0.5, 0, offset)
		elif side == "east":
			position = Vector3(width * 0.5, 0, offset)
		create_doorway_threshold(
			String(opening["name"]), position, float(opening["width"]),
			float(opening["height"]), wall_thickness, side in ["north", "south"],
			String(opening.get("label", ""))
		)


func _build_wall_side(side_name: String, length: float, height: float, thickness: float, fixed_axis: float, along_x: bool, openings: Array, material: Material) -> void:
	openings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("offset", 0.0)) < float(b.get("offset", 0.0)))
	var cursor := -length * 0.5
	var piece_index := 0
	for opening in openings:
		var opening_width := float(opening["width"])
		var opening_height := float(opening["height"])
		var opening_center := float(opening.get("offset", 0.0))
		var opening_start := clampf(opening_center - opening_width * 0.5, -length * 0.5, length * 0.5)
		var opening_end := clampf(opening_center + opening_width * 0.5, -length * 0.5, length * 0.5)
		assert(opening_start >= cursor, "%s wall door openings overlap" % side_name)
		if opening_start - cursor > 0.01:
			_create_wall_piece("%sWallSegment%02d" % [side_name, piece_index], cursor, opening_start, height, thickness, fixed_axis, along_x, material)
			piece_index += 1
		var header_height := height - opening_height
		if header_height > 0.01:
			var header_center := Vector3(opening_center, opening_height + header_height * 0.5, fixed_axis) if along_x else Vector3(fixed_axis, opening_height + header_height * 0.5, opening_center)
			var header_size := Vector3(opening_end - opening_start, header_height, thickness) if along_x else Vector3(thickness, header_height, opening_end - opening_start)
			_create_box_col("%sDoorHeader%02d" % [side_name, piece_index], header_center, header_size, material)
			piece_index += 1
		cursor = opening_end
	if length * 0.5 - cursor > 0.01:
		_create_wall_piece("%sWallSegment%02d" % [side_name, piece_index], cursor, length * 0.5, height, thickness, fixed_axis, along_x, material)


func _create_wall_piece(piece_name: String, start: float, finish: float, height: float, thickness: float, fixed_axis: float, along_x: bool, material: Material) -> void:
	var center_axis := (start + finish) * 0.5
	var center := Vector3(center_axis, height * 0.5, fixed_axis) if along_x else Vector3(fixed_axis, height * 0.5, center_axis)
	var size := Vector3(finish - start, height, thickness) if along_x else Vector3(thickness, height, finish - start)
	_create_box_col(piece_name, center, size, material)


func create_doorway_threshold(door_name: String, position: Vector3, width: float, height: float, depth: float, is_along_x: bool, sign_label: String = "") -> void:
	var root := Node3D.new()
	root.name = door_name
	root.position = position
	root.set_meta("placeholder_entrance", true)
	root.set_meta("opening_width", width)
	root.set_meta("opening_height", height)
	add_child(root)

	var frame_t := 0.15
	var post_w := 0.2
	var half_w := width * 0.5

	# Left/Right Frame Posts
	var post_l_pos := Vector3(-half_w - post_w * 0.5, height * 0.5, 0) if is_along_x else Vector3(0, height * 0.5, -half_w - post_w * 0.5)
	var post_r_pos := Vector3(half_w + post_w * 0.5, height * 0.5, 0) if is_along_x else Vector3(0, height * 0.5, half_w + post_w * 0.5)
	var post_size := Vector3(post_w, height, depth + 0.1) if is_along_x else Vector3(depth + 0.1, height, post_w)

	_create_box_col("FramePostL", post_l_pos, post_size, PAINTED_METAL, root)
	_create_box_col("FramePostR", post_r_pos, post_size, PAINTED_METAL, root)

	# Lintel / Header
	var header_pos := Vector3(0, height + 0.15, 0)
	var header_size := Vector3(width + post_w * 2.0, 0.3, depth + 0.12) if is_along_x else Vector3(depth + 0.12, 0.3, width + post_w * 2.0)
	_create_box_col("FrameHeader", header_pos, header_size, PAINTED_METAL, root)

	# Sealed Collision-Backed Placeholder Door
	var door_size := Vector3(width, height, 0.12) if is_along_x else Vector3(0.12, height, width)
	var door := _create_box_col("PlaceholderDoor", Vector3(0, height * 0.5, 0), door_size, SECURITY_DARK, root)
	door.set_meta("temporary_placeholder", true)

	# Identification Sign above door
	if not sign_label.is_empty():
		var sign_pos := Vector3(0, height + 0.45, (depth * 0.5 + 0.08) * (1.0 if is_along_x else 0.0)) if is_along_x else Vector3((depth * 0.5 + 0.08), height + 0.45, 0)
		var sign_rot := Vector3.ZERO if is_along_x else Vector3(0, 90, 0)
		_create_sign(door_name + "Sign", root, sign_pos, sign_label, sign_rot)


func create_migration_anchor(anchor_name: String, position: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = anchor_name
	marker.position = position
	add_child(marker)
	return marker


func _create_sign(sign_name: String, parent_node: Node3D, pos: Vector3, text: String, rot_deg: Vector3) -> void:
	var label := Label3D.new()
	label.double_sided = false
	label.name = sign_name
	label.text = text
	label.position = pos
	label.rotation_degrees = rot_deg
	label.font_size = 32
	label.pixel_size = 0.005
	label.modulate = Color("e0d5a8")
	label.outline_modulate = Color("151a1c")
	label.outline_size = 4
	label.layers = visual_layer_mask
	parent_node.add_child(label)


func _create_box_col(part_name: String, center: Vector3, size: Vector3, material: Material, parent_node: Node3D = self) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = part_name
	body.position = center

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Mesh"
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

	parent_node.add_child(body)
	return body
