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
signal suppressor_changed(suppressor: SuppressorDefinition)
signal suppressor_durability_changed(remaining: int, maximum: int)
signal suppressor_broken(suppressor_id: StringName)

enum WeaponState {
	HOLSTERED,
	READY,
	FIRING,
	RELOADING,
	EMPTY,
}

enum ReloadMode {
	NONE,
	FULL_MAGAZINE,
	INDIVIDUAL_ROUND,
}

const HITSCAN_MASK := 1 | 32
const FIRING_FEEDBACK_TIME := 0.085

var definition: FirearmDefinition
var magazine_ammo := 0
var reserve_ammo := 0
var state: WeaponState = WeaponState.HOLSTERED
var cooldown_remaining := 0.0
var reload_remaining := 0.0
var reload_mode: ReloadMode = ReloadMode.NONE
var _firing_feedback_remaining := 0.0
var _visual: FirearmVisualBase
var _reload_was_empty := false
var suppressor_definition: SuppressorDefinition
var suppressor_remaining_uses := 0
var suppressed_shots_this_magazine := false

var _burst_remaining := 0
var _burst_step_index := 0
var _burst_timer := 0.0
var _burst_camera: Camera3D
var _burst_base_spread := 0.0


func configure(firearm_definition: FirearmDefinition, saved_magazine := -1, saved_reserve := -1, suppressor_snapshot: Dictionary = {}) -> bool:
	if firearm_definition == null or not firearm_definition.is_valid_firearm_definition():
		return false
	definition = firearm_definition
	magazine_ammo = clampi(saved_magazine if saved_magazine >= 0 else definition.magazine_size, 0, definition.magazine_size)
	reserve_ammo = clampi(saved_reserve if saved_reserve >= 0 else definition.initial_reserve_ammo, 0, definition.reserve_ammo_capacity)
	_cancel_burst()
	reload_mode = ReloadMode.NONE
	if not _build_visual():
		return false
	if not suppressor_snapshot.is_empty():
		var saved_suppressor := suppressor_snapshot.get("definition") as SuppressorDefinition
		if saved_suppressor and not attach_suppressor(saved_suppressor, suppressor_snapshot):
			return false
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
	_cancel_burst()
	reload_remaining = 0.0
	reload_mode = ReloadMode.NONE
	_firing_feedback_remaining = 0.0
	_set_state(WeaponState.HOLSTERED)
	if _visual:
		_visual.cancel_weapon_animation()
	visible = false


func try_fire(camera: Camera3D, spread_degrees := 0.0) -> bool:
	if definition == null or camera == null or state in [WeaponState.HOLSTERED, WeaponState.RELOADING] or cooldown_remaining > 0.0 or _burst_remaining > 0:
		return false
	if magazine_ammo <= 0:
		_set_state(WeaponState.EMPTY)
		empty_triggered.emit()
		return false

	match definition.fire_mode:
		FirearmDefinition.FireMode.BURST:
			return _start_burst(camera, spread_degrees)
		FirearmDefinition.FireMode.SEMI_AUTO, FirearmDefinition.FireMode.AUTOMATIC, FirearmDefinition.FireMode.SINGLE_SHOT:
			return _fire_single_round(camera, spread_degrees)
		_:
			return false


func _fire_single_round(camera: Camera3D, spread_degrees: float) -> bool:
	magazine_ammo -= 1
	cooldown_remaining = definition.shot_interval
	_firing_feedback_remaining = FIRING_FEEDBACK_TIME
	_set_state(WeaponState.FIRING)
	_play_visual_feedback(magazine_ammo)
	ammo_changed.emit(magazine_ammo, reserve_ammo)
	shot_fired.emit(definition, magazine_ammo, reserve_ammo)
	_perform_hitscan(camera, maxf(0.0, spread_degrees))
	_register_suppressed_shot(camera.global_position)
	if magazine_ammo <= 0:
		_finalize_suppressor_magazine_use()
	return true


func _start_burst(camera: Camera3D, spread_degrees: float) -> bool:
	var rounds_to_fire := mini(definition.burst_size, magazine_ammo)
	if rounds_to_fire <= 0:
		_set_state(WeaponState.EMPTY)
		empty_triggered.emit()
		return false

	_burst_camera = camera
	_burst_base_spread = maxf(0.0, spread_degrees)
	_burst_remaining = rounds_to_fire
	_burst_step_index = 0
	_set_state(WeaponState.FIRING)
	_execute_burst_shot()
	return true


func _execute_burst_shot() -> void:
	if magazine_ammo <= 0 or not is_instance_valid(_burst_camera):
		_finish_burst()
		return

	magazine_ammo -= 1
	var shot_spread := _burst_base_spread + float(_burst_step_index) * definition.burst_spread_growth
	_burst_step_index += 1
	_burst_remaining -= 1

	_firing_feedback_remaining = FIRING_FEEDBACK_TIME
	_play_visual_feedback(magazine_ammo)
	ammo_changed.emit(magazine_ammo, reserve_ammo)
	shot_fired.emit(definition, magazine_ammo, reserve_ammo)
	_perform_hitscan(_burst_camera, maxf(0.0, shot_spread))
	_register_suppressed_shot(_burst_camera.global_position)
	if magazine_ammo <= 0:
		_finalize_suppressor_magazine_use()

	if _burst_remaining <= 0 or magazine_ammo <= 0:
		_finish_burst()
	else:
		_burst_timer = definition.intra_burst_interval


func _finish_burst() -> void:
	_burst_remaining = 0
	_burst_camera = null
	cooldown_remaining = definition.burst_recovery_delay
	_set_state(WeaponState.EMPTY if magazine_ammo <= 0 else WeaponState.READY)


func _cancel_burst() -> void:
	_burst_remaining = 0
	_burst_camera = null
	_burst_timer = 0.0


func is_burst_active() -> bool:
	return _burst_remaining > 0


func get_burst_remaining() -> int:
	return _burst_remaining


func start_reload() -> bool:
	if definition == null or state in [WeaponState.HOLSTERED, WeaponState.RELOADING] or _burst_remaining > 0:
		return false
	if magazine_ammo >= definition.magazine_size or reserve_ammo <= 0:
		return false
	_finalize_suppressor_magazine_use()
	_reload_was_empty = magazine_ammo <= 0
	reload_remaining = definition.reload_time
	reload_mode = ReloadMode.FULL_MAGAZINE
	_set_state(WeaponState.RELOADING)
	if _visual:
		_visual.play_reload(definition.reload_time, _reload_was_empty)
	reload_started.emit(definition.reload_time)
	return true


func start_individual_round_load() -> bool:
	if definition == null or not definition.supports_individual_round_loading():
		return false
	if state in [WeaponState.HOLSTERED, WeaponState.RELOADING] or _burst_remaining > 0:
		return false
	if magazine_ammo >= definition.magazine_size or reserve_ammo <= 0:
		return false
	_finalize_suppressor_magazine_use()
	_reload_was_empty = magazine_ammo <= 0
	reload_remaining = definition.individual_round_reload_time
	reload_mode = ReloadMode.INDIVIDUAL_ROUND
	_set_state(WeaponState.RELOADING)
	if _visual:
		_visual.play_individual_round_load(reload_remaining)
	reload_started.emit(reload_remaining)
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
	_finalize_suppressor_magazine_use()
	_cancel_burst()
	magazine_ammo = definition.magazine_size
	reserve_ammo = definition.reserve_ammo_capacity
	reload_remaining = 0.0
	reload_mode = ReloadMode.NONE
	_reload_was_empty = false
	_set_state(WeaponState.READY if state != WeaponState.HOLSTERED else WeaponState.HOLSTERED)
	if _visual:
		_visual.finish_reload(magazine_ammo)
	else:
		_update_visual_ammo_state()
	ammo_changed.emit(magazine_ammo, reserve_ammo)


func get_ammo_snapshot() -> Dictionary:
	return {"magazine": magazine_ammo, "reserve": reserve_ammo}


func attach_suppressor(suppressor: SuppressorDefinition, saved_state: Dictionary = {}) -> bool:
	if definition == null or suppressor == null or suppressor_definition != null \
		or not suppressor.is_valid_suppressor() or not suppressor.supports_weapon(definition.normalized_weapon_id()) \
		or bool(saved_state.get("broken", false)):
		return false
	var remaining := int(saved_state.get("remaining_magazine_uses", suppressor.max_magazine_uses))
	if suppressor.max_magazine_uses > 0 and remaining <= 0:
		return false
	if _visual == null or not _visual.set_suppressor_visual(suppressor, definition.normalized_weapon_id()):
		return false
	suppressor_definition = suppressor
	suppressor_remaining_uses = clampi(remaining, 0, suppressor.max_magazine_uses) if suppressor.max_magazine_uses > 0 else -1
	suppressed_shots_this_magazine = bool(saved_state.get("used_this_magazine", false))
	suppressor_changed.emit(suppressor_definition)
	suppressor_durability_changed.emit(suppressor_remaining_uses, suppressor.max_magazine_uses)
	return true


func detach_suppressor() -> Dictionary:
	if suppressor_definition == null:
		return {}
	var snapshot := get_suppressor_snapshot()
	suppressor_definition = null
	suppressor_remaining_uses = 0
	suppressed_shots_this_magazine = false
	if _visual: _visual.clear_suppressor_visual()
	suppressor_changed.emit(null)
	return snapshot


func get_suppressor_snapshot() -> Dictionary:
	if suppressor_definition == null:
		return {}
	return {
		"definition": suppressor_definition,
		"suppressor_id": suppressor_definition.normalized_id(),
		"remaining_magazine_uses": suppressor_remaining_uses,
		"used_this_magazine": suppressed_shots_this_magazine,
		"broken": false,
	}


func is_suppressed() -> bool:
	return suppressor_definition != null


func get_suppressor_type() -> StringName:
	return StringName(suppressor_definition.type_name()) if suppressor_definition else &""


func get_effective_noise_radius() -> float:
	if definition == null: return 0.0
	return definition.base_noise_radius * suppressor_definition.noise_radius_multiplier if suppressor_definition else definition.base_noise_radius


func get_muzzle_flash_mode() -> StringName:
	if suppressor_definition == null: return &"NORMAL"
	return &"SUBTLE" if suppressor_definition.suppressor_type == SuppressorDefinition.Type.PROPER else &"REDUCED"


func get_sound_profile() -> StringName:
	if suppressor_definition == null: return &"UNSUPPRESSED"
	return &"PROPER_SUPPRESSED" if suppressor_definition.suppressor_type == SuppressorDefinition.Type.PROPER else &"MAKESHIFT_SUPPRESSED"


func _register_suppressed_shot(origin: Vector3) -> void:
	if suppressor_definition:
		suppressed_shots_this_magazine = true
	WorldNoiseSystem.emit_weapon_noise(origin, definition.normalized_weapon_id(), definition.base_noise_radius, get_effective_noise_radius(), get_suppressor_type(), self)


func _finalize_suppressor_magazine_use() -> void:
	if suppressor_definition == null or not suppressed_shots_this_magazine:
		return
	suppressed_shots_this_magazine = false
	if suppressor_definition.max_magazine_uses <= 0:
		return
	suppressor_remaining_uses = maxi(0, suppressor_remaining_uses - 1)
	suppressor_durability_changed.emit(suppressor_remaining_uses, suppressor_definition.max_magazine_uses)
	if suppressor_remaining_uses == 0:
		_break_suppressor()


func _break_suppressor() -> void:
	if suppressor_definition == null: return
	var broken_id := suppressor_definition.normalized_id()
	suppressor_definition = null
	suppressor_remaining_uses = 0
	suppressed_shots_this_magazine = false
	if _visual: _visual.clear_suppressor_visual()
	suppressor_changed.emit(null)
	suppressor_broken.emit(broken_id)


func _physics_process(delta: float) -> void:
	if _burst_remaining > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_execute_burst_shot()
	else:
		cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
		if state == WeaponState.FIRING:
			_firing_feedback_remaining -= delta
			if _firing_feedback_remaining <= 0.0:
				_set_state(WeaponState.EMPTY if magazine_ammo <= 0 else WeaponState.READY)
	if state == WeaponState.RELOADING:
		reload_remaining -= delta
		if reload_remaining <= 0.0:
			_finish_reload()


func _finish_reload() -> void:
	var required := 1 if reload_mode == ReloadMode.INDIVIDUAL_ROUND else definition.magazine_size - magazine_ammo
	var transferred := mini(required, reserve_ammo)
	magazine_ammo += transferred
	reserve_ammo -= transferred
	reload_remaining = 0.0
	reload_mode = ReloadMode.NONE
	_set_state(WeaponState.EMPTY if magazine_ammo <= 0 else WeaponState.READY)
	if _visual:
		_visual.finish_reload(magazine_ammo)
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
		return
	# Environment impact — mirrors the slingshot on_slingshot_projectile_impact
	# pattern. Check both the collider itself and its breakable_owner meta so
	# child StaticBody3D nodes can route hits to their owning prop script.
	if collider:
		var hit_pos := result.position as Vector3
		var owner_node: Node = collider.get_meta("breakable_owner") if collider.has_meta("breakable_owner") else null
		if owner_node and owner_node.has_method("on_hitscan_impact"):
			owner_node.call("on_hitscan_impact", hit_pos)
		elif collider.has_method("on_hitscan_impact"):
			collider.call("on_hitscan_impact", hit_pos)


func _build_visual() -> bool:
	if _visual:
		_visual.queue_free()
		_visual = null
	if definition == null or definition.first_person_visual_scene == null:
		push_error("Firearm definition requires a first-person visual scene")
		return false
	var instance := definition.first_person_visual_scene.instantiate()
	if not instance is FirearmVisualBase:
		push_error("Firearm visual must extend FirearmVisualBase: %s" % definition.first_person_visual_scene.resource_path)
		instance.free()
		return false
	_visual = instance as FirearmVisualBase
	add_child(_visual)
	var contract_failures := _visual.validate_visual_contract()
	if not contract_failures.is_empty():
		for failure in contract_failures:
			push_error("%s: %s" % [definition.display_name, failure])
		_visual.free()
		_visual = null
		return false
	return true


func _play_visual_feedback(rounds_remaining: int) -> void:
	if _visual:
		_visual.play_fire_feedback(rounds_remaining)


func _update_visual_ammo_state() -> void:
	if _visual:
		_visual.set_slide_locked(magazine_ammo <= 0)


func get_visual() -> FirearmVisualBase:
	return _visual


func get_sight_alignment_pixels(camera: Camera3D) -> Dictionary:
	return _visual.get_sight_alignment_pixels(camera) if _visual else {}


func _set_state(next_state: WeaponState) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state)
