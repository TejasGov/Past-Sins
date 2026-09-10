extends Node
class_name DevDamageTestTool

## Range-only body-health probe. It deliberately owns no weapon, firing, ammo,
## animation, recoil, or combat behavior.
signal test_hit(target: DamageableHumanDummy, hit_zone: StringName, damage: float)
signal targets_reset

const TEST_VALUES: Array[int] = [30, 40, 50, 70, 90, 100, 120, 140, 150, 200, 300, 400]

var selected_index := 3
var _hud: CanvasLayer
var _selection_label: Label
var _aim_label: Label
var _result_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not DevModeManager.is_enabled():
		queue_free()
		return
	add_to_group("dev_damage_test_tools")
	_build_hud()
	_refresh_selection()


func _process(_delta: float) -> void:
	if _aim_label == null:
		return
	var zone := get_aimed_hit_zone()
	if zone:
		var target := zone.damageable_owner as DamageableHumanDummy
		_aim_label.text = "AIMED TARGET: %s  //  %s" % [target.target_label if target else "UNKNOWN", zone.get_hit_zone_id()]
		_aim_label.modulate = Color("9ee2c0")
	else:
		_aim_label.text = "AIMED TARGET: —"
		_aim_label.modulate = Color("839397")


func _unhandled_input(event: InputEvent) -> void:
	if not DevModeManager.is_enabled() or DevModeManager.is_menu_open() or event.is_echo():
		return
	if event.is_action_pressed("dev_test_damage_previous"):
		cycle_damage(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dev_test_damage_next"):
		cycle_damage(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dev_apply_test_damage"):
		apply_to_aimed_zone()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dev_reset_range_targets"):
		reset_targets()
		get_viewport().set_input_as_handled()


func get_selected_damage() -> int:
	return TEST_VALUES[selected_index]


func get_last_readout() -> String:
	return _result_label.text if _result_label else ""


func set_test_damage(value: int) -> bool:
	var index := TEST_VALUES.find(value)
	if index < 0:
		return false
	selected_index = index
	_refresh_selection()
	return true


func cycle_damage(direction: int) -> void:
	selected_index = posmod(selected_index + direction, TEST_VALUES.size())
	_refresh_selection()


func get_aimed_hit_zone() -> BodyHitZone:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 120.0, 32)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var collider := result.get("collider") as Node
	return collider as BodyHitZone if collider is BodyHitZone else null


func apply_to_aimed_zone() -> bool:
	var zone := get_aimed_hit_zone()
	if zone == null:
		_result_label.text = "NO HIT ZONE DETECTED"
		_result_label.modulate = Color("e1a06f")
		return false
	return apply_damage_to_zone(zone, get_selected_damage())


func apply_damage_to_zone(zone: BodyHitZone, amount: float) -> bool:
	if zone == null or zone.damageable_owner == null:
		return false
	var target := zone.damageable_owner as DamageableHumanDummy
	if target == null:
		return false
	if target.is_dead():
		_result_label.text = "TARGET: %s\nHIT ZONE: %s\nDAMAGE: 0\nRESULT: ALREADY DEAD — RESET REQUIRED" % [target.target_label, zone.get_hit_zone_id()]
		_result_label.modulate = Color("dc7770")
		return false
	zone.apply_test_damage(amount)
	var total := target.get_total_health()
	if target.is_dead():
		_result_label.text = "TARGET: %s\nHIT ZONE: %s\nDAMAGE: %d\nRESULT: DEAD" % [target.target_label, zone.get_hit_zone_id(), int(amount)]
		_result_label.modulate = Color("ff7770")
	else:
		_result_label.text = "TARGET: %s\nHIT ZONE: %s\nDAMAGE: %d\nHEALTH: %d / %d" % [target.target_label, zone.get_hit_zone_id(), int(amount), int(target.get_current_health()), int(total)]
		_result_label.modulate = Color("a9dfc3")
	test_hit.emit(target, zone.get_hit_zone_id(), amount)
	return true


func reset_targets() -> void:
	var range_root := get_parent()
	for node in get_tree().get_nodes_in_group("weapon_range_damage_dummies"):
		if range_root.is_ancestor_of(node) and node is DamageableHumanDummy:
			(node as DamageableHumanDummy).reset_target()
	_result_label.text = "ALL DAMAGE TARGETS RESTORED"
	_result_label.modulate = Color("9ee2c0")
	targets_reset.emit()


func report_firearm_hit(weapon_name: String, zone: BodyHitZone, amount: float) -> void:
	if zone == null or _result_label == null:
		return
	var target := zone.damageable_owner as DamageableHumanDummy
	if target == null:
		return
	if target.is_dead():
		_result_label.text = "%s\n%s\n%d DAMAGE\nTARGET: DEAD" % [weapon_name.to_upper(), zone.get_hit_zone_id(), int(amount)]
		_result_label.modulate = Color("ff7770")
	else:
		_result_label.text = "%s\n%s\n%d DAMAGE\nTARGET: %d / %d" % [
			weapon_name.to_upper(), zone.get_hit_zone_id(), int(amount),
			int(target.get_current_health()), int(target.get_total_health()),
		]
		_result_label.modulate = Color("a9dfc3")


func _refresh_selection() -> void:
	if _selection_label:
		_selection_label.text = "TEST DAMAGE: %d    [ / ] CHANGE    T APPLY    Y RESET TARGETS" % get_selected_damage()


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "DamageProbeHUD"
	_hud.layer = 120
	add_child(_hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(22, 74)
	panel.size = Vector2(470, 190)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.03, 0.034, 0.93)
	style.border_color = Color("bd963c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	panel.add_child(layout)
	var title := Label.new()
	title.text = "BODY HEALTH PROBE // DEV ONLY // NOT A WEAPON"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("f0ca69"))
	layout.add_child(title)
	_selection_label = Label.new()
	_selection_label.add_theme_color_override("font_color", Color("c9d9dc"))
	layout.add_child(_selection_label)
	var values := Label.new()
	values.text = "QUICK VALUES: 30  40  50  70  90  100  120  140  150  200  300  400"
	values.add_theme_font_size_override("font_size", 11)
	values.add_theme_color_override("font_color", Color("81979d"))
	layout.add_child(values)
	_aim_label = Label.new()
	layout.add_child(_aim_label)
	_result_label = Label.new()
	_result_label.text = "Aim at a colored mannequin segment and press T."
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_result_label)
