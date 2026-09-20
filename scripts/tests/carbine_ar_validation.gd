extends Node3D

const RANGE := preload("res://scenes/dev/WeaponRange.tscn")
const PISTOL: FirearmDefinition = preload("res://resources/weapons/pistol.tres")
const SMG: FirearmDefinition = preload("res://resources/weapons/smg.tres")
const CARBINE: FirearmDefinition = preload("res://resources/weapons/carbine_ar.tres")

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
	_validate_existing_firearms()

	DevModeManager.set_enabled(true)
	_range = RANGE.instantiate() as WeaponRange
	add_child(_range)
	for frame in range(4):
		await get_tree().process_frame
	await get_tree().physics_frame
	_player = _range.get_node("Actors/WeaponRangePlayer") as PlayerController
	_controller = _player.get_node("WeaponController") as PlayerWeaponController

	_validate_world_pickup()
	await _validate_inventory_and_equip()
	if _controller.current_firearm == null:
		_finish()
		return
	_validate_first_person_visual()
	await _validate_ads()
	await _validate_automatic_fire_and_recoil()
	_validate_damage_table()
	await _validate_empty_magazine_and_reload()
	await _validate_drop_and_pickup()
	_validate_future_compatibility()
	await _validate_dev_controls()
	_finish()


func _validate_definition() -> void:
	_check(CARBINE.weapon_id == &"carbine_ar" and CARBINE.item_id == &"carbine_ar", "Carbine IDs must be data-driven and consistent")
	_check(CARBINE.display_name == "Carbine AR", "Carbine display name must be Carbine AR")
	_check(CARBINE.category == ItemDefinition.Category.FIREARM, "Carbine must use the FIREARM category")
	_check(CARBINE.fire_mode == FirearmDefinition.FireMode.AUTOMATIC, "Carbine must use automatic fire")
	_check(is_equal_approx(CARBINE.shot_interval, 0.1), "Carbine automatic cadence must be 0.10s per round (600 RPM)")
	_check(is_equal_approx(CARBINE.reload_time, 1.5), "Carbine reload must be exactly 1.5 seconds")
	_check(CARBINE.magazine_size == 30, "Carbine magazine must hold 30 rounds")
	_check(CARBINE.damage_for_zone(&"LOWER_BODY") == 35.0, "Carbine lower-body damage must be 35")
	_check(CARBINE.damage_for_zone(&"TORSO") == 80.0, "Carbine torso damage must be 80")
	_check(CARBINE.damage_for_zone(&"HEAD") == 150.0, "Carbine head damage must be 150")
	_check(CARBINE.ads_spread_degrees < SMG.ads_spread_degrees, "Carbine ADS must be more precise than the SMG")
	_check(CARBINE.hip_fire_spread_degrees < SMG.hip_fire_spread_degrees, "Carbine hip fire must be more controlled than the SMG")
	_check(CARBINE.ads_spread_degrees < CARBINE.hip_fire_spread_degrees * 0.25, "Carbine ADS spread must be much tighter than hip fire")
	_check(CARBINE.recoil_camera_degrees_override > 0.75, "Carbine per-shot camera kick must be stronger than the shared pistol kick")
	_check(CARBINE.horizontal_recoil_degrees < SMG.horizontal_recoil_degrees, "Carbine horizontal recoil must be milder than the SMG")


func _validate_existing_firearms() -> void:
	_check(PISTOL.magazine_size == 8 and PISTOL.fire_mode == FirearmDefinition.FireMode.SEMI_AUTO, "Pistol must remain an 8-round semi-automatic")
	_check(PISTOL.damage_for_zone(&"LOWER_BODY") == 30.0 and PISTOL.damage_for_zone(&"TORSO") == 70.0 and PISTOL.damage_for_zone(&"HEAD") == 120.0, "Pistol damage must remain 30/70/120")
	_check(SMG.magazine_size == 25 and SMG.fire_mode == FirearmDefinition.FireMode.AUTOMATIC and is_equal_approx(SMG.shot_interval, 0.08), "SMG must remain a 25-round automatic firearm at 750 RPM")
	_check(SMG.damage_for_zone(&"LOWER_BODY") == 30.0 and SMG.damage_for_zone(&"TORSO") == 65.0 and SMG.damage_for_zone(&"HEAD") == 140.0, "SMG damage must remain 30/65/140")
	var directory := DirAccess.open("res://resources/weapons")
	var resources: Array[String] = []
	if directory:
		directory.list_dir_begin()
		var file_name := directory.get_next()
		while file_name != "":
			if not directory.current_is_dir() and file_name.ends_with(".tres"):
				var resource := load("res://resources/weapons/%s" % file_name)
				if resource is FirearmDefinition: resources.append(file_name)
			file_name = directory.get_next()
		directory.list_dir_end()
	resources.sort()
	_check(resources == ["carbine_ar.tres", "pistol.tres", "smg.tres", "sniper_rifle.tres"], "Pistol, SMG, Carbine and Sniper firearm definitions must be registered, found: %s" % str(resources))


func _validate_world_pickup() -> void:
	var pickup := _range.get_node_or_null("Interactables/CarbineARPickup") as FirearmPickup
	_check(pickup != null and pickup.definition == CARBINE, "The real Carbine pickup must replace its range placeholder")
	if pickup == null:
		return
	var visual := pickup.get_node_or_null("VisualMount/WeaponRoot") as Node3D
	_check(visual != null, "Carbine pickup must instantiate CarbineAR_World")
	if visual == null:
		return
	for part in [
		"Receiver", "DustCover", "Barrel", "Muzzle", "FrontSightPost",
		"RearSightBlock", "GasTube", "UpperHandguard", "LowerHandguard",
		"CurvedMagazineSegment1", "CurvedMagazineSegment2", "CurvedMagazineSegment3",
		"Trigger", "TriggerGuardBow", "PistolGrip", "WoodStock",
		"ChargingHandle", "Magazine", "PickupCollider", "InteractionAnchor",
		"MuzzlePoint", "MagazineSocket", "SuppressorAttachmentPoint",
	]:
		_check(visual.find_child(part, true, false) != null, "Carbine world model is missing recognizable part: %s" % part)
	var stock := visual.find_child("WoodStock", true, false) as MeshInstance3D
	var handguard := visual.find_child("LowerHandguard", true, false) as MeshInstance3D
	_check(_is_ak_wood(stock) and _is_ak_wood(handguard), "Carbine stock and handguard must use the dedicated warm varnished wood finish")


func _validate_inventory_and_equip() -> void:
	_controller.unequip_current()
	InventoryManager.clear_all_inventory(false)
	_check(InventoryManager.add_item(PISTOL), "Pistol must fill firearm slot 1")
	_check(InventoryManager.add_item(SMG), "SMG must fill firearm slot 2")
	_check(not InventoryManager.add_item(CARBINE), "Carbine must be rejected when both firearm slots are occupied")
	_check(InventoryManager.get_last_feedback() == InventoryComponent.FIREARM_SLOTS_FULL, "A full loadout must report FIREARM SLOTS FULL")
	var range_pickup := _range.get_node_or_null("Interactables/CarbineARPickup") as FirearmPickup
	_check(range_pickup != null and range_pickup.get_interaction_prompt(_player).contains("[G] DROP EQUIPPED"), "A full-slot pickup prompt must explain how to drop the equipped weapon")
	InventoryManager.clear_all_inventory(false)
	_check(InventoryManager.add_item(PISTOL), "Pistol must be addable after clearing")
	_check(InventoryManager.add_item(CARBINE), "Carbine must occupy the second firearm slot")
	_check(InventoryManager.get_firearm_slot(1) == CARBINE, "Carbine definition must remain in firearm slot 2")
	_check(_controller.equip_slot(InventoryComponent.FIREARM_SLOT_2), "Carbine must equip from firearm slot 2")
	await get_tree().process_frame
	_check(_controller.current_firearm != null and _controller.current_firearm.definition == CARBINE, "Equipped runtime must use the Carbine definition")


func _validate_first_person_visual() -> void:
	var visual := _controller.current_firearm.get_visual()
	_check(visual is FirearmVisualBase, "Carbine first-person model must use FirearmVisualBase")
	if visual == null:
		return
	_check(visual.validate_visual_contract().is_empty(), "Carbine first-person model must satisfy every shared visual anchor")
	for part in ["RightHand", "LeftHand", "Magazine", "ADSAnchor", "RearSightAimPoint", "FrontSightAimPoint", "MuzzleFlashPoint", "SuppressorAttachmentPoint"]:
		_check(visual.find_child(part, true, false) != null, "Carbine first-person model is missing: %s" % part)


func _validate_ads() -> void:
	_check(_controller.is_crosshair_visible(), "Carbine hip stance must show the shared crosshair")
	_controller._set_aim_held(true)
	await _advance_frames(45)
	_check(_controller.ads_active and _controller.get_ads_blend() > 0.98, "Holding RMB state must smoothly settle into Carbine ADS")
	_check(absf(_player.camera.fov - _controller.ads_fov) < 0.75, "Carbine ADS must narrow the shared camera FOV")
	_check(not _controller.is_crosshair_visible(), "Normal crosshair must hide behind the Carbine iron sights")
	_check(_controller.get_current_spread_degrees() < CARBINE.hip_fire_spread_degrees * 0.25, "Carbine ADS must tighten accuracy")
	var metrics := _controller.get_sight_alignment_pixels()
	_check(float(metrics.get("ads_error", INF)) <= 4.0, "Carbine ADS anchor must align within four pixels of the firing ray")
	_check(float(metrics.get("rear_error", INF)) <= 4.0, "Carbine rear sight must align within four pixels of the firing ray")
	_check(float(metrics.get("front_error", INF)) <= 4.0, "Carbine front sight must align within four pixels of the firing ray")
	_check(float(metrics.get("sight_separation", INF)) <= 4.0, "Carbine front/rear sights must form a coherent sight picture")
	_controller._set_aim_held(false)
	await _advance_frames(45)
	_check(not _controller.ads_active and _controller.is_crosshair_visible(), "Releasing aim must restore Carbine hip stance and crosshair")


func _validate_automatic_fire_and_recoil() -> void:
	var firearm := _controller.current_firearm
	firearm.refill_ammo()
	var shot_count := {"value": 0}
	firearm.shot_fired.connect(func(_definition: FirearmDefinition, _magazine: int, _reserve: int) -> void: shot_count.value += 1)
	Input.action_press("fire_weapon")
	for frame in range(38):
		await get_tree().physics_frame
	Input.action_release("fire_weapon")
	var rounds_fired := int(shot_count.value)
	_check(rounds_fired >= 5 and rounds_fired <= 8, "Holding Carbine fire for about 0.6s must produce a 600 RPM rate-limited stream, found %d rounds" % rounds_fired)
	_check(firearm.magazine_ammo == 30 - rounds_fired, "Every Carbine automatic shot must consume exactly one round")
	_check(_controller.get_camera_recoil_degrees() > 0.0, "Carbine recoil must climb during sustained automatic fire")
	var ammo_after_release := firearm.magazine_ammo
	for frame in range(24):
		await get_tree().physics_frame
	_check(firearm.magazine_ammo == ammo_after_release, "Releasing LMB must stop Carbine fire immediately")
	for frame in range(35):
		await get_tree().physics_frame
	_check(_controller.get_camera_recoil_degrees() < 0.02, "Carbine aim must recover smoothly after trigger release")


func _validate_damage_table() -> void:
	var unarmored := _dummy("UNARMORED")
	var standard := _dummy("STANDARD VEST")
	var advanced := _dummy("ADVANCED VEST")
	unarmored.reset_target()
	unarmored.health.apply_damage(CARBINE.damage_for_zone(&"TORSO"), &"TORSO")
	_check(is_equal_approx(unarmored.get_current_health(), 20.0), "One Carbine torso hit must leave 20 of 100 HP")
	standard.reset_target()
	standard.health.apply_damage(CARBINE.damage_for_zone(&"TORSO"), &"TORSO")
	_check(is_equal_approx(standard.get_current_health(), 45.0), "One Carbine torso hit must leave 45 of 125 HP")
	advanced.reset_target()
	advanced.health.apply_damage(CARBINE.damage_for_zone(&"TORSO"), &"TORSO")
	_check(is_equal_approx(advanced.get_current_health(), 70.0), "One Carbine torso hit must leave 70 of 150 HP")
	for target in [unarmored, standard, advanced]:
		target.reset_target()
		target.health.apply_damage(CARBINE.damage_for_zone(&"HEAD"), &"HEAD")
		_check(target.is_dead(), "A 150-damage Carbine head hit must kill every current armor state")
	unarmored.reset_target()
	for hit in range(3):
		unarmored.health.apply_damage(CARBINE.damage_for_zone(&"LOWER_BODY"), &"LOWER_BODY")
	_check(unarmored.is_dead(), "Three 35-damage lower-body hits must kill a 100 HP target")


func _validate_empty_magazine_and_reload() -> void:
	var firearm := _controller.current_firearm
	firearm.magazine_ammo = 2
	firearm.reserve_ammo = 30
	var shot_count := {"value": 0}
	firearm.shot_fired.connect(func(_definition: FirearmDefinition, _magazine: int, _reserve: int) -> void: shot_count.value += 1)
	Input.action_press("fire_weapon")
	for frame in range(30):
		await get_tree().physics_frame
	Input.action_release("fire_weapon")
	_check(int(shot_count.value) == 2, "A two-round automatic magazine must produce exactly two shots")
	_check(firearm.magazine_ammo == 0 and firearm.state == FirearmComponent.WeaponState.EMPTY, "Automatic fire must stop at zero with EMPTY state")
	_check(not _controller.fire() and firearm.magazine_ammo == 0, "Dry fire must not emit a shot or create negative ammo")
	_check(_controller.reload(), "Empty Carbine must still reload")
	_check(is_equal_approx(firearm.reload_remaining, 1.5), "Carbine reload timer must begin at exactly 1.5 seconds")
	var visual := firearm.get_visual()
	_check(visual != null and visual.is_reload_playing(), "Carbine must play its rifle reload presentation")
	await get_tree().create_timer(0.40).timeout
	_check(visual.get_magazine_offset() > 0.05, "Curved Carbine magazine must visibly leave its socket during reload")
	for frame in range(75):
		await get_tree().physics_frame
	_check(firearm.magazine_ammo == 30 and firearm.reserve_ammo == 0, "Carbine reload must transfer 30 reserve rounds into its magazine")
	_check(firearm.state == FirearmComponent.WeaponState.READY and visual.is_magazine_visible(), "Reload must restore ready state and visible magazine")


func _validate_drop_and_pickup() -> void:
	var firearm := _controller.current_firearm
	firearm.magazine_ammo = 17
	firearm.reserve_ammo = 71
	var player_position := _player.global_position
	var has_g_binding := false
	for event in InputMap.action_get_events("drop_weapon"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_G:
			has_g_binding = true
	_check(has_g_binding, "The drop_weapon action must remain bound to G")
	var drop_event := InputEventAction.new()
	drop_event.action = &"drop_weapon"
	drop_event.pressed = true
	_controller._unhandled_input(drop_event)
	_check(InventoryManager.get_firearm_slot(1) == null, "Dropping Carbine must clear its firearm slot")
	_check(_controller.current_firearm == null, "Dropping must fully unequip the Carbine")
	_check(InventoryManager.get_last_feedback() == "WEAPON DROPPED — FIREARM SLOT FREED", "Dropping must clearly report that the firearm slot is free")
	var dropped: FirearmPickup
	for node in get_tree().get_nodes_in_group("firearm_pickups"):
		if node is FirearmPickup and (node as FirearmPickup).definition == CARBINE and (node as FirearmPickup).name.begins_with("Dropped"):
			dropped = node as FirearmPickup
			break
	_check(dropped != null, "Dropping must spawn a real Carbine world pickup")
	if dropped:
		_check(dropped.saved_magazine == 17 and dropped.saved_reserve == 71, "Dropped Carbine must preserve 17/71 ammo")
		var horizontal_distance := Vector2(dropped.global_position.x - player_position.x, dropped.global_position.z - player_position.z).length()
		_check(horizontal_distance <= 1.2, "Dropped Carbine must land at the player's feet, found %.2fm away" % horizontal_distance)
		_check(InventoryManager.add_item(SMG), "The freed firearm slot must immediately accept a different weapon")
		_check(InventoryManager.get_firearm_slot(1) == SMG, "SMG must occupy the slot freed by dropping the Carbine")
		_check(InventoryManager.remove_item(&"smg"), "Test SMG must be removable before retrieving the Carbine")
		dropped.interact(_player)
		await get_tree().process_frame
		_check(InventoryManager.get_firearm_slot(1) == CARBINE, "Picking the dropped Carbine back up must restore its slot")
		_controller.equip_slot(1)
		await get_tree().process_frame
		_check(_controller.current_firearm.magazine_ammo == 17 and _controller.current_firearm.reserve_ammo == 71, "Re-equipped Carbine must restore 17/71 ammo")


func _validate_future_compatibility() -> void:
	var firearm := _controller.current_firearm
	_check(firearm != null and firearm.get_visual().find_child("SuppressorAttachmentPoint", true, false) != null, "Carbine must retain its reusable suppressor attachment point")


func _validate_dev_controls() -> void:
	_check(DevModeManager.refill_carbine_ammo(), "Dev refill Carbine action must succeed")
	_check(_controller.current_firearm.magazine_ammo == 30 and _controller.current_firearm.reserve_ammo == 120, "Dev refill must restore Carbine ammo to 30/120")
	_check(DevModeManager.remove_carbine_ar(), "Dev remove Carbine action must succeed")
	await get_tree().process_frame
	_check(not InventoryManager.has_item(&"carbine_ar"), "Dev remove must clear Carbine from inventory")
	_check(DevModeManager.give_carbine_ar(), "Dev give Carbine action must succeed")
	_check(InventoryManager.has_item(&"carbine_ar"), "Dev give must restore Carbine to inventory")


func _dummy(label: String) -> DamageableHumanDummy:
	for node in get_tree().get_nodes_in_group("weapon_range_damage_dummies"):
		if _range.is_ancestor_of(node) and node is DamageableHumanDummy and (node as DamageableHumanDummy).target_label == label:
			return node as DamageableHumanDummy
	return null


func _is_ak_wood(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance == null or mesh_instance.material_override == null:
		return false
	var material := mesh_instance.material_override as StandardMaterial3D
	if material == null:
		return false
	var finish := preload("res://materials/props/wood_ak_furniture.tres")
	return material.albedo_texture == finish.albedo_texture and material.uv1_triplanar and not material.uv1_world_triplanar and material.roughness <= 0.5


func _advance_frames(count: int) -> void:
	for frame in range(count):
		_controller._process(1.0 / 60.0)
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	InventoryManager.clear_all_inventory(false)
	if is_instance_valid(_range):
		_range.free()
	DevModeManager.set_enabled(false)
	if _failures.is_empty():
		print("CARBINE AR VALIDATION: PASS — AK-pattern visuals, held automatic fire at 600 RPM, 35/80/150 damage, precise ADS, recoil, reload, drop/swap, and Dev controls")
	else:
		for failure in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
