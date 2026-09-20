extends SceneTree


func _initialize() -> void:
	if OS.get_cmdline_user_args().is_empty():
		push_error("Usage: -- <res://scene>")
		quit(2)
		return
	var path := OS.get_cmdline_user_args()[0]
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Unable to load %s" % path)
		quit(3)
		return
	var root := packed.instantiate()
	print("SCENE ", path)
	_print_tree(root, "")
	root.free()
	quit()


func _print_tree(node: Node, indent: String) -> void:
	var extra := ""
	if node is Skeleton3D:
		var skeleton := node as Skeleton3D
		var names: Array[String] = []
		for index in skeleton.get_bone_count():
			names.append(skeleton.get_bone_name(index))
		extra = " bones=%d [%s]" % [skeleton.get_bone_count(), ", ".join(names)]
	elif node is AnimationPlayer:
		var player := node as AnimationPlayer
		var names: Array[String] = []
		for library_name in player.get_animation_library_list():
			var library := player.get_animation_library(library_name)
			for animation_name in library.get_animation_list():
				var animation := library.get_animation(animation_name)
				names.append("%s len=%.3f tracks=%d" % [
					(library_name + "/" if not library_name.is_empty() else "") + animation_name,
					animation.length,
					animation.get_track_count(),
				])
				if animation_name == "Walk" or animation_name == "mixamo_com":
					for track_index in mini(animation.get_track_count(), 12):
						print(indent, "    track ", track_index, " type=", animation.track_get_type(track_index), " path=", animation.track_get_path(track_index), " keys=", animation.track_get_key_count(track_index))
						if animation.track_get_key_count(track_index) > 0:
							print(indent, "      first=", animation.track_get_key_value(track_index, 0))
		extra = " animations=[%s]" % ", ".join(names)
	elif node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var surfaces := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0
		extra = " surfaces=%d aabb=%s" % [surfaces, mesh_instance.get_aabb()]
	print(indent, node.name, " <", node.get_class(), ">", extra, " transform=", node.transform if node is Node3D else "")
	for child in node.get_children():
		_print_tree(child, indent + "  ")
