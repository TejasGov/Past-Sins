extends StaticBody3D
class_name DevReturnTerminal

@export var target_scene_id: StringName = &"dev_test_hub"
@export var display_name := "Dev Hub"


func get_interaction_prompt(_player: Node) -> String:
	if not DevModeManager.is_enabled():
		return ""
	return "[E] Return to %s" % display_name


func interact(_player: Node) -> void:
	if DevModeManager.is_enabled():
		DevModeManager.enter_test_scene(target_scene_id)
