extends Node
class_name ToxinStatusComponent

signal toxin_started(duration: float)
signal toxin_completed

enum TargetRole { GENERIC, INMATE, GUARD }

@export var target_role: TargetRole = TargetRole.GENERIC
@export_range(0.1, 10.0, 0.1) var inmate_transition_time := 0.45
@export_range(0.1, 10.0, 0.1) var guard_transition_time := 3.0
var health_component: HealthComponent
var transition_remaining := 0.0
var active := false
var incapacitated := false


func configure(health: HealthComponent, role: TargetRole) -> void:
	health_component = health
	target_role = role


func apply_fictional_toxin() -> bool:
	if active or incapacitated or health_component == null or health_component.is_dead(): return false
	transition_remaining = guard_transition_time if target_role == TargetRole.GUARD else inmate_transition_time
	active = true
	toxin_started.emit(transition_remaining)
	return true


func can_use_security_actions() -> bool:
	return target_role != TargetRole.GUARD or (not active and not incapacitated)


func reset_status() -> void:
	active = false
	incapacitated = false
	transition_remaining = 0.0


func _physics_process(delta: float) -> void:
	if not active: return
	transition_remaining = maxf(0.0, transition_remaining - delta)
	if transition_remaining > 0.0: return
	active = false
	incapacitated = true
	if health_component and not health_component.is_dead(): health_component.apply_damage(health_component.current_health, &"TOXIN")
	toxin_completed.emit()
