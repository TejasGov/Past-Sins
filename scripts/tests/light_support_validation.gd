extends Node

const MAIN_SCENE := preload("res://scenes/levels/CellBlockPrototype.tscn")


func _ready() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	var level := MAIN_SCENE.instantiate()
	add_child(level)
	await get_tree().process_frame

	var supported_interior_lights := 0
	for floor in level.get_node("Floors").get_children():
		for child in floor.get_children():
			if child is not OmniLight3D:
				continue
			var light := child as OmniLight3D
			if light.name.begins_with("YardLight_"):
				var suffix := light.name.trim_prefix("YardLight_")
				assert(floor.has_node("YardLightPole_%s" % suffix), "%s floats without a pole" % light.name)
				assert(floor.has_node("YardLightFixture_%s" % suffix), "%s floats without a fixture" % light.name)
				continue
			var fixture := floor.get_node_or_null("%sFixture" % light.name) as MeshInstance3D
			var mount := floor.get_node_or_null("%sMount" % light.name) as MeshInstance3D
			assert(fixture != null, "%s has no visible ceiling fixture" % light.name)
			assert(mount != null, "%s floats without a ceiling mount" % light.name)
			var fixture_box := fixture.mesh as BoxMesh
			var mount_box := mount.mesh as BoxMesh
			var fixture_top := fixture.position.y + fixture_box.size.y * 0.5
			var mount_bottom := mount.position.y - mount_box.size.y * 0.5
			var mount_top := mount.position.y + mount_box.size.y * 0.5
			assert(is_equal_approx(fixture_top, mount_bottom), "%s mount does not touch its fixture" % light.name)
			assert(is_equal_approx(mount_top, 3.8), "%s mount does not reach the overhead slab" % light.name)
			supported_interior_lights += 1
	assert(supported_interior_lights >= 20, "Too few interior fixtures were audited")
	print("LIGHT_SUPPORT_VALIDATION: PASS — %d interior fixtures plus all yard lights have physical supports" % supported_interior_lights)
	get_tree().quit(0)
