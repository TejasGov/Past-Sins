extends Node
class_name PlayerMeleeController

signal equipped_changed(melee_id: StringName, equipped: bool)
signal weapon_dropped(melee_id: StringName, pickup: MeleePickup)
signal visibility_class_changed(visibility_class: StringName)
signal improvised_aim_changed(aiming: bool)
signal improvised_projectile_hit_person(suspicion_value: float)

const MELEE_SCENE := preload("res://scenes/weapons/MeleeComponent.tscn")
const PICKUP_SCENE := preload("res://scenes/weapons/MeleePickup.tscn")
const SLINGSHOT_SCENE := preload("res://scenes/weapons/SlingshotComponent.tscn")

@export var camera_path := NodePath("../Head/Camera3D")
@export var weapon_mount_path := NodePath("../Head/Camera3D/WeaponMount")
@export_range(1.0, 30.0, 0.5) var camera_recovery_speed := 11.0

@onready var player: PlayerController = get_parent() as PlayerController
@onready var camera: Camera3D = get_node(camera_path)
@onready var weapon_mount: Node3D = get_node(weapon_mount_path)

var current_melee: MeleeComponent
var current_slingshot: SlingshotComponent
var _hud: CanvasLayer
var _panel: PanelContainer
var _label: RichTextLabel
var _camera_impact := 0.0
var _applied_camera_impact := 0.0
var _drop_in_progress := false
var _aim_held := false
var _aim_blend := 0.0
var _reticle: Label
var _normal_fov := 78.0
var _reported_improvised_aim := false
var _fire_was_held := false
var _external_view_blocked := false


func _ready() -> void:
	add_to_group("player_melee_controllers")
	process_mode = Node.PROCESS_MODE_ALWAYS
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	DevModeManager.mode_changed.connect(_on_dev_mode_changed)
	set_process_unhandled_input(true)
	if DevModeManager.is_enabled(): _build_hud()
	_normal_fov = camera.fov


func _unhandled_input(event: InputEvent) -> void:
	if _external_view_blocked or not DevModeManager.is_enabled() or DevModeManager.is_menu_open() or not player.control_enabled or event.is_echo():
		return
	if event.is_action_pressed("equip_melee_slot"):
		toggle_equip()
		get_viewport().set_input_as_handled()
		return
	if current_melee == null and current_slingshot == null:
		return
	if event.is_action_pressed("fire_weapon"):
		if current_slingshot:
			_fire_was_held = true
			if not current_slingshot.begin_draw(): InventoryManager.request_feedback("SLINGSHOT NOT READY OR OUT OF AMMO")
		else: attack()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("fire_weapon") and current_slingshot:
		current_slingshot.release_draw(camera, player)
		_fire_was_held = false
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("aim") and current_slingshot:
		_aim_held = true
		get_viewport().set_input_as_handled()
	elif event.is_action_released("aim") and current_slingshot:
		_aim_held = false
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reload_weapon") and current_slingshot:
		if not current_slingshot.cycle_ammo(): InventoryManager.request_feedback("ALTERNATE SLINGSHOT AMMO UNAVAILABLE")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("holster_weapon"):
		unequip_current()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("drop_weapon"):
		unequip_and_drop_current()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if is_instance_valid(camera):
		camera.rotation.x -= _applied_camera_impact
		_camera_impact = move_toward(_camera_impact, 0.0, camera_recovery_speed * delta)
		_applied_camera_impact = -deg_to_rad(_camera_impact)
		camera.rotation.x += _applied_camera_impact
	var aim_target := 1.0 if current_slingshot and _aim_held and player.control_enabled and not DevModeManager.is_menu_open() and not _external_view_blocked else 0.0
	_aim_blend = lerpf(_aim_blend, aim_target, 1.0 - exp(-10.0 * delta))
	if current_slingshot:
		current_slingshot.set_aim_amount(_aim_blend)
		current_slingshot.visible = not _external_view_blocked
	if current_melee: current_melee.visible = not _external_view_blocked
	if is_instance_valid(camera) and not _external_view_blocked and (current_slingshot != null or _aim_blend > 0.001): camera.fov = lerpf(_normal_fov, 72.0, _aim_blend)
	if _reticle: _reticle.visible = not _external_view_blocked and current_slingshot != null and _aim_blend > 0.15
	var aiming_now := current_slingshot != null and _aim_held
	if aiming_now != _reported_improvised_aim:
		_reported_improvised_aim = aiming_now
		improvised_aim_changed.emit(aiming_now)
	_poll_slingshot_trigger()
	_update_hud()


func _poll_slingshot_trigger() -> void:
	if current_slingshot == null or not DevModeManager.is_enabled() or DevModeManager.is_menu_open() or not player.control_enabled:
		if current_slingshot and current_slingshot.state == SlingshotComponent.State.DRAWING: current_slingshot.cancel_draw()
		_fire_was_held = false
		return
	var held := Input.is_action_pressed("fire_weapon")
	if held and not _fire_was_held:
		if not current_slingshot.begin_draw(): InventoryManager.request_feedback("SLINGSHOT NOT READY OR OUT OF AMMO")
	elif not held and _fire_was_held and current_slingshot.state == SlingshotComponent.State.DRAWING:
		current_slingshot.release_draw(camera, player)
	_fire_was_held = held


func attack() -> bool:
	return not _external_view_blocked and current_melee != null and current_melee.try_attack(camera)


func set_external_view_blocked(blocked: bool) -> void:
	_external_view_blocked = blocked
	_aim_held = false
	_fire_was_held = false
	if current_slingshot:
		current_slingshot.cancel_draw()
		current_slingshot.visible = not blocked
	if current_melee: current_melee.visible = not blocked
	if _reticle: _reticle.visible = false


func toggle_equip() -> bool:
	if current_melee or current_slingshot:
		unequip_current()
		return true
	return equip_melee_slot()


func equip_melee_slot() -> bool:
	if not DevModeManager.is_enabled(): return false
	var item := InventoryManager.get_melee_slot()
	if not item is MeleeDefinition:
		InventoryManager.request_feedback("MELEE ITEM CANNOT BE EQUIPPED")
		return false
	var firearm := player.get_node_or_null("WeaponController") as PlayerWeaponController
	if firearm: firearm.unequip_current()
	unequip_current()
	var definition := item as MeleeDefinition
	if definition is SlingshotDefinition:
		current_slingshot = SLINGSHOT_SCENE.instantiate() as SlingshotComponent
		current_slingshot.name = "ImprovisedSlingshotRuntime"
		weapon_mount.add_child(current_slingshot)
		if not current_slingshot.configure(definition as SlingshotDefinition):
			current_slingshot.queue_free(); current_slingshot = null; return false
		current_slingshot.projectile_launched.connect(_on_slingshot_projectile_launched)
		current_slingshot.draw_failed.connect(InventoryManager.request_feedback)
	else:
		current_melee = MELEE_SCENE.instantiate() as MeleeComponent
		current_melee.name = "%sRuntime" % definition.display_name.to_pascal_case()
		weapon_mount.add_child(current_melee)
		if not current_melee.configure(definition):
			current_melee.queue_free(); current_melee = null; return false
		current_melee.hit_confirmed.connect(_on_hit_confirmed)
		current_melee.attack_started.connect(_on_attack_started)
		current_melee.equip()
	_update_hud()
	equipped_changed.emit(definition.normalized_melee_id(), true)
	visibility_class_changed.emit(definition.weapon_visibility_class)
	return true


func unequip_current() -> void:
	_cancel_camera_impact()
	var active_definition: MeleeDefinition = current_melee.definition if current_melee else (current_slingshot.definition if current_slingshot else null)
	_aim_held = false
	_fire_was_held = false
	_aim_blend = 0.0
	if is_instance_valid(camera): camera.fov = _normal_fov
	if current_slingshot:
		current_slingshot.cancel_draw()
		current_slingshot.queue_free()
		current_slingshot = null
	if active_definition == null:
		_update_hud()
		return
	var melee_id := active_definition.normalized_melee_id()
	if current_melee:
		current_melee.unequip()
		current_melee.queue_free()
		current_melee = null
	_update_hud()
	equipped_changed.emit(melee_id, false)
	visibility_class_changed.emit(&"")


func unequip_and_drop_current() -> bool:
	if current_melee == null and current_slingshot == null: return false
	var definition: MeleeDefinition = current_melee.definition if current_melee else current_slingshot.definition
	var transform := _get_drop_transform()
	_drop_in_progress = true
	var cleared := InventoryManager.clear_melee_slot()
	_drop_in_progress = false
	if not cleared: return false
	var pickup := PICKUP_SCENE.instantiate() as MeleePickup
	pickup.name = "Dropped%s" % definition.display_name.to_pascal_case()
	pickup.definition = definition
	_get_drop_parent().add_child(pickup)
	pickup.global_transform = transform
	InventoryManager.request_feedback("MELEE DROPPED — SLOT FREED")
	weapon_dropped.emit(definition.normalized_melee_id(), pickup)
	return true


func get_weapon_visibility_class() -> StringName:
	if current_slingshot: return &"IMPROVISED_WEAPON"
	return current_melee.definition.weapon_visibility_class if current_melee and current_melee.definition else &""


func is_melee_weapon_visible() -> bool:
	return get_weapon_visibility_class() == &"MELEE"


func get_improvised_suspicion_floor() -> float:
	if current_slingshot == null: return 0.0
	return current_slingshot.definition.aimed_at_person_suspicion if _aim_held else current_slingshot.definition.held_suspicion_floor


func _on_slingshot_projectile_launched(projectile: SlingshotProjectile, _toxin: bool, _charge: float) -> void:
	var witnessed_suspicion := current_slingshot.definition.witnessed_person_hit_suspicion if current_slingshot else 100.0
	projectile.impacted.connect(func(surface: StringName, _intensity: float, _position: Vector3):
		if surface == &"BODY": improvised_projectile_hit_person.emit(witnessed_suspicion)
	)
	projectile.body_hit.connect(_on_slingshot_body_hit)


func _on_slingshot_body_hit(zone: BodyHitZone, damage: float, toxin: bool) -> void:
	for node in get_tree().get_nodes_in_group("dev_damage_test_tools"):
		if node.has_method("report_slingshot_hit"):
			node.call("report_slingshot_hit", zone, damage, toxin)
			break


func _on_attack_started(definition: MeleeDefinition) -> void:
	# A small anticipatory motion differentiates a held tool from a static prop;
	# the stronger impact pulse is applied only on a confirmed target hit.
	_camera_impact = maxf(_camera_impact, definition.camera_impact_degrees * 0.18)


func _on_hit_confirmed(definition: MeleeDefinition, zone: BodyHitZone, lethal: bool, _position: Vector3) -> void:
	_camera_impact = maxf(_camera_impact, definition.camera_impact_degrees)
	for node in get_tree().get_nodes_in_group("dev_damage_test_tools"):
		if node.has_method("report_melee_hit"):
			node.call("report_melee_hit", definition.display_name, zone, lethal)
			break


func _on_inventory_changed() -> void:
	if current_melee and not InventoryManager.has_item(current_melee.definition.normalized_id()):
		unequip_current()
	if current_slingshot and not InventoryManager.has_item(current_slingshot.definition.normalized_id()): unequip_current()


func _on_dev_mode_changed(enabled: bool) -> void:
	if enabled:
		_build_hud()
	else:
		unequip_current()
		if _hud:
			_hud.queue_free()
			_hud = null
			_panel = null
			_label = null


func _build_hud() -> void:
	if _hud: return
	_hud = CanvasLayer.new()
	_hud.name = "MeleeHUD"
	_hud.layer = 125
	add_child(_hud)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.position = Vector2(-294, -132)
	_panel.size = Vector2(272, 108)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.025, 0.03, 0.92)
	style.border_color = Color("c7a34a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(11)
	_panel.add_theme_stylebox_override("panel", style)
	_hud.add_child(_panel)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = false
	_label.scroll_active = false
	_label.add_theme_color_override("font_color", Color("d9e2df"))
	_label.add_theme_font_size_override("normal_font_size", 14)
	_panel.add_child(_label)
	_reticle = Label.new()
	_reticle.text = "•"
	_reticle.add_theme_font_size_override("font_size", 24)
	_reticle.add_theme_color_override("font_color", Color("e2ddc4"))
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.position = Vector2(-7, -16)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_reticle)
	_update_hud()


func _update_hud() -> void:
	if _label == null: return
	if current_melee == null and current_slingshot == null:
		_panel.visible = false
		_label.text = ""
		return
	_panel.visible = true
	if current_slingshot:
		var ammo := current_slingshot.definition.toxin_ammo if current_slingshot.selected_toxin else current_slingshot.definition.normal_ammo
		var state: String = SlingshotComponent.State.keys()[current_slingshot.state]
		_label.text = "[right][font_size=18][b]IMPROVISED SLINGSHOT[/b][/font_size]\n[color=#c7a34a]%s  x%d  // %s  // DRAW %d%%[/color]\nHOLD/RELEASE LMB  RMB AIM  R AMMO\nH HOLSTER  G DROP[/right]" % [ammo.display_name.to_upper(), current_slingshot.get_selected_ammo_count(), state, int(current_slingshot.get_charge() * 100.0)]
	else:
		var state := "SWINGING" if current_melee.attack_remaining > 0.0 else "READY"
		_label.text = "[right][font_size=18][b]%s[/b][/font_size]\n[color=#c7a34a]%s[/color]\nLMB ATTACK  H HOLSTER  G DROP[/right]" % [current_melee.definition.display_name.to_upper(), state]


func _cancel_camera_impact() -> void:
	if is_instance_valid(camera): camera.rotation.x -= _applied_camera_impact
	_applied_camera_impact = 0.0
	_camera_impact = 0.0


func _get_drop_parent() -> Node:
	var ancestor: Node = player
	while ancestor:
		if ancestor.is_in_group("dev_only_scene"):
			var interactables := ancestor.get_node_or_null("Interactables")
			return interactables if interactables else ancestor
		ancestor = ancestor.get_parent()
	return get_tree().current_scene


func _get_drop_transform() -> Transform3D:
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var intended := player.global_position + forward * 1.0
	var query := PhysicsRayQueryParameters3D.create(intended + Vector3.UP * 1.5, intended + Vector3.DOWN * 2.5, 1)
	var result := player.get_world_3d().direct_space_state.intersect_ray(query)
	var position := result.position as Vector3 + Vector3.UP * 0.02 if not result.is_empty() else intended + Vector3.DOWN * 0.9
	return Transform3D(Basis(Vector3.UP, player.global_rotation.y), position)
