extends ItemDefinition
class_name FirearmDefinition

enum FireMode {
	SEMI_AUTO,
}

@export var weapon_id: StringName = &""
@export var magazine_size := 1
@export var fire_mode: FireMode = FireMode.SEMI_AUTO
@export_range(0.01, 10.0, 0.01) var shot_interval := 0.5
@export_range(0.01, 15.0, 0.01) var reload_time := 1.5
@export_range(0, 999, 1) var initial_reserve_ammo := 0
@export_range(0, 999, 1) var reserve_ammo_capacity := 0
@export_range(1.0, 500.0, 1.0) var hitscan_range := 120.0
@export_group("Accuracy")
@export_range(0.0, 10.0, 0.01) var hip_fire_spread_degrees := 0.8
@export_range(0.0, 5.0, 0.01) var ads_spread_degrees := 0.08
@export_group("Damage")
@export_range(0.0, 999.0, 1.0) var lower_body_damage := 0.0
@export_range(0.0, 999.0, 1.0) var torso_damage := 0.0
@export_range(0.0, 999.0, 1.0) var head_damage := 0.0
@export var first_person_visual_scene: PackedScene
@export var world_visual_scene: PackedScene


func is_valid_firearm_definition() -> bool:
	return is_valid_definition() \
		and category == Category.FIREARM \
		and normalized_weapon_id() == normalized_id() \
		and magazine_size > 0 \
		and shot_interval > 0.0 \
		and reload_time > 0.0


func normalized_weapon_id() -> StringName:
	return StringName(str(weapon_id).strip_edges().to_lower())


func damage_for_zone(hit_zone: StringName) -> float:
	match StringName(str(hit_zone).strip_edges().to_upper()):
		&"HEAD":
			return head_damage
		&"LOWER_BODY":
			return lower_body_damage
		_:
			return torso_damage
