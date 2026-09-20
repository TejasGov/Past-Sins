extends Node3D

const RANGE := preload("res://scenes/dev/WeaponRange.tscn")
const PISTOL: FirearmDefinition = preload("res://resources/weapons/pistol.tres")
const SMG: FirearmDefinition = preload("res://resources/weapons/smg.tres")
const CARBINE: FirearmDefinition = preload("res://resources/weapons/carbine_ar.tres")
const SNIPER: FirearmDefinition = preload("res://resources/weapons/sniper_rifle.tres")
const PROPER: SuppressorDefinition = preload("res://resources/items/proper_suppressor.tres")
const MAKESHIFT: SuppressorDefinition = preload("res://resources/items/makeshift_suppressor.tres")

var failures: Array[String] = []


func _ready() -> void: call_deferred("_validate")


func _validate() -> void:
	DevModeManager.set_enabled(true)
	var range_scene := RANGE.instantiate() as WeaponRange; add_child(range_scene)
	for _frame in range(8): await get_tree().process_frame
	InventoryManager.clear_all_inventory(false)
	var player := DevModeManager.get_player() as PlayerController
	var controller := player.get_node("WeaponController") as PlayerWeaponController

	_check(PROPER.is_valid_suppressor() and PROPER.compatible_weapon_ids == [&"carbine_ar", &"sniper_rifle"], "Proper compatibility must be data-driven for Carbine/Sniper only")
	_check(MAKESHIFT.is_valid_suppressor() and MAKESHIFT.compatible_weapon_ids == [&"pistol", &"smg"] and MAKESHIFT.max_magazine_uses == 4, "Makeshift compatibility/durability must be data-driven for Pistol/SMG")
	_check(not PROPER.supports_weapon(&"pistol") and not MAKESHIFT.supports_weapon(&"carbine_ar") and not MAKESHIFT.supports_weapon(&"improvised_slingshot"), "Incompatible weapons must fail compatibility checks")
	var range_pickups := get_tree().get_nodes_in_group("weapon_range_suppressor_pickups").filter(func(node): return range_scene.is_ancestor_of(node))
	_check(range_pickups.size() == 2 and InputMap.has_action("toggle_suppressor"), "Range must contain both suppressor pickups and a clean attachment input action")
	_check([PISTOL.lower_body_damage, PISTOL.torso_damage, PISTOL.head_damage] == [30.0, 70.0, 120.0], "Pistol damage must remain unchanged")
	_check([SMG.lower_body_damage, SMG.torso_damage, SMG.head_damage] == [30.0, 65.0, 140.0], "SMG damage must remain unchanged")
	_check([CARBINE.lower_body_damage, CARBINE.torso_damage, CARBINE.head_damage] == [35.0, 80.0, 150.0], "Carbine damage must remain unchanged")
	_check([SNIPER.lower_body_damage, SNIPER.torso_damage, SNIPER.head_damage] == [200.0, 300.0, 400.0], "Sniper damage must remain unchanged")

	InventoryManager.add_item(PISTOL, 1, false); InventoryManager.add_item(SMG, 1, false)
	InventoryManager.add_item(MAKESHIFT, 1, false); InventoryManager.add_item(PROPER, 1, false)
	controller.equip_slot(0)
	_check(not controller.attach_suppressor(PROPER.item_id), "Proper suppressor must reject Pistol")
	_check(controller.attach_suppressor(MAKESHIFT.item_id), "Makeshift suppressor must attach to Pistol")
	_check(not InventoryManager.add_item(MAKESHIFT, 1, false), "Unique attached suppressor must not duplicate in equipment inventory")
	var pistol := controller.current_firearm
	_check(pistol.is_suppressed() and pistol.get_visual().has_suppressor_visual(), "Pistol FP model must show attached makeshift suppressor")
	_check(controller.is_firearm_visibly_held(), "Suppressed firearm must remain visibly held for guard threat detection")
	_check(pistol.get_effective_noise_radius() == PISTOL.base_noise_radius * MAKESHIFT.noise_radius_multiplier and pistol.get_muzzle_flash_mode() == &"REDUCED", "Makeshift must reduce noise/flash by its configuration")
	pistol.magazine_ammo = 7
	_check(pistol.start_reload() and pistol.suppressor_remaining_uses == 4, "Reloading without a suppressed shot must consume zero uses")
	pistol._physics_process(2.0)
	var noises: Array[Dictionary] = []
	WorldNoiseSystem.weapon_noise_emitted.connect(func(event: Dictionary): noises.append(event), CONNECT_ONE_SHOT)
	_check(pistol.try_fire(player.camera, 0.0), "Suppressed Pistol must still fire")
	_check(not noises.is_empty() and noises[0].suppressed and noises[0].suppressor_type == &"MAKESHIFT", "Shot must emit a structured suppressed weapon-noise event")
	_check(pistol.start_reload(), "Partial suppressed magazine must reload")
	_check(pistol.suppressor_remaining_uses == 3, "One or more suppressed shots then reload must consume exactly one magazine-use")
	pistol._physics_process(2.0)
	var after_first_use := pistol.suppressor_remaining_uses
	_check(pistol.start_reload() == false and pistol.suppressor_remaining_uses == after_first_use, "Reload rejection/zero new shots must consume zero uses")

	# Detaching and reattaching carries the dirty-magazine flag instead of resetting it.
	pistol.magazine_ammo = maxi(1, pistol.magazine_ammo - 1)
	pistol.cooldown_remaining = 0.0
	_check(pistol.try_fire(player.camera, 0.0), "Second suppressed cycle must fire")
	_check(controller.detach_suppressor(), "Attached suppressor must detach")
	_check(controller.attach_suppressor(MAKESHIFT.item_id), "Detached suppressor must reattach")
	_check(pistol.suppressed_shots_this_magazine, "Detach/reattach must preserve used-magazine state")
	var before_reattach_reload := pistol.suppressor_remaining_uses
	_check(pistol.start_reload() and pistol.suppressor_remaining_uses == before_reattach_reload - 1, "Reattach exploit must not avoid durability consumption")
	pistol._physics_process(2.0)

	var before_full_mag := pistol.suppressor_remaining_uses
	pistol.magazine_ammo = PISTOL.magazine_size
	for _round in range(PISTOL.magazine_size):
		pistol.cooldown_remaining = 0.0
		pistol.try_fire(player.camera, 0.0)
	_check(pistol.suppressor_remaining_uses == before_full_mag - 1 and pistol.suppressed_shots_this_magazine == false, "Emptying a full magazine must consume exactly one use")
	pistol._physics_process(1.0)

	# Switching preserves the attachment and one owned item cannot attach twice.
	controller.equip_slot(1)
	_check(controller.current_firearm.definition == SMG and not controller.attach_suppressor(MAKESHIFT.item_id), "One makeshift suppressor cannot be duplicated onto SMG")
	controller.equip_slot(0)
	_check(controller.current_firearm.is_suppressed(), "Switching back must restore the Pistol attachment")

	# Dropped weapon owns the attachment; inventory no longer retains a duplicate.
	_check(controller.unequip_and_drop_current(), "Suppressed Pistol must drop")
	await get_tree().process_frame
	var dropped: FirearmPickup
	for node in get_tree().get_nodes_in_group("firearm_pickups"):
		if node is FirearmPickup and (node as FirearmPickup).name.begins_with("DroppedPistol"): dropped = node; break
	_check(dropped != null and dropped.attached_suppressor == MAKESHIFT and not InventoryManager.has_item(MAKESHIFT.item_id), "Dropped Pistol must visually/statefully own its suppressor without inventory duplication")
	if dropped:
		var world_visual := dropped._find_firearm_visual(dropped.visual_mount)
		_check(world_visual != null and world_visual.has_suppressor_visual(), "Dropped world model must show its suppressor")
		# Free SMG slot so the dropped Pistol can be recovered.
		InventoryManager.clear_firearm_slot(1)
		dropped.interact(player); await get_tree().process_frame
		_check(InventoryManager.has_item(MAKESHIFT.item_id) and controller.current_firearm and controller.current_firearm.is_suppressed(), "Picking the weapon back up must restore attachment and durability")
	_check(controller.detach_suppressor(), "Recovered makeshift suppressor must detach from Pistol")
	InventoryManager.add_item(SMG, 1, false); controller.equip_slot(1)
	_check(controller.attach_suppressor(MAKESHIFT.item_id) and controller.current_firearm.get_visual().has_suppressor_visual(), "Makeshift suppressor must attach to SMG")
	_check(controller.detach_suppressor(), "Makeshift suppressor must detach from SMG")
	controller.equip_slot(0); _check(controller.attach_suppressor(MAKESHIFT.item_id), "Makeshift suppressor must reattach to Pistol for durability test")

	# Four fired magazine cycles break/consume makeshift suppression exactly once.
	controller.current_firearm.suppressor_remaining_uses = 1
	controller.current_firearm.magazine_ammo = 2
	controller.current_firearm.reserve_ammo = 8
	controller.current_firearm.cooldown_remaining = 0.0
	controller.current_firearm.state = FirearmComponent.WeaponState.READY
	controller.current_firearm.try_fire(player.camera, 0.0)
	controller.current_firearm.start_reload()
	_check(not controller.current_firearm.is_suppressed() and not InventoryManager.has_item(MAKESHIFT.item_id) and controller.get_suppressor_status().contains("BROKEN"), "Fourth used magazine must break/consume makeshift suppressor, show BROKEN and restore unsuppressed behavior")

	# Proper suppression is reusable and quieter/subtler than makeshift.
	InventoryManager.clear_all_inventory(false)
	InventoryManager.add_item(CARBINE, 1, false); InventoryManager.add_item(SNIPER, 1, false); InventoryManager.add_item(PROPER, 1, false)
	controller.equip_slot(0)
	_check(controller.attach_suppressor(PROPER.item_id), "Proper suppressor must attach to Carbine")
	var carbine := controller.current_firearm
	_check(carbine.suppressor_remaining_uses == -1 and carbine.get_effective_noise_radius() < PISTOL.base_noise_radius * MAKESHIFT.noise_radius_multiplier and PROPER.muzzle_flash_multiplier < MAKESHIFT.muzzle_flash_multiplier, "Proper suppressor must be reusable, quieter and subtler than makeshift")
	carbine.magazine_ammo = 2; carbine.reserve_ammo = 30; carbine.try_fire(player.camera, 0.0); carbine.start_reload()
	_check(carbine.suppressor_remaining_uses == -1 and carbine.is_suppressed(), "Proper suppressor must not lose durability")
	controller.equip_slot(1)
	_check(not controller.attach_suppressor(PROPER.item_id), "One proper suppressor cannot attach to both owned compatible rifles")
	controller.equip_slot(0)
	_check(controller.current_firearm.is_suppressed(), "Proper suppressor must survive weapon switching")
	_check(controller.detach_suppressor(), "Proper suppressor must detach from Carbine")
	controller.equip_slot(1)
	_check(controller.attach_suppressor(PROPER.item_id) and controller.current_firearm.get_visual().has_suppressor_visual(), "Proper suppressor must attach to Sniper Rifle")

	var listeners := get_tree().get_nodes_in_group("weapon_range_sound_listeners").filter(func(node): return range_scene.is_ancestor_of(node))
	_check(listeners.size() == 4, "Range must provide 10/25/50/100m sound-listener markers")
	_check(DevModeManager.has_method("attach_compatible_suppressor") and DevModeManager.has_method("reset_makeshift_suppressor_durability"), "Dev controls must expose attach/detach/durability operations")

	range_scene.free(); DevModeManager.set_enabled(false)
	if failures.is_empty(): print("SUPPRESSOR VALIDATION: PASS — compatibility, FP/world visuals, noise/flash, durability, switching, drop/pickup and Dev Range")
	else:
		for failure in failures: push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
