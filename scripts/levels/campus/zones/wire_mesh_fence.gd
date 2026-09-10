extends Node3D

## A ground-origin, local-X fence panel. One instanced box mesh renders all
## welded wires and uprights; one thin collision panel prevents squeezing.
@export_range(0.3, 70.0, 0.1) var length := 3.0
@export_range(1.2, 5.0, 0.1) var height := 3.2
@export_flags_3d_render var visual_layer_mask := 1

const METAL := preload("res://materials/props/painted_metal.tres")


func _ready() -> void:
	add_to_group("campus_mesh_fences")
	var transforms: Array[Transform3D] = []
	var posts := maxi(1, ceili(length / 3.0))
	for index in range(posts + 1):
		var x := lerpf(-length * 0.5, length * 0.5, float(index) / posts)
		transforms.append(_part(Vector3(x, height * 0.5, 0), Vector3(0.08, height, 0.08)))
	var wires := maxi(1, ceili(length / 0.4))
	for index in range(wires + 1):
		var x := lerpf(-length * 0.5, length * 0.5, float(index) / wires)
		transforms.append(_part(Vector3(x, height * 0.5, 0), Vector3(0.018, height, 0.024)))
	var courses := ceili(height / 0.4)
	for index in range(courses + 1):
		var y := lerpf(0.04, height - 0.04, float(index) / courses)
		transforms.append(_part(Vector3(0, y, 0), Vector3(length, 0.018, 0.024)))
	for y in [0.08, height - 0.04]:
		transforms.append(_part(Vector3(0, y, 0), Vector3(length, 0.045, 0.055)))
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for index in range(transforms.size()):
		batch.set_instance_transform(index, transforms[index])
	var visual := MultiMeshInstance3D.new()
	visual.name = "WeldedWireAndPosts"
	visual.multimesh = batch
	visual.material_override = METAL
	visual.layers = visual_layer_mask
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	var body := StaticBody3D.new()
	body.name = "FenceCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = "Panel"
	var shape := BoxShape3D.new()
	shape.size = Vector3(length + 0.08, height, 0.08)
	collision.shape = shape
	collision.position.y = height * 0.5
	body.add_child(collision)
	add_child(body)


func _part(center: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY.scaled(size), center)
