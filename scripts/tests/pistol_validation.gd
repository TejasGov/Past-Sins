extends Node3D

const RANGE := preload("res://scenes/dev/WeaponRange.tscn")
const PISTOL: FirearmDefinition = preload("res://resources/weapons/pistol.tres")

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
	_check(PISTOL.weapon_id == &"pistol" and PISTOL.item_id == &"pistol", "Pistol IDs must be data-driven and consistent")
	_check(PISTOL.magazine_size == 8 and PISTOL.fire_mode == FirearmDefinition.FireMode.SEMI_AUTO, "Pistol must be an 8-round semi-automatic firearm")
	_check(is_equal_approx(PISTOL.shot_interval, 0.5) and is_equal_approx(PISTOL.reload_time, 1.5), "Pistol timing must be 0.5s shots / 1.5s reload")
	_check(PISTOL.damage_for_zone(&"LOWER_BODY") == 30.0 and PISTOL.damage_for_zone(&"TORSO") == 70.0 and PISTOL.damage_for_zone(&"HEAD") == 120.0, "Pistol hit-zone damage table is incorrect")
	_check(PISTOL.hip_fire_spread_degrees > PISTOL.ads_spread_degrees and PISTOL.ads_spread_degrees >= 0.0, "Pistol hip spread must be wider than its configurable ADS spread")

	DevModeManager.set_enabled(true)
	_range = RANGE.instantiate() as WeaponRange
	add_child(_range)
	for frame in range(4):
		await get_tree().process_frame
	await get_tree().physics_frame
	_player = _range.get_node("Actors/WeaponRangePlayer") as PlayerController
	_controller = _player.get_node("WeaponController") as PlayerWeaponController
	_tool = _range.get_node("DamageTestTool") as DevDamageTestTool
	var pickup := _range.get_node_or_null("Interactables/PistolPickup") as FirearmPickup
	_check(pickup != null and pickup.definition == PISTOL, "PISTOL rack position must contain the real pistol pickup")
	if pickup:
		pickup.interact(_player)
	await get_tree().process_frame
	_check(InventoryManager.get_firearm_slot(0) == PISTOL, "Pistol pickup must use firearm slot 1")
	_check(_controller.current_firearm != null and _controller.current_firearm.definition == PISTOL, "Pistol must equip after pickup")
	_check(_controller.current_firearm != null and _controller.current_firearm.visible and _controller.current_firearm.find_child("PistolFirstPersonVisual", true, false) != null, "Equipped pistol must show its separate first-person visual")
	if _controller.current_firearm == null:
		_finish()
		return

	await _validate_aiming_and_crosshair()
	await _validate_handling_polish()
	await _validate_damage_matrix()
	await _validate_fire_rate_and_magazine()
	await _validate_reload()
	await _validate_drop_and_pickup()
	await _validate_refill_and_reset()
	await _validate_dev_controls()

	_finish()


func _validate_aiming_and_crosshair() -> void:
	var aim_events := InputMap.action_get_events("aim")
	var has_right_mouse := false
	for event in aim_events:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			has_right_mouse = true
	_check(has_right_mouse, "The aim action must be bound to Right Mouse Button")
	_check(_controller.is_crosshair_visible(), "Equipping a firearm must show the centered crosshair")
	_check(_controller.is_ammo_hud_visible() and "[font_size=30]" in _controller.get_ammo_hud_text(), "Equipped pistol must show a magazine-emphasized ammo HUD")

	_controller.unequip_current()
	await get_tree().process_frame
	_check(not _controller.is_crosshair_visible(), "Unequipping a firearm must hide the crosshair")
	_check(not _controller.is_ammo_hud_visible(), "Unequipping must hide the firearm ammo HUD")
	_check(not _controller.ads_active and is_equal_approx(_player.camera.fov, _controller.normal_fov), "Unequipping must cancel ADS and restore normal FOV")
	_check(_controller.equip_slot(InventoryComponent.FIREARM_SLOT_1), "Pistol must re-equip after crosshair visibility test")
	await get_tree().process_frame


func _validate_handling_polish() -> void:
	var firearm := _controller.current_firearm
	var visual := firearm.find_child("PistolFirstPersonVisual", true, false) as PistolVisual
	var hip_spread := _controller.get_current_spread_degrees()
	_check(visual != null, "Pistol handling polish requires the reusable first-person visual")
	if visual == null:
		return
	_check(visual is FirearmVisualBase, "Pistol visual must use the shared firearm presentation contract")
	_check(visual.validate_visual_contract().is_empty(), "Pistol visual must provide every standardized first-person anchor")
	for required_part in [
		"Slide", "SlideNose", "EjectionPortTop", "Extractor", "RearSightLeft",
		"FrontSight", "FrameChassis", "DustCover", "Beavertail", "Grip",
		"TriggerGuardBow", "Trigger", "SlideStop", "Magazine", "MagazineBasePlate",
		"Barrel", "Bore", "GuideRod",
	]:
		_check(visual.find_child(required_part, true, false) != null, "Low-poly pistol is missing recognizable part: %s" % required_part)
	_check(visual.find_children("*", "MeshInstance3D", true, false).size() < 70, "Low-poly pistol must stay within its Web-friendly mesh budget")

	# Idle sway remains subtle; movement produces a separate bob layer, sprint
	# strengthens it, crouch reduces it, and ADS suppresses both.
	_send_aim_event(false)
	await _advance_ads(45)
	_player.is_sprinting = false
	_player.is_crouching = false
	_player.velocity = Vector3.ZERO
	var idle_sway_max := 0.0
	for frame in range(90):
		_controller._process(1.0 / 60.0)
		idle_sway_max = maxf(idle_sway_max, _controller.get_last_sway_offset().length())
	_check(idle_sway_max > 0.0 and idle_sway_max < 0.012, "Stationary pistol sway must remain subtle")

	var walk_bob_max := 0.0
	for frame in range(120):
		_player.velocity = Vector3(_player.walk_speed, 0, 0)
		_controller._process(1.0 / 60.0)
		walk_bob_max = maxf(walk_bob_max, _controller.get_last_bob_offset().length())
	_check(walk_bob_max > 0.012, "Walking speed must drive visible lightweight weapon bob")
	var moving_crosshair_spread := _controller.get_crosshair_spread()
	_check(moving_crosshair_spread > 1.0, "Movement must subtly widen the hip-fire crosshair")

	_player.is_sprinting = true
	var sprint_bob_max := 0.0
	for frame in range(120):
		_player.velocity = Vector3(_player.sprint_speed, 0, 0)
		_controller._process(1.0 / 60.0)
		sprint_bob_max = maxf(sprint_bob_max, _controller.get_last_bob_offset().length())
	_check(sprint_bob_max > walk_bob_max * 1.35, "Sprinting must strengthen weapon bob")

	_player.is_sprinting = false
	_player.is_crouching = true
	var crouch_bob_max := 0.0
	for frame in range(120):
		_player.velocity = Vector3(_player.crouch_speed, 0, 0)
		_controller._process(1.0 / 60.0)
		crouch_bob_max = maxf(crouch_bob_max, _controller.get_last_bob_offset().length())
	_check(crouch_bob_max < walk_bob_max * 0.7, "Crouching must reduce weapon bob")

	_player.is_crouching = false
	_send_aim_event(true)
	await _advance_ads(45)
	var ads_bob_max := 0.0
	var ads_sway_max := 0.0
	for frame in range(120):
		_player.velocity = Vector3(_player.walk_speed, 0, 0)
		_controller._process(1.0 / 60.0)
		ads_bob_max = maxf(ads_bob_max, _controller.get_last_bob_offset().length())
		ads_sway_max = maxf(ads_sway_max, _controller.get_last_sway_offset().length())
	_check(ads_bob_max < walk_bob_max * 0.25 and ads_sway_max < idle_sway_max * 0.25, "ADS must heavily reduce sway and movement bob")
	_send_aim_event(false)
	await _advance_ads(45)
	_player.velocity = Vector3.ZERO
	for frame in range(120):
		_controller._process(1.0 / 60.0)
	_check(_controller.get_last_bob_offset().length() < 0.001, "Movement bob must smoothly return to neutral after stopping")

	# Every valid shot drives camera/weapon recoil, slide and muzzle flash. Camera
	# recoil is applied as a temporary offset and must restore the prior aim.
	var target := _dummy("ADVANCED VEST")
	target.reset_target()
	firearm.refill_ammo()
	await _aim_at(target, &"LOWER_BODY")
	var camera_pitch_before := _player.camera.rotation.x
	await _wait_until_ready()
	_check(_controller.fire(), "Handling test valid shot must fire")
	_check(_controller.get_weapon_recoil_amount() > 0.5 and _controller.get_camera_recoil_degrees() > 0.1, "Valid shots must add configurable weapon and camera recoil")
	_check(visual.get_slide_offset() > 0.1, "Every valid shot must drive the slide backward")
	_check(visual.is_muzzle_flash_visible(), "A valid shot must produce the brief muzzle flash")
	_controller._process(1.0 / 60.0)
	_check(_player.camera.rotation.x < camera_pitch_before, "Pistol recoil must kick the camera upward")
	_check(_controller.get_crosshair_spread() > moving_crosshair_spread, "Firing must briefly expand the hip-fire crosshair")
	for frame in range(120):
		_controller._process(1.0 / 60.0)
		await get_tree().physics_frame
	_check(_controller.get_weapon_recoil_amount() < 0.001 and _controller.get_camera_recoil_degrees() < 0.001, "Weapon and camera recoil must recover fully")
	_check(absf(_player.camera.rotation.x - camera_pitch_before) < 0.002, "Camera recoil recovery must not permanently shift aim")
	_check(not visual.is_muzzle_flash_visible(), "Muzzle flash must disappear immediately after a valid shot")
	var hip_camera_impulse := _controller.hip_camera_recoil_degrees
	var hip_weapon_impulse := 1.0
	target.reset_target()
	firearm.refill_ammo()
	_send_aim_event(true)
	await _advance_ads(45)
	await _aim_at(target, &"LOWER_BODY")
	await _wait_until_ready()
	_check(_controller.fire(), "ADS recoil comparison shot must fire")
	_check(_controller.get_camera_recoil_degrees() < hip_camera_impulse and _controller.get_weapon_recoil_amount() < hip_weapon_impulse, "ADS must apply reduced camera and weapon kick")
	for frame in range(90):
		_controller._process(1.0 / 60.0)
		await get_tree().physics_frame

	# Empty-state visual, dry fire and the complete magazine/reload presentation.
	firearm.magazine_ammo = 1
	firearm.reserve_ammo = 8
	await _wait_until_ready()
	var health_before_last_round := target.get_current_health()
	_check(_controller.fire(), "Last magazine round must still fire")
	_check(firearm.magazine_ammo == 0 and visual.is_slide_locked() and _controller.ads_active, "The slide must lock backward when the last aimed round is fired")
	for frame in range(12):
		await get_tree().physics_frame
	_check(not visual.is_muzzle_flash_visible() and visual.is_slide_locked(), "Empty pistol must hide muzzle flash while keeping the slide locked")
	await _wait_until_ready()
	var health_before_dry_fire := target.get_current_health()
	_check(not _controller.fire(), "Dry fire must not generate a shot")
	_check(firearm.magazine_ammo == 0 and target.get_current_health() == health_before_dry_fire and visual.is_slide_locked(), "Dry fire must consume no ammo, apply no hit and retain slide lock")
	_check(not visual.is_muzzle_flash_visible() and health_before_dry_fire <= health_before_last_round, "Dry fire must never create muzzle flash or extra damage")

	_send_aim_event(false)
	await _advance_ads(20)
	_check(_controller.reload() and visual.is_reload_playing(), "The exact 1.5-second reload must start its procedural visual sequence")
	for frame in range(28):
		await get_tree().physics_frame
	_check(visual.get_magazine_offset() > 0.08 or not visual.is_magazine_visible(), "Reload presentation must visibly remove the separate magazine")
	for frame in range(64):
		await get_tree().physics_frame
	_check(firearm.magazine_ammo == 8 and firearm.reserve_ammo == 0, "Empty reload must still complete with the existing ammo math")
	_check(not visual.is_reload_playing() and visual.is_magazine_visible() and visual.get_magazine_offset() < 0.001, "Reload must finish with the replacement magazine seated")
	_check(not visual.is_slide_locked(), "Empty reload must release the slide back into battery")
	firearm.refill_ammo()
	_player.velocity = Vector3.ZERO
	_check(_controller.is_crosshair_visible(), "Re-equipping the pistol must restore the crosshair")

	var standard := _dummy("STANDARD VEST")
	standard.reset_target()
	_controller.current_firearm.refill_ammo()
	await _aim_at(standard, &"TORSO")
	_send_aim_event(true)
	await _advance_ads(45)
	_check(_controller.ads_active and _controller.get_ads_blend() > 0.98, "Holding RMB must smoothly enter ADS")
	_check(absf(_player.camera.fov - _controller.ads_fov) < 0.5, "ADS must smoothly narrow the camera FOV")
	_check(_controller.weapon_mount.position.distance_to(_controller.get_active_ads_position()) < 0.01, "ADS must smoothly move the weapon to its configured sight position")
	_check(_controller.get_active_ads_position().z < _controller.ads_weapon_position.z, "Pistol ADS should sit slightly farther from the camera than the shared default")
	_check(not _controller.is_crosshair_visible(), "The normal crosshair must hide while iron sights are active")
	_check(_controller.get_current_spread_degrees() < hip_spread * 0.25, "ADS must use much tighter configurable spread than hip fire")
	var sight_metrics := _controller.get_sight_alignment_pixels()
	_check(not sight_metrics.is_empty(), "Pistol must expose reusable ADS and sight alignment metrics")
	_check(_controller.fire() and int(standard.get_current_health()) == 55, "ADS hitscan must remain aligned to the camera center and preserve torso damage")
	_check(_controller.reload(), "Reload must still start while ADS is held")
	for frame in range(20):
		await get_tree().physics_frame
	_send_aim_event(false)
	await _advance_ads(20)
	_check(_controller.current_firearm.state == FirearmComponent.WeaponState.RELOADING and not _controller.ads_active, "Releasing aim during reload must return toward hip without interrupting reload")
	for frame in range(52):
		await get_tree().physics_frame
	_check(_controller.current_firearm.magazine_ammo == 8 and _controller.current_firearm.reserve_ammo == 23, "ADS reload must preserve the existing magazine/reserve rules")
	_send_aim_event(true)
	await _advance_ads(45)
	_check(_controller.ads_active, "The pistol must be able to aim immediately after reload completes")

	_send_aim_event(false)
	await _advance_ads(45)
	_check(not _controller.ads_active and _controller.get_ads_blend() < 0.02, "Releasing RMB must smoothly return to hip fire")
	_check(absf(_player.camera.fov - _controller.normal_fov) < 0.5, "Releasing RMB must restore normal FOV")
	_check(_controller.weapon_mount.position.distance_to(_controller.hip_weapon_position) < 0.01, "Releasing RMB must restore the configured hip position")
	_check(_controller.is_crosshair_visible(), "Hip fire must restore the normal crosshair")

	_send_aim_event(true)
	await _advance_ads(10)
	_controller.unequip_current()
	_check(not _controller.ads_active and _controller.get_ads_blend() == 0.0, "Unequipping during ADS must reset the aiming state immediately")
	_check(not _controller.is_crosshair_visible() and is_equal_approx(_player.camera.fov, _controller.normal_fov), "Unequipping during ADS must hide the crosshair and restore FOV")
	_check(_controller.equip_slot(InventoryComponent.FIREARM_SLOT_1), "Pistol must remain equipable after cancelling ADS")
	await get_tree().process_frame


func _send_aim_event(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = &"aim"
	event.pressed = pressed
	_controller._unhandled_input(event)


func _advance_ads(frames: int) -> void:
	for frame in range(frames):
		_controller._process(1.0 / 60.0)
		await get_tree().physics_frame


func _validate_damage_matrix() -> void:
	var cases := [
		["UNARMORED", 100, {&"LOWER_BODY": 70, &"TORSO": 30, &"HEAD": 0}],
		["STANDARD VEST", 125, {&"LOWER_BODY": 95, &"TORSO": 55, &"HEAD": 5}],
		["ADVANCED VEST", 150, {&"LOWER_BODY": 120, &"TORSO": 80, &"HEAD": 30}],
	]
	for case in cases:
		var dummy := _dummy(String(case[0]))
		_check(dummy != null and int(dummy.get_total_health()) == int(case[1]), "%s target total health is incorrect" % case[0])
		if dummy == null:
			continue
		var expectations: Dictionary = case[2]
		for zone_id in [&"LOWER_BODY", &"TORSO", &"HEAD"]:
			dummy.reset_target()
			_controller.current_firearm.refill_ammo()
			await _wait_until_ready()
			var zone := _zone(dummy, zone_id)
			await _aim_at(dummy, zone_id)
			_check(_controller.fire(), "%s %s pistol hitscan did not fire" % [case[0], zone_id])
			_check(int(dummy.get_current_health()) == int(expectations[zone_id]), "%s %s expected %d HP, found %d" % [case[0], zone_id, expectations[zone_id], int(dummy.get_current_health())])
			if case[0] == "STANDARD VEST" and zone_id == &"TORSO":
				_check(_tool.get_last_readout() == "PISTOL\nTORSO\n70 DAMAGE\nTARGET: 55 / 125", "Pistol hit must feed the existing DEV damage readout")
			_check(zone != null, "%s is missing its reusable %s zone" % [case[0], zone_id])


func _validate_fire_rate_and_magazine() -> void:
	var target := _dummy("ADVANCED VEST")
	target.reset_target()
	_controller.current_firearm.refill_ammo()
	await _wait_until_ready()
	await _aim_at(target, &"LOWER_BODY")
	_check(_controller.fire(), "First semi-auto trigger press must fire")
	var after_first := _controller.current_firearm.magazine_ammo
	_check(not _controller.fire() and _controller.current_firearm.magazine_ammo == after_first, "Pistol must reject shots inside its 0.5-second cooldown")
	for frame in range(20):
		await get_tree().physics_frame
	_check(not _controller.fire(), "Pistol must still be cooling down before 0.5 seconds")
	await _wait_until_ready()
	_check(_controller.fire(), "A distinct trigger press after 0.5 seconds must fire")
	await _wait_until_ready()
	_controller.current_firearm.refill_ammo()
	var held_start := _controller.current_firearm.magazine_ammo
	var held_event := InputEventAction.new()
	held_event.action = &"fire_weapon"
	held_event.pressed = true
	_controller._unhandled_input(held_event)
	for frame in range(42):
		await get_tree().physics_frame
	_check(_controller.current_firearm.magazine_ammo == held_start - 1, "Holding fire without a new press must not make the semi-auto pistol automatic")

	_controller.current_firearm.refill_ammo()
	target.reset_target()
	for shot in range(8):
		await _wait_until_ready()
		_check(_controller.fire(), "Magazine shot %d of 8 failed" % (shot + 1))
	_check(_controller.current_firearm.magazine_ammo == 0, "Eight shots must empty the magazine exactly")
	await _wait_until_ready()
	_check(not _controller.fire() and _controller.current_firearm.magazine_ammo == 0 and _controller.current_firearm.state == FirearmComponent.WeaponState.EMPTY, "Empty magazine must stop at zero and enter EMPTY")


func _validate_reload() -> void:
	var firearm := _controller.current_firearm
	_check(firearm.magazine_ammo == 0 and firearm.reserve_ammo == 24, "Reload test must begin at 0 / 24")
	_check(_controller.reload(), "Reload must start with an empty magazine and reserve ammo")
	_check(firearm.state == FirearmComponent.WeaponState.RELOADING and not _controller.fire(), "Pistol must not fire during reload")
	for frame in range(72):
		await get_tree().physics_frame
	_check(firearm.magazine_ammo == 0 and firearm.state == FirearmComponent.WeaponState.RELOADING, "Reload must not finish before 1.5 seconds")
	for frame in range(20):
		await get_tree().physics_frame
	_check(firearm.magazine_ammo == 8 and firearm.reserve_ammo == 16 and firearm.state == FirearmComponent.WeaponState.READY, "1.5-second reload must transfer exactly 8 rounds from reserve")
	_check(not _controller.reload(), "Reloading a full magazine must do nothing")
	firearm.magazine_ammo = 6
	firearm.reserve_ammo = 3
	_check(_controller.reload(), "Partial magazine reload must start")
	for frame in range(92):
		await get_tree().physics_frame
	_check(firearm.magazine_ammo == 8 and firearm.reserve_ammo == 1, "Partial reload must not waste reserve ammunition")
	firearm.magazine_ammo = 4
	firearm.reserve_ammo = 0
	_check(not _controller.reload() and firearm.magazine_ammo == 4, "Reload with zero reserve must fail cleanly")


func _validate_drop_and_pickup() -> void:
	var before_drop := _controller.current_firearm.get_ammo_snapshot()
	_check(_controller.drop_equipped_weapon(), "Equipped pistol must be droppable")
	await get_tree().process_frame
	_check(not InventoryManager.has_item(&"pistol") and _controller.current_firearm == null, "Dropped pistol must leave the firearm slot and first-person view")
	var dropped: FirearmPickup
	for node in get_tree().get_nodes_in_group("firearm_pickups"):
		if _range.is_ancestor_of(node) and node is FirearmPickup and (node as FirearmPickup).definition == PISTOL:
			dropped = node as FirearmPickup
			break
	_check(dropped != null, "Dropping must create a grounded reusable pistol pickup")
	if dropped:
		dropped.interact(_player)
		await get_tree().process_frame
	_check(InventoryManager.has_item(&"pistol") and _controller.current_firearm != null, "Dropped pistol must be collectible and equip again")
	var restored := _controller.get_ammo_snapshot(&"pistol")
	_check(int(restored.get("magazine", -1)) == int(before_drop.magazine) and int(restored.get("reserve", -1)) == int(before_drop.reserve), "Dropped pistol must preserve magazine and reserve ammo")


func _validate_refill_and_reset() -> void:
	var firearm := _controller.current_firearm
	firearm.magazine_ammo = 1
	firearm.reserve_ammo = 0
	var refill_control := _range.get_node_or_null("Interactables/RefillPistolAmmoControl") as DevRangeFirearmControl
	_check(refill_control != null, "Range REFILL AMMO control must be functional")
	if refill_control:
		refill_control.interact(_player)
	_check(firearm.magazine_ammo == 8 and firearm.reserve_ammo == 24, "Range refill must restore pistol magazine and reserve")
	var unarmored := _dummy("UNARMORED")
	unarmored.health.apply_damage(20, &"TORSO")
	var reset_control := _range.get_node("Interactables/ResetTargetsControl") as DevRangeResetControl
	reset_control.interact(_player)
	_check(unarmored.get_current_health() == 100.0 and not unarmored.is_dead(), "Existing RESET TARGETS control must remain functional")


func _validate_dev_controls() -> void:
	var menu := DevModeManager.get_node_or_null("DevMenu") as DevMenu
	var labels: Array[String] = []
	if menu:
		for button in menu.find_children("*", "Button", true, false):
			labels.append((button as Button).text)
	_check("GIVE PISTOL" in labels and "REMOVE PISTOL" in labels and "REFILL PISTOL AMMO" in labels, "Dev Menu must expose dedicated pistol controls")
	_check(DevModeManager.remove_pistol() and not InventoryManager.has_item(&"pistol"), "Dev remove-pistol control must clear the firearm slot")
	_check(DevModeManager.give_pistol(), "Dev give-pistol control must use normal slot assignment")
	await get_tree().process_frame
	_check(_controller.current_firearm != null, "Dev-given pistol must equip through the weapon controller")
	if _controller.current_firearm:
		_controller.current_firearm.magazine_ammo = 1
		_controller.current_firearm.reserve_ammo = 0
		_check(DevModeManager.refill_pistol_ammo() and _controller.current_firearm.magazine_ammo == 8 and _controller.current_firearm.reserve_ammo == 24, "Dev refill-pistol control must restore 8 / 24")


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


func _wait_until_ready() -> void:
	while _controller.current_firearm and _controller.current_firearm.cooldown_remaining > 0.0:
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


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	InventoryManager.clear_all_inventory(false)
	if is_instance_valid(_range):
		_range.free()
	DevModeManager.set_enabled(false)
	if _failures.is_empty():
		print("PISTOL VALIDATION: PASS — recoil/sway/bob/spread, slide/magazine/reload presentation, crosshair/ADS, hitscan damage and existing workflows")
	else:
		for failure in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
