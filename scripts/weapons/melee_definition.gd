extends ItemDefinition
class_name MeleeDefinition

@export var melee_id: StringName = &""
@export_range(0.5, 3.0, 0.05) var reach := 1.55
@export_range(0.1, 3.0, 0.05) var attack_duration := 0.6
@export_range(0.01, 2.0, 0.01) var impact_time := 0.2
@export_range(0.1, 3.0, 0.05) var attack_cooldown := 0.6
@export var lethal_melee := true
@export_range(0.0, 500.0, 1.0) var fallback_damage := 40.0
@export_range(0.0, 2.0, 0.05) var camera_impact_degrees := 0.25
@export var weapon_visibility_class: StringName = &"MELEE"
@export var first_person_visual_scene: PackedScene
@export var world_visual_scene: PackedScene


func is_valid_melee_definition() -> bool:
	return is_valid_definition() \
		and category == Category.MELEE \
		and normalized_melee_id() == normalized_id() \
		and reach > 0.0 \
		and attack_duration > 0.0 \
		and impact_time > 0.0 and impact_time <= attack_duration \
		and attack_cooldown >= attack_duration \
		and first_person_visual_scene != null \
		and world_visual_scene != null


func normalized_melee_id() -> StringName:
	return StringName(str(melee_id).strip_edges().to_lower())
