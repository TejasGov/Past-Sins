extends RefCounted

## Consolidates static room dressing into one ArrayMesh per shared material.
## Original individual colliders, fixture roots, names and audit metadata remain.
static func consolidate(room: Node3D) -> void:
	var sources: Array[Dictionary] = []
	_collect(room, Transform3D.IDENTITY, sources)
	var groups: Dictionary = {}
	for entry in sources:
		var source: MeshInstance3D = entry.node
		for surface in range(source.mesh.get_surface_count()):
			var material: Material = source.material_override
			if not material:
				material = source.mesh.surface_get_material(surface)
			var automatic_light := source.is_in_group("campus_indoor_light_visuals")
			var key := "%s:%s" % [material.get_instance_id() if material else 0, "night" if automatic_light else "static"]
			if not groups.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tool.set_material(material)
				groups[key] = {"tool": tool, "automatic_light": automatic_light}
			var batch: SurfaceTool = groups[key].tool
			batch.append_from(source.mesh, surface, entry.transform)
	for key in groups:
		var visual := MeshInstance3D.new()
		visual.name = "BatchedFurniture_%s" % String(key).validate_node_name()
		var batch: SurfaceTool = groups[key].tool
		visual.mesh = batch.commit()
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		room.add_child(visual)
		if bool(groups[key].automatic_light):
			visual.add_to_group("campus_indoor_light_visuals")
			visual.set_meta("automatic_night_light", true)
	for entry in sources:
		var source: MeshInstance3D = entry.node
		source.free()
	room.set_meta("batched_material_count", groups.size())
	room.set_meta("source_mesh_count", sources.size())

static func _collect(node: Node3D, transform: Transform3D, result: Array[Dictionary]) -> void:
	# Camera props retain live references to their head/status meshes for their
	# public set_active/set_mount_type API, even when used as decoration.
	if node.is_in_group("cctv_cameras"):
		return
	for child in node.get_children():
		if not child is Node3D:
			continue
		var local: Transform3D = transform * child.transform
		if child is MeshInstance3D and child.mesh:
			result.append({"node": child, "transform": local})
		_collect(child, local, result)
