extends CanvasLayer
class_name DevMenu

var _dimmer: ColorRect
var _panel: PanelContainer
var _tabs: TabContainer
var _teleport_search: LineEdit
var _teleport_list: VBoxContainer
var _player_state: Label
var _health_value: SpinBox
var _invulnerability: CheckButton
var _noclip: CheckButton
var _infinite_stamina: CheckButton
var _inventory: RichTextLabel
var _key_picker: OptionButton
var _item_picker: OptionButton
var _access_picker: OptionButton
var _command_list: VBoxContainer
var _test_scene_list: VBoxContainer
var _status: Label
var _access_entries: Array[Dictionary] = []
var _inventory_refresh_queued := false


func _ready() -> void:
	layer = 200
	_build_ui()
	DevModeManager.registry_changed.connect(refresh_all)
	DevModeManager.player_test_state_changed.connect(_refresh_player)
	AccessManager.inventory_changed.connect(_queue_inventory_refresh)
	InventoryManager.inventory_changed.connect(_queue_inventory_refresh)
	refresh_all()
	set_menu_open(false)


func set_menu_open(open: bool) -> void:
	_dimmer.visible = open
	_panel.visible = open
	if open:
		refresh_all()


func refresh_all() -> void:
	if not is_node_ready():
		return
	_refresh_teleports(_teleport_search.text)
	_refresh_player()
	_refresh_inventory()
	_refresh_access()
	_refresh_commands()
	_refresh_test_scenes()


func _build_ui() -> void:
	var indicator := Label.new()
	indicator.name = "DevModeIndicator"
	indicator.set_anchors_preset(Control.PRESET_CENTER_TOP)
	indicator.position = Vector2(-135, 10)
	indicator.size = Vector2(270, 30)
	indicator.text = "DEV MODE  •  F8 TOOLS"
	indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	indicator.add_theme_font_size_override("font_size", 16)
	indicator.add_theme_color_override("font_color", Color("ffd45c"))
	indicator.add_theme_color_override("font_shadow_color", Color.BLACK)
	indicator.add_theme_constant_override("shadow_offset_x", 2)
	indicator.add_theme_constant_override("shadow_offset_y", 2)
	add_child(indicator)

	_dimmer = ColorRect.new()
	_dimmer.name = "MenuDimmer"
	_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dimmer.color = Color(0.005, 0.008, 0.012, 0.78)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dimmer)

	_panel = PanelContainer.new()
	_panel.name = "DeveloperMenu"
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 90
	_panel.offset_top = 55
	_panel.offset_right = -90
	_panel.offset_bottom = -50
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("10191d")
	panel_style.border_color = Color("d8a93f")
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	_panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "BLACKSITE // DEVELOPER TOOLS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("f0c760"))
	header.add_child(title)
	var close := Button.new()
	close.text = "CLOSE  [F8]"
	close.pressed.connect(func(): DevModeManager.set_menu_open(false))
	header.add_child(close)
	var exit_dev := Button.new()
	exit_dev.text = "EXIT DEV MODE"
	exit_dev.pressed.connect(func(): DevModeManager.set_enabled(false))
	header.add_child(exit_dev)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_tabs)
	_build_navigation_tab()
	_build_player_tab()
	_build_access_tab()
	_build_world_tab()
	_build_test_hub_tab()

	_status = Label.new()
	_status.text = "Ready"
	_status.add_theme_color_override("font_color", Color("9ed7be"))
	layout.add_child(_status)


func _new_tab(name: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = name.validate_node_name()
	margin.set("theme_override_constants/margin_left", 8)
	margin.set("theme_override_constants/margin_top", 12)
	margin.set("theme_override_constants/margin_right", 8)
	margin.set("theme_override_constants/margin_bottom", 8)
	_tabs.add_child(margin)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, name)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	return content


func _build_navigation_tab() -> void:
	var tab := _new_tab("Navigation")
	var hint := Label.new()
	hint.text = "Named campus spawn points — selecting a destination also resets suspicion."
	tab.add_child(hint)
	_teleport_search = LineEdit.new()
	_teleport_search.placeholder_text = "Filter buildings, floors, yard, pool, B1 or B2…"
	_teleport_search.text_changed.connect(_refresh_teleports)
	tab.add_child(_teleport_search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)
	_teleport_list = VBoxContainer.new()
	_teleport_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_teleport_list)


func _build_player_tab() -> void:
	var tab := _new_tab("Player Testing")
	_player_state = Label.new()
	_player_state.add_theme_color_override("font_color", Color("b8d8d2"))
	tab.add_child(_player_state)
	var health_row := HBoxContainer.new()
	tab.add_child(health_row)
	var health_label := Label.new()
	health_label.text = "Health"
	health_label.custom_minimum_size.x = 140
	health_row.add_child(health_label)
	_health_value = SpinBox.new()
	_health_value.min_value = 0
	_health_value.max_value = 100
	_health_value.value = 100
	_health_value.custom_minimum_size.x = 140
	health_row.add_child(_health_value)
	_add_button(health_row, "SET HEALTH", func(): DevModeManager.set_player_health(_health_value.value))
	_add_button(health_row, "RESET HEALTH", DevModeManager.reset_player_health)

	var vest_row := HBoxContainer.new()
	tab.add_child(vest_row)
	_add_button(vest_row, "GIVE STANDARD VEST", func(): DevModeManager.set_vest(&"standard_vest"))
	_add_button(vest_row, "GIVE ADVANCED VEST", func(): DevModeManager.set_vest(&"advanced_vest"))
	_add_button(vest_row, "REMOVE VEST", func(): DevModeManager.set_vest(&""))

	_invulnerability = CheckButton.new()
	_invulnerability.text = "Invulnerability (blocks detention/failure)"
	_invulnerability.toggled.connect(DevModeManager.set_invulnerable)
	tab.add_child(_invulnerability)
	_noclip = CheckButton.new()
	_noclip.text = "Noclip / free flight (WASD, Space up, C down, Shift fast)"
	_noclip.toggled.connect(DevModeManager.set_noclip)
	tab.add_child(_noclip)
	_infinite_stamina = CheckButton.new()
	_infinite_stamina.text = "Infinite stamina (applies when a stamina provider is registered)"
	_infinite_stamina.toggled.connect(DevModeManager.set_infinite_stamina)
	tab.add_child(_infinite_stamina)
	_add_button(tab, "RESET SUSPICION", SuspicionSystem.reset)
	_add_button(tab, "RETURN PLAYER TO NORMAL STATE", DevModeManager.return_player_to_normal)


func _build_access_tab() -> void:
	var tab_root := _new_tab("Inventory / Access")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_root.add_child(scroll)
	var tab := VBoxContainer.new()
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_theme_constant_override("separation", 9)
	scroll.add_child(tab)
	var loadout_heading := Label.new()
	loadout_heading.text = "INVENTORY TEST // DATA-ONLY PLACEHOLDERS"
	loadout_heading.add_theme_color_override("font_color", Color("e2bc61"))
	tab.add_child(loadout_heading)
	_inventory = RichTextLabel.new()
	_inventory.custom_minimum_size.y = 190
	_inventory.fit_content = false
	_inventory.scroll_active = true
	tab.add_child(_inventory)
	var clear_row := HBoxContainer.new()
	tab.add_child(clear_row)
	_add_button(clear_row, "CLEAR FIREARM SLOTS", func(): DevModeManager.clear_firearm_slots(); _inventory_action_status(InventoryComponent.INVENTORY_CLEARED))
	_add_button(clear_row, "CLEAR MELEE SLOT", func(): DevModeManager.clear_melee_slot(); _inventory_action_status(InventoryComponent.INVENTORY_CLEARED))
	_add_button(clear_row, "CLEAR EQUIPMENT", func(): DevModeManager.clear_equipment_inventory(); _inventory_action_status(InventoryComponent.INVENTORY_CLEARED))
	_add_button(clear_row, "CLEAR ALL INVENTORY", func(): DevModeManager.clear_all_inventory(); _inventory_action_status(InventoryComponent.INVENTORY_CLEARED))
	var pistol_row := HBoxContainer.new()
	tab.add_child(pistol_row)
	_add_button(pistol_row, "GIVE PISTOL", func(): _pistol_action("PISTOL GIVEN", DevModeManager.give_pistol()))
	_add_button(pistol_row, "REMOVE PISTOL", func(): _pistol_action("PISTOL REMOVED", DevModeManager.remove_pistol()))
	_add_button(pistol_row, "REFILL PISTOL AMMO", func(): _pistol_action("PISTOL AMMO REFILLED", DevModeManager.refill_pistol_ammo()))
	var smg_row := HBoxContainer.new()
	tab.add_child(smg_row)
	_add_button(smg_row, "GIVE SMG", func(): _pistol_action("SMG GIVEN", DevModeManager.give_smg()))
	_add_button(smg_row, "REMOVE SMG", func(): _pistol_action("SMG REMOVED", DevModeManager.remove_smg()))
	_add_button(smg_row, "REFILL SMG AMMO", func(): _pistol_action("SMG AMMO REFILLED", DevModeManager.refill_smg_ammo()))
	var carbine_row := HBoxContainer.new()
	tab.add_child(carbine_row)
	_add_button(carbine_row, "GIVE CARBINE AR", func(): _pistol_action("CARBINE AR GIVEN", DevModeManager.give_carbine_ar()))
	_add_button(carbine_row, "REMOVE CARBINE AR", func(): _pistol_action("CARBINE AR REMOVED", DevModeManager.remove_carbine_ar()))
	_add_button(carbine_row, "REFILL CARBINE AMMO", func(): _pistol_action("CARBINE AMMO REFILLED", DevModeManager.refill_carbine_ammo()))
	var sniper_row := HBoxContainer.new()
	tab.add_child(sniper_row)
	_add_button(sniper_row, "GIVE SNIPER RIFLE", func(): _pistol_action("SNIPER RIFLE GIVEN", DevModeManager.give_sniper_rifle()))
	_add_button(sniper_row, "REMOVE SNIPER RIFLE", func(): _pistol_action("SNIPER RIFLE REMOVED", DevModeManager.remove_sniper_rifle()))
	_add_button(sniper_row, "REFILL SNIPER AMMO", func(): _pistol_action("SNIPER AMMO REFILLED", DevModeManager.refill_sniper_ammo()))
	var melee_row := HBoxContainer.new()
	tab.add_child(melee_row)
	_add_button(melee_row, "GIVE KITCHEN KNIFE", func(): _pistol_action("KITCHEN KNIFE GIVEN", DevModeManager.give_kitchen_knife()))
	_add_button(melee_row, "REMOVE KITCHEN KNIFE", func(): _pistol_action("KITCHEN KNIFE REMOVED", DevModeManager.remove_kitchen_knife()))
	_add_button(melee_row, "GIVE SLINGSHOT", func(): _pistol_action("SLINGSHOT GIVEN", DevModeManager.give_slingshot()))
	_add_button(melee_row, "REMOVE SLINGSHOT", func(): _pistol_action("SLINGSHOT REMOVED", DevModeManager.remove_slingshot()))
	var slingshot_row := HBoxContainer.new()
	tab.add_child(slingshot_row)
	_add_button(slingshot_row, "GIVE NORMAL NAILS", func(): _pistol_action("NORMAL NAILS GIVEN", DevModeManager.give_normal_nails()))
	_add_button(slingshot_row, "GIVE TOXIN NAILS", func(): _pistol_action("TOXIN NAILS GIVEN", DevModeManager.give_toxin_nails()))
	_add_button(slingshot_row, "REFILL SLINGSHOT AMMO", func(): _pistol_action("SLINGSHOT AMMO REFILLED", DevModeManager.refill_slingshot_ammo()))
	_add_button(slingshot_row, "RESET PROJECTILES", func(): DevModeManager.reset_slingshot_projectiles(); _inventory_action_status("PROJECTILES RESET"))
	_add_button(slingshot_row, "RESET BREAKABLE LIGHT", func(): DevModeManager.reset_slingshot_breakable_lights(); _inventory_action_status("BREAKABLE LIGHT RESET"))
	var equipment_row := HBoxContainer.new()
	tab.add_child(equipment_row)
	_add_button(equipment_row, "GIVE MONOCULAR", func(): _pistol_action("MONOCULAR GIVEN", DevModeManager.give_monocular()))
	_add_button(equipment_row, "REMOVE MONOCULAR", func(): _pistol_action("MONOCULAR REMOVED", DevModeManager.remove_monocular()))
	var suppressor_row := HBoxContainer.new()
	tab.add_child(suppressor_row)
	_add_button(suppressor_row, "GIVE PROPER SUPPRESSOR", func(): _pistol_action("PROPER SUPPRESSOR GIVEN", DevModeManager.give_proper_suppressor()))
	_add_button(suppressor_row, "REMOVE PROPER SUPPRESSOR", func(): _pistol_action("PROPER SUPPRESSOR REMOVED", DevModeManager.remove_proper_suppressor()))
	_add_button(suppressor_row, "GIVE MAKESHIFT SUPPRESSOR", func(): _pistol_action("MAKESHIFT SUPPRESSOR GIVEN", DevModeManager.give_makeshift_suppressor()))
	_add_button(suppressor_row, "REMOVE MAKESHIFT SUPPRESSOR", func(): _pistol_action("MAKESHIFT SUPPRESSOR REMOVED", DevModeManager.remove_makeshift_suppressor()))
	var suppressor_control_row := HBoxContainer.new()
	tab.add_child(suppressor_control_row)
	_add_button(suppressor_control_row, "ATTACH COMPATIBLE SUPPRESSOR", func(): _pistol_action("SUPPRESSOR ATTACHED", DevModeManager.attach_compatible_suppressor()))
	_add_button(suppressor_control_row, "DETACH SUPPRESSOR", func(): _pistol_action("SUPPRESSOR DETACHED", DevModeManager.detach_suppressor()))
	_add_button(suppressor_control_row, "RESET MAKESHIFT DURABILITY", func(): _pistol_action("MAKESHIFT DURABILITY RESET", DevModeManager.reset_makeshift_suppressor_durability()))
	var item_label := Label.new()
	item_label.text = "DEV TEST ITEMS — GIVE REPEATEDLY TO VERIFY FULL/STACK RULES"
	item_label.add_theme_color_override("font_color", Color("e2bc61"))
	tab.add_child(item_label)
	var item_row := HBoxContainer.new()
	tab.add_child(item_row)
	_item_picker = OptionButton.new()
	_item_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_row.add_child(_item_picker)
	_add_button(item_row, "GIVE ITEM", _give_selected_item)
	_add_button(item_row, "REMOVE ONE", _remove_selected_item)
	var access_heading := Label.new()
	access_heading.text = "KEYS / ACCESS"
	access_heading.add_theme_color_override("font_color", Color("e2bc61"))
	tab.add_child(access_heading)
	var row := HBoxContainer.new()
	tab.add_child(row)
	_key_picker = OptionButton.new()
	_key_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_key_picker)
	_add_button(row, "GIVE KEY", _give_selected_key)
	_add_button(row, "REMOVE KEY", _remove_selected_key)
	var bulk := HBoxContainer.new()
	tab.add_child(bulk)
	_add_button(bulk, "GIVE ALL REGISTERED KEYS", func(): DevModeManager.give_all_keys(); refresh_all())
	_add_button(bulk, "CLEAR DEV-GRANTED INVENTORY", func(): DevModeManager.clear_test_inventory(); refresh_all())


func _build_world_tab() -> void:
	var tab := _new_tab("World Testing")
	var hint := Label.new()
	hint.text = "Select a loaded door or gate. Direct poses are development-only and do not grant progression."
	tab.add_child(hint)
	_access_picker = OptionButton.new()
	tab.add_child(_access_picker)
	var row := HBoxContainer.new()
	tab.add_child(row)
	_add_button(row, "UNLOCK SELECTED", func(): _operate_access(&"unlock"))
	_add_button(row, "OPEN SELECTED", func(): _operate_access(&"open"))
	_add_button(row, "CLOSE SELECTED", func(): _operate_access(&"close"))
	_add_button(tab, "RESET ALL DOORS / GATES TO AUTHORED STATE", func(): DevModeManager.reset_access_to_defaults(); _set_status("Access states reset"))
	_add_button(tab, "RELOAD / RE-ENTER CURRENT AREA", func(): _set_status("Area re-entered" if DevModeManager.reload_current_area() else "No area point available"))
	_add_button(tab, "RESTART CURRENT SCENE", DevModeManager.restart_current_scene)
	var command_heading := Label.new()
	command_heading.text = "REGISTERED EXTENSION COMMANDS"
	command_heading.add_theme_color_override("font_color", Color("e2bc61"))
	tab.add_child(command_heading)
	_command_list = VBoxContainer.new()
	tab.add_child(_command_list)


func _build_test_hub_tab() -> void:
	var tab := _new_tab("Test Environments")
	var description := Label.new()
	description.text = "Dev-only scenes outside the prison campus.\nThe Weapons Test Range contains implemented firearm stations; unimplemented weapon/equipment positions remain placeholders."
	tab.add_child(description)
	_test_scene_list = VBoxContainer.new()
	tab.add_child(_test_scene_list)
	_add_button(tab, "RETURN TO PRISON CAMPUS", DevModeManager.return_to_campus)


func _refresh_teleports(filter := "") -> void:
	if _teleport_list == null:
		return
	for child in _teleport_list.get_children(): child.queue_free()
	var query := filter.strip_edges().to_lower()
	var previous_category := ""
	for entry in DevModeManager.get_teleport_entries():
		var searchable := "%s %s" % [entry.category, entry.display_name]
		if not query.is_empty() and not searchable.to_lower().contains(query): continue
		if String(entry.category) != previous_category:
			previous_category = String(entry.category)
			var heading := Label.new()
			heading.text = previous_category.to_upper()
			heading.add_theme_color_override("font_color", Color("e2bc61"))
			_teleport_list.add_child(heading)
		var button := Button.new()
		button.text = String(entry.display_name)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: StringName = entry.id
		button.pressed.connect(func():
			if not DevModeManager.teleport_to(id): _set_status("Teleport unavailable")
		)
		_teleport_list.add_child(button)


func _refresh_player() -> void:
	if _player_state == null: return
	_player_state.text = "Health: %.0f / %.0f    Vest: %s    Invulnerable: %s    Noclip: %s" % [DevModeManager.test_health, DevModeManager.test_max_health, str(DevModeManager.equipped_vest) if not DevModeManager.equipped_vest.is_empty() else "none", "ON" if DevModeManager.invulnerable else "off", "ON" if DevModeManager.noclip_enabled else "off"]
	_health_value.value = DevModeManager.test_health
	_invulnerability.set_pressed_no_signal(DevModeManager.invulnerable)
	_noclip.set_pressed_no_signal(DevModeManager.noclip_enabled)
	_infinite_stamina.set_pressed_no_signal(DevModeManager.infinite_stamina)


func _refresh_inventory() -> void:
	if _inventory == null: return
	_inventory_refresh_queued = false
	_inventory.text = DevModeManager.get_inventory_summary()
	_key_picker.clear()
	for key_id in DevModeManager.get_registered_key_ids():
		_key_picker.add_item(str(key_id))
		_key_picker.set_item_metadata(_key_picker.item_count - 1, key_id)
	_item_picker.clear()
	for entry in DevModeManager.get_test_item_entries():
		_item_picker.add_item(String(entry.display_name))
		_item_picker.set_item_metadata(_item_picker.item_count - 1, entry.id)
	if _item_picker.item_count == 0:
		_item_picker.add_item("No test items registered")
		_item_picker.disabled = true
	else:
		_item_picker.disabled = false


func _queue_inventory_refresh() -> void:
	if _inventory_refresh_queued: return
	_inventory_refresh_queued = true
	call_deferred("_refresh_inventory")


func _refresh_access() -> void:
	if _access_picker == null: return
	_access_picker.clear()
	_access_entries = DevModeManager.get_access_entries()
	for entry in _access_entries:
		_access_picker.add_item("%s  —  %s" % [entry.display_name, entry.path])


func _refresh_commands() -> void:
	if _command_list == null: return
	for child in _command_list.get_children(): child.queue_free()
	for entry in DevModeManager.get_command_entries():
		var id: StringName = entry.id
		_add_button(_command_list, "%s — %s" % [entry.category, entry.display_name], func():
			_set_status("Command executed" if DevModeManager.execute_command(id) else "Command unavailable")
		)


func _refresh_test_scenes() -> void:
	if _test_scene_list == null: return
	for child in _test_scene_list.get_children(): child.queue_free()
	for entry in DevModeManager.get_test_scene_entries():
		var id: StringName = entry.id
		_add_button(_test_scene_list, "ENTER %s" % String(entry.display_name).to_upper(), func(): DevModeManager.enter_test_scene(id))


func _give_selected_key() -> void:
	if _key_picker.selected < 0: return
	var id := _key_picker.get_item_metadata(_key_picker.selected) as StringName
	_set_status("Key granted: %s" % id if DevModeManager.give_key(id) else "Key already owned")
	refresh_all()


func _remove_selected_key() -> void:
	if _key_picker.selected < 0: return
	var id := _key_picker.get_item_metadata(_key_picker.selected) as StringName
	_set_status("Key removed: %s" % id if DevModeManager.remove_key(id) else "Key was not owned")
	refresh_all()


func _give_selected_item() -> void:
	if _item_picker.disabled or _item_picker.selected < 0: return
	var id := StringName(_item_picker.get_item_metadata(_item_picker.selected))
	var added := DevModeManager.give_test_item(id)
	_set_status(DevModeManager.get_last_inventory_feedback() if not DevModeManager.get_last_inventory_feedback().is_empty() else ("ITEM ACQUIRED" if added else "Test item unavailable"))
	_refresh_inventory()


func _remove_selected_item() -> void:
	if _item_picker.disabled or _item_picker.selected < 0: return
	var id := StringName(_item_picker.get_item_metadata(_item_picker.selected))
	_set_status("ITEM REMOVED" if DevModeManager.remove_test_item(id) else "ITEM NOT OWNED")
	_refresh_inventory()


func _inventory_action_status(message: String) -> void:
	_set_status(message)
	_refresh_inventory()


func _pistol_action(success_message: String, success: bool) -> void:
	_set_status(success_message if success else DevModeManager.get_last_inventory_feedback())
	_refresh_inventory()


func _operate_access(action: StringName) -> void:
	if _access_picker.selected < 0 or _access_picker.selected >= _access_entries.size(): return
	_set_status("Selected access: %s" % action if DevModeManager.set_selected_access_state(_access_entries[_access_picker.selected], action) else "Selected access unavailable")


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _set_status(text: String) -> void:
	if _status: _status.text = text
