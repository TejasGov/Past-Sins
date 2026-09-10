extends Node3D
class_name CentralYardGrounds

@export_flags_3d_render var visual_layer_mask: int = 1

const YARD_SURFACE := preload("res://materials/props/concrete.tres")
const COURT_MAT := preload("res://materials/props/court_surface.tres")
const FENCE_MAT := preload("res://materials/props/painted_metal.tres")
const SECURITY_DARK := preload("res://materials/props/security_dark.tres")
const YARD_GREEN := preload("res://materials/props/yard_green.tres")


func _ready() -> void:
	_build_yard()


func _build_yard() -> void:
	# 1. Compact 52m x 54m yard; all programmed recreation remains.
	_create_mesh("YardFloorSlab", Vector3(0, 0.005, 0), Vector3(52, 0.01, 54), YARD_SURFACE)

	# 2. Basketball Court Markings Surface
	_create_mesh("BasketballCourtPad", Vector3(-14, 0.01, 0), Vector3(16, 0.01, 24), COURT_MAT)

	# 3. Outdoor Exercise Area Pad
	_create_mesh("ExerciseEquipmentPad", Vector3(14, 0.01, -12), Vector3(16, 0.01, 16), SECURITY_DARK)

	# 4. Garden Plot
	_create_mesh("GardenPlotSurface", Vector3(14, 0.01, 12), Vector3(16, 0.01, 16), YARD_GREEN)

	# 5. Low-cost rectangular walking track loop. Four shallow strips make the
	# route readable without curves, decals, transparency, or added collision.
	_create_mesh("WalkingTrackNorth", Vector3(0, 0.018, -23.8), Vector3(46, 0.018, 2.5), COURT_MAT)
	_create_mesh("WalkingTrackSouth", Vector3(0, 0.018, 23.8), Vector3(46, 0.018, 2.5), COURT_MAT)
	_create_mesh("WalkingTrackWest", Vector3(-22.5, 0.018, 0), Vector3(2.5, 0.018, 50), COURT_MAT)
	_create_mesh("WalkingTrackEast", Vector3(22.5, 0.018, 0), Vector3(2.5, 0.018, 50), COURT_MAT)

	# 6. Yard Perimeter Security Fencing with Gated Openings
	_build_fence_enclosure()


func _build_fence_enclosure() -> void:
	var half_w := 26.0
	var half_d := 27.0
	var fence_h := 3.2
	var fence_t := 0.15

	# North Fence with central 4m gate opening at x = 0
	var n_side_w := (half_w * 2.0 - 4.0) * 0.5
	_create_fence_segment("NorthFenceWest", Vector3(-half_w + n_side_w * 0.5, fence_h * 0.5, -half_d), Vector3(n_side_w, fence_h, fence_t))
	_create_fence_segment("NorthFenceEast", Vector3(half_w - n_side_w * 0.5, fence_h * 0.5, -half_d), Vector3(n_side_w, fence_h, fence_t))
	_create_gate_posts("NorthGatePosts", Vector3(0, 0, -half_d), 4.0, fence_h)

	# South Fence with central 4m gate opening at x = 0
	var s_side_w := (half_w * 2.0 - 4.0) * 0.5
	_create_fence_segment("SouthFenceWest", Vector3(-half_w + s_side_w * 0.5, fence_h * 0.5, half_d), Vector3(s_side_w, fence_h, fence_t))
	_create_fence_segment("SouthFenceEast", Vector3(half_w - s_side_w * 0.5, fence_h * 0.5, half_d), Vector3(s_side_w, fence_h, fence_t))
	_create_gate_posts("SouthGatePosts", Vector3(0, 0, half_d), 4.0, fence_h)

	# West Fence (facing Cellhouse A) with 2 gate openings at z = 0 and z = 15
	_create_fence_segment("WestFenceNorth", Vector3(-half_w, fence_h * 0.5, -14.5), Vector3(fence_t, fence_h, 25.0))
	_create_fence_segment("WestFenceMid", Vector3(-half_w, fence_h * 0.5, 7.5), Vector3(fence_t, fence_h, 11.0))
	_create_fence_segment("WestFenceSouth", Vector3(-half_w, fence_h * 0.5, 22.0), Vector3(fence_t, fence_h, 10.0))
	_create_gate_posts("WestGateMain", Vector3(-half_w, 0, 0), 4.0, fence_h, true)
	_create_gate_posts("WestGateYard", Vector3(-half_w, 0, 15), 4.0, fence_h, true)

	# East Fence (facing Cellhouse B) with 1 gate opening at z = 0
	var e_side_d := (half_d * 2.0 - 4.0) * 0.5
	_create_fence_segment("EastFenceNorth", Vector3(half_w, fence_h * 0.5, -half_d + e_side_d * 0.5), Vector3(fence_t, fence_h, e_side_d))
	_create_fence_segment("EastFenceSouth", Vector3(half_w, fence_h * 0.5, half_d - e_side_d * 0.5), Vector3(fence_t, fence_h, e_side_d))
	_create_gate_posts("EastGateMain", Vector3(half_w, 0, 0), 4.0, fence_h, true)


func _create_fence_segment(seg_name: String, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = seg_name
	body.position = center

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Mesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = FENCE_MAT
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


func _create_gate_posts(gate_name: String, center: Vector3, width: float, height: float, along_z: bool = false) -> void:
	var root := Node3D.new()
	root.name = gate_name
	root.position = center
	add_child(root)

	var half_w := width * 0.5
	var post_a_pos := Vector3(0, height * 0.5, -half_w) if along_z else Vector3(-half_w, height * 0.5, 0)
	var post_b_pos := Vector3(0, height * 0.5, half_w) if along_z else Vector3(half_w, height * 0.5, 0)

	_create_mesh("PostA", post_a_pos, Vector3(0.2, height, 0.2), SECURITY_DARK, root)
	_create_mesh("PostB", post_b_pos, Vector3(0.2, height, 0.2), SECURITY_DARK, root)


func _create_mesh(part_name: String, center: Vector3, size: Vector3, material: Material, parent_node: Node3D = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	instance.mesh = box_mesh
	instance.material_override = material
	instance.position = center
	instance.layers = visual_layer_mask
	parent_node.add_child(instance)
	return instance
