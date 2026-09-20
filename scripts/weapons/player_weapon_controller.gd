extends Node
class_name PlayerWeaponController

## Player-facing adapter for inventory selection and firearm input. It is kept
## separate from PlayerController movement and remains inert outside Dev Mode.
signal equipped_changed(weapon_id: StringName, equipped: bool)
signal aim_changed(aiming: bool)
signal weapon_dropped(weapon_id: StringName, pickup: FirearmPickup)

const FIREARM_SCENE := preload("res://scenes/weapons/FirearmComponent.tscn")
const PICKUP_SCENE := preload("res://scenes/weapons/FirearmPickup.tscn")
const CROSSHAIR_SCENE := preload("res://scenes/ui/FirearmCrosshair.tscn")

@export var camera_path := NodePath("../Head/Camera3D")
@export var weapon_mount_path := NodePath("../Head/Camera3D/WeaponMount")

@export_group("Aim Down Sights")
@export_range(45.0, 110.0, 1.0) var normal_fov := 78.0
@export_range(35.0, 90.0, 1.0) var ads_fov := 60.0
@export_range(1.0, 30.0, 0.5) var ads_transition_speed := 10.0
@export var hip_weapon_position := Vector3.ZERO
@export var hip_weapon_rotation_degrees := Vector3.ZERO
@export var ads_weapon_position := Vector3(-0.272, 0.096, 0.468)
@export var ads_weapon_rotation_degrees := Vector3(2.0, 3.0, 0.0)
@export_range(0.0, 1.0, 0.05) var ads_recoil_multiplier := 0.7

@export_group("Recoil")
@export_range(0.0, 5.0, 0.05) var hip_camera_recoil_degrees := 0.75
@export_range(0.0, 5.0, 0.05) var ads_camera_recoil_degrees := 0.36
@export var hip_weapon_recoil_position := Vector3(0, 0.045, 0.075)
@export var ads_weapon_recoil_position := Vector3(0, 0.02, 0.04)
@export var hip_weapon_recoil_rotation_degrees := Vector3(5.0, 0, 0)
@export var ads_weapon_recoil_rotation_degrees := Vector3(2.2, 0, 0)
@export_range(1.0, 40.0, 0.5) var recoil_recovery_speed := 10.0
@export_range(1.0, 40.0, 0.5) var ads_recoil_recovery_speed := 16.0

@export_group("Weapon Sway And Bob")
@export var idle_sway_amount := Vector2(0.004, 0.005)
@export var walking_bob_amount := Vector2(0.016, 0.021)
@export_range(0.1, 4.0, 0.05) var sprint_bob_multiplier := 1.65
@export_range(0.1, 1.0, 0.05) var crouch_bob_multiplier := 0.55
@export_range(0.0, 1.0, 0.05) var ads_motion_multiplier := 0.12
@export_range(1.0, 20.0, 0.5) var movement_blend_speed := 8.0
@export_range(1.0, 20.0, 0.5) var bob_frequency := 7.5

@export_group("Crosshair")
@export var hide_crosshair_while_ads := true
@export_range(2.0, 32.0, 1.0) var crosshair_line_length := 8.0
@export_range(0.0, 24.0, 1.0) var crosshair_center_gap := 5.0
@export_range(1.0, 6.0, 0.5) var crosshair_thickness := 2.0
@export var crosshair_color := Color(0.86, 0.92, 0.9, 0.92)
@export_range(0.0, 16.0, 0.5) var movement_crosshair_expansion := 3.0
@export_range(0.0, 16.0, 0.5) var firing_crosshair_expansion := 4.0
@export_range(1.0, 40.0, 0.5) var crosshair_recovery_speed := 16.0

@onready var player: PlayerController = get_parent() as PlayerController
@onready var camera: Camera3D = get_node(camera_path)
@onready var weapon_mount: Node3D = get_node(weapon_mount_path)

var equipped_slot := -1
var current_firearm: FirearmComponent
var _ammo_snapshots: Dictionary = {}
var _suppressor_snapshots: Dictionary = {}
var _stored_suppressor_states: Dictionary = {}
var _hud: CanvasLayer
var _ammo_panel: PanelContainer
var _ammo_label: RichTextLabel
var _crosshair: FirearmCrosshair
var _scope_overlay: Control
var _aim_held := false
var _ads_blend := 0.0
var _advanced_scope_zoom := false
var _advanced_scope_zoom_blend := 0.0
var ads_active := false
var _handling_time := 0.0
var _bob_phase := 0.0
var _movement_blend := 0.0
var _weapon_recoil_amount := 0.0
var _camera_recoil_degrees := 0.0
var _camera_recoil_yaw_degrees := 0.0
var _applied_camera_recoil_radians := 0.0
var _applied_camera_recoil_yaw_radians := 0.0
var _crosshair_bloom := 0.0
var _last_sway_offset := Vector3.ZERO
var _last_bob_offset := Vector3.ZERO
var _drop_in_progress := false
var _external_view_blocked := false
var _last_makeshift_suppressor_broken := false


func _ready() -> void:
	add_to_group("player_weapon_controllers")
	process_mode = Node.PROCESS_MODE_ALWAYS
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	DevModeManager.mode_changed.connect(_on_dev_mode_changed)
	set_process_unhandled_input(true)
	weapon_mount.position = hip_weapon_position
	weapon_mount.rotation_degrees = hip_weapon_rotation_degrees
	camera.fov = normal_fov
	if DevModeManager.is_enabled():
		_build_hud()
		call_deferred("_equip_first_supported_firearm")


func _unhandled_input(event: InputEvent) -> void:
	# Always accept an aim release so opening a menu or losing control cannot
	# leave the weapon latched in ADS.
	if event.is_action_released("aim") and (current_firearm != null or _aim_held or ads_active):
		_set_aim_held(false)
		get_viewport().set_input_as_handled()
		return
	if _external_view_blocked:
		return
	if not DevModeManager.is_enabled() or DevModeManager.is_menu_open() or not player.control_enabled or event.is_echo():
		return
	if event.is_action_pressed("fire_weapon"):
		if current_firearm == null:
			return
		fire()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("aim"):
		if current_firearm == null:
			return
		_set_aim_held(current_firearm != null)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("scope_zoom_in"):
		if set_advanced_scope_zoom(true):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("scope_zoom_out"):
		if set_advanced_scope_zoom(false):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("reload_single_round"):
		if current_firearm == null:
			return
		load_single_round()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("reload_weapon"):
		if current_firearm == null:
			return
		reload()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("equip_firearm_slot_1"):
		toggle_equip_slot(InventoryComponent.FIREARM_SLOT_1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("equip_firearm_slot_2"):
		toggle_equip_slot(InventoryComponent.FIREARM_SLOT_2)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("holster_weapon"):
		if current_firearm == null:
			return
		unequip_current()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("drop_weapon"):
		if current_firearm == null:
			return
		unequip_and_drop_current()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_suppressor"):
		if current_firearm == null: return
		if current_firearm.is_suppressed(): detach_suppressor()
		else: attach_compatible_suppressor()
		get_viewport().set_input_as_handled()
		return


func _process(delta: float) -> void:
	if _external_view_blocked:
		_set_ads_active(false)
		if current_firearm: current_firearm.visible = false
		if _crosshair: _crosshair.visible = false
		if _scope_overlay: _scope_overlay.visible = false
		return
	if current_firearm: current_firearm.visible = true
	var can_aim := _aim_held and current_firearm != null \
		and current_firearm.state != FirearmComponent.WeaponState.RELOADING \
		and DevModeManager.is_enabled() \
		and not DevModeManager.is_menu_open() and player.control_enabled
	_set_ads_active(can_aim)
	var target_blend := 1.0 if can_aim else 0.0
	var blend_weight := 1.0 - exp(-ads_transition_speed * delta)
	_ads_blend = lerpf(_ads_blend, target_blend, blend_weight)
	var scope_zoom_target := 1.0 if can_aim and _advanced_scope_zoom else 0.0
	_advanced_scope_zoom_blend = lerpf(_advanced_scope_zoom_blend, scope_zoom_target, blend_weight)
	if absf(_ads_blend - target_blend) < 0.001:
		_ads_blend = target_blend
	if absf(_advanced_scope_zoom_blend - scope_zoom_target) < 0.001:
		_advanced_scope_zoom_blend = scope_zoom_target
	_update_handling_motion(delta)
	_update_camera_recoil(delta)
	var active_ads_pos := get_active_ads_position()
	var active_ads_rot := get_active_ads_rotation_degrees()
	var recoil_position := hip_weapon_recoil_position.lerp(ads_weapon_recoil_position, _ads_blend) * _weapon_recoil_amount
	var recoil_rotation := hip_weapon_recoil_rotation_degrees.lerp(ads_weapon_recoil_rotation_degrees, _ads_blend) * _weapon_recoil_amount
	weapon_mount.position = hip_weapon_position.lerp(active_ads_pos, _ads_blend) + _last_sway_offset + _last_bob_offset + recoil_position
	weapon_mount.rotation_degrees = hip_weapon_rotation_degrees.lerp(active_ads_rot, _ads_blend) + recoil_rotation + Vector3(_last_bob_offset.y * 40.0, 0, -_last_sway_offset.x * 55.0)
	camera.fov = lerpf(normal_fov, get_active_ads_fov(), _ads_blend)
	_crosshair_bloom = move_toward(_crosshair_bloom, 0.0, crosshair_recovery_speed * delta)
	_update_crosshair()
	_update_scope_overlay()
	if current_firearm and current_firearm.get_visual():
		current_firearm.get_visual().set_ads_blend(_ads_blend)
	_handle_runtime_firing()


func _handle_runtime_firing() -> void:
	if not DevModeManager.is_enabled() or DevModeManager.is_menu_open() or not player.control_enabled or current_firearm == null:
		return
	if Input.is_action_just_pressed("fire_weapon"):
		fire()
	elif current_firearm.definition \
		and current_firearm.definition.fire_mode == FirearmDefinition.FireMode.AUTOMATIC \
		and current_firearm.magazine_ammo > 0 \
		and Input.is_action_pressed("fire_weapon"):
		# The component's configurable shot interval gates follow-up rounds. Semi-
		# automatic firearms still require a fresh trigger edge.
		fire()


func fire() -> bool:
	return not _external_view_blocked and current_firearm != null and current_firearm.try_fire(camera, get_current_spread_degrees())


func set_external_view_blocked(blocked: bool) -> void:
	_external_view_blocked = blocked
	if blocked: _cancel_ads_immediately()
	if current_firearm: current_firearm.visible = not blocked
	_update_crosshair()
	_update_scope_overlay()


func reload() -> bool:
	if current_firearm != null and current_firearm.start_reload():
		_set_aim_held(false)
		_set_ads_active(false)
		return true
	return false


func load_single_round() -> bool:
	if current_firearm != null and current_firearm.start_individual_round_load():
		_set_aim_held(false)
		_set_ads_active(false)
		return true
	return false


func toggle_equip_slot(index: int) -> bool:
	if current_firearm != null and equipped_slot == index:
		unequip_current()
		return true
	return equip_slot(index)


func equip_slot(index: int) -> bool:
	if not DevModeManager.is_enabled():
		return false
	var item := InventoryManager.get_firearm_slot(index)
	if not item is FirearmDefinition:
		InventoryManager.request_feedback("ITEM CANNOT BE EQUIPPED")
		return false
	var definition := item as FirearmDefinition
	var melee := player.get_node_or_null("MeleeController") as PlayerMeleeController
	if melee: melee.unequip_current()
	unequip_current()
	var snapshot: Dictionary = _ammo_snapshots.get(definition.normalized_weapon_id(), {})
	var suppressor_snapshot: Dictionary = _suppressor_snapshots.get(definition.normalized_weapon_id(), {})
	current_firearm = FIREARM_SCENE.instantiate() as FirearmComponent
	current_firearm.name = "%sRuntime" % definition.display_name.to_pascal_case()
	weapon_mount.add_child(current_firearm)
	if not current_firearm.configure(definition, int(snapshot.get("magazine", -1)), int(snapshot.get("reserve", -1)), suppressor_snapshot):
		current_firearm.queue_free()
		current_firearm = null
		return false
	equipped_slot = index
	current_firearm.ammo_changed.connect(_on_ammo_changed)
	current_firearm.state_changed.connect(_on_weapon_state_changed)
	current_firearm.shot_fired.connect(_on_shot_fired)
	current_firearm.hit_confirmed.connect(_on_hit_confirmed)
	current_firearm.suppressor_changed.connect(_on_suppressor_changed)
	current_firearm.suppressor_durability_changed.connect(_on_suppressor_durability_changed)
	current_firearm.suppressor_broken.connect(_on_suppressor_broken)
	current_firearm.equip()
	_refresh_scope_overlay()
	_update_weapon_hud()
	_update_crosshair()
	equipped_changed.emit(definition.normalized_weapon_id(), true)
	return true


func unequip_current() -> void:
	_cancel_ads_immediately()
	if current_firearm == null:
		equipped_slot = -1
		_update_weapon_hud()
		_update_crosshair()
		return
	var weapon_id := current_firearm.definition.normalized_weapon_id()
	_ammo_snapshots[weapon_id] = current_firearm.get_ammo_snapshot()
	_store_current_suppressor_snapshot()
	current_firearm.unequip()
	current_firearm.queue_free()
	current_firearm = null
	_clear_scope_overlay()
	equipped_slot = -1
	_update_weapon_hud()
	_update_crosshair()
	equipped_changed.emit(weapon_id, false)


func unequip_and_drop_current() -> bool:
	if current_firearm == null or equipped_slot < 0:
		return false
	var definition := current_firearm.definition
	var snapshot := current_firearm.get_ammo_snapshot()
	var suppressor_snapshot := current_firearm.get_suppressor_snapshot()
	var drop_transform := _get_drop_transform()
	var old_slot := equipped_slot
	_drop_in_progress = true
	if not suppressor_snapshot.is_empty():
		InventoryManager.remove_item(suppressor_snapshot.suppressor_id, 1, false)
	var slot_cleared := InventoryManager.clear_firearm_slot(old_slot)
	_drop_in_progress = false
	if not slot_cleared:
		return false
	var pickup := PICKUP_SCENE.instantiate() as FirearmPickup
	pickup.name = "Dropped%s" % definition.display_name.to_pascal_case()
	pickup.definition = definition
	pickup.saved_magazine = int(snapshot.magazine)
	pickup.saved_reserve = int(snapshot.reserve)
	if not suppressor_snapshot.is_empty():
		pickup.attached_suppressor = suppressor_snapshot.definition as SuppressorDefinition
		pickup.suppressor_remaining_uses = int(suppressor_snapshot.remaining_magazine_uses)
		pickup.suppressor_used_this_magazine = bool(suppressor_snapshot.used_this_magazine)
	var parent := _get_drop_parent()
	parent.add_child(pickup)
	pickup.global_transform = drop_transform
	_ammo_snapshots.erase(definition.normalized_weapon_id())
	_suppressor_snapshots.erase(definition.normalized_weapon_id())
	InventoryManager.request_feedback("WEAPON DROPPED — FIREARM SLOT FREED")
	weapon_dropped.emit(definition.normalized_weapon_id(), pickup)
	return true


## Compatibility alias for existing callers and tests. Dropping is the explicit
## inventory-removing unequip path; ordinary holstering keeps the weapon owned.
func drop_equipped_weapon() -> bool:
	return unequip_and_drop_current()


func register_ammo_snapshot(weapon_id: StringName, magazine: int, reserve: int) -> void:
	if magazine < 0 and reserve < 0:
		return
	_ammo_snapshots[weapon_id] = {"magazine": magazine, "reserve": reserve}


func register_suppressor_snapshot(weapon_id: StringName, suppressor: SuppressorDefinition, remaining_uses: int, used_this_magazine: bool) -> void:
	if suppressor == null: return
	_suppressor_snapshots[weapon_id] = {
		"definition": suppressor,
		"suppressor_id": suppressor.normalized_id(),
		"remaining_magazine_uses": remaining_uses,
		"used_this_magazine": used_this_magazine,
		"broken": false,
	}


func attach_suppressor(suppressor_id: StringName) -> bool:
	if current_firearm == null or current_firearm.is_suppressed():
		InventoryManager.request_feedback("FIREARM REQUIRED OR ALREADY SUPPRESSED")
		return false
	var suppressor := InventoryManager.get_item_definition(suppressor_id) as SuppressorDefinition
	if suppressor == null or not suppressor.supports_weapon(current_firearm.definition.normalized_weapon_id()):
		InventoryManager.request_feedback("INCOMPATIBLE SUPPRESSOR")
		return false
	if _is_suppressor_attached_elsewhere(suppressor.normalized_id(), current_firearm.definition.normalized_weapon_id()):
		InventoryManager.request_feedback("SUPPRESSOR ALREADY ATTACHED")
		return false
	var state: Dictionary = _stored_suppressor_states.get(suppressor.normalized_id(), {})
	if not current_firearm.attach_suppressor(suppressor, state):
		InventoryManager.request_feedback("SUPPRESSOR UNAVAILABLE")
		return false
	_stored_suppressor_states.erase(suppressor.normalized_id())
	_last_makeshift_suppressor_broken = false
	_store_current_suppressor_snapshot()
	InventoryManager.request_feedback("%s ATTACHED" % suppressor.display_name.to_upper())
	_update_weapon_hud()
	return true


func attach_compatible_suppressor() -> bool:
	if current_firearm == null: return false
	for entry in InventoryManager.get_items_in_category(ItemDefinition.Category.EQUIPMENT):
		var suppressor := entry.definition as SuppressorDefinition
		if suppressor and suppressor.supports_weapon(current_firearm.definition.normalized_weapon_id()):
			return attach_suppressor(suppressor.normalized_id())
	InventoryManager.request_feedback("NO COMPATIBLE SUPPRESSOR")
	return false


func detach_suppressor() -> bool:
	if current_firearm == null or not current_firearm.is_suppressed():
		InventoryManager.request_feedback("NO SUPPRESSOR ATTACHED")
		return false
	var weapon_id := current_firearm.definition.normalized_weapon_id()
	var snapshot := current_firearm.detach_suppressor()
	if snapshot.is_empty(): return false
	_stored_suppressor_states[snapshot.suppressor_id] = snapshot
	_suppressor_snapshots.erase(weapon_id)
	InventoryManager.request_feedback("SUPPRESSOR DETACHED")
	_update_weapon_hud()
	return true


func reset_makeshift_suppressor_durability() -> bool:
	var changed := false
	if current_firearm and current_firearm.suppressor_definition \
		and current_firearm.suppressor_definition.suppressor_type == SuppressorDefinition.Type.MAKESHIFT:
		current_firearm.suppressor_remaining_uses = current_firearm.suppressor_definition.max_magazine_uses
		current_firearm.suppressed_shots_this_magazine = false
		_store_current_suppressor_snapshot(); changed = true
	for weapon_id in _suppressor_snapshots.keys():
		var state: Dictionary = _suppressor_snapshots[weapon_id]
		var definition := state.definition as SuppressorDefinition
		if definition and definition.suppressor_type == SuppressorDefinition.Type.MAKESHIFT:
			state.remaining_magazine_uses = definition.max_magazine_uses
			state.used_this_magazine = false
			_suppressor_snapshots[weapon_id] = state; changed = true
	for suppressor_id in _stored_suppressor_states.keys():
		var state: Dictionary = _stored_suppressor_states[suppressor_id]
		var definition := state.definition as SuppressorDefinition
		if definition and definition.suppressor_type == SuppressorDefinition.Type.MAKESHIFT:
			state.remaining_magazine_uses = definition.max_magazine_uses
			state.used_this_magazine = false
			state.broken = false
			_stored_suppressor_states[suppressor_id] = state; changed = true
	_update_weapon_hud()
	if changed:
		_last_makeshift_suppressor_broken = false
		InventoryManager.request_feedback("MAKESHIFT DURABILITY RESET")
	return changed


func get_suppressor_status() -> String:
	if current_firearm == null or not current_firearm.is_suppressed():
		return "MAKESHIFT SUPPRESSOR — BROKEN" if _last_makeshift_suppressor_broken else "UNSUPPRESSED"
	var suppressor := current_firearm.suppressor_definition
	if suppressor.max_magazine_uses > 0:
		return "%s  %d / %d MAGAZINES" % [suppressor.display_name.to_upper(), current_firearm.suppressor_remaining_uses, suppressor.max_magazine_uses]
	return "%s  REUSABLE" % suppressor.display_name.to_upper()


func _store_current_suppressor_snapshot() -> void:
	if current_firearm == null: return
	var weapon_id := current_firearm.definition.normalized_weapon_id()
	var snapshot := current_firearm.get_suppressor_snapshot()
	if snapshot.is_empty(): _suppressor_snapshots.erase(weapon_id)
	else: _suppressor_snapshots[weapon_id] = snapshot


func _is_suppressor_attached_elsewhere(suppressor_id: StringName, current_weapon_id: StringName) -> bool:
	for weapon_id in _suppressor_snapshots.keys():
		if weapon_id != current_weapon_id and StringName((_suppressor_snapshots[weapon_id] as Dictionary).get("suppressor_id", &"")) == suppressor_id:
			return true
	return false


func refill_firearm_ammo(weapon_id: StringName) -> bool:
	var normalized := StringName(str(weapon_id).strip_edges().to_lower())
	var definition := InventoryManager.get_item_definition(normalized) as FirearmDefinition
	if definition == null:
		return false
	if current_firearm != null and current_firearm.definition.normalized_weapon_id() == normalized:
		current_firearm.refill_ammo()
		_ammo_snapshots[normalized] = current_firearm.get_ammo_snapshot()
	else:
		_ammo_snapshots[normalized] = {"magazine": definition.magazine_size, "reserve": definition.reserve_ammo_capacity}
	InventoryManager.request_feedback("%s AMMO REFILLED" % definition.display_name.to_upper())
	return true


func add_reserve_ammo(weapon_id: StringName, amount: int) -> int:
	var normalized := StringName(str(weapon_id).strip_edges().to_lower())
	var definition := InventoryManager.get_item_definition(normalized) as FirearmDefinition
	if definition == null or amount <= 0:
		return 0
	if current_firearm != null and current_firearm.definition.normalized_weapon_id() == normalized:
		var added := current_firearm.add_reserve_ammo(amount)
		_ammo_snapshots[normalized] = current_firearm.get_ammo_snapshot()
		return added
	var snapshot: Dictionary = _ammo_snapshots.get(normalized, {"magazine": definition.magazine_size, "reserve": definition.initial_reserve_ammo})
	var previous := int(snapshot.reserve)
	snapshot.reserve = mini(definition.reserve_ammo_capacity, previous + amount)
	_ammo_snapshots[normalized] = snapshot
	return int(snapshot.reserve) - previous


func get_ammo_snapshot(weapon_id: StringName) -> Dictionary:
	var normalized := StringName(str(weapon_id).strip_edges().to_lower())
	if current_firearm != null and current_firearm.definition.normalized_weapon_id() == normalized:
		return current_firearm.get_ammo_snapshot()
	return (_ammo_snapshots.get(normalized, {}) as Dictionary).duplicate()


func _on_inventory_changed() -> void:
	if not _drop_in_progress:
		for weapon_id in _suppressor_snapshots.keys():
			var suppressor_id := StringName((_suppressor_snapshots[weapon_id] as Dictionary).get("suppressor_id", &""))
			if not InventoryManager.has_item(suppressor_id): _suppressor_snapshots.erase(weapon_id)
		for suppressor_id in _stored_suppressor_states.keys():
			if not InventoryManager.has_item(suppressor_id as StringName): _stored_suppressor_states.erase(suppressor_id)
		if current_firearm and current_firearm.suppressor_definition and not InventoryManager.has_item(current_firearm.suppressor_definition.normalized_id()):
			current_firearm.detach_suppressor()
	if current_firearm != null and not InventoryManager.has_item(current_firearm.definition.normalized_id()):
		unequip_current()
	if current_firearm == null and DevModeManager.is_enabled() and not _drop_in_progress:
		_equip_first_supported_firearm()


func _equip_first_supported_firearm() -> void:
	for index in range(InventoryComponent.FIREARM_SLOT_COUNT):
		if InventoryManager.get_firearm_slot(index) is FirearmDefinition:
			equip_slot(index)
			return


func _on_dev_mode_changed(enabled: bool) -> void:
	if enabled:
		_build_hud()
		_equip_first_supported_firearm()
	else:
		_cancel_ads_immediately()
		unequip_current()
		if _hud:
			_hud.queue_free()
			_hud = null
			_ammo_label = null
			_ammo_panel = null
			_crosshair = null
			_scope_overlay = null


func _on_ammo_changed(_magazine: int, _reserve: int) -> void:
	if current_firearm:
		_ammo_snapshots[current_firearm.definition.normalized_weapon_id()] = current_firearm.get_ammo_snapshot()
	_update_weapon_hud()


func _on_weapon_state_changed(_state: FirearmComponent.WeaponState) -> void:
	_update_weapon_hud()


func _on_suppressor_changed(_suppressor: SuppressorDefinition) -> void:
	_store_current_suppressor_snapshot()
	_update_weapon_hud()


func _on_suppressor_durability_changed(_remaining: int, _maximum: int) -> void:
	_store_current_suppressor_snapshot()
	_update_weapon_hud()


func _on_suppressor_broken(suppressor_id: StringName) -> void:
	_last_makeshift_suppressor_broken = true
	if current_firearm: _suppressor_snapshots.erase(current_firearm.definition.normalized_weapon_id())
	_stored_suppressor_states.erase(suppressor_id)
	InventoryManager.remove_item(suppressor_id, 1, false)
	InventoryManager.request_feedback("MAKESHIFT SUPPRESSOR BROKEN")
	_update_weapon_hud()


func _on_shot_fired(definition: FirearmDefinition, _magazine: int, _reserve: int) -> void:
	var ads_weight := _ads_blend
	var kick := definition.recoil_weapon_kick_override if (definition and definition.recoil_weapon_kick_override > 0.0) else 1.0
	var hip_cam := definition.recoil_camera_degrees_override if (definition and definition.recoil_camera_degrees_override > 0.0) else hip_camera_recoil_degrees
	var ads_cam := definition.ads_camera_recoil_override if (definition and definition.ads_camera_recoil_override > 0.0) else ads_camera_recoil_degrees

	_weapon_recoil_amount = minf(1.35, _weapon_recoil_amount + lerpf(kick, kick * ads_recoil_multiplier, ads_weight))
	_camera_recoil_degrees = minf(3.5, _camera_recoil_degrees + lerpf(hip_cam, ads_cam, ads_weight))
	if definition and definition.horizontal_recoil_degrees > 0.0:
		var horiz := randf_range(-definition.horizontal_recoil_degrees, definition.horizontal_recoil_degrees)
		_camera_recoil_yaw_degrees = clampf(_camera_recoil_yaw_degrees + horiz * lerpf(1.0, 0.4, ads_weight), -2.0, 2.0)
	_crosshair_bloom = minf(12.0, _crosshair_bloom + firing_crosshair_expansion)


func _on_hit_confirmed(definition: FirearmDefinition, zone: BodyHitZone, damage: float, _hit_position: Vector3) -> void:
	for node in get_tree().get_nodes_in_group("dev_damage_test_tools"):
		if node.has_method("report_firearm_hit"):
			node.call("report_firearm_hit", definition.display_name, zone, damage)
			break


func _get_drop_parent() -> Node:
	var ancestor: Node = player
	while ancestor:
		if ancestor.is_in_group("dev_only_scene"):
			var interactables := ancestor.get_node_or_null("Interactables")
			return interactables if interactables else ancestor
		ancestor = ancestor.get_parent()
	return get_tree().current_scene


func _get_drop_transform() -> Transform3D:
	var horizontal_forward := -camera.global_basis.z
	horizontal_forward.y = 0.0
	horizontal_forward = horizontal_forward.normalized()
	# Keep the pickup close and retrievable without overlapping the character.
	var intended := player.global_position + horizontal_forward * 1.05
	var query := PhysicsRayQueryParameters3D.create(intended + Vector3.UP * 1.5, intended + Vector3.DOWN * 2.5, 1)
	var result := player.get_world_3d().direct_space_state.intersect_ray(query)
	var position := result.position as Vector3 + Vector3.UP * 0.02 if not result.is_empty() else intended + Vector3.DOWN * 0.9
	return Transform3D(Basis(Vector3.UP, player.global_rotation.y), position)


func _build_hud() -> void:
	if _hud != null:
		return
	_hud = CanvasLayer.new()
	_hud.name = "FirearmHUD"
	_hud.layer = 125
	add_child(_hud)
	_ammo_panel = PanelContainer.new()
	_ammo_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo_panel.position = Vector2(-304, -232)
	_ammo_panel.size = Vector2(282, 208)
	_ammo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.025, 0.03, 0.92)
	style.border_color = Color("c7a34a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(11)
	_ammo_panel.add_theme_stylebox_override("panel", style)
	_hud.add_child(_ammo_panel)
	_crosshair = CROSSHAIR_SCENE.instantiate() as FirearmCrosshair
	_crosshair.name = "Crosshair"
	_crosshair.line_length = crosshair_line_length
	_crosshair.center_gap = crosshair_center_gap
	_crosshair.line_thickness = crosshair_thickness
	_crosshair.crosshair_color = crosshair_color
	_hud.add_child(_crosshair)
	_ammo_label = RichTextLabel.new()
	_ammo_label.bbcode_enabled = true
	_ammo_label.fit_content = false
	_ammo_label.scroll_active = false
	_ammo_label.add_theme_color_override("font_color", Color("d9e2df"))
	_ammo_label.add_theme_font_size_override("normal_font_size", 15)
	_ammo_panel.add_child(_ammo_label)
	_update_weapon_hud()
	_update_crosshair()


func _update_weapon_hud() -> void:
	if _ammo_label == null:
		return
	if current_firearm == null:
		_ammo_panel.visible = false
		_ammo_label.text = ""
		return
	_ammo_panel.visible = true
	var state_label := String(FirearmComponent.WeaponState.keys()[int(current_firearm.state)])
	var fire_label := "HOLD LMB AUTO" if current_firearm.definition.fire_mode == FirearmDefinition.FireMode.AUTOMATIC else "LMB FIRE"
	var load_label := "\nSHIFT+R LOAD 1 ROUND" if current_firearm.definition.supports_individual_round_loading() else ""
	var scope_label := "\nSCOPE %s  //  WHEEL ZOOM" % ("ADVANCED" if _advanced_scope_zoom else "STANDARD") if _supports_advanced_scope_zoom() else ""
	var suppression := "%s\nNOISE %.0f M  //  FLASH %s" % [get_suppressor_status(), current_firearm.get_effective_noise_radius(), current_firearm.get_muzzle_flash_mode()]
	_ammo_label.text = "[right][font_size=17][b]%s[/b][/font_size]\n[font_size=30][b]%d[/b][/font_size] [color=#8f9d9b][font_size=18]/ %d[/font_size][/color]\n[color=#c7a34a]%s[/color]\n[color=#9ed7be][font_size=12]%s%s[/font_size][/color]\n[font_size=13]%s  RMB AIM  R RELOAD%s\nX ATTACH/DETACH  H HOLSTER  G DROP[/font_size][/right]" % [
		current_firearm.definition.display_name.to_upper(), current_firearm.magazine_ammo,
		current_firearm.reserve_ammo, state_label, suppression, scope_label, fire_label, load_label,
	]


func _set_aim_held(held: bool) -> void:
	_aim_held = held
	if not held:
		_advanced_scope_zoom = false
		_update_weapon_hud()


func set_advanced_scope_zoom(enabled: bool) -> bool:
	if not _supports_advanced_scope_zoom() or not (_aim_held or ads_active):
		return false
	_advanced_scope_zoom = enabled
	_update_weapon_hud()
	return true


func is_advanced_scope_zoom_active() -> bool:
	return _advanced_scope_zoom and _supports_advanced_scope_zoom()


func _supports_advanced_scope_zoom() -> bool:
	return current_firearm != null and current_firearm.definition != null \
		and current_firearm.definition.has_advanced_scope_zoom


func _set_ads_active(active: bool) -> void:
	if ads_active == active:
		return
	ads_active = active
	aim_changed.emit(ads_active)


func _cancel_ads_immediately() -> void:
	_aim_held = false
	_ads_blend = 0.0
	_advanced_scope_zoom = false
	_advanced_scope_zoom_blend = 0.0
	_set_ads_active(false)
	_reset_camera_recoil()
	_weapon_recoil_amount = 0.0
	_last_sway_offset = Vector3.ZERO
	_last_bob_offset = Vector3.ZERO
	if is_instance_valid(weapon_mount):
		weapon_mount.position = hip_weapon_position
		weapon_mount.rotation_degrees = hip_weapon_rotation_degrees
	if is_instance_valid(camera):
		camera.fov = normal_fov
	_update_crosshair()
	_update_scope_overlay()


func _update_crosshair() -> void:
	if _crosshair == null:
		return
	_crosshair.set_aiming(ads_active)
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length() if is_instance_valid(player) else 0.0
	var movement_ratio := clampf(horizontal_speed / maxf(0.1, player.walk_speed), 0.0, 1.5) if is_instance_valid(player) else 0.0
	var movement_expansion := movement_crosshair_expansion * movement_ratio
	if is_instance_valid(player) and player.is_sprinting:
		movement_expansion *= sprint_bob_multiplier
	elif is_instance_valid(player) and player.is_crouching:
		movement_expansion *= crouch_bob_multiplier
	_crosshair.set_spread(movement_expansion + _crosshair_bloom)
	_crosshair.visible = not _external_view_blocked and current_firearm != null and (not ads_active or not hide_crosshair_while_ads)


func is_crosshair_visible() -> bool:
	return _crosshair != null and _crosshair.visible


func is_firearm_visibly_held() -> bool:
	return current_firearm != null and current_firearm.visible and not _external_view_blocked


func get_active_ads_position() -> Vector3:
	if current_firearm and current_firearm.definition and current_firearm.definition.has_custom_ads_transform:
		return current_firearm.definition.custom_ads_position
	return ads_weapon_position


func get_active_ads_rotation_degrees() -> Vector3:
	if current_firearm and current_firearm.definition and current_firearm.definition.has_custom_ads_transform:
		return current_firearm.definition.custom_ads_rotation_degrees
	return ads_weapon_rotation_degrees


func get_active_ads_fov() -> float:
	var base_ads_fov := ads_fov
	if current_firearm and current_firearm.definition and current_firearm.definition.ads_fov_override > 0.0:
		base_ads_fov = current_firearm.definition.ads_fov_override
	if _supports_advanced_scope_zoom():
		return lerpf(base_ads_fov, current_firearm.definition.advanced_scope_fov, _advanced_scope_zoom_blend)
	return base_ads_fov


func get_active_ads_motion_multiplier() -> float:
	if current_firearm and current_firearm.definition and current_firearm.definition.ads_motion_multiplier_override >= 0.0:
		return current_firearm.definition.ads_motion_multiplier_override
	return ads_motion_multiplier


func get_ads_blend() -> float:
	return _ads_blend


func is_scope_overlay_visible() -> bool:
	return _scope_overlay != null and _scope_overlay.visible


func get_current_spread_degrees() -> float:
	if current_firearm == null or current_firearm.definition == null:
		return 0.0
	return lerpf(current_firearm.definition.hip_fire_spread_degrees, current_firearm.definition.ads_spread_degrees, _ads_blend)


func get_sight_alignment_pixels() -> Dictionary:
	return current_firearm.get_sight_alignment_pixels(camera) if current_firearm else {}


func get_weapon_recoil_amount() -> float:
	return _weapon_recoil_amount


func get_camera_recoil_degrees() -> float:
	return _camera_recoil_degrees


func get_last_sway_offset() -> Vector3:
	return _last_sway_offset


func get_last_bob_offset() -> Vector3:
	return _last_bob_offset


func is_ammo_hud_visible() -> bool:
	return _ammo_panel != null and _ammo_panel.visible


func get_ammo_hud_text() -> String:
	return _ammo_label.text if _ammo_label else ""


func get_crosshair_spread() -> float:
	return _crosshair.get_spread() if _crosshair else 0.0


func _update_handling_motion(delta: float) -> void:
	_handling_time += delta
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var movement_target := clampf(horizontal_speed / maxf(0.1, player.walk_speed), 0.0, 1.0)
	var blend_weight := 1.0 - exp(-movement_blend_speed * delta)
	_movement_blend = lerpf(_movement_blend, movement_target, blend_weight)
	if _movement_blend < 0.001:
		_movement_blend = 0.0
	if horizontal_speed > 0.05:
		_bob_phase += delta * (bob_frequency + horizontal_speed * 0.65)
	var stance_multiplier := sprint_bob_multiplier if player.is_sprinting else (crouch_bob_multiplier if player.is_crouching else 1.0)
	var ads_multiplier := lerpf(1.0, get_active_ads_motion_multiplier(), _ads_blend)
	_last_sway_offset = Vector3(
		sin(_handling_time * 1.15) * idle_sway_amount.x,
		cos(_handling_time * 1.35) * idle_sway_amount.y,
		0.0
	) * ads_multiplier
	_last_bob_offset = Vector3(
		sin(_bob_phase) * walking_bob_amount.x,
		-cos(_bob_phase * 2.0) * walking_bob_amount.y,
		0.0
	) * _movement_blend * stance_multiplier * ads_multiplier
	var recovery := lerpf(_get_recoil_recovery(false), _get_recoil_recovery(true), _ads_blend)
	if _is_sustained_fire_active():
		recovery *= 0.1
	_weapon_recoil_amount = move_toward(_weapon_recoil_amount, 0.0, recovery * delta)


func _update_camera_recoil(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	camera.rotation.x -= _applied_camera_recoil_radians
	camera.rotation.y -= _applied_camera_recoil_yaw_radians
	var recovery := lerpf(_get_recoil_recovery(false), _get_recoil_recovery(true), _ads_blend)
	if _is_sustained_fire_active():
		recovery *= 0.1
	_camera_recoil_degrees = move_toward(_camera_recoil_degrees, 0.0, recovery * delta)
	_camera_recoil_yaw_degrees = move_toward(_camera_recoil_yaw_degrees, 0.0, recovery * delta)
	_applied_camera_recoil_radians = -deg_to_rad(_camera_recoil_degrees)
	_applied_camera_recoil_yaw_radians = deg_to_rad(_camera_recoil_yaw_degrees)
	camera.rotation.x += _applied_camera_recoil_radians
	camera.rotation.y += _applied_camera_recoil_yaw_radians


func _is_sustained_fire_active() -> bool:
	if current_firearm == null or current_firearm.definition == null:
		return false
	if current_firearm.is_burst_active():
		return true
	return current_firearm.definition.fire_mode == FirearmDefinition.FireMode.AUTOMATIC \
		and Input.is_action_pressed("fire_weapon") \
		and current_firearm.magazine_ammo > 0


func _reset_camera_recoil() -> void:
	if is_instance_valid(camera):
		camera.rotation.x -= _applied_camera_recoil_radians
		camera.rotation.y -= _applied_camera_recoil_yaw_radians
	_applied_camera_recoil_radians = 0.0
	_applied_camera_recoil_yaw_radians = 0.0
	_camera_recoil_degrees = 0.0
	_camera_recoil_yaw_degrees = 0.0


func _get_recoil_recovery(for_ads: bool) -> float:
	if current_firearm and current_firearm.definition:
		var override := current_firearm.definition.ads_recoil_recovery_speed_override if for_ads else current_firearm.definition.recoil_recovery_speed_override
		if override > 0.0:
			return override
	return ads_recoil_recovery_speed if for_ads else recoil_recovery_speed


func _refresh_scope_overlay() -> void:
	_clear_scope_overlay()
	if _hud == null or current_firearm == null or current_firearm.definition == null:
		return
	var scene := current_firearm.definition.scope_overlay_scene
	if scene == null:
		return
	var instance := scene.instantiate()
	if not instance is Control:
		push_error("Scope overlay scene root must extend Control: %s" % scene.resource_path)
		instance.free()
		return
	_scope_overlay = instance as Control
	_scope_overlay.name = "ScopeOverlay"
	_scope_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scope_overlay.visible = false
	_hud.add_child(_scope_overlay)
	# Keep the normal crosshair and ammo card above the scope mask.
	_hud.move_child(_scope_overlay, 0)


func _update_scope_overlay() -> void:
	if _scope_overlay == null:
		return
	var blend := clampf(_ads_blend, 0.0, 1.0)
	_scope_overlay.visible = current_firearm != null and blend > 0.01
	if _scope_overlay.has_method("set_scope_blend"):
		_scope_overlay.call("set_scope_blend", blend)
	else:
		_scope_overlay.modulate.a = blend


func _clear_scope_overlay() -> void:
	if _scope_overlay:
		_scope_overlay.queue_free()
		_scope_overlay = null
