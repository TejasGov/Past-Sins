extends SceneTree


func _initialize() -> void:
	for inspected_class in ["RetargetModifier3D", "SkeletonModifier3D", "BoneMap", "SkeletonProfile", "SkeletonProfileHumanoid"]:
		print("CLASS ", inspected_class, " exists=", ClassDB.class_exists(inspected_class))
		if ClassDB.class_exists(inspected_class):
			for method in ClassDB.class_get_method_list(inspected_class, true):
				print("  ", method.name)
	var profile := SkeletonProfileHumanoid.new()
	print("HUMANOID BONES ", profile.get_bone_size())
	for bone_index in profile.get_bone_size():
		print("  ", profile.get_bone_name(bone_index), " parent=", profile.get_bone_parent(bone_index))
	quit()
