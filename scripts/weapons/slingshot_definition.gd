extends MeleeDefinition
class_name SlingshotDefinition

@export_group("Draw And Projectile")
@export_range(0.1, 2.0, 0.05) var maximum_draw_time := 0.8
@export_range(1.0, 80.0, 0.5) var minimum_velocity := 14.0
@export_range(1.0, 80.0, 0.5) var maximum_velocity := 38.0
@export_range(0.0, 20.0, 0.1) var minimum_spread_degrees := 0.45
@export_range(0.0, 20.0, 0.1) var maximum_spread_degrees := 5.0
@export_range(0.0, 1.0, 0.05) var aimed_spread_multiplier := 0.25
@export_range(0.0, 20.0, 0.25) var projectile_gravity := 7.0
@export_range(2.0, 30.0, 0.5) var maximum_zero_distance := 12.0
@export_range(0.2, 3.0, 0.05) var reload_setup_time := 1.6
@export_range(0.0, 1.0, 0.05) var normal_nail_recovery_chance := 0.5
@export var normal_ammo: ItemDefinition
@export var toxin_ammo: ItemDefinition
@export var projectile_scene: PackedScene
@export var weapon_visibility_class_override: StringName = &"IMPROVISED_WEAPON"
@export_range(0.0, 100.0, 1.0) var held_suspicion_floor := 60.0
@export_range(0.0, 100.0, 1.0) var aimed_at_person_suspicion := 100.0
@export_range(0.0, 100.0, 1.0) var witnessed_person_hit_suspicion := 100.0
@export var damage_lower_body := 25.0
@export var damage_torso := 45.0
@export var damage_head := 120.0


func damage_for_zone(zone: StringName) -> float:
	match zone:
		&"HEAD": return damage_head
		&"TORSO": return damage_torso
		_: return damage_lower_body


func is_valid_slingshot_definition() -> bool:
	return is_valid_melee_definition() and normal_ammo != null and toxin_ammo != null and projectile_scene != null and maximum_draw_time > 0.0 and maximum_velocity > minimum_velocity
