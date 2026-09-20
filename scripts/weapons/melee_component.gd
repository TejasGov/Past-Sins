extends Node3D
class_name MeleeComponent

signal state_changed(attacking: bool)
signal attack_started(definition: MeleeDefinition)
signal impact_resolved(definition: MeleeDefinition, hit: bool)
signal hit_confirmed(definition: MeleeDefinition, zone: BodyHitZone, lethal: bool, hit_position: Vector3)

const HIT_MASK := 1 | 32

var definition: MeleeDefinition
var cooldown_remaining := 0.0
var attack_remaining := 0.0
var impact_remaining := 0.0
var _impact_resolved := true
var _attack_camera: Camera3D
var _visual: MeleeVisualBase


func configure(melee_definition: MeleeDefinition) -> bool:
	if melee_definition == null or not melee_definition.is_valid_melee_definition():
		return false
	definition = melee_definition
	return _build_visual()


func equip() -> void:
	visible = true


func unequip() -> void:
	attack_remaining = 0.0
	impact_remaining = 0.0
	_impact_resolved = true
	_attack_camera = null
	if _visual: _visual.cancel_melee_animation()
	visible = false
	state_changed.emit(false)


func try_attack(camera: Camera3D) -> bool:
	if definition == null or camera == null or cooldown_remaining > 0.0 or attack_remaining > 0.0:
		return false
	cooldown_remaining = definition.attack_cooldown
	attack_remaining = definition.attack_duration
	impact_remaining = definition.impact_time
	_impact_resolved = false
	_attack_camera = camera
	if _visual: _visual.play_attack(definition.attack_duration, definition.impact_time)
	state_changed.emit(true)
	attack_started.emit(definition)
	return true


func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if attack_remaining <= 0.0:
		return
	attack_remaining = maxf(0.0, attack_remaining - delta)
	if not _impact_resolved:
		impact_remaining -= delta
		if impact_remaining <= 0.0:
			_resolve_impact()
	if attack_remaining <= 0.0:
		_attack_camera = null
		state_changed.emit(false)


func _resolve_impact() -> void:
	_impact_resolved = true
	if not is_instance_valid(_attack_camera):
		impact_resolved.emit(definition, false)
		return
	var start := _attack_camera.global_position
	var end := start - _attack_camera.global_basis.z * definition.reach
	var query := PhysicsRayQueryParameters3D.create(start, end, HIT_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := _attack_camera.get_world_3d().direct_space_state.intersect_ray(query)
	var collider := result.get("collider") as Node if not result.is_empty() else null
	if collider is BodyHitZone:
		var zone := collider as BodyHitZone
		var was_dead := zone.health_component != null and zone.health_component.is_dead()
		var lethal_applied := definition.lethal_melee and zone.health_component != null and zone.health_component.lethal_melee_vulnerable
		var killed := zone.apply_melee_hit(definition.lethal_melee, definition.fallback_damage)
		if not was_dead:
			if _visual: _visual.play_impact(definition.camera_impact_degrees >= 0.5)
			hit_confirmed.emit(definition, zone, killed and lethal_applied, result.position as Vector3)
		impact_resolved.emit(definition, not was_dead)
		return
	# The first solid wall/door collision intentionally terminates the ray.
	impact_resolved.emit(definition, false)


func get_visual() -> MeleeVisualBase:
	return _visual


func has_resolved_current_swing() -> bool:
	return _impact_resolved


func _build_visual() -> bool:
	var instance := definition.first_person_visual_scene.instantiate()
	if not instance is MeleeVisualBase:
		push_error("Melee visual must extend MeleeVisualBase: %s" % definition.first_person_visual_scene.resource_path)
		instance.free()
		return false
	_visual = instance as MeleeVisualBase
	add_child(_visual)
	var failures := _visual.validate_visual_contract()
	if not failures.is_empty():
		for failure in failures: push_error("%s: %s" % [definition.display_name, failure])
		_visual.free()
		_visual = null
		return false
	return true
