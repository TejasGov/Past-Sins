extends Node

## Permanent, registration-driven development framework. Dev tools start inert
## unless enabled by project settings/CLI. Play Mode exposes only the deliberate
## developer authorization prompt shortcut (Command+D by default).
signal mode_changed(enabled: bool)
signal menu_visibility_changed(open: bool)
signal registry_changed
signal player_test_state_changed

const MENU_SCENE := preload("res://scenes/dev/DevMenu.tscn")
const UNLOCK_PROMPT_SCENE := preload("res://scenes/dev/DevUnlockPrompt.tscn")
const NOCLIP_CONTROLLER := preload("res://scripts/dev/dev_noclip_controller.gd")
const CAMPUS_SCENE := "res://scenes/levels/campus/PrisonCampusPrototype.tscn"
const DEV_ACCESS_CODE := "tez"
const PISTOL_DEFINITION: FirearmDefinition = preload("res://resources/weapons/pistol.tres")
const SMG_DEFINITION: FirearmDefinition = preload("res://resources/weapons/smg.tres")
const CARBINE_DEFINITION: FirearmDefinition = preload("res://resources/weapons/carbine_ar.tres")
const SNIPER_DEFINITION: FirearmDefinition = preload("res://resources/weapons/sniper_rifle.tres")
const KNIFE_DEFINITION: MeleeDefinition = preload("res://resources/weapons/kitchen_knife.tres")
const SLINGSHOT_DEFINITION: SlingshotDefinition = preload("res://resources/weapons/improvised_slingshot.tres")
const SLINGSHOT_NAIL: ItemDefinition = preload("res://resources/items/slingshot_nail.tres")
const SLINGSHOT_TOXIN_NAIL: ItemDefinition = preload("res://resources/items/slingshot_nail_toxin.tres")
const MONOCULAR_DEFINITION: ItemDefinition = preload("res://resources/items/monocular.tres")
const PROPER_SUPPRESSOR: SuppressorDefinition = preload("res://resources/items/proper_suppressor.tres")
const MAKESHIFT_SUPPRESSOR: SuppressorDefinition = preload("res://resources/items/makeshift_suppressor.tres")
const TEST_INVENTORY_DEFINITIONS: Array[ItemDefinition] = [
	PISTOL_DEFINITION,
	SMG_DEFINITION,
	CARBINE_DEFINITION,
	SNIPER_DEFINITION,
	KNIFE_DEFINITION,
	SLINGSHOT_DEFINITION,
	SLINGSHOT_NAIL,
	SLINGSHOT_TOXIN_NAIL,
	MONOCULAR_DEFINITION,
	PROPER_SUPPRESSOR,
	MAKESHIFT_SUPPRESSOR,
	preload("res://resources/items/dev/test_firearm_a.tres"),
	preload("res://resources/items/dev/test_firearm_b.tres"),
	preload("res://resources/items/dev/test_firearm_c.tres"),
	preload("res://resources/items/dev/test_melee_a.tres"),
	preload("res://resources/items/dev/test_melee_b.tres"),
	preload("res://resources/items/dev/test_equipment.tres"),
	preload("res://resources/items/dev/test_stackable_equipment.tres"),
]

var enabled := false
var invulnerable := false
var noclip_enabled := false
var infinite_stamina := false
var test_health := 100.0
var test_max_health := 100.0
var equipped_vest: StringName = &""

var _teleports: Dictionary = {}
var _test_items: Dictionary = {}
var _commands: Dictionary = {}
var _test_scenes: Dictionary = {}
var _dev_granted_keys: Dictionary = {}
var _dev_modified_access: Dictionary = {}
var _menu: CanvasLayer
var _unlock_prompt: CanvasLayer
var _noclip: DevNoclipController
var _menu_open := false
var _saved_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _saved_player_control := true
var _unlock_saved_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _unlock_saved_player_control := true
var _last_player_id := 0
var _current_scene_id := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Authorization must remain available while the rest of the framework is
	# dormant. _input handles only Command+D; F8/dev commands remain disabled.
	set_process_input(true)
	enabled = bool(ProjectSettings.get_setting("blacksite/development/dev_mode", false)) or OS.get_cmdline_user_args().has("--dev-mode")
	_register_builtins()
	if enabled:
		call_deferred("_activate")
		mode_changed.emit(true)


func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("open_dev_unlock", true):
		return
	if enabled:
		set_menu_open(true)
	else:
		open_unlock_prompt()
	get_viewport().set_input_as_handled()


func open_unlock_prompt() -> void:
	if enabled or _unlock_prompt != null:
		return
	_unlock_saved_mouse_mode = Input.mouse_mode
	var player := get_player()
	if player and player.has_method("set_control_enabled"):
		_unlock_saved_player_control = bool(player.get("control_enabled"))
		player.call("set_control_enabled", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_unlock_prompt = UNLOCK_PROMPT_SCENE.instantiate() as CanvasLayer
	add_child(_unlock_prompt)
	_unlock_prompt.code_submitted.connect(attempt_dev_unlock)
	_unlock_prompt.cancelled.connect(close_unlock_prompt)


func attempt_dev_unlock(code: String) -> bool:
	if enabled:
		set_menu_open(true)
		return true
	if code.strip_edges().to_lower() != DEV_ACCESS_CODE:
		if _unlock_prompt:
			_unlock_prompt.show_error()
		return false
	close_unlock_prompt()
	set_enabled(true)
	set_menu_open(true)
	return true


func close_unlock_prompt() -> void:
	if _unlock_prompt == null:
		return
	var player := get_player()
	if player and player.has_method("set_control_enabled"):
		player.call("set_control_enabled", _unlock_saved_player_control)
	Input.mouse_mode = _unlock_saved_mouse_mode
	_unlock_prompt.queue_free()
	_unlock_prompt = null


func _process(_delta: float) -> void:
	if not enabled:
		return
	var scene := get_tree().current_scene
	var scene_id := scene.get_instance_id() if scene else 0
	if scene_id != _current_scene_id:
		_current_scene_id = scene_id
		_prune_scene_registry()
		call_deferred("_refresh_menu")
	var player := get_player()
	var player_id := player.get_instance_id() if player else 0
	if player_id != _last_player_id:
		_last_player_id = player_id
		_apply_state_to_player(player)


func _unhandled_input(event: InputEvent) -> void:
	if enabled and event.is_action_pressed("toggle_dev_menu"):
		toggle_menu()
		get_viewport().set_input_as_handled()


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if enabled:
		_activate()
	else:
		_deactivate()
	mode_changed.emit(enabled)


func is_enabled() -> bool:
	return enabled


func is_menu_open() -> bool:
	return _menu_open


func toggle_menu() -> void:
	if not enabled:
		return
	set_menu_open(not _menu_open)


func set_menu_open(open: bool) -> void:
	if (not enabled and open) or _menu_open == open:
		return
	_menu_open = open
	var player := get_player()
	if open:
		_saved_mouse_mode = Input.mouse_mode
		if player and player.has_method("set_control_enabled"):
			_saved_player_control = bool(player.get("control_enabled"))
			player.call("set_control_enabled", false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if player and player.has_method("set_control_enabled"):
			player.call("set_control_enabled", _saved_player_control)
		Input.mouse_mode = _saved_mouse_mode
	if _menu and _menu.has_method("set_menu_open"):
		_menu.call("set_menu_open", open)
	menu_visibility_changed.emit(open)


func register_teleport_point(id: StringName, display_name: String, category: String, marker: Node3D) -> void:
	if not enabled or id.is_empty() or not is_instance_valid(marker):
		return
	marker.add_to_group("dev_teleport_points")
	_teleports[id] = {"id": id, "display_name": display_name, "category": category, "target": weakref(marker)}
	registry_changed.emit()
	_refresh_menu()


func register_test_scene(id: StringName, display_name: String, scene_path: String) -> void:
	if id.is_empty() or scene_path.is_empty():
		return
	_test_scenes[id] = {"id": id, "display_name": display_name, "scene_path": scene_path}
	registry_changed.emit()


func register_test_item(id: StringName, display_name: String, give_callable: Callable, remove_callable: Callable = Callable(), item_definition: ItemDefinition = null) -> void:
	_test_items[id] = {"id": id, "display_name": display_name, "give": give_callable, "remove": remove_callable, "item_definition": item_definition}
	registry_changed.emit()


func register_inventory_test_definition(item_definition: ItemDefinition) -> void:
	if item_definition == null or not item_definition.is_valid_definition() or not item_definition.dev_only:
		return
	var item_id := item_definition.normalized_id()
	register_test_item(
		item_id,
		item_definition.display_name,
		_give_inventory_definition.bind(item_definition),
		_remove_inventory_definition.bind(item_id),
		item_definition
	)


func register_command(id: StringName, display_name: String, category: String, callable: Callable) -> void:
	_commands[id] = {"id": id, "display_name": display_name, "category": category, "callable": callable}
	registry_changed.emit()


func get_teleport_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _teleports.values():
		var target: Object = (entry.target as WeakRef).get_ref()
		if is_instance_valid(target):
			result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := "%s/%s" % [a.category, a.display_name]
		var right := "%s/%s" % [b.category, b.display_name]
		return left.naturalnocasecmp_to(right) < 0)
	return result


func get_test_scene_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _test_scenes.values():
		result.append(entry)
	return result


func get_test_item_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _test_items.values():
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.display_name).naturalnocasecmp_to(String(b.display_name)) < 0)
	return result


func give_test_item(id: StringName) -> bool:
	if not enabled or not _test_items.has(id):
		return false
	var callable: Callable = _test_items[id].give
	if not callable.is_valid():
		return false
	var result: Variant = callable.call()
	return bool(result) if result is bool else true


func remove_test_item(id: StringName) -> bool:
	if not enabled or not _test_items.has(id):
		return false
	var callable: Callable = _test_items[id].remove
	if not callable.is_valid():
		return false
	var result: Variant = callable.call()
	return bool(result) if result is bool else true


func get_command_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _commands.values():
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return ("%s/%s" % [a.category, a.display_name]).naturalnocasecmp_to("%s/%s" % [b.category, b.display_name]) < 0)
	return result


func execute_command(id: StringName) -> bool:
	if not enabled or not _commands.has(id):
		return false
	var callable: Callable = _commands[id].callable
	if not callable.is_valid():
		return false
	callable.call()
	return true


func teleport_to(id: StringName) -> bool:
	if not enabled or not _teleports.has(id):
		return false
	var target := (_teleports[id].target as WeakRef).get_ref() as Node3D
	var player := get_player()
	if not is_instance_valid(target) or player == null:
		return false
	set_menu_open(false)
	player.global_transform = target.global_transform
	player.velocity = Vector3.ZERO
	if player.has_method("exit_restricted_zone"):
		player.set("restricted_suspicion_multiplier", 1.0)
	SuspicionSystem.reset()
	return true


func enter_test_scene(id: StringName) -> bool:
	if not enabled or not _test_scenes.has(id):
		return false
	set_menu_open(false)
	return get_tree().change_scene_to_file(String(_test_scenes[id].scene_path)) == OK


func return_to_campus() -> bool:
	if not enabled:
		return false
	set_menu_open(false)
	return get_tree().change_scene_to_file(CAMPUS_SCENE) == OK


func get_player() -> PlayerController:
	return get_tree().get_first_node_in_group("player") as PlayerController


func reset_player_health() -> void:
	set_player_health(test_max_health)


func set_player_health(value: float) -> void:
	test_health = clampf(value, 0.0, test_max_health)
	var player := get_player()
	if player:
		if player.has_method("set_health"):
			player.call("set_health", test_health)
		else:
			player.set_meta("dev_health", test_health)
			player.set_meta("dev_max_health", test_max_health)
	player_test_state_changed.emit()


func set_vest(vest_id: StringName) -> void:
	equipped_vest = vest_id if vest_id in [&"standard_vest", &"advanced_vest"] else &""
	var player := get_player()
	if player:
		if player.has_method("equip_vest"):
			player.call("equip_vest", equipped_vest)
		else:
			player.set_meta("dev_vest", equipped_vest)
	player_test_state_changed.emit()


func set_invulnerable(value: bool) -> void:
	invulnerable = value if enabled else false
	var player := get_player()
	if player:
		player.set_meta("dev_invulnerable", invulnerable)
	player_test_state_changed.emit()


func blocks_player_failure() -> bool:
	return enabled and invulnerable


func set_noclip(value: bool) -> void:
	noclip_enabled = value if enabled else false
	_apply_noclip(get_player())
	player_test_state_changed.emit()


func set_infinite_stamina(value: bool) -> void:
	infinite_stamina = value if enabled else false
	var player := get_player()
	if player:
		if player.has_method("set_infinite_stamina"):
			player.call("set_infinite_stamina", infinite_stamina)
		else:
			player.set_meta("dev_infinite_stamina", infinite_stamina)
	player_test_state_changed.emit()


func return_player_to_normal() -> void:
	set_invulnerable(false)
	set_noclip(false)
	set_infinite_stamina(false)
	set_vest(&"")
	reset_player_health()
	SuspicionSystem.reset()


func get_registered_key_ids() -> Array[StringName]:
	var ids: Dictionary = {}
	for key_id in [&"cellblock_key", &"service_key", &"medical_key", &"security_key", &"lab_key", &"cell_master_key"]:
		ids[key_id] = true
	var scene := get_tree().current_scene
	if scene:
		for node in scene.find_children("*", "", true, false):
			if node is KeyPickup:
				ids[(node as KeyPickup).key_id] = true
			elif node is NormalDoor:
				var normal := node as NormalDoor
				if not normal.required_key_id.is_empty(): ids[normal.required_key_id] = true
			elif node is PrisonSlidingGate:
				var gate := node as PrisonSlidingGate
				if not gate.required_key_id.is_empty(): ids[gate.required_key_id] = true
				if not gate.master_key_id.is_empty(): ids[gate.master_key_id] = true
	var result: Array[StringName] = []
	for id in ids.keys():
		if not StringName(id).is_empty(): result.append(StringName(id))
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a).naturalnocasecmp_to(str(b)) < 0)
	return result


func give_key(key_id: StringName) -> bool:
	if not enabled or key_id.is_empty():
		return false
	var added := AccessManager.add_key(key_id, str(key_id).replace("_", " ").capitalize())
	if added:
		_dev_granted_keys[key_id] = true
	return added


func remove_key(key_id: StringName) -> bool:
	if not enabled:
		return false
	_dev_granted_keys.erase(key_id)
	return AccessManager.remove_key(key_id)


func give_all_keys() -> void:
	for key_id in get_registered_key_ids():
		give_key(key_id)


func clear_test_inventory() -> void:
	for key_id in _dev_granted_keys.keys():
		AccessManager.remove_key(key_id)
	_dev_granted_keys.clear()
	InventoryManager.clear_dev_only_items()
	for entry in _test_items.values():
		if entry.item_definition != null:
			continue
		var remove_callable: Callable = entry.remove
		if remove_callable.is_valid(): remove_callable.call()
	registry_changed.emit()


func get_inventory_summary() -> String:
	var slot_1 := InventoryManager.get_firearm_slot(InventoryComponent.FIREARM_SLOT_1) as ItemDefinition
	var slot_2 := InventoryManager.get_firearm_slot(InventoryComponent.FIREARM_SLOT_2) as ItemDefinition
	var melee := InventoryManager.get_melee_slot() as ItemDefinition
	var equipment_lines: PackedStringArray = []
	for entry in InventoryManager.get_inventory_entries():
		var definition := entry.definition as ItemDefinition
		if definition.category == ItemDefinition.Category.EQUIPMENT:
			equipment_lines.append("%s  x%d" % [definition.display_name, int(entry.count)])
	var keys := AccessManager.get_keys()
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	var access := AccessManager.get_unlocked_access_ids()
	access.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return "FIREARM SLOT 1: %s\nFIREARM SLOT 2: %s\nMELEE SLOT: %s\n\nEQUIPMENT\n%s\nMONOCULAR STATE: %s\nSUPPRESSOR: %s\n\nKEYS / ACCESS CARDS (%d)\n%s\n\nUNLOCKED ACCESS (%d)\n%s" % [
		_slot_label(slot_1), _slot_label(slot_2), _slot_label(melee),
		"\n".join(equipment_lines) if not equipment_lines.is_empty() else "—",
		get_monocular_state(), get_suppressor_state(),
		keys.size(), _join_ids(keys), access.size(), _join_ids(access),
	]


func clear_firearm_slots() -> void:
	InventoryManager.clear_firearm_slots()


func clear_melee_slot() -> void:
	InventoryManager.clear_melee_slot()


func clear_equipment_inventory() -> void:
	InventoryManager.clear_equipment()


func clear_all_inventory() -> void:
	InventoryManager.clear_all_inventory()
	_dev_granted_keys.clear()


func get_last_inventory_feedback() -> String:
	return InventoryManager.get_last_feedback()


func give_pistol() -> bool:
	return enabled and InventoryManager.add_item(PISTOL_DEFINITION)


func remove_pistol() -> bool:
	return enabled and InventoryManager.remove_item(PISTOL_DEFINITION.item_id)


func refill_pistol_ammo() -> bool:
	if not enabled:
		return false
	var player := get_player()
	var controller := player.get_node_or_null("WeaponController") as PlayerWeaponController if player else null
	return controller != null and controller.refill_firearm_ammo(&"pistol")


func give_smg() -> bool:
	return enabled and InventoryManager.add_item(SMG_DEFINITION)


func remove_smg() -> bool:
	return enabled and InventoryManager.remove_item(SMG_DEFINITION.item_id)


func refill_smg_ammo() -> bool:
	if not enabled:
		return false
	var player := get_player()
	var controller := player.get_node_or_null("WeaponController") as PlayerWeaponController if player else null
	return controller != null and controller.refill_firearm_ammo(&"smg")


func give_carbine_ar() -> bool:
	return enabled and InventoryManager.add_item(CARBINE_DEFINITION)


func remove_carbine_ar() -> bool:
	return enabled and InventoryManager.remove_item(CARBINE_DEFINITION.item_id)


func refill_carbine_ammo() -> bool:
	if not enabled:
		return false
	var player := get_player()
	var controller := player.get_node_or_null("WeaponController") as PlayerWeaponController if player else null
	return controller != null and controller.refill_firearm_ammo(&"carbine_ar")


func give_sniper_rifle() -> bool:
	return enabled and InventoryManager.add_item(SNIPER_DEFINITION)


func remove_sniper_rifle() -> bool:
	return enabled and InventoryManager.remove_item(SNIPER_DEFINITION.item_id)


func refill_sniper_ammo() -> bool:
	if not enabled:
		return false
	var player := get_player()
	var controller := player.get_node_or_null("WeaponController") as PlayerWeaponController if player else null
	return controller != null and controller.refill_firearm_ammo(&"sniper_rifle")


func give_kitchen_knife() -> bool:
	return enabled and InventoryManager.add_item(KNIFE_DEFINITION)


func remove_kitchen_knife() -> bool:
	return enabled and InventoryManager.remove_item(KNIFE_DEFINITION.item_id)


func give_slingshot() -> bool:
	if not enabled: return false
	if not InventoryManager.has_item(SLINGSHOT_DEFINITION.item_id) and not InventoryManager.add_item(SLINGSHOT_DEFINITION): return false
	var missing := maxi(0, 12 - InventoryManager.get_item_count(SLINGSHOT_NAIL.item_id))
	if missing > 0: InventoryManager.add_item(SLINGSHOT_NAIL, missing)
	return true


func remove_slingshot() -> bool:
	return enabled and InventoryManager.remove_item(SLINGSHOT_DEFINITION.item_id)


func give_normal_nails(quantity := 12) -> bool:
	return enabled and InventoryManager.add_item(SLINGSHOT_NAIL, quantity)


func give_toxin_nails(quantity := 12) -> bool:
	return enabled and InventoryManager.add_item(SLINGSHOT_TOXIN_NAIL, quantity)


func refill_slingshot_ammo() -> bool:
	if not enabled: return false
	var normal_missing := maxi(0, 12 - InventoryManager.get_item_count(SLINGSHOT_NAIL.item_id))
	if normal_missing > 0: InventoryManager.add_item(SLINGSHOT_NAIL, normal_missing)
	return true


func reset_slingshot_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group("slingshot_projectiles"): projectile.queue_free()


func reset_slingshot_breakable_lights() -> void:
	for light in get_tree().get_nodes_in_group("slingshot_breakable_lights"):
		if light.has_method("reset_light"): light.call("reset_light")


func give_monocular() -> bool:
	return enabled and InventoryManager.add_item(MONOCULAR_DEFINITION)


func remove_monocular() -> bool:
	return enabled and InventoryManager.remove_item(MONOCULAR_DEFINITION.item_id)


func give_proper_suppressor() -> bool:
	return enabled and InventoryManager.add_item(PROPER_SUPPRESSOR)


func remove_proper_suppressor() -> bool:
	return enabled and InventoryManager.remove_item(PROPER_SUPPRESSOR.item_id)


func give_makeshift_suppressor() -> bool:
	return enabled and InventoryManager.add_item(MAKESHIFT_SUPPRESSOR)


func remove_makeshift_suppressor() -> bool:
	return enabled and InventoryManager.remove_item(MAKESHIFT_SUPPRESSOR.item_id)


func attach_compatible_suppressor() -> bool:
	if not enabled: return false
	var player := get_player()
	var controller := player.get_node_or_null("WeaponController") as PlayerWeaponController if player else null
	return controller != null and controller.attach_compatible_suppressor()


func detach_suppressor() -> bool:
	if not enabled: return false
	var player := get_player()
	var controller := player.get_node_or_null("WeaponController") as PlayerWeaponController if player else null
	return controller != null and controller.detach_suppressor()


func reset_makeshift_suppressor_durability() -> bool:
	if not enabled: return false
	var player := get_player()
	var controller := player.get_node_or_null("WeaponController") as PlayerWeaponController if player else null
	return controller != null and controller.reset_makeshift_suppressor_durability()


func get_suppressor_state() -> String:
	var player := get_player()
	var controller := player.get_node_or_null("WeaponController") as PlayerWeaponController if player else null
	return controller.get_suppressor_status() if controller else "UNSUPPRESSED"


func get_monocular_state() -> String:
	var player := get_player()
	var controller := player.get_node_or_null("EquipmentController") if player else null
	return str(controller.call("get_state_name")) if controller and controller.has_method("get_state_name") else "INACTIVE"


func get_access_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var scene := get_tree().current_scene
	if scene == null:
		return result
	for node in scene.find_children("*", "", true, false):
		if node is NormalDoor or node is PrisonSlidingGate:
			result.append({"target": weakref(node), "display_name": String(node.get("display_name")), "path": String(node.get_path())})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.display_name).naturalnocasecmp_to(String(b.display_name)) < 0)
	return result


func set_selected_access_state(entry: Dictionary, action: StringName) -> bool:
	if not enabled or not entry.has("target"):
		return false
	var door := (entry.target as WeakRef).get_ref() as Node3D
	if not is_instance_valid(door):
		return false
	_remember_access_state(door)
	if action == &"unlock":
		door.set("is_locked", false)
		if door.has_method("_update_access_indicator"): door.call("_update_access_indicator")
		return true
	if action in [&"open", &"close"]:
		var opened := action == &"open"
		door.set("is_locked", false)
		door.set("is_open", opened)
		door.call("_apply_pose", opened)
		var blocker := door.get("blocker") as CollisionShape3D
		if blocker: blocker.set_deferred("disabled", opened)
		return true
	return false


func reset_access_to_defaults() -> void:
	for entry in get_access_entries():
		var door := (entry.target as WeakRef).get_ref() as Node3D
		if not door: continue
		var locked := bool(door.get("starts_locked"))
		var opened := bool(door.get("starts_open")) and not locked
		door.set("is_locked", locked)
		door.set("is_open", opened)
		door.call("_apply_pose", opened)
		var blocker := door.get("blocker") as CollisionShape3D
		if blocker: blocker.set_deferred("disabled", opened)
		if door.has_method("_update_access_indicator"): door.call("_update_access_indicator")


func reload_current_area() -> bool:
	var player := get_player()
	if player == null:
		return false
	var nearest_id: StringName = &""
	var nearest_distance := INF
	for entry in get_teleport_entries():
		var target := (entry.target as WeakRef).get_ref() as Node3D
		var distance := player.global_position.distance_squared_to(target.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = entry.id
	return teleport_to(nearest_id) if not nearest_id.is_empty() else false


func restart_current_scene() -> void:
	if enabled:
		set_menu_open(false)
		get_tree().reload_current_scene()


func _activate() -> void:
	if _unlock_prompt:
		close_unlock_prompt()
	if _menu == null:
		_menu = MENU_SCENE.instantiate() as CanvasLayer
		add_child(_menu)
	_menu.visible = true
	set_process(true)
	set_process_unhandled_input(true)
	_apply_state_to_player(get_player())


func _deactivate() -> void:
	if _menu_open: set_menu_open(false)
	return_player_to_normal()
	clear_test_inventory()
	_restore_dev_access_states()
	if _menu: _menu.queue_free()
	_menu = null
	set_process(false)
	# Keep _input active so Command+D can request authorization without a restart.
	set_process_unhandled_input(false)


func _apply_state_to_player(player: PlayerController) -> void:
	if player == null:
		return
	set_player_health(test_health)
	set_vest(equipped_vest)
	set_invulnerable(invulnerable)
	set_infinite_stamina(infinite_stamina)
	_apply_noclip(player)


func _apply_noclip(player: PlayerController) -> void:
	if _noclip and (not is_instance_valid(_noclip.player) or _noclip.player != player or not noclip_enabled):
		_noclip.deactivate()
		_noclip.queue_free()
		_noclip = null
	if noclip_enabled and player and _noclip == null:
		_noclip = NOCLIP_CONTROLLER.new() as DevNoclipController
		add_child(_noclip)
		_noclip.activate(player)


func _register_builtins() -> void:
	register_test_scene(&"dev_test_hub", "Dev Test Hub", "res://scenes/dev/DevTestHub.tscn")
	register_test_scene(&"weapons_test_range", "Weapons Test Range", "res://scenes/dev/WeaponRange.tscn")
	for definition in TEST_INVENTORY_DEFINITIONS:
		register_inventory_test_definition(definition)


func _prune_scene_registry() -> void:
	for id in _teleports.keys():
		var target: Object = (_teleports[id].target as WeakRef).get_ref()
		if not is_instance_valid(target): _teleports.erase(id)


func _refresh_menu() -> void:
	if _menu and _menu.has_method("refresh_all"):
		_menu.call_deferred("refresh_all")


func _remember_access_state(door: Node3D) -> void:
	var instance_id := door.get_instance_id()
	if _dev_modified_access.has(instance_id):
		return
	_dev_modified_access[instance_id] = {
		"target": weakref(door),
		"is_locked": bool(door.get("is_locked")),
		"is_open": bool(door.get("is_open")),
	}


func _restore_dev_access_states() -> void:
	for snapshot in _dev_modified_access.values():
		var door := (snapshot.target as WeakRef).get_ref() as Node3D
		if not is_instance_valid(door):
			continue
		var opened := bool(snapshot.is_open)
		door.set("is_locked", bool(snapshot.is_locked))
		door.set("is_open", opened)
		door.call("_apply_pose", opened)
		var blocker := door.get("blocker") as CollisionShape3D
		if blocker:
			blocker.set_deferred("disabled", opened)
		if door.has_method("_update_access_indicator"):
			door.call("_update_access_indicator")
	_dev_modified_access.clear()


func _join_ids(ids: Array[StringName]) -> String:
	if ids.is_empty(): return "—"
	var strings: PackedStringArray = []
	for id in ids: strings.append(str(id))
	return ", ".join(strings)


func _slot_label(item: ItemDefinition) -> String:
	return item.display_name if item != null else "EMPTY"


func _give_inventory_definition(item_definition: ItemDefinition) -> bool:
	return enabled and InventoryManager.add_item(item_definition)


func _remove_inventory_definition(item_id: StringName) -> bool:
	return enabled and InventoryManager.remove_item(item_id)
