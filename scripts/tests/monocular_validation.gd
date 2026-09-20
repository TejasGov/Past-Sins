extends Node3D

const RANGE := preload("res://scenes/dev/WeaponRange.tscn")
const MONOCULAR: ItemDefinition = preload("res://resources/items/monocular.tres")
const PISTOL: FirearmDefinition = preload("res://resources/weapons/pistol.tres")
const SNIPER: FirearmDefinition = preload("res://resources/weapons/sniper_rifle.tres")
const KNIFE: MeleeDefinition = preload("res://resources/weapons/kitchen_knife.tres")
var failures: Array[String] = []


func _ready() -> void: call_deferred("_validate")


func _validate() -> void:
	DevModeManager.set_enabled(true)
	var range_scene := RANGE.instantiate() as WeaponRange
	add_child(range_scene)
	for _frame in range(6): await get_tree().process_frame
	InventoryManager.clear_all_inventory(false)
	var player := DevModeManager.get_player() as PlayerController
	var equipment: Variant = player.get_node("EquipmentController")
	var firearms := player.get_node("WeaponController") as PlayerWeaponController
	var melee := player.get_node("MeleeController") as PlayerMeleeController

	_check(MONOCULAR.category == ItemDefinition.Category.EQUIPMENT and not MONOCULAR.stackable, "Monocular must be unique EQUIPMENT")
	_check(float(MONOCULAR.get("zoom_1_fov")) == 26.0 and float(MONOCULAR.get("zoom_2_fov")) == 13.0 and float(MONOCULAR.get("zoom_3_fov")) == 9.75, "Monocular must expose discrete 3x/6x/8x FOV states")
	var pickup: Node
	for node in get_tree().get_nodes_in_group("equipment_pickups"):
		if range_scene.is_ancestor_of(node) and node.get("definition") == MONOCULAR: pickup = node; break
	_check(pickup != null, "Range must replace the monocular placeholder with a functional pickup")
	if pickup: pickup.call("interact", player)
	_check(InventoryManager.has_item(&"monocular"), "Picking up monocular must add it to equipment inventory")
	_check(InventoryManager.get_firearm_slot(0) == null and InventoryManager.get_melee_slot() == null, "Monocular must not occupy firearm or melee slots")
	_check(not InventoryManager.add_item(MONOCULAR, 1, false), "Unique monocular must reject duplicate ownership")

	InventoryManager.add_item(PISTOL, 1, false)
	firearms.equip_slot(0)
	_check(equipment.toggle_selected() and equipment.visual != null, "Key 4 selection must create the first-person monocular")
	_check(equipment.activate(), "Use action must raise the selected monocular")
	var ammo_before := firearms.current_firearm.magazine_ammo
	_check(not firearms.fire() and firearms.current_firearm.magazine_ammo == ammo_before, "Firearms must not fire through monocular view")
	_check(not melee.attack(), "Melee must not attack through monocular view")
	_check(equipment.is_overlay_visible() and not equipment.visual.visible and not firearms.is_crosshair_visible() and not firearms.current_firearm.visible, "Active monocular view must hide the physical optic, weapon presentation and firearm crosshair")

	equipment.call("set_zoom_state", 1)
	var fov_before := player.camera.fov
	await get_tree().process_frame
	_check(player.camera.fov < fov_before and player.camera.fov > float(MONOCULAR.get("zoom_1_fov")), "Zoom transition must interpolate rather than snap")
	for _frame in range(45): equipment._process(0.016)
	_check(absf(player.camera.fov - float(MONOCULAR.get("zoom_1_fov"))) < 0.75 and equipment.get_zoom_label() == "3x", "First wheel step must settle at Zoom 1 / 3x")
	equipment.call("set_zoom_state", 2)
	for _frame in range(45): equipment._process(0.016)
	_check(absf(player.camera.fov - float(MONOCULAR.get("zoom_2_fov"))) < 0.75 and equipment.get_zoom_label() == "6x", "Second wheel step must settle at Zoom 2 / 6x")
	equipment.call("set_zoom_state", 3)
	for _frame in range(45): equipment._process(0.016)
	_check(absf(player.camera.fov - float(MONOCULAR.get("zoom_3_fov"))) < 0.75 and equipment.get_zoom_label() == "8x", "Third wheel step must settle at Zoom 3 / 8x")
	equipment.call("set_zoom_state", 99)
	_check(int(equipment.get("zoom_state")) == 3, "Zoom in must clamp at Zoom 3")
	equipment.call("set_zoom_state", 1)
	equipment.call("set_zoom_state", 0)
	equipment.call("set_zoom_state", -20)
	_check(int(equipment.get("zoom_state")) == 0 and equipment.call("get_zoom_label") == "1x", "Zoom out must return one discrete state and clamp at normal")

	player.is_sprinting = true; equipment._process(0.016)
	_check(not equipment.active, "Sprinting must cancel monocular view")
	player.is_sprinting = false
	for _frame in range(60): equipment._process(0.016)
	_check(not equipment.is_overlay_visible() and absf(player.camera.fov - float(MONOCULAR.get("normal_fov"))) < 0.2 and firearms.current_firearm.visible, "Closing monocular must restore FOV and prior weapon presentation")

	var rmb_press := InputEventMouseButton.new()
	rmb_press.button_index = MOUSE_BUTTON_RIGHT; rmb_press.pressed = true
	Input.parse_input_event(rmb_press); await get_tree().process_frame
	_check(equipment.active and not firearms.ads_active, "Holding RMB with the monocular selected must raise only the optic")
	var rmb_release := InputEventMouseButton.new()
	rmb_release.button_index = MOUSE_BUTTON_RIGHT; rmb_release.pressed = false
	Input.parse_input_event(rmb_release); await get_tree().process_frame
	_check(not equipment.active and not firearms.ads_active, "Releasing RMB must lower the optic without latching firearm ADS")
	for _frame in range(60): equipment._process(0.016)

	var observation_targets := get_tree().get_nodes_in_group("monocular_observation_targets").filter(func(node): return range_scene.is_ancestor_of(node))
	var distances: Array[int] = []
	for target in observation_targets: distances.append(int(target.get_meta("distance_m")))
	distances.sort()
	_check(distances == [15, 30, 60, 100], "Observation annex must provide 15m, 30m, 60m and 100m targets")
	_check(InputMap.has_action("equip_monocular") and InputMap.has_action("use_equipment") and InputMap.has_action("monocular_zoom_in") and InputMap.has_action("monocular_zoom_out"), "Monocular must use dedicated input actions")
	_check(_action_has_mouse_button(&"use_equipment", MOUSE_BUTTON_RIGHT), "Monocular use must be bound to RMB")

	# Regression: a lowered-but-selected monocular must not survive a weapon or
	# melee slot selection and steal the next RMB press.
	equipment.call("_stow_for_other_item")
	firearms.unequip_current(); melee.unequip_current(); InventoryManager.clear_all_inventory(false)
	InventoryManager.add_item(SNIPER, 1, false)
	InventoryManager.add_item(KNIFE, 1, false)
	InventoryManager.add_item(MONOCULAR, 1, false)
	_check(equipment.toggle_selected() and equipment.selected and not equipment.active, "Monocular must support a lowered selected state")
	equipment._input(_key_press(KEY_1))
	_check(not equipment.selected and not equipment.active and equipment.visual == null, "Key 1 must fully stow a lowered monocular")
	_check(firearms.current_firearm != null and firearms.current_firearm.definition == SNIPER, "Key 1 must equip the requested firearm after stowing monocular")
	firearms._unhandled_input(rmb_press)
	await get_tree().process_frame
	_check(not equipment.active and firearms.ads_active, "RMB after key 1 must enter firearm ADS, never reopen monocular")
	firearms._unhandled_input(rmb_release)
	await get_tree().process_frame
	_check(equipment.toggle_selected(), "Monocular must remain selectable after firearm handoff")
	equipment._input(_key_press(KEY_3))
	_check(not equipment.selected and not equipment.active, "Key 3 must fully stow the monocular")
	_check(melee.current_melee != null and melee.current_melee.definition == KNIFE and firearms.current_firearm == null, "Key 3 must equip the melee slot and clear the firearm")

	range_scene.free(); DevModeManager.set_enabled(false)
	if failures.is_empty(): print("MONOCULAR VALIDATION: PASS — RMB hold view, slot handoff, melee switching, hidden optic, 1x/3x/6x/8x zoom and weapon safety")
	else:
		for failure in failures: push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)


func _action_has_mouse_button(action: StringName, button: MouseButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button:
			return true
	return false


func _key_press(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	return event
