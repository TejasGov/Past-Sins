extends Node3D
class_name FirearmComponent

## Reusable firearm runtime. Player input, movement, inventory and visuals live
## outside this component; this node owns only firearm state and hitscan results.
signal state_changed(state: WeaponState)
signal ammo_changed(magazine: int, reserve: int)
signal shot_fired(definition: FirearmDefinition, magazine: int, reserve: int)
signal empty_triggered
signal hit_confirmed(definition: FirearmDefinition, zone: BodyHitZone, damage: float, hit_position: Vector3)
signal reload_started(duration: float)
signal reload_finished

enum WeaponState {
	HOLSTERED,
	READY,
	FIRING,
	RELOADING,
	EMPTY,
}

const HITSCAN_MASK := 1 | 32
const FIRING_FEEDBACK_TIME := 0.085

var definition: FirearmDefinition
var magazine_ammo := 0
var reserve_ammo := 0
var state: WeaponState = WeaponState.HOLSTERED
var cooldown_remaining := 0.0
var reload_remaining := 0.0
var _firing_feedback_remaining := 0.0
var _visual: Node3D
var _reload_was_empty := false


func configure(firearm_definition: FirearmDefinition, saved_magazine := -1, saved_reserve := -1) -> bool:
	if firearm_definition == null or not firearm_definition.is_valid_firearm_definition():
		return false
	definition = firearm_definition
	magazine_ammo = clampi(saved_magazine if saved_magazine >= 0 else definition.magazine_size, 0, definition.magazine_size)
	reserve_ammo = clampi(saved_reserve if saved_reserve >= 0 else definition.initial_reserve_ammo, 0, definition.reserve_ammo_capacity)
	_build_visual()
	_update_visual_ammo_state()
	_set_state(WeaponState.HOLSTERED)
	ammo_changed.emit(magazine_ammo, reserve_ammo)
	return true


func equip() -> bool:
	if definition == null:
		return false
	visible = true
	_set_state(WeaponState.EMPTY if magazine_ammo <= 0 else WeaponState.READY)
	return true


func unequip() -> void:
	reload_remaining = 0.0
	_firing_feedback_remaining = 0.0
	_set_state(WeaponState.HOLSTERED)
	if _visual and _visual.has_method("cancel_weapon_animation"):
		_visual.call("cancel_weapon_animation")
	visible = false


func try_fire(camera: Camera3D, spread_degrees := 0.0) -> bool:
	if definition == null or camera == null or state in [WeaponState.HOLSTERED, WeaponState.RELOADING] or cooldown_remaining > 0.0:
		return false
	if definition.fire_mode != FirearmDefinition.FireMode.SEMI_AUTO:
		return false
	if magazine_ammo <= 0:
		_set_state(WeaponState.EMPTY)
		empty_triggered.emit()
		return false

	magazine_ammo -= 1
	cooldown_remaining = definition.shot_interval
	_firing_feedback_remaining = FIRING_FEEDBACK_TIME
	_set_state(WeaponState.FIRING)
	_play_visual_feedback(magazine_ammo)
	ammo_changed.emit(magazine_ammo, reserve_ammo)
	shot_fired.emit(definition, magazine_ammo, reserve_ammo)
	_perform_hitscan(camera, maxf(0.0, spread_degrees))
	return true


func start_reload() -> bool:
	if definition == null or state in [WeaponState.HOLSTERED, WeaponState.RELOADING]:
		return false
	if magazine_ammo >= definition.magazine_size or reserve_ammo <= 0:
		return false
	_reload_was_empty = magazine_ammo <= 0
	reload_remaining = definition.reload_time
	_set_state(WeaponState.RELOADING)
	if _visual and _visual.has_method("play_reload"):
		_visual.call("play_reload", definition.reload_time, _reload_was_empty)
	reload_started.emit(definition.reload_time)
	return true


func add_reserve_ammo(amount: int) -> int:
	if definition == null or amount <= 0:
		return 0
	var previous := reserve_ammo
	reserve_ammo = mini(definition.reserve_ammo_capacity, reserve_ammo + amount)
	var added := reserve_ammo - previous
	if added > 0:
		ammo_changed.emit(magazine_ammo, reserve_ammo)
	return added


func refill_ammo() -> void:
	if definition == null:
		return
	magazine_ammo = definition.magazine_size
	reserve_ammo = definition.reserve_ammo_capacity
	reload_remaining = 0.0
	_reload_was_empty = false
	_set_state(WeaponState.READY if state != WeaponState.HOLSTERED else WeaponState.HOLSTERED)
	if _visual and _visual.has_method("finish_reload"):
		_visual.call("finish_reload", magazine_ammo)
	else:
		_update_visual_ammo_state()
	ammo_changed.emit(magazine_ammo, reserve_ammo)


func get_ammo_snapshot() -> Dictionary:
	return {"magazine": magazine_ammo, "reserve": reserve_ammo}


func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if state == WeaponState.FIRING:
		_firing_feedback_remaining -= delta
		if _firing_feedback_remaining <= 0.0:
			_set_state(WeaponState.EMPTY if magazine_ammo <= 0 else WeaponState.READY)
	elif state == WeaponState.RELOADING:
		reload_remaining -= delta
		if reload_remaining <= 0.0:
			_finish_reload()


func _finish_reload() -> void:
	var required := definition.magazine_size - magazine_ammo
	var transferred := mini(required, reserve_ammo)
	magazine_ammo += transferred
	reserve_ammo -= transferred
	reload_remaining = 0.0
	_set_state(WeaponState.EMPTY if magazine_ammo <= 0 else WeaponState.READY)
	if _visual and _visual.has_method("finish_reload"):
		_visual.call("finish_reload", magazine_ammo)
	_reload_was_empty = false
	ammo_changed.emit(magazine_ammo, reserve_ammo)
	reload_finished.emit()


func _perform_hitscan(camera: Camera3D, spread_degrees: float) -> void:
	var start := camera.global_position
	var direction := -camera.global_basis.z
	if spread_degrees > 0.0:
		var horizontal := tan(deg_to_rad(randf_range(-spread_degrees, spread_degrees)))
		var vertical := tan(deg_to_rad(randf_range(-spread_degrees, spread_degrees)))
		direction = (direction + camera.global_basis.x * horizontal + camera.global_basis.y * vertical).normalized()
	var end := start + direction * definition.hitscan_range
	var query := PhysicsRayQueryParameters3D.create(start, end, HITSCAN_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider := result.get("collider") as Node
	if collider is BodyHitZone:
		var zone := collider as BodyHitZone
		var damage := definition.damage_for_zone(zone.get_hit_zone_id())
		zone.apply_damage(damage)
		hit_confirmed.emit(definition, zone, damage, result.position as Vector3)


func _build_visual() -> void:
	if _visual:
		_visual.queue_free()
		_visual = null
	if definition == null or definition.first_person_visual_scene == null:
		return
	_visual = definition.first_person_visual_scene.instantiate() as Node3D
	add_child(_visual)


func _play_visual_feedback(rounds_remaining: int) -> void:
	if _visual and _visual.has_method("play_fire_feedback"):
		_visual.call("play_fire_feedback", rounds_remaining)


func _update_visual_ammo_state() -> void:
	if _visual and _visual.has_method("set_slide_locked"):
		_visual.call("set_slide_locked", magazine_ammo <= 0)


func _set_state(next_state: WeaponState) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state)
