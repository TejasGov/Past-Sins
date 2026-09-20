extends ItemDefinition
class_name MonocularDefinition

@export_group("Optics")
@export_range(45.0, 110.0, 1.0) var normal_fov := 78.0
@export_range(15.0, 60.0, 1.0) var zoom_1_fov := 26.0
@export_range(8.0, 45.0, 1.0) var zoom_2_fov := 13.0
@export_range(6.0, 35.0, 0.25) var zoom_3_fov := 9.75
@export_range(1.0, 30.0, 0.5) var zoom_transition_speed := 10.0
@export var first_person_visual_scene: PackedScene
@export var world_visual_scene: PackedScene


func is_valid_monocular() -> bool:
	return is_valid_definition() and category == ItemDefinition.Category.EQUIPMENT and not stackable and first_person_visual_scene != null and world_visual_scene != null and zoom_3_fov < zoom_2_fov and zoom_2_fov < zoom_1_fov and zoom_1_fov < normal_fov
