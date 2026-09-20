extends Node3D

const RANGE := preload("res://scenes/dev/WeaponRange.tscn")
const PISTOL: FirearmDefinition = preload("res://resources/weapons/pistol.tres")
const SMG: FirearmDefinition = preload("res://resources/weapons/smg.tres")
const CARBINE: FirearmDefinition = preload("res://resources/weapons/carbine_ar.tres")
const SNIPER: FirearmDefinition = preload("res://resources/weapons/sniper_rifle.tres")
const PROPER_SUPPRESSOR: SuppressorDefinition = preload("res://resources/items/proper_suppressor.tres")
const MAKESHIFT_SUPPRESSOR: SuppressorDefinition = preload("res://resources/items/makeshift_suppressor.tres")

var _failures: Array[String] = []
var _range: WeaponRange
var _player: PlayerController
var _controller: PlayerWeaponController


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	DevModeManager.set_enabled(false)
	InventoryManager.clear_all_inventory(false)
	_validate_definition()
	_validate_existing_weapons()
	_validate_input()

	DevModeManager.set_enabled(true)
	_range = RANGE.instantiate() as WeaponRange
	add_child(_range)
	for frame in range(5): await get_tree().process_frame
	await get_tree().physics_frame
	_player = _range.get_node("Actors/WeaponRangePlayer") as PlayerController
	_controller = _player.get_node("WeaponController") as PlayerWeaponController
	_validate_world_pickup()
	await _validate_inventory_and_equip()
	if _controller.current_firearm == null:
		_finish()
		return
	_validate_first_person_visual()
	await _validate_scope_ads()
	await _validate_single_shot_and_recoil()
	await _validate_damage_table()
	await _validate_reload_paths()
	await _validate_drop_and_retrieve()
	await _validate_lifecycle_cleanup()
	await _validate_dev_controls()
	_validate_future_only_attachment()
	_finish()


func _validate_definition() -> void:
	_check(SNIPER.item_id == &"sniper_rifle" and SNIPER.weapon_id == &"sniper_rifle", "Sniper IDs must be data-driven and consistent")
	_check(SNIPER.display_name == "Sniper Rifle" and SNIPER.category == ItemDefinition.Category.FIREARM, "Sniper Rifle must use the FIREARM item contract")
	_check(SNIPER.fire_mode == FirearmDefinition.FireMode.SINGLE_SHOT, "Sniper must use the reusable SINGLE_SHOT mode")
	_check(SNIPER.magazine_size == 5, "Sniper magazine must hold five rounds")
	_check(is_equal_approx(SNIPER.shot_interval, 1.5), "Sniper cooldown must be 1.5 seconds")
	_check(is_equal_approx(SNIPER.reload_time, 2.5), "Sniper full-magazine reload must be 2.5 seconds")
	_check(SNIPER.supports_individual_round_loading() and is_equal_approx(SNIPER.individual_round_reload_time, 1.5), "Sniper must support a 1.5-second single-round load")
	_check(SNIPER.damage_for_zone(&"LOWER_BODY") == 200.0 and SNIPER.damage_for_zone(&"TORSO") == 300.0 and SNIPER.damage_for_zone(&"HEAD") == 400.0, "Sniper damage must be 200/300/400")
	_check(SNIPER.ads_fov_override >= 25.0 and SNIPER.ads_fov_override <= 35.0, "Scoped ADS must use a 25–35 degree FOV")
	_check(SNIPER.has_advanced_scope_zoom and is_equal_approx(SNIPER.advanced_scope_fov, 18.0), "Sniper must expose exactly one data-driven advanced scope zoom")
	_check(SNIPER.ads_motion_multiplier_override <= 0.05 and SNIPER.scope_overlay_scene != null, "Scoped ADS must provide low sway and a scope overlay")


func _validate_existing_weapons() -> void:
	_check(PISTOL.fire_mode == FirearmDefinition.FireMode.SEMI_AUTO and PISTOL.damage_for_zone(&"TORSO") == 70.0, "Pistol behavior must remain unchanged")
	_check(SMG.fire_mode == FirearmDefinition.FireMode.AUTOMATIC and is_equal_approx(SMG.shot_interval, 0.08) and SMG.damage_for_zone(&"TORSO") == 65.0, "SMG behavior must remain unchanged")
	_check(CARBINE.fire_mode == FirearmDefinition.FireMode.AUTOMATIC and is_equal_approx(CARBINE.shot_interval, 0.1) and CARBINE.damage_for_zone(&"TORSO") == 80.0, "Carbine behavior must remain unchanged")
	_check(PROPER_SUPPRESSOR.supports_weapon(&"carbine_ar") and PROPER_SUPPRESSOR.supports_weapon(&"sniper_rifle") and not PROPER_SUPPRESSOR.supports_weapon(&"pistol"), "Proper suppressor compatibility must remain limited to Carbine and Sniper")
	_check(MAKESHIFT_SUPPRESSOR.supports_weapon(&"pistol") and MAKESHIFT_SUPPRESSOR.supports_weapon(&"smg") and not MAKESHIFT_SUPPRESSOR.supports_weapon(&"sniper_rifle"), "Makeshift suppressor compatibility must remain limited to Pistol and SMG")


func _validate_input() -> void:
	var bound := false
	for event in InputMap.action_get_events("reload_single_round"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_R and (event as InputEventKey).shift_pressed:
			bound = true
	_check(bound, "Reusable single-round load input must be bound to Shift+R")
	_check(_action_has_mouse_button(&"scope_zoom_in", MOUSE_BUTTON_WHEEL_UP) and _action_has_mouse_button(&"scope_zoom_out", MOUSE_BUTTON_WHEEL_DOWN), "Sniper advanced zoom must use dedicated mouse-wheel scope actions")


func _validate_world_pickup() -> void:
	var pickup := _range.get_node_or_null("Interactables/SniperRiflePickup") as FirearmPickup
	_check(pickup != null and pickup.definition == SNIPER, "The SNIPER range placeholder must be replaced by a functional pickup")
	if pickup == null: return
	_check(pickup.label.text == "SNIPER RIFLE\n[E] PICK UP", "Sniper range pickup must be clearly labeled")
	var root := pickup.get_node_or_null("VisualMount/WeaponRoot") as Node3D
	_check(root != null, "Sniper pickup must instantiate its world model")
	if root == null: return
	for part in ["Receiver", "PrecisionBarrel", "MuzzleBrake", "ScopeBody", "ScopeObjectiveHousing", "ScopeEyepiece", "AdjustableCheekRest", "DetachableBoxMagazine", "FoldedBipodLeft", "FoldedBipodRight", "BoltHandle", "PickupCollider"]:
		_check(root.find_child(part, true, false) != null, "Sniper world model is missing recognizable part: %s" % part)
	var collider := root.find_child("PickupCollider", true, false) as CollisionShape3D
	var shape := collider.shape as BoxShape3D if collider else null
	_check(shape != null and shape.size.x >= 2.7, "Sniper world silhouette must be visibly longer than the Carbine")


func _validate_inventory_and_equip() -> void:
	_controller.unequip_current()
	InventoryManager.clear_all_inventory(false)
	_check(InventoryManager.add_item(PISTOL) and InventoryManager.add_item(CARBINE), "Two existing firearms must fill both slots")
	_check(not InventoryManager.add_item(SNIPER) and InventoryManager.get_last_feedback() == InventoryComponent.FIREARM_SLOTS_FULL, "Sniper pickup must respect the two-firearm slot limit")
	InventoryManager.clear_all_inventory(false)
	_check(InventoryManager.add_item(SNIPER), "Sniper must enter firearm slot 1")
	_check(_controller.equip_slot(InventoryComponent.FIREARM_SLOT_1), "Sniper must equip through the shared controller")
	await get_tree().process_frame
	_check(_controller.current_firearm != null and _controller.current_firearm.definition == SNIPER, "Equipped runtime must use sniper data")


func _validate_first_person_visual() -> void:
	var visual := _controller.current_firearm.get_visual()
	_check(visual is FirearmVisualBase and visual.validate_visual_contract().is_empty(), "Sniper FP model must satisfy the shared visual contract")
	for part in ["RightHand", "LeftHand", "ScopeObjectiveLens", "ScopeRearGlass", "ElevationTurret", "WindageTurret", "MuzzleFlash", "LooseRound", "SuppressorAttachmentPoint"]:
		_check(visual.find_child(part, true, false) != null, "Sniper FP model is missing: %s" % part)


func _validate_scope_ads() -> void:
	_check(_controller.is_crosshair_visible() and not _controller.is_scope_overlay_visible(), "Hip stance must use the shared crosshair without the scope overlay")
	_controller._set_aim_held(true)
	await _advance_frames(50)
	_check(_controller.ads_active and _controller.get_ads_blend() > 0.98, "Holding RMB must settle into scoped ADS")
	_check(absf(_player.camera.fov - 30.0) < 0.75, "Sniper ADS must smoothly settle at 30-degree FOV")
	_check(not _controller.is_crosshair_visible() and _controller.is_scope_overlay_visible(), "Scope reticle must replace the hip crosshair")
	var overlay := _controller._scope_overlay
	var center := _player.get_viewport().get_visible_rect().size * 0.5
	_check(overlay != null and overlay.has_method("get_reticle_center") and (overlay.call("get_reticle_center") as Vector2).distance_to(center) < 0.1, "Scope reticle must share the exact center of the firing ray")
	var metrics := _controller.get_sight_alignment_pixels()
	_check(float(metrics.get("ads_error", INF)) <= 4.0 and float(metrics.get("rear_error", INF)) <= 4.0 and float(metrics.get("front_error", INF)) <= 4.0, "Scope axis must align within four pixels of the camera ray")
	_check(_controller.get_current_spread_degrees() <= 0.02, "Scoped sniper spread must be effectively precise")
	_check(_controller.set_advanced_scope_zoom(true), "Scoped sniper must accept its one advanced zoom step")
	await _advance_frames(50)
	_check(_controller.is_advanced_scope_zoom_active() and absf(_player.camera.fov - 18.0) < 0.75, "Advanced sniper zoom must smoothly settle at 18-degree FOV")
	_check(_controller.set_advanced_scope_zoom(true) and _controller.is_advanced_scope_zoom_active(), "Additional zoom-in attempts must remain clamped to the one advanced level")
	_check(_controller.set_advanced_scope_zoom(false), "Scope zoom-out must return to standard magnification")
	await _advance_frames(50)
	_check(not _controller.is_advanced_scope_zoom_active() and absf(_player.camera.fov - 30.0) < 0.75, "Scope zoom-out must smoothly restore standard 30-degree FOV")
	_controller._set_aim_held(false)
	await _advance_frames(50)
	_check(not _controller.ads_active and not _controller.is_scope_overlay_visible() and _controller.is_crosshair_visible(), "Releasing RMB must restore hip view and shared crosshair")
	_check(absf(_player.camera.fov - _controller.normal_fov) < 0.75, "Releasing RMB must restore the normal camera FOV")
	_controller._set_aim_held(true)
	await _advance_frames(50)


func _validate_single_shot_and_recoil() -> void:
	var firearm := _controller.current_firearm
	firearm.refill_ammo()
	_check(_controller.fire(), "Fresh sniper must fire")
	_check(firearm.magazine_ammo == 4, "A sniper shot must consume exactly one round")
	_check(not _controller.fire() and firearm.magazine_ammo == 4, "Cooldown must reject an immediate second shot")
	_check(_controller.get_camera_recoil_degrees() >= 1.0 and _controller.get_weapon_recoil_amount() >= 1.0, "Sniper shot must deliver strong camera and weapon recoil")
	await _physics_frames(95)
	_check(_controller.fire() and firearm.magazine_ammo == 3, "Sniper must fire again after its 1.5-second cooldown")


func _validate_damage_table() -> void:
	for target in _dummies():
		for zone in [&"LOWER_BODY", &"TORSO", &"HEAD"]:
			target.reset_target()
			target.health.apply_damage(SNIPER.damage_for_zone(zone), zone)
			_check(target.is_dead(), "%s sniper damage must kill %s at current health" % [zone, target.target_label])
	var standard := _dummy("STANDARD VEST")
	standard.reset_target()
	var torso := _zone(standard, &"TORSO")
	var chest := torso.get_node("ChestVisual") as MeshInstance3D
	_player.global_position = standard.global_position + Vector3(0, 0.95, 8.0)
	_player.velocity = Vector3.ZERO
	_player.camera.look_at(chest.global_position, Vector3.UP)
	_controller.current_firearm.refill_ammo()
	_controller.current_firearm.cooldown_remaining = 0.0
	await get_tree().physics_frame
	_check(_controller.fire(), "Scoped firing ray must reach an aimed torso hit zone")
	var tool := _range.get_node("DamageTestTool") as DevDamageTestTool
	_check(tool.get_last_readout() == "SNIPER RIFLE\nTORSO\n300 DAMAGE\nTARGET: DEAD", "Sniper hit must report its actual TORSO zone and 300 damage through the existing readout")


func _validate_reload_paths() -> void:
	var firearm := _controller.current_firearm
	await _physics_frames(95)
	firearm.magazine_ammo = 0
	firearm.reserve_ammo = 5
	_controller._set_aim_held(true)
	await _advance_frames(12)
	_check(_controller.reload(), "Sniper full-magazine reload must start")
	_check(not _controller.ads_active and is_equal_approx(firearm.reload_remaining, 2.5), "Reload must cancel ADS and use 2.5 seconds")
	_check((firearm.get_visual() as SniperRifleVisual).is_reload_playing(), "Sniper must play a distinct full-magazine reload")
	await _physics_frames(155)
	_check(firearm.magazine_ammo == 5 and firearm.reserve_ammo == 0 and firearm.state == FirearmComponent.WeaponState.READY, "Full reload must transfer exactly five rounds once")

	firearm.magazine_ammo = 2
	firearm.reserve_ammo = 3
	_check(_controller.load_single_round(), "Shift+R API must start an individual-round load")
	_check((firearm.get_visual() as SniperRifleVisual).is_individual_round_load_playing(), "Individual load must have its own presentation")
	await _physics_frames(95)
	_check(firearm.magazine_ammo == 3 and firearm.reserve_ammo == 2, "Individual reload must transfer exactly one round")
	await _physics_frames(95)
	_check(firearm.magazine_ammo == 3 and firearm.reserve_ammo == 2, "Individual reload must not duplicate or automatically continue loading")

	firearm.magazine_ammo = 0
	firearm.reserve_ammo = 0
	firearm.cooldown_remaining = 0.0
	_check(not _controller.fire() and firearm.magazine_ammo == 0, "Empty sniper must not fire or create negative ammo")
	_check(not _controller.reload() and not _controller.load_single_round(), "Reload paths must reject an empty reserve")


func _validate_drop_and_retrieve() -> void:
	var firearm := _controller.current_firearm
	firearm.refill_ammo()
	firearm.magazine_ammo = 4
	firearm.reserve_ammo = 9
	_check(_controller.unequip_and_drop_current(), "Sniper must drop through the shared firearm-slot workflow")
	await get_tree().process_frame
	var dropped: FirearmPickup
	for node in get_tree().get_nodes_in_group("firearm_pickups"):
		if node is FirearmPickup and (node as FirearmPickup).name.begins_with("Dropped") and (node as FirearmPickup).definition == SNIPER:
			dropped = node as FirearmPickup
			break
	_check(dropped != null and dropped.saved_magazine == 4 and dropped.saved_reserve == 9, "Dropped sniper must preserve its exact 4/9 ammo state")
	_check(InventoryManager.get_firearm_slot(0) == null, "Dropping sniper must free its firearm slot")
	if dropped:
		dropped.interact(_player)
		await get_tree().process_frame
		_check(InventoryManager.get_firearm_slot(0) == SNIPER, "Dropped sniper must be pickable again")
		_check(_controller.current_firearm != null and _controller.current_firearm.magazine_ammo == 4 and _controller.current_firearm.reserve_ammo == 9, "Retrieved sniper must restore its 4/9 ammo")


func _validate_lifecycle_cleanup() -> void:
	var firearm := _controller.current_firearm
	firearm.refill_ammo()
	_controller._set_aim_held(true)
	await _advance_frames(35)
	_controller.unequip_current()
	await get_tree().process_frame
	_check(not _controller.ads_active and not _controller.is_scope_overlay_visible() and absf(_player.camera.fov - _controller.normal_fov) < 0.1, "Unequip must remove scope overlay and restore camera state")
	_check(InventoryManager.add_item(PISTOL), "Pistol must fit the second slot for cleanup regression")
	_check(_controller.equip_slot(InventoryComponent.FIREARM_SLOT_2), "Pistol must still equip after sniper")
	await get_tree().process_frame
	_check(_controller._scope_overlay == null and _controller.is_crosshair_visible(), "Non-scoped firearms must not inherit the sniper overlay")
	_controller.unequip_current()
	InventoryManager.remove_item(&"pistol")
	_controller.equip_slot(InventoryComponent.FIREARM_SLOT_1)
	await get_tree().process_frame


func _validate_dev_controls() -> void:
	_check(DevModeManager.refill_sniper_ammo(), "Dev refill sniper action must succeed")
	_check(_controller.current_firearm.magazine_ammo == 5 and _controller.current_firearm.reserve_ammo == 25, "Dev refill must restore sniper ammo to 5/25")
	_check(DevModeManager.remove_sniper_rifle(), "Dev remove sniper action must succeed")
	await get_tree().process_frame
	_check(not InventoryManager.has_item(&"sniper_rifle"), "Dev remove must clear sniper inventory")
	_check(DevModeManager.give_sniper_rifle(), "Dev give sniper action must succeed")
	_check(InventoryManager.has_item(&"sniper_rifle"), "Dev give must restore sniper inventory")


func _validate_future_only_attachment() -> void:
	var firearm := _controller.current_firearm
	_check(firearm == null or not firearm.is_suppressed(), "Sniper must begin without an attachment")
	_check(SNIPER.future_suppressor_compatible and CARBINE.future_suppressor_compatible and PISTOL.future_suppressor_compatible and SMG.future_suppressor_compatible, "All firearm visuals must advertise an attachment socket")
	var scene := SNIPER.first_person_visual_scene.instantiate()
	add_child(scene)
	await get_tree().process_frame
	_check(scene.find_child("SuppressorAttachmentPoint", true, false) != null, "Sniper must expose its suppressor attachment marker")
	scene.queue_free()


func _dummies() -> Array[DamageableHumanDummy]:
	var result: Array[DamageableHumanDummy] = []
	for node in get_tree().get_nodes_in_group("weapon_range_damage_dummies"):
		if _range.is_ancestor_of(node) and node is DamageableHumanDummy: result.append(node)
	return result


func _dummy(label: String) -> DamageableHumanDummy:
	for target in _dummies():
		if target.target_label == label: return target
	return null


func _zone(dummy: DamageableHumanDummy, zone_id: StringName) -> BodyHitZone:
	for zone in dummy.get_hit_zones():
		if zone.get_hit_zone_id() == zone_id: return zone
	return null


func _advance_frames(count: int) -> void:
	for frame in range(count):
		_controller._process(1.0 / 60.0)
		await get_tree().physics_frame


func _physics_frames(count: int) -> void:
	for frame in range(count): await get_tree().physics_frame


func _action_has_mouse_button(action: StringName, button: MouseButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)


func _finish() -> void:
	InventoryManager.clear_all_inventory(false)
	if is_instance_valid(_range): _range.free()
	DevModeManager.set_enabled(false)
	if _failures.is_empty():
		print("SNIPER RIFLE VALIDATION: PASS — two-level scoped ADS, 5-round single-shot cadence, 200/300/400 damage, dual reload paths, range pickup and Dev controls")
	else:
		for failure in _failures: push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
