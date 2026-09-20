extends Node3D

const RANGE := preload("res://scenes/dev/WeaponRange.tscn")
const KNIFE: MeleeDefinition = preload("res://resources/weapons/kitchen_knife.tres")
const SLINGSHOT: SlingshotDefinition = preload("res://resources/weapons/improvised_slingshot.tres")
const SNIPER: FirearmDefinition = preload("res://resources/weapons/sniper_rifle.tres")

var failures: Array[String] = []
var range_scene: WeaponRange
var player: PlayerController
var controller: PlayerMeleeController


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	DevModeManager.set_enabled(true)
	range_scene = RANGE.instantiate() as WeaponRange
	add_child(range_scene)
	for frame in range(4): await get_tree().process_frame
	await get_tree().physics_frame
	player = DevModeManager.get_player()
	controller = player.get_node("MeleeController") as PlayerMeleeController
	_check(controller != null, "Player must own a separate reusable melee controller")
	_check(InputMap.has_action("equip_melee_slot"), "Melee slot must have a dedicated input action")
	_check(_action_has_key("equip_melee_slot", KEY_3), "Melee slot must bind to key 3")
	_check(KNIFE.reach >= 1.4 and KNIFE.reach <= 1.7, "Knife reach must remain realistic and configurable")
	_check(KNIFE.weapon_visibility_class == &"MELEE" and SLINGSHOT.weapon_visibility_class == &"IMPROVISED_WEAPON", "Improvised-slot weapons must expose their correct visibility classes")
	await _validate_visual(KNIFE, ["Blade", "CuttingEdge", "BladeTip", "Handle", "HandleRivet10"])

	InventoryManager.clear_all_inventory()
	_check(InventoryManager.add_item(KNIFE), "Knife must enter the reusable melee slot")
	_check(not InventoryManager.add_item(SLINGSHOT) and InventoryManager.get_last_feedback() == InventoryComponent.MELEE_SLOT_FULL, "Knife and slingshot must compete for the same single improvised slot")
	_check(InventoryManager.add_item(SNIPER), "A firearm and melee weapon must coexist in independent slots")
	var firearm_controller := player.get_node("WeaponController") as PlayerWeaponController
	_check(firearm_controller.equip_slot(0), "Firearm must equip before the melee switching check")
	_check(controller.equip_melee_slot() and controller.current_melee.definition == KNIFE, "Key-slot controller must equip the knife")
	_check(firearm_controller.current_firearm == null and not firearm_controller.is_crosshair_visible() and not firearm_controller.is_scope_overlay_visible(), "Selecting melee must clear firearm, crosshair, ADS and scope state")
	_check(controller.get_weapon_visibility_class() == &"MELEE", "Equipped melee must report its visibility class")

	var armored_labels := ["UNARMORED", "STANDARD VEST", "ADVANCED VEST"]
	for label in armored_labels:
		var dummy := _dummy(label)
		dummy.reset_target()
		await _swing_at(dummy, KNIFE)
		_check(dummy.is_dead(), "Knife successful hit must be lethal against %s" % label)

	var melee_target := _dummy("MELEE RESET TARGET")
	melee_target.reset_target()
	await _swing_at(melee_target, KNIFE)
	var readout := (range_scene.get_node("DamageTestTool") as DevDamageTestTool).get_last_readout()
	_check(readout == "KITCHEN KNIFE\nLETHAL MELEE\nTARGET: DEAD", "Knife hit must produce an explicit lethal-melee readout")

	# Range and first-solid-collision behavior are checked independently of model animation.
	melee_target.reset_target()
	_position_and_aim(melee_target, 2.4)
	controller.attack()
	await _wait_for_swing(KNIFE)
	_check(not melee_target.is_dead(), "Melee must not hit targets beyond configured reach")
	melee_target.reset_target()
	_position_and_aim(melee_target, 1.15)
	var blocker := _make_blocker(player.camera.global_position.lerp(_torso(melee_target).global_position, 0.5))
	controller.attack()
	await _wait_for_swing(KNIFE)
	_check(not melee_target.is_dead(), "A solid wall/closed-door collision must block melee")
	blocker.queue_free()
	await get_tree().physics_frame

	# Future special targets can opt out without changing either weapon.
	melee_target.reset_target()
	melee_target.health.lethal_melee_vulnerable = false
	await _swing_at(melee_target, KNIFE)
	_check(not melee_target.is_dead() and melee_target.get_current_health() == 65.0, "Lethal-melee immunity must fall back to configurable ordinary damage")
	melee_target.health.lethal_melee_vulnerable = true

	var dropped := controller.unequip_and_drop_current()
	await get_tree().process_frame
	_check(dropped and InventoryManager.get_melee_slot() == null, "Dropping melee must free the melee slot")
	_check(_owned_group("melee_pickups").size() >= 3, "Dropped melee must become a reusable world pickup")
	_check(DevModeManager.give_kitchen_knife() and DevModeManager.remove_kitchen_knife(), "Dev Menu API must give and remove knife")
	_check(DevModeManager.give_slingshot() and DevModeManager.remove_slingshot(), "Dev Menu API must give and remove slingshot")

	range_scene.free()
	DevModeManager.set_enabled(false)
	if failures.is_empty():
		print("MELEE WEAPON VALIDATION: PASS — models, slot, switching, lethal armor bypass, range, occlusion, special-target opt-out, drop and Dev APIs")
	else:
		for failure in failures: push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _swing_at(dummy: DamageableHumanDummy, definition: MeleeDefinition) -> void:
	_position_and_aim(dummy, 1.15)
	_check(controller.attack(), "%s swing must start when ready" % definition.display_name)
	await _wait_for_swing(definition)


func _wait_for_swing(definition: MeleeDefinition) -> void:
	var frames := ceili((definition.attack_cooldown + 0.08) * 60.0)
	for frame in range(frames): await get_tree().physics_frame


func _position_and_aim(dummy: DamageableHumanDummy, distance: float) -> void:
	player.global_position = dummy.global_position + Vector3(0, 0, distance)
	player.velocity = Vector3.ZERO
	player.camera.look_at(_torso(dummy).global_position, Vector3.UP)


func _torso(dummy: DamageableHumanDummy) -> BodyHitZone:
	return dummy.get_node("Body/Torso") as BodyHitZone


func _make_blocker(at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 2.6, 0.2)
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = at
	return body


func _dummy(label: String) -> DamageableHumanDummy:
	for node in get_tree().get_nodes_in_group("weapon_range_damage_dummies"):
		if range_scene.is_ancestor_of(node) and (node as DamageableHumanDummy).target_label == label:
			return node as DamageableHumanDummy
	return null


func _validate_visual(definition: MeleeDefinition, parts: Array[String]) -> void:
	for scene in [definition.first_person_visual_scene, definition.world_visual_scene]:
		var packed := scene as PackedScene
		var instance: Node = packed.instantiate()
		add_child(instance)
		await get_tree().process_frame
		for part in parts: _check(instance.find_child(part, true, false) != null, "%s model is missing recognizable %s" % [definition.display_name, part])
		instance.free()


func _owned_group(group_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for node in get_tree().get_nodes_in_group(group_name):
		if range_scene.is_ancestor_of(node): result.append(node)
	return result


func _action_has_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode: return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
