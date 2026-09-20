extends Node
class_name HealthComponent

signal health_changed(current_health: float, total_health: float)
signal damage_applied(amount: float, hit_zone: StringName)
signal armor_changed(armor_type: ArmorTypes.Type, armor_bonus: float)
signal died(hit_zone: StringName)

@export_range(1.0, 10000.0, 1.0) var base_health := 100.0
@export var armor_type: ArmorTypes.Type = ArmorTypes.Type.NONE
@export var lethal_melee_vulnerable := true

var armor_bonus := 0.0
var current_health := 100.0
var _dead := false


func _ready() -> void:
	armor_bonus = ArmorTypes.bonus_for(armor_type)
	reset_health()


func apply_damage(amount: float, hit_zone: StringName = &"") -> float:
	if _dead or amount <= 0.0:
		return 0.0
	var applied := minf(amount, current_health)
	current_health = maxf(0.0, current_health - amount)
	damage_applied.emit(applied, hit_zone)
	health_changed.emit(current_health, get_total_health())
	if current_health <= 0.0:
		_dead = true
		died.emit(hit_zone)
	return applied


func apply_lethal_melee(hit_zone: StringName = &"TORSO") -> bool:
	if _dead or not lethal_melee_vulnerable:
		return false
	apply_damage(current_health, hit_zone)
	return _dead


func heal(amount: float) -> float:
	if _dead or amount <= 0.0:
		return 0.0
	var previous := current_health
	current_health = minf(get_total_health(), current_health + amount)
	if not is_equal_approx(previous, current_health):
		health_changed.emit(current_health, get_total_health())
	return current_health - previous


func reset_health() -> void:
	armor_bonus = ArmorTypes.bonus_for(armor_type)
	current_health = get_total_health()
	_dead = false
	health_changed.emit(current_health, get_total_health())


func set_armor_type(value: ArmorTypes.Type, restore_to_full := true) -> void:
	armor_type = value
	armor_bonus = ArmorTypes.bonus_for(armor_type)
	armor_changed.emit(armor_type, armor_bonus)
	if restore_to_full:
		reset_health()
	else:
		current_health = minf(current_health, get_total_health())
		health_changed.emit(current_health, get_total_health())


func get_total_health() -> float:
	return base_health + armor_bonus


func is_dead() -> bool:
	return _dead
