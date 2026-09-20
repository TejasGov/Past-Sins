extends ItemDefinition
class_name FirearmDefinition

enum FireMode {
	SEMI_AUTO,
	BURST,
	AUTOMATIC,
	SINGLE_SHOT,
}

@export var weapon_id: StringName = &""
@export var magazine_size := 1
@export var fire_mode: FireMode = FireMode.SEMI_AUTO
@export_range(0.01, 10.0, 0.01) var shot_interval := 0.5
@export_range(0.01, 15.0, 0.01) var reload_time := 1.5
@export_range(0.0, 15.0, 0.01) var individual_round_reload_time := 0.0
@export_range(0, 999, 1) var initial_reserve_ammo := 0
@export_range(0, 999, 1) var reserve_ammo_capacity := 0
@export_range(1.0, 500.0, 1.0) var hitscan_range := 120.0
@export_group("Stealth")
@export_range(1.0, 250.0, 1.0) var base_noise_radius := 100.0
@export_group("Burst Fire")
@export_range(1, 20, 1) var burst_size := 5
@export_range(0.01, 1.0, 0.005) var intra_burst_interval := 0.04
@export_range(0.0, 2.0, 0.01) var burst_recovery_delay := 0.25
@export_range(0.0, 5.0, 0.01) var burst_spread_growth := 0.12
@export_group("Accuracy")
@export_range(0.0, 10.0, 0.01) var hip_fire_spread_degrees := 0.8
@export_range(0.0, 5.0, 0.01) var ads_spread_degrees := 0.08
@export_group("Custom Handling")
@export var has_custom_ads_transform := false
@export var custom_ads_position := Vector3.ZERO
@export var custom_ads_rotation_degrees := Vector3.ZERO
@export_range(0.0, 90.0, 1.0) var ads_fov_override := 0.0
@export var has_advanced_scope_zoom := false
@export_range(5.0, 60.0, 1.0) var advanced_scope_fov := 18.0
@export_range(-1.0, 1.0, 0.01) var ads_motion_multiplier_override := -1.0
@export var scope_overlay_scene: PackedScene
@export var future_suppressor_compatible := false
@export_range(0.0, 5.0, 0.01) var recoil_camera_degrees_override := 0.0
@export_range(0.0, 5.0, 0.01) var ads_camera_recoil_override := 0.0
@export_range(0.0, 5.0, 0.01) var recoil_weapon_kick_override := 0.0
@export_range(0.0, 5.0, 0.01) var horizontal_recoil_degrees := 0.0
@export_range(0.0, 40.0, 0.5) var recoil_recovery_speed_override := 0.0
@export_range(0.0, 40.0, 0.5) var ads_recoil_recovery_speed_override := 0.0
@export_group("Damage")
@export_range(0.0, 999.0, 1.0) var lower_body_damage := 0.0
@export_range(0.0, 999.0, 1.0) var torso_damage := 0.0
@export_range(0.0, 999.0, 1.0) var head_damage := 0.0
@export var first_person_visual_scene: PackedScene
@export var world_visual_scene: PackedScene


func is_valid_firearm_definition() -> bool:
	var base_valid := is_valid_definition() \
		and category == Category.FIREARM \
		and normalized_weapon_id() == normalized_id() \
		and magazine_size > 0 \
		and reload_time > 0.0
	if not base_valid:
		return false
	if fire_mode == FireMode.BURST:
		return burst_size > 0 and intra_burst_interval > 0.0 and burst_recovery_delay >= 0.0
	return shot_interval > 0.0


func normalized_weapon_id() -> StringName:
	return StringName(str(weapon_id).strip_edges().to_lower())


func supports_individual_round_loading() -> bool:
	return individual_round_reload_time > 0.0


func damage_for_zone(hit_zone: StringName) -> float:
	match StringName(str(hit_zone).strip_edges().to_upper()):
		&"HEAD":
			return head_damage
		&"LOWER_BODY":
			return lower_body_damage
		_:
			return torso_damage
