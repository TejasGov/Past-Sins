extends Node

const CAMPUS := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn")
const HUB := preload("res://scenes/dev/DevTestHub.tscn")
const RANGE := preload("res://scenes/dev/WeaponRange.tscn")
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	DevModeManager.set_enabled(false)
	_check(not DevModeManager.is_enabled(), "Play Mode must be the default")
	_check(DevModeManager.get_node_or_null("DevMenu") == null, "Play Mode must not instantiate developer UI")
	var unlock_shortcut_bound := false
	for binding in InputMap.action_get_events(&"open_dev_unlock"):
		if binding is InputEventKey:
			var key := binding as InputEventKey
			if key.physical_keycode == KEY_D and key.meta_pressed: unlock_shortcut_bound = true
	_check(unlock_shortcut_bound, "open_dev_unlock must be physically bound to Command+D")
	var unlock_event := InputEventAction.new()
	unlock_event.action = &"open_dev_unlock"
	unlock_event.pressed = true
	DevModeManager._input(unlock_event)
	_check(not DevModeManager.is_enabled(), "Command+D must require authorization before enabling Dev Mode")
	_check(DevModeManager.get_node_or_null("DevUnlockPrompt") != null, "Command+D must open the authorization text box")
	_check(not DevModeManager.attempt_dev_unlock("wrong"), "Incorrect development code must be rejected")
	_check(not DevModeManager.is_enabled(), "Incorrect development code must leave Play Mode active")
	_check(DevModeManager.attempt_dev_unlock("tez"), "Development code tez must authorize Dev Mode")
	_check(DevModeManager.is_enabled(), "Accepted development code must enter Dev Mode at runtime")
	_check(DevModeManager.is_menu_open(), "Accepted development code must open the developer menu")
	DevModeManager.set_enabled(false)
	await get_tree().process_frame
	_check(not DevModeManager.is_enabled(), "Exit Dev Mode must return to Play Mode at runtime")
	_check(not DevModeManager.is_menu_open(), "Returning to Play Mode must close the developer menu")
	_check(DevModeManager.get_node_or_null("DevMenu") == null, "Returning to Play Mode must remove developer UI")

	DevModeManager.set_enabled(true)
	await get_tree().process_frame
	_check(DevModeManager.is_enabled(), "Dev Mode must be enableable at runtime")
	_check(DevModeManager.get_node_or_null("DevMenu") != null, "Dev Mode must instantiate the reusable menu")
	var f8_bound := false
	for binding in InputMap.action_get_events(&"toggle_dev_menu"):
		if binding is InputEventKey and (binding as InputEventKey).physical_keycode == KEY_F8: f8_bound = true
	_check(f8_bound, "toggle_dev_menu must be physically bound to F8")

	var campus := CAMPUS.instantiate() as PrisonCampusPrototype
	add_child(campus)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	_check(player != null, "Playable campus must provide a player for dev tools")
	var destinations := DevModeManager.get_teleport_entries()
	_check(destinations.size() >= 20, "Campus must register at least 20 named destinations, found %d" % destinations.size())
	var probe := CapsuleShape3D.new()
	probe.radius = 0.35
	probe.height = 1.8
	for entry in destinations:
		var point := (entry.target as WeakRef).get_ref() as Node3D
		_check(_destination_is_clear(point, probe), "Dev destination intersects campus geometry: %s" % entry.display_name)
		_check(DevModeManager.teleport_to(entry.id), "Teleport button command failed: %s" % entry.display_name)
		_check(player.global_position.distance_to(point.global_position) < 0.05, "Teleport did not use marker transform: %s" % entry.display_name)
	for required in [&"cellhouse_a_floor_1", &"cellhouse_a_floor_2", &"cellhouse_a_floor_3", &"cellhouse_b_floor_1", &"cellhouse_b_floor_2", &"food_services", &"medical_ward", &"security_hq_ground", &"security_hq_upper", &"maintenance_ground", &"maintenance_b1", &"administration", &"central_yard", &"pool_annex", &"nidra_b2"]:
		_check(_has_destination(destinations, required), "Missing dev destination: %s" % required)

	var event := InputEventAction.new()
	event.action = &"toggle_dev_menu"
	event.pressed = true
	DevModeManager._unhandled_input(event)
	_check(DevModeManager.is_menu_open(), "F8 action must open the developer menu")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Menu must release the mouse")
	DevModeManager._unhandled_input(event)
	_check(not DevModeManager.is_menu_open(), "F8 action must close the developer menu")

	_check(DevModeManager.teleport_to(&"central_yard"), "Named teleport command failed")
	var yard_target := _target_for(&"central_yard")
	_check(yard_target != null and player.global_position.distance_to(yard_target.global_position) < 0.05, "Teleport must use the named marker transform")

	DevModeManager.set_player_health(37.0)
	DevModeManager.set_vest(&"standard_vest")
	DevModeManager.set_invulnerable(true)
	DevModeManager.set_noclip(true)
	_check(is_equal_approx(float(player.get_meta("dev_health", -1.0)), 37.0), "Health adapter did not update player test state")
	_check(player.get_meta("dev_vest", &"") == &"standard_vest", "Standard vest adapter did not update player test state")
	_check(DevModeManager.blocks_player_failure(), "Invulnerability must block the failure boundary")
	_check(player.collision_mask == 0 and not player.is_physics_processing(), "Noclip must disable ordinary player collision/motor")
	DevModeManager.return_player_to_normal()
	_check(not DevModeManager.invulnerable and not DevModeManager.noclip_enabled and player.is_physics_processing(), "Return-to-normal must clear dev toggles")

	_check(DevModeManager.give_key(&"service_key"), "Individual key grant failed")
	_check(AccessManager.has_key(&"service_key"), "Granted key did not reach AccessManager")
	DevModeManager.give_all_keys()
	_check(AccessManager.has_key(&"security_key") and AccessManager.has_key(&"lab_key"), "Give-all must include secure registered keys")
	DevModeManager.clear_test_inventory()
	_check(not AccessManager.has_key(&"service_key") and not AccessManager.has_key(&"security_key"), "Clear test inventory must remove dev-granted keys")
	var extension_state := {"item": false, "command": false}
	DevModeManager.register_test_item(&"future_test_item", "Future Test Item", func(): extension_state.item = true, func(): extension_state.item = false)
	DevModeManager.register_command(&"future_command", "Future Command", "Validation", func(): extension_state.command = true)
	_check(DevModeManager.give_test_item(&"future_test_item") and bool(extension_state.item), "Registered future item give handler failed")
	_check(DevModeManager.remove_test_item(&"future_test_item") and not bool(extension_state.item), "Registered future item remove handler failed")
	_check(DevModeManager.execute_command(&"future_command") and bool(extension_state.command), "Registered future command handler failed")

	var access := DevModeManager.get_access_entries()
	_check(not access.is_empty(), "World tools require registered loaded doors/gates")
	if not access.is_empty():
		_check(DevModeManager.set_selected_access_state(access[0], &"open"), "Selected access open command failed")
		var selected := (access[0].target as WeakRef).get_ref() as Node3D
		_check(selected != null and bool(selected.get("is_open")), "Selected access did not reach open state")
		DevModeManager.reset_access_to_defaults()
		var original_locked := bool(selected.get("is_locked"))
		var original_open := bool(selected.get("is_open"))
		DevModeManager.give_key(&"lab_key")
		DevModeManager.set_selected_access_state(access[0], &"open")
		DevModeManager.set_enabled(false)
		await get_tree().process_frame
		_check(not AccessManager.has_key(&"lab_key"), "Leaving Dev Mode must clear dev-granted keys")
		_check(bool(selected.get("is_locked")) == original_locked and bool(selected.get("is_open")) == original_open, "Leaving Dev Mode must restore temporary door/gate overrides")
		DevModeManager.set_enabled(true)
		await get_tree().process_frame

	campus.free()
	await get_tree().process_frame
	var hub := HUB.instantiate() as DevTestHub
	add_child(hub)
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(hub.has_node("WeaponsRangeSpawn"), "Separate Dev Test Hub is missing the Weapons Test Range")
	_check(get_tree().get_first_node_in_group("player") != null, "Dev Test Hub must be enterable with a player")
	_check(_has_destination(DevModeManager.get_teleport_entries(), &"weapons_range_staging"), "Dev Hub must retain a Weapons Range transfer bay")
	_check(_test_scene_path(&"weapons_test_range") == "res://scenes/dev/WeaponRange.tscn", "Weapons Test Range must be a dedicated registered scene")
	_check(_test_scene_path(&"dev_test_hub") == "res://scenes/dev/DevTestHub.tscn", "Dev Test Hub must remain separately registered")
	var dedicated_range := RANGE.instantiate() as WeaponRange
	add_child(dedicated_range)
	await get_tree().process_frame
	_check(dedicated_range.get_node_or_null("Interactables/ReturnToDevHub") != null, "Dedicated range must include return-to-hub navigation")
	dedicated_range.free()

	hub.free()
	DevModeManager.set_menu_open(true)
	DevModeManager.set_enabled(false)
	await get_tree().process_frame
	_check(DevModeManager.get_node_or_null("DevMenu") == null, "Disabling Dev Mode must remove all dev UI")
	_check(not DevModeManager.is_enabled(), "Play Mode must be restored after dev testing")
	_check(not DevModeManager.is_menu_open(), "Disabling Dev Mode must close an open menu cleanly")

	if _failures.is_empty():
		print("DEV MODE VALIDATION: PASS — Command+D authorization, isolated Play Mode, F8 menu, 20+ destinations, player/access tools and external test hub")
	else:
		for failure in _failures: push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _has_destination(entries: Array[Dictionary], id: StringName) -> bool:
	for entry in entries:
		if entry.id == id: return true
	return false


func _target_for(id: StringName) -> Node3D:
	for entry in DevModeManager.get_teleport_entries():
		if entry.id == id: return (entry.target as WeakRef).get_ref() as Node3D
	return null


func _test_scene_path(id: StringName) -> String:
	for entry in DevModeManager.get_test_scene_entries():
		if entry.id == id: return String(entry.scene_path)
	return ""


func _destination_is_clear(point: Node3D, shape: Shape3D) -> bool:
	if point == null: return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = point.global_transform
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_viewport().world_3d.direct_space_state.intersect_shape(query, 4).is_empty()


func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
