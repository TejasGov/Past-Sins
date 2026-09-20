extends Node3D

const RANGE := preload("res://scenes/dev/WeaponRange.tscn")
const PISTOL: FirearmDefinition = preload("res://resources/weapons/pistol.tres")
const SMG: FirearmDefinition = preload("res://resources/weapons/smg.tres")

var _failures: Array[String] = []
var _range: WeaponRange
var _player: PlayerController
var _controller: PlayerWeaponController
var _tool: DevDamageTestTool


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	DevModeManager.set_enabled(false)
	InventoryManager.clear_all_inventory(false)

	# 1. SMG DEFINITION
	_check(SMG.weapon_id == &"smg" and SMG.item_id == &"smg", "SMG IDs must be data-driven and consistent")
	_check(SMG.display_name == "SMG", "SMG display name must be 'SMG'")
	_check(SMG.fire_mode == FirearmDefinition.FireMode.AUTOMATIC, "SMG fire mode must be AUTOMATIC")
	_check(is_equal_approx(SMG.shot_interval, 0.08), "SMG automatic cadence must be 0.08s per round (750 RPM)")
	_check(is_equal_approx(SMG.reload_time, 1.5), "SMG reload time must be exactly 1.5s")
	_check(SMG.magazine_size == 25, "SMG magazine size must be 25 rounds")
	_check(SMG.damage_for_zone(&"LOWER_BODY") == 30.0, "SMG lower body damage must be 30")
	_check(SMG.damage_for_zone(&"TORSO") == 65.0, "SMG torso damage must be 65")
	_check(SMG.damage_for_zone(&"HEAD") == 140.0, "SMG head damage must be 140")
	_check(SMG.hip_fire_spread_degrees > PISTOL.ads_spread_degrees, "SMG hip-fire spread must be wider than pistol ADS")
	_check(SMG.ads_spread_degrees < SMG.hip_fire_spread_degrees, "SMG ADS spread must be noticeably tighter than hip-fire")

	# 16. PISTOL BEHAVIOR UNCHANGED
	_check(PISTOL.weapon_id == &"pistol" and PISTOL.magazine_size == 8 and PISTOL.fire_mode == FirearmDefinition.FireMode.SEMI_AUTO, "Pistol must remain 8-round semi-auto")
	_check(PISTOL.damage_for_zone(&"LOWER_BODY") == 30.0 and PISTOL.damage_for_zone(&"TORSO") == 70.0 and PISTOL.damage_for_zone(&"HEAD") == 120.0, "Pistol damage table must remain unchanged")

	# 20. NO OTHER NEW WEAPONS ADDED
	var dir := DirAccess.open("res://resources/weapons")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		var weapon_resources: Array[String] = []
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var resource := load("res://resources/weapons/%s" % file_name)
				if resource is FirearmDefinition: weapon_resources.append(file_name)
			file_name = dir.get_next()
		weapon_resources.sort()
		_check(weapon_resources == ["carbine_ar.tres", "pistol.tres", "smg.tres", "sniper_rifle.tres"], "All four implemented firearm resources must exist, found: %s" % str(weapon_resources))

	DevModeManager.set_enabled(true)
	_range = RANGE.instantiate() as WeaponRange
	add_child(_range)
	for frame in range(4):
		await get_tree().process_frame
	await get_tree().physics_frame

	_player = _range.get_node("Actors/WeaponRangePlayer") as PlayerController
	_controller = _player.get_node("WeaponController") as PlayerWeaponController
	_tool = _range.get_node("DamageTestTool") as DevDamageTestTool

	# 2. WORLD MODEL & SCALE BESIDE PISTOL
	var smg_pickup := _range.get_node_or_null("Interactables/SMGPickup") as FirearmPickup
	var pistol_pickup := _range.get_node_or_null("Interactables/PistolPickup") as FirearmPickup
	_check(smg_pickup != null and smg_pickup.definition == SMG, "SMG rack position must contain the real SMG pickup")
	_check(pistol_pickup != null and pistol_pickup.definition == PISTOL, "Pistol rack position must remain intact")
	if smg_pickup:
		var world_visual := smg_pickup.get_node_or_null("VisualMount/WeaponRoot") as Node3D
		_check(world_visual != null, "SMG pickup must instantiate SMG_World scene")
		if world_visual:
			_check(world_visual.find_child("PickupCollider", true, false) != null, "SMG world model must have PickupCollider")
			_check(world_visual.find_child("InteractionAnchor", true, false) != null, "SMG world model must have InteractionAnchor")
			_check(world_visual.find_child("MuzzlePoint", true, false) != null, "SMG world model must have MuzzlePoint")
			_check(world_visual.find_child("MagazineSocket", true, false) != null, "SMG world model must have MagazineSocket")
			_check(world_visual.find_child("SuppressorAttachmentPoint", true, false) != null, "SMG world model must have SuppressorAttachmentPoint")
			for part in ["Receiver", "Barrel", "Muzzle", "FrontSight", "RearSight", "Trigger", "TriggerGuard", "PistolGrip", "Stock", "Handguard", "Bolt", "ChargingHandle", "EjectionPort"]:
				_check(world_visual.find_child(part, true, false) != null, "SMG world model missing required part: %s" % part)

	# 17. FIREARM SLOT LIMITS & LOADOUT INTEGRATION
	_controller.unequip_current()
	InventoryManager.clear_all_inventory(false)
	_check(InventoryManager.add_item(PISTOL), "Must be able to add pistol to slot 1")
	_check(InventoryManager.add_item(SMG), "Must be able to add SMG to slot 2")
	_check(InventoryManager.get_firearm_slot(0) == PISTOL, "Slot 1 must contain pistol")
	_check(InventoryManager.get_firearm_slot(1) == SMG, "Slot 2 must contain SMG")
	# Try 3rd firearm
	_check(not InventoryManager.add_item(PISTOL), "3rd firearm must be rejected when slots are full")

	# Equip SMG (Slot 2)
	_check(_controller.equip_slot(InventoryComponent.FIREARM_SLOT_2), "Must be able to equip SMG from slot 2")
	await get_tree().process_frame
	var firearm := _controller.current_firearm
	_check(firearm != null and firearm.definition == SMG, "Equipped firearm must be SMG")

	# 3. FIRST-PERSON MODEL
	var fp_visual := firearm.get_visual() if firearm else null
	_check(fp_visual != null, "SMG must instantiate SMG_FP first-person visual")
	if fp_visual:
		_check(fp_visual is FirearmVisualBase, "SMG visual must use the shared firearm presentation contract")
		_check(fp_visual.validate_visual_contract().is_empty(), "SMG visual must provide every standardized first-person anchor")
		_check(fp_visual.find_child("RightHand", true, false) != null, "SMG FP must have RightHand")
		_check(fp_visual.find_child("LeftHand", true, false) != null, "SMG FP must have LeftHand")
		_check(fp_visual.find_child("ADSAnchor", true, false) != null, "SMG FP must have ADSAnchor")
		_check(fp_visual.find_child("HipAnchor", true, false) != null, "SMG FP must have HipAnchor")
		_check(fp_visual.find_child("MuzzleFlashPoint", true, false) != null, "SMG FP must have MuzzleFlashPoint")
		_check(fp_visual.find_child("SuppressorAttachmentPoint", true, false) != null, "SMG FP must have SuppressorAttachmentPoint")
		_check(fp_visual.find_child("Magazine", true, false) != null, "SMG FP must have separate Magazine node")

	# 19. NO SUPPRESSOR BEHAVIOR
	_check(not firearm.has_meta("suppressor_attached"), "No suppressor behavior must be implemented yet")

	# 12 & 13. ADS AND CROSSHAIR
	_check(_controller.is_crosshair_visible(), "SMG in hip stance must show crosshair")
	_send_aim_event(true)
	await _advance_frames(35)
	_check(_controller.ads_active and _controller.get_ads_blend() > 0.95, "Holding aim must transition to ADS")
	_check(absf(_player.camera.fov - _controller.ads_fov) < 1.0, "ADS must narrow FOV to 60")
	_check(not _controller.is_crosshair_visible(), "Crosshair must hide during SMG ADS")
	_check(_controller.get_current_spread_degrees() < SMG.hip_fire_spread_degrees * 0.35, "ADS spread must be noticeably tighter")
	if fp_visual:
		var sight_metrics := _controller.get_sight_alignment_pixels()
		var screen_center := sight_metrics.get("screen_center", Vector2.ZERO) as Vector2
		var sight_tolerance := maxf(8.0, screen_center.y * 0.025)
		_check(float(sight_metrics.get("ads_error", INF)) <= sight_tolerance, "SMG ADS anchor must remain centered on the camera firing ray")
		_check(float(sight_metrics.get("front_error", INF)) <= sight_tolerance, "SMG front sight must remain aligned with the camera firing ray")
		_check(float(sight_metrics.get("sight_separation", INF)) <= sight_tolerance, "SMG rear and front sights must form a consistent sight picture")
	_check(SMG.custom_ads_position.z <= 0.2, "SMG ADS pose must stay far enough forward that the receiver does not obscure the target")
	_send_aim_event(false)
	await _advance_frames(35)
	_check(not _controller.ads_active, "Releasing aim must return to hip stance")
	_check(_controller.is_crosshair_visible(), "Crosshair must be visible again in hip stance")

	# AUTOMATIC FIRE: hold to fire at the configured cadence, release to stop.
	var target := _dummy("ADVANCED VEST")
	target.reset_target()
	firearm.refill_ammo()
	_check(firearm.magazine_ammo == 25, "SMG magazine must start with 25 rounds")
	await _aim_at(target, &"TORSO")
	_tool.reset_targets()
	var shot_count := {"value": 0}
	firearm.shot_fired.connect(func(_definition: FirearmDefinition, _magazine: int, _reserve: int) -> void: shot_count.value += 1)
	Input.action_press("fire_weapon")
	for frame in range(34):
		await get_tree().physics_frame
	Input.action_release("fire_weapon")
	var rounds_fired := int(shot_count.value)
	_check(rounds_fired >= 5 and rounds_fired <= 9, "Holding SMG fire for about half a second must produce a rate-limited automatic stream, found %d rounds" % rounds_fired)
	_check(firearm.magazine_ammo == 25 - rounds_fired, "Every SMG automatic shot must consume exactly one round")
	var ammo_after_release := firearm.magazine_ammo
	for frame in range(20):
		await get_tree().physics_frame
	_check(firearm.magazine_ammo == ammo_after_release, "Releasing LMB must stop SMG fire immediately")
	for frame in range(35):
		await get_tree().physics_frame
	_check(_controller.get_camera_recoil_degrees() < 0.02, "SMG camera recoil must recover after trigger release")

	# DAMAGE: LOWER_BODY = 30, TORSO = 65, HEAD = 140
	target.reset_target()
	target.health.apply_damage(SMG.damage_for_zone(&"TORSO"), &"TORSO")
	_check(is_equal_approx(target.health.current_health, 85.0), "Torso damage of 65 on 150HP vest must leave 85HP")

	target.reset_target()
	target.health.apply_damage(SMG.damage_for_zone(&"LOWER_BODY"), &"LOWER_BODY")
	_check(is_equal_approx(target.health.current_health, 120.0), "Lower body damage of 30 on 150HP vest must leave 120HP")

	target.reset_target()
	target.health.apply_damage(SMG.damage_for_zone(&"HEAD"), &"HEAD")
	_check(is_equal_approx(target.health.current_health, 10.0), "Head damage of 140 on 150HP vest must leave 10HP")

	# AUTOMATIC EMPTY STATE (NO NEGATIVE AMMO)
	firearm.magazine_ammo = 3
	firearm.reserve_ammo = 25
	Input.action_press("fire_weapon")
	for frame in range(30):
		await get_tree().physics_frame
	Input.action_release("fire_weapon")
	_check(firearm.magazine_ammo == 0, "Automatic fire must consume only the remaining 3 rounds and stop at 0, found: %d" % firearm.magazine_ammo)
	_check(firearm.state == FirearmComponent.WeaponState.EMPTY, "Weapon state must be EMPTY when magazine hits 0")
	if fp_visual:
		_check(not fp_visual.is_muzzle_flash_visible(), "Muzzle flash must not be visible when empty")

	# Dry fire must not create fake rounds or go negative
	_check(not _controller.fire(), "Firing empty SMG must return false (dry fire)")
	_check(firearm.magazine_ammo == 0, "Magazine ammo must remain 0 and never go negative")

	# 11. RELOAD TAKES EXACTLY 1.5 SECONDS
	_check(_controller.reload(), "Reload must start from empty state")
	_check(firearm.state == FirearmComponent.WeaponState.RELOADING, "State must be RELOADING")
	if fp_visual:
		_check(fp_visual.is_reload_playing(), "Visual reload animation must be playing")
	_check(is_equal_approx(firearm.reload_remaining, 1.5), "Reload remaining time must start at 1.5s")

	# Advance 95 physics frames (~1.58s at 60 FPS)
	for f in range(95):
		await get_tree().physics_frame

	_check(firearm.magazine_ammo == 25, "Completed reload must load 25 rounds into magazine")
	_check(firearm.reserve_ammo == 0, "Completed reload must deduct 25 rounds from reserve")
	_check(firearm.state == FirearmComponent.WeaponState.READY, "State must return to READY after reload")

	# 18. DROP AND PICK UP AGAIN
	firearm.magazine_ammo = 17
	firearm.reserve_ammo = 63
	_check(_controller.drop_equipped_weapon(), "Player must be able to drop equipped SMG")
	_check(InventoryManager.get_firearm_slot(1) == null, "Slot 2 must be cleared after drop")
	_check(_controller.current_firearm == null or _controller.current_firearm.definition != SMG, "SMG must no longer be equipped after drop")

	var dropped_smg: FirearmPickup = null
	for node in get_tree().get_nodes_in_group("firearm_pickups"):
		if node is FirearmPickup and (node as FirearmPickup).definition == SMG and (node as FirearmPickup).name.begins_with("Dropped"):
			dropped_smg = node as FirearmPickup
			break
	_check(dropped_smg != null, "Dropped SMG pickup must be spawned in world")
	if dropped_smg:
		_check(dropped_smg.saved_magazine == 17 and dropped_smg.saved_reserve == 63, "Dropped SMG must preserve ammo counts (17 / 63)")
		dropped_smg.interact(_player)
		await get_tree().process_frame
		_check(InventoryManager.get_firearm_slot(1) == SMG, "Re-acquired SMG must be back in firearm inventory")
		_controller.equip_slot(1)
		await get_tree().process_frame
		_check(_controller.current_firearm != null and _controller.current_firearm.magazine_ammo == 17 and _controller.current_firearm.reserve_ammo == 63, "Re-equipped SMG must restore saved ammo (17 / 63)")

	# DEV MENU & CONTROLS VALIDATION
	_check(DevModeManager.refill_smg_ammo(), "DevModeManager.refill_smg_ammo must succeed")
	_check(_controller.current_firearm.magazine_ammo == 25 and _controller.current_firearm.reserve_ammo == 100, "Refill SMG ammo must restore 25 / 100")
	_check(DevModeManager.remove_smg(), "DevModeManager.remove_smg must succeed")
	_check(not InventoryManager.has_item(&"smg"), "SMG must be removed from inventory")
	_check(DevModeManager.give_smg(), "DevModeManager.give_smg must succeed")
	_check(InventoryManager.has_item(&"smg"), "SMG must be added back via DevModeManager")

	_finish()


func _aim_at(dummy: DamageableHumanDummy, zone_id: StringName) -> void:
	var zone := _zone(dummy, zone_id)
	if zone == null:
		return
	var visual_name := "HeadVisual" if zone_id == &"HEAD" else ("ChestVisual" if zone_id == &"TORSO" else "PelvisVisual")
	var visual := zone.get_node(visual_name) as MeshInstance3D
	_player.global_position = dummy.global_position + Vector3(0, 0.95, 5.0)
	_player.velocity = Vector3.ZERO
	_player.camera.look_at(visual.global_position, Vector3.UP)
	await get_tree().physics_frame


func _dummy(label: String) -> DamageableHumanDummy:
	for node in get_tree().get_nodes_in_group("weapon_range_damage_dummies"):
		if _range.is_ancestor_of(node) and node is DamageableHumanDummy and (node as DamageableHumanDummy).target_label == label:
			return node as DamageableHumanDummy
	return null


func _zone(dummy: DamageableHumanDummy, zone_id: StringName) -> BodyHitZone:
	for zone in dummy.get_hit_zones():
		if zone.get_hit_zone_id() == zone_id:
			return zone
	return null


func _send_aim_event(held: bool) -> void:
	_controller._set_aim_held(held)


func _advance_frames(count: int) -> void:
	for f in range(count):
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
		print("SMG VALIDATION: PASS — held automatic fire at 750 RPM, release stop, 30/65/140 damage, empty handling, ADS/recoil, reload, drop/swap, and dev range integration")
	else:
		for failure in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
