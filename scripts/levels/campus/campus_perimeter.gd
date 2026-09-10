extends Node3D
class_name CampusPerimeter

@export_flags_3d_render var visual_layer_mask: int = 1

const CONCRETE_WALL := preload("res://materials/props/concrete.tres")
const SECURITY_DARK := preload("res://materials/props/security_dark.tres")
const PAINTED_METAL := preload("res://materials/props/painted_metal.tres")


func _ready() -> void:
	_build_perimeter()


func _build_perimeter() -> void:
	var half_w := 78.0
	var half_d := 94.0
	var wall_h := 5.2
	var wall_t := 0.6
	var wall_y := wall_h * 0.5

	# 1. West Wall (continuous)
	_create_wall("WestPerimeterWall", Vector3(-half_w, wall_y, 0), Vector3(wall_t, wall_h, half_d * 2.0))

	# 2. East Wall (continuous)
	_create_wall("EastPerimeterWall", Vector3(half_w, wall_y, 0), Vector3(wall_t, wall_h, half_d * 2.0))

	# 3. North Wall with Service Sally Port opening (width 10m at center)
	var n_segment_w := (half_w * 2.0 - 10.0) * 0.5
	_create_wall("NorthWallWest", Vector3(-half_w + n_segment_w * 0.5, wall_y, -half_d), Vector3(n_segment_w, wall_h, wall_t))
	_create_wall("NorthWallEast", Vector3(half_w - n_segment_w * 0.5, wall_y, -half_d), Vector3(n_segment_w, wall_h, wall_t))
	_build_sally_port("NorthServiceSallyPort", Vector3(0, 0, -half_d), Vector3(10.0, wall_h, 8.0), "NORTH SERVICE SALLY PORT")

	# 4. South Wall with Main Vehicle Sally Port opening (width 12m at center)
	var s_segment_w := (half_w * 2.0 - 12.0) * 0.5
	_create_wall("SouthWallWest", Vector3(-half_w + s_segment_w * 0.5, wall_y, half_d), Vector3(s_segment_w, wall_h, wall_t))
	_create_wall("SouthWallEast", Vector3(half_w - s_segment_w * 0.5, wall_y, half_d), Vector3(s_segment_w, wall_h, wall_t))
	_build_sally_port("SouthMainSallyPort", Vector3(0, 0, half_d), Vector3(12.0, wall_h, 10.0), "MAIN SECURE VEHICLE SALLY PORT")

	# 5. Anti-Climb Fence Headers along all perimeter walls
	_build_fence_tops(half_w, half_d, wall_h)


func _create_wall(wall_name: String, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = wall_name
	body.position = center

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Mesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = CONCRETE_WALL
	mesh_inst.layers = visual_layer_mask
	body.add_child(mesh_inst)

	var shape_inst := CollisionShape3D.new()
	shape_inst.name = "Collision"
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape_inst.shape = box_shape
	body.add_child(shape_inst)

	add_child(body)
	return body


func _build_sally_port(port_name: String, center: Vector3, size: Vector3, sign_text: String) -> void:
	var root := Node3D.new()
	root.name = port_name
	root.position = center
	add_child(root)

	# Left and Right Gatehouse Piers
	var pier_w := 1.2
	var pier_left := _create_box_col("PierLeft", Vector3(-size.x * 0.5 + pier_w * 0.5, size.y * 0.5, 0), Vector3(pier_w, size.y, size.z), CONCRETE_WALL)
	var pier_right := _create_box_col("PierRight", Vector3(size.x * 0.5 - pier_w * 0.5, size.y * 0.5, 0), Vector3(pier_w, size.y, size.z), CONCRETE_WALL)
	root.add_child(pier_left)
	root.add_child(pier_right)

	# Overhead Heavy Concrete Lintel / Header
	var header := _create_box_col("Header", Vector3(0, size.y - 0.5, 0), Vector3(size.x, 1.0, size.z), CONCRETE_WALL)
	root.add_child(header)

	# Closed Heavy Security Sally Port Gates (Collision-backed placeholder)
	var gate_thickness := 0.25
	var gate_w := size.x - pier_w * 2.0
	var gate_outer := _create_box_col("OuterBarrierGate", Vector3(0, (size.y - 1.0) * 0.5, -size.z * 0.45), Vector3(gate_w, size.y - 1.0, gate_thickness), SECURITY_DARK)
	var gate_inner := _create_box_col("InnerBarrierGate", Vector3(0, (size.y - 1.0) * 0.5, size.z * 0.45), Vector3(gate_w, size.y - 1.0, gate_thickness), SECURITY_DARK)
	root.add_child(gate_outer)
	root.add_child(gate_inner)
	# Keep the compound sealed, but communicate a real controlled vehicle
	# shutter rather than an unexplained featureless black wall.
	for gate in [gate_outer, gate_inner]:
		gate.get_node("Mesh").visible = false
		var detail := preload("res://scenes/props/common/InstitutionalDoorVisual.tscn").instantiate()
		detail.position.y = -(size.y - 1.0) * 0.5
		detail.set("width", gate_w)
		detail.set("height", size.y - 1.0)
		detail.set("thickness", gate_thickness)
		detail.set("style", 2)
		detail.set("caption", "VEHICLE SALLY PORT\nGATEHOUSE CONTROL / SEALED")
		gate.add_child(detail)

	# Small Guard Sentry Booth attached to one pier
	var booth := _create_box_col("GuardBooth", Vector3(size.x * 0.5 + 1.5, 1.5, 0), Vector3(2.2, 3.0, 3.0), PAINTED_METAL)
	root.add_child(booth)


func _build_fence_tops(half_w: float, half_d: float, base_h: float) -> void:
	var post_h := 1.0
	var post_mat := PAINTED_METAL
	var y_pos := base_h + post_h * 0.5

	# Posts along North and South
	for x in range(-int(half_w), int(half_w) + 1, 6):
		var post_n := _create_mesh("FencePostN_%d" % x, Vector3(float(x), y_pos, -half_d), Vector3(0.08, post_h, 0.08), post_mat)
		var post_s := _create_mesh("FencePostS_%d" % x, Vector3(float(x), y_pos, half_d), Vector3(0.08, post_h, 0.08), post_mat)
		add_child(post_n)
		add_child(post_s)

	# Posts along West and East
	for z in range(-int(half_d), int(half_d) + 1, 6):
		var post_w := _create_mesh("FencePostW_%d" % z, Vector3(-half_w, y_pos, float(z)), Vector3(0.08, post_h, 0.08), post_mat)
		var post_e := _create_mesh("FencePostE_%d" % z, Vector3(half_w, y_pos, float(z)), Vector3(0.08, post_h, 0.08), post_mat)
		add_child(post_w)
		add_child(post_e)

	# Three continuous anti-climb rails make the header readable from a distance
	# for only twelve extra meshes.
	for index in range(3):
		var rail_y := base_h + 0.25 + float(index) * 0.32
		add_child(_create_mesh("FenceRailNorth%02d" % index, Vector3(0, rail_y, -half_d), Vector3(half_w * 2.0, 0.04, 0.04), post_mat))
		add_child(_create_mesh("FenceRailSouth%02d" % index, Vector3(0, rail_y, half_d), Vector3(half_w * 2.0, 0.04, 0.04), post_mat))
		add_child(_create_mesh("FenceRailWest%02d" % index, Vector3(-half_w, rail_y, 0), Vector3(0.04, 0.04, half_d * 2.0), post_mat))
		add_child(_create_mesh("FenceRailEast%02d" % index, Vector3(half_w, rail_y, 0), Vector3(0.04, 0.04, half_d * 2.0), post_mat))


func _create_box_col(part_name: String, center: Vector3, size: Vector3, material: Material) -> StaticBody3D:
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

	return body


func _create_mesh(part_name: String, center: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	instance.mesh = box_mesh
	instance.material_override = material
	instance.position = center
	instance.layers = visual_layer_mask
	return instance
