extends Node
class_name PlayerEquipmentController

signal monocular_state_changed(state: StringName)

enum ZoomState { NORMAL, ZOOM_1, ZOOM_2, ZOOM_3 }
const MONOCULAR: ItemDefinition = preload("res://resources/items/monocular.tres")

@export var camera_path := NodePath("../Head/Camera3D")
@export var mount_path := NodePath("../Head/Camera3D/EquipmentMount")
@onready var player: PlayerController = get_parent() as PlayerController
@onready var camera: Camera3D = get_node(camera_path)
@onready var mount: Node3D = get_node(mount_path)

var selected := false
var active := false
var zoom_state := ZoomState.NORMAL
var use_blend := 0.0
var visual: Node3D
var _releasing := false
var _hud: CanvasLayer
var _overlay: ColorRect
var _indicator: Label


func _ready() -> void:
	add_to_group("player_equipment_controllers")
	process_mode = Node.PROCESS_MODE_ALWAYS
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	# Equipment gets the shared RMB before weapon controllers' unhandled input.
	set_process_input(true)
	_build_hud()


func _input(event: InputEvent) -> void:
	# Always honor RMB release so a menu/control-state change cannot leave the optic raised.
	if selected and event.is_action_released("use_equipment"):
		deactivate()
		get_viewport().set_input_as_handled()
		return
	if DevModeManager.is_menu_open() or not player.control_enabled or event.is_echo(): return
	if event.is_action_pressed("equip_monocular"):
		toggle_selected(); get_viewport().set_input_as_handled(); return
	# Slot changes must stow a selected monocular even when it is lowered. Leaving
	# `selected` latched here made the next RMB raise the optic over the newly
	# equipped weapon and could leave melee externally blocked as well.
	if selected or active or _releasing:
		if event.is_action_pressed("equip_firearm_slot_1"):
			_stow_for_other_item(); (player.get_node("WeaponController") as PlayerWeaponController).equip_slot(0); get_viewport().set_input_as_handled(); return
		if event.is_action_pressed("equip_firearm_slot_2"):
			_stow_for_other_item(); (player.get_node("WeaponController") as PlayerWeaponController).equip_slot(1); get_viewport().set_input_as_handled(); return
		if event.is_action_pressed("equip_melee_slot"):
			_stow_for_other_item(); (player.get_node("MeleeController") as PlayerMeleeController).equip_melee_slot(); get_viewport().set_input_as_handled(); return
	if selected and event.is_action_pressed("use_equipment"):
		activate()
		get_viewport().set_input_as_handled(); return
	if not active: return
	if event.is_action_pressed("monocular_zoom_in"):
		set_zoom_state(mini(ZoomState.ZOOM_3, zoom_state + 1)); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("monocular_zoom_out"):
		set_zoom_state(maxi(ZoomState.NORMAL, zoom_state - 1)); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("fire_weapon") or event.is_action_pressed("aim"):
		get_viewport().set_input_as_handled(); return


func _process(delta: float) -> void:
	if active and player.is_sprinting: deactivate()
	var target := 1.0 if active else 0.0
	var transition_speed := float(MONOCULAR.get("zoom_transition_speed"))
	use_blend = lerpf(use_blend, target, 1.0 - exp(-transition_speed * delta))
	if visual:
		# The housing is only visible while raising/lowering it. Once the eye is
		# looking through the optic, including at 1x, it is outside the view cone.
		visual.visible = not active and _releasing and use_blend > 0.01
		visual.call("set_use_blend", use_blend)
	if active:
		camera.fov = lerpf(camera.fov, _target_fov(), 1.0 - exp(-transition_speed * delta))
	elif _releasing:
		var normal_fov := float(MONOCULAR.get("normal_fov"))
		camera.fov = lerpf(camera.fov, normal_fov, 1.0 - exp(-transition_speed * delta))
		if use_blend < 0.01 and absf(camera.fov - normal_fov) < 0.1:
			_releasing = false; camera.fov = normal_fov; _set_weapon_block(false)
	_update_hud()


func toggle_selected() -> bool:
	if not InventoryManager.has_item(MONOCULAR.item_id):
		InventoryManager.request_feedback("MONOCULAR NOT OWNED"); return false
	if selected:
		deactivate(true); selected = false; _set_weapon_block(false)
		if visual: visual.queue_free(); visual = null
	else:
		selected = true
		visual = MONOCULAR.get("first_person_visual_scene").instantiate() as Node3D
		mount.add_child(visual); visual.visible = false
		# Cancel pre-existing firearm ADS without changing its inventory/equip state.
		_set_weapon_block(true)
		_set_weapon_block(false)
	InventoryManager.request_feedback("MONOCULAR SELECTED" if selected else "MONOCULAR STOWED")
	return true


func activate() -> bool:
	if not selected or active: return false
	active = true; _releasing = false; zoom_state = ZoomState.NORMAL
	_set_weapon_block(true); _update_hud(); monocular_state_changed.emit(&"NORMAL")
	return true


func deactivate(immediate := false) -> void:
	if not active and not _releasing: return
	active = false; zoom_state = ZoomState.NORMAL
	if immediate:
		use_blend = 0.0; camera.fov = float(MONOCULAR.get("normal_fov")); _releasing = false; _set_weapon_block(false)
		if visual: visual.visible = false
	else: _releasing = true
	_update_hud(); monocular_state_changed.emit(&"INACTIVE")


func set_zoom_state(value: int) -> void:
	if not active: return
	zoom_state = clampi(value, ZoomState.NORMAL, ZoomState.ZOOM_3)
	monocular_state_changed.emit(StringName(ZoomState.keys()[zoom_state]))
	_update_hud()


func get_state_name() -> String:
	if not active: return "INACTIVE"
	return ZoomState.keys()[zoom_state]


func is_overlay_visible() -> bool:
	return _overlay != null and _overlay.visible


func get_zoom_label() -> String:
	return ["1x", "3x", "6x", "8x"][zoom_state] if active else "—"


func _target_fov() -> float:
	match zoom_state:
		ZoomState.ZOOM_1: return float(MONOCULAR.get("zoom_1_fov"))
		ZoomState.ZOOM_2: return float(MONOCULAR.get("zoom_2_fov"))
		ZoomState.ZOOM_3: return float(MONOCULAR.get("zoom_3_fov"))
		_: return float(MONOCULAR.get("normal_fov"))


func _set_weapon_block(blocked: bool) -> void:
	(player.get_node("WeaponController") as PlayerWeaponController).set_external_view_blocked(blocked)
	(player.get_node("MeleeController") as PlayerMeleeController).set_external_view_blocked(blocked)


func _stow_for_other_item() -> void:
	deactivate(true)
	selected = false
	_set_weapon_block(false)
	if visual:
		visual.queue_free()
		visual = null


func _on_inventory_changed() -> void:
	if selected and not InventoryManager.has_item(MONOCULAR.item_id):
		deactivate(true); selected = false; _set_weapon_block(false)
		if visual: visual.queue_free(); visual = null


func _build_hud() -> void:
	_hud = CanvasLayer.new(); _hud.name = "MonocularHUD"; _hud.layer = 140; add_child(_hud)
	_overlay = ColorRect.new(); _overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new(); shader.code = "shader_type canvas_item; uniform float aspect=1.77778; void fragment(){ vec2 p=UV-vec2(0.5); p.x*=aspect; float d=length(p); float edge=smoothstep(0.34,0.39,d); float vignette=smoothstep(0.18,0.39,d)*0.24; COLOR=vec4(0.005,0.008,0.008,max(edge*0.96,vignette)); }"
	var material := ShaderMaterial.new(); material.shader = shader; _overlay.material = material; _hud.add_child(_overlay)
	var dot := Label.new(); dot.text = "+"; dot.set_anchors_preset(Control.PRESET_CENTER); dot.position = Vector2(-5, -12); dot.add_theme_font_size_override("font_size", 17); dot.add_theme_color_override("font_color", Color(0.72, 0.80, 0.74, 0.7)); _overlay.add_child(dot)
	_indicator = Label.new(); _indicator.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); _indicator.position = Vector2(-170, -90); _indicator.size = Vector2(145, 58); _indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; _indicator.add_theme_font_size_override("font_size", 16); _indicator.add_theme_color_override("font_color", Color("b9cbc4")); _hud.add_child(_indicator)
	_update_hud()


func _update_hud() -> void:
	if _overlay == null: return
	_overlay.visible = active
	_indicator.visible = active
	if active: _indicator.text = "MONOCULAR\n%s" % ["1x", "3x", "6x", "8x"][zoom_state]
