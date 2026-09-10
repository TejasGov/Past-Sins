extends StaticBody3D
class_name DevRangeResetControl


func get_interaction_prompt(_player: Node) -> String:
	return "[E] Reset Targets" if DevModeManager.is_enabled() else ""


func interact(_player: Node) -> void:
	if not DevModeManager.is_enabled():
		return
	for tool in get_tree().get_nodes_in_group("dev_damage_test_tools"):
		if tool.has_method("reset_targets"):
			tool.call("reset_targets")
			return
