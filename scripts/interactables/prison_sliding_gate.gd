extends Node3D
class_name PrisonSlidingGate

const CELL_BARS := preload("res://materials/props/cell_bars.tres")
const Affordance := preload("res://scripts/props/interaction_affordance.gd")

@export var display_name := "Prison Gate"
@export var required_key_id: StringName = &"cellblock_key"
## Optional facility-wide override. Cell doors use this for the future police
## chief's master key while retaining their own individual key IDs.
@export var master_key_id: StringName = &""
@export var persistent_access_id: StringName = &""
@export var starts_locked := true
@export var starts_open := false
@export var open_direction := 1.0
@export_range(0.5, 3.5, 0.05) var slide_distance := 1.7
@export_range(0.2, 2.0, 0.05) var animation_duration := 0.75
@export_range(1.1, 2.4, 0.05) var gate_width := 1.5
@export_range(2.0, 3.0, 0.05) var gate_height := 2.5
@export_range(4, 10, 1) var slat_count := 7
@export var bulletproof_glass := false
@export var gate_color := Color("343a38")
@export var panel_label := ""
@export var reader_light_enabled := true

@onready var leaf: AnimatableBody3D = $GateLeaf
@onready var visuals: Node3D = $GateLeaf/Visuals
@onready var blocker: CollisionShape3D = $GateLeaf/CollisionShape3D
@onready var safety_shape: CollisionShape3D = $DoorwaySafety/CollisionShape3D

var is_open := false
var is_locked := true
var _moving := false
var _transition: Tween
var _closed_position := Vector3.ZERO
var _reader_led_mesh: MeshInstance3D
var _reader_led_material: StandardMaterial3D
var _reader_light: OmniLight3D


func _ready() -> void:
	add_to_group("map_access")
	if bulletproof_glass:
		add_to_group("high_security_glass_doors")
	_build_gate_visuals()
	_configure_collision()
	is_locked = starts_locked and not _is_persistently_unlocked()
	is_open = starts_open and not is_locked
	_closed_position = leaf.position
	_build_key_reader()
	_update_access_indicator()
	_apply_pose(is_open)
	blocker.disabled = is_open


func get_interaction_prompt(_player: Node) -> String:
	if _moving:
		return ""
	if is_locked:
		return "[E] Unlock Gate" if _has_required_key() else "[E] Locked"
	return "[E] Close Gate" if is_open else "[E] Open Gate"


func interact(_player: Node) -> void:
	if _moving:
		return
	if is_locked:
		if not _has_required_key():
			_show_message("KEY REQUIRED")
			return
		is_locked = false
		if not persistent_access_id.is_empty():
			AccessManager.unlock_access(persistent_access_id)
		_show_message("ACCESS GRANTED")
		_trigger_authorization_sequence()
		return
	if is_open and _doorway_is_blocked():
		_show_message("GATEWAY BLOCKED")
		return
	_animate_to(not is_open)


func _build_key_reader() -> void:
	# Mount reader box on the right frame post at chest height
	var reader_parent := StaticBody3D.new()
	reader_parent.name = "KeyReader"
	reader_parent.position = Vector3(gate_width * 0.5 + 0.1, gate_height * 0.5, 0.12)
	# Existing generic interaction resolves the parent gate. Layer 4 is the
	# interaction ray only, so the painted control does not block walking.
	reader_parent.collision_layer = 4
	reader_parent.collision_mask = 0
	add_child(reader_parent)
	var reader_collider := CollisionShape3D.new()
	reader_collider.name = "ReaderInteractionShape"
	var reader_shape := BoxShape3D.new()
	reader_shape.size = Vector3(0.18, 0.28, 0.16)
	reader_collider.shape = reader_shape
	reader_parent.add_child(reader_collider)

	# Keypad/card reader body
	var body_mesh := MeshInstance3D.new()
	body_mesh.name = "ReaderBody"
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.28, 0.12)
	body_mesh.mesh = box
	# Existing inset plate leaves a narrow, non-emissive yellow painted bezel.
	body_mesh.material_override = Affordance.HAZARD
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	reader_parent.add_child(body_mesh)

	# Keypad panel plate
	var plate_mesh := MeshInstance3D.new()
	plate_mesh.name = "ReaderPlate"
	var plate := BoxMesh.new()
	plate.size = Vector3(0.14, 0.22, 0.02)
	plate_mesh.mesh = plate
	plate_mesh.position = Vector3(0, 0, 0.065)
	plate_mesh.material_override = Affordance.PANEL
	plate_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	reader_parent.add_child(plate_mesh)

	# Status LED indicator
	_reader_led_material = Affordance.led_material(Color("d65038"))
	_reader_led_mesh = MeshInstance3D.new()
	_reader_led_mesh.name = "StatusLED"
	var led_box := BoxMesh.new()
	led_box.size = Vector3(0.05, 0.03, 0.03)
	_reader_led_mesh.mesh = led_box
	_reader_led_mesh.position = Vector3(0, 0.08, 0.075)
	_reader_led_mesh.material_override = _reader_led_material
	_reader_led_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	reader_parent.add_child(_reader_led_mesh)

	# Lightweight short-range light for authorized gate feedback
	if reader_light_enabled:
		_reader_light = OmniLight3D.new()
		_reader_light.name = "ReaderLight"
		_reader_light.position = Vector3(0, 0.08, 0.12)
		_reader_light.omni_range = 1.2
		_reader_light.omni_attenuation = 2.0
		_reader_light.shadow_enabled = false
		_reader_light.visible = false
		reader_parent.add_child(_reader_light)


func _update_access_indicator() -> void:
	if not _reader_led_material:
		return
	if is_locked:
		var red_color := Color("ec573b")
		_reader_led_material.albedo_color = red_color
		_reader_led_material.emission_enabled = true
		_reader_led_material.emission = red_color
		_reader_led_material.emission_energy_multiplier = 1.1
		if _reader_light:
			_reader_light.visible = false
	else:
		var green_color := Color("70dc95")
		_reader_led_material.albedo_color = green_color
		_reader_led_material.emission_enabled = true
		_reader_led_material.emission = green_color
		_reader_led_material.emission_energy_multiplier = 1.25
		if _reader_light:
			_reader_light.light_color = green_color
			_reader_light.light_energy = 0.8
			_reader_light.visible = true


func _trigger_authorization_sequence() -> void:
	_moving = true
	_update_access_indicator()
	# Brief authorization flash and short delay before gate leaf slides open
	var tween := create_tween()
	tween.tween_property(_reader_led_material, "emission_energy_multiplier", 1.8, 0.12)
	tween.tween_property(_reader_led_material, "emission_energy_multiplier", 1.25, 0.13)
	tween.tween_callback(func():
		_moving = false
		_animate_to(true)
	)


func _build_gate_visuals() -> void:
	var material: StandardMaterial3D = CELL_BARS
	if bulletproof_glass:
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.22, 0.5, 0.55, 0.38)
		glass.metallic = 0.08
		glass.roughness = 0.18
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		var pane_width := (gate_width - 0.22) * 0.5
		_add_visual_box("BallisticGlassLeft", Vector3(-pane_width * 0.5 - 0.045, gate_height * 0.5, 0), Vector3(pane_width, gate_height - 0.18, 0.11), glass)
		_add_visual_box("BallisticGlassRight", Vector3(pane_width * 0.5 + 0.045, gate_height * 0.5, 0), Vector3(pane_width, gate_height - 0.18, 0.11), glass)
		for x in [-gate_width * 0.5 + 0.055, 0.0, gate_width * 0.5 - 0.055]:
			_add_visual_box("ReinforcedMullion", Vector3(x, gate_height * 0.5, 0), Vector3(0.1, gate_height, 0.16), material)
		for y in [0.08, gate_height - 0.08]:
			_add_visual_box("ReinforcedRail", Vector3(0, y, 0), Vector3(gate_width, 0.14, 0.16), material)
		var marking := Label3D.new()
		marking.name = "BallisticGlassMarking"
		marking.text = "BALLISTIC GLASS"
		marking.position = Vector3(0, 0.35, 0.09)
		marking.font_size = 22
		marking.pixel_size = 0.0024
		marking.modulate = Color(0.65, 0.9, 0.9, 0.8)
		visuals.add_child(marking)
		return
	var usable_width := gate_width - 0.16
	# Cell doors are instanced hundreds of times across the campus. Keep all
	# identical vertical bars in one MultiMesh per gate so the visual remains
	# readable while avoiding one MeshInstance3D/draw submission per slat.
	var slats := MultiMeshInstance3D.new()
	slats.name = "Slats"
	var slat_mesh := BoxMesh.new()
	slat_mesh.size = Vector3(0.09, gate_height, 0.13)
	var slat_instances := MultiMesh.new()
	slat_instances.transform_format = MultiMesh.TRANSFORM_3D
	slat_instances.mesh = slat_mesh
	slat_instances.instance_count = slat_count
	for index in range(slat_count):
		var ratio := float(index) / float(maxi(1, slat_count - 1))
		var x := lerpf(-usable_width * 0.5, usable_width * 0.5, ratio)
		slat_instances.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(x, gate_height * 0.5, 0)))
	slats.multimesh = slat_instances
	slats.material_override = material
	slats.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	visuals.add_child(slats)
	# The three identical rails move as one leaf. Instance them in one draw call;
	# retain the individual slats and the existing leaf collider/animation.
	var rails := MultiMeshInstance3D.new()
	rails.name = "CrossRails"
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(gate_width, 0.12, 0.16)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = rail_mesh
	instances.instance_count = 3
	var heights := [0.18, gate_height * 0.52, gate_height - 0.18]
	for index in heights.size():
		instances.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(0, heights[index], 0)))
	rails.multimesh = instances
	rails.material_override = material
	rails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	visuals.add_child(rails)
	if not panel_label.is_empty():
		for side in [-1.0, 1.0]:
			var label := Label3D.new()
			label.name = "GateLabel"
			label.text = panel_label
			label.position = Vector3(0, gate_height * 0.68, 0.1 * side)
			label.rotation_degrees.y = 180.0 if side < 0.0 else 0.0
			label.font_size = 42
			label.pixel_size = 0.0032
			label.modulate = Color("ffe183")
			label.outline_modulate = Color("181a18")
			label.outline_size = 8
			visuals.add_child(label)


func _add_visual_box(piece_name: String, center: Vector3, size: Vector3, material: Material) -> void:
	var piece := MeshInstance3D.new()
	piece.name = piece_name
	var mesh := BoxMesh.new()
	mesh.size = size
	piece.mesh = mesh
	piece.position = center
	piece.material_override = material
	# Bars and structural rails must cast the familiar prison shadows. Keep
	# optional transparent panes out of the cheap opaque shadow pass.
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if material is StandardMaterial3D and (material as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visuals.add_child(piece)


func _configure_collision() -> void:
	var shape := blocker.shape.duplicate() as BoxShape3D
	shape.size = Vector3(gate_width, gate_height, 0.16)
	blocker.shape = shape
	blocker.position.y = gate_height * 0.5
	var clearance := safety_shape.shape.duplicate() as BoxShape3D
	clearance.size = Vector3(gate_width + 0.3, gate_height, 1.0)
	safety_shape.shape = clearance
	safety_shape.position.y = gate_height * 0.5
	$FrameLeft.position = Vector3(-gate_width * 0.5 - 0.1, gate_height * 0.5, 0)
	$FrameRight.position = Vector3(gate_width * 0.5 + 0.1, gate_height * 0.5, 0)
	$FrameHeader.position = Vector3(0, gate_height + 0.08, 0)
	for post in [$FrameLeft, $FrameRight]:
		var post_mesh := post.mesh.duplicate() as BoxMesh
		post_mesh.size.y = gate_height + 0.2
		post.mesh = post_mesh
	var header_mesh := $FrameHeader.mesh.duplicate() as BoxMesh
	header_mesh.size.x = gate_width + 0.3
	$FrameHeader.mesh = header_mesh


func _apply_pose(opened: bool) -> void:
	var direction := 1.0 if open_direction >= 0.0 else -1.0
	leaf.position = _closed_position + Vector3.RIGHT * (slide_distance * direction if opened else 0.0)


func _animate_to(opened: bool) -> void:
	if _transition and _transition.is_valid():
		_transition.kill()
	_moving = true
	is_open = opened
	blocker.set_deferred("disabled", true)
	var direction := 1.0 if open_direction >= 0.0 else -1.0
	var target := _closed_position + Vector3.RIGHT * (slide_distance * direction if opened else 0.0)
	_transition = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(leaf, "position", target, animation_duration)
	_transition.tween_callback(_finish_transition.bind(opened))


func _finish_transition(opened: bool) -> void:
	_moving = false
	if not opened and _doorway_is_blocked():
		_show_message("GATEWAY BLOCKED")
		_animate_to(true)
		return
	blocker.set_deferred("disabled", opened)


func _doorway_is_blocked() -> bool:
	safety_shape.force_update_transform()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = safety_shape.shape
	query.transform = safety_shape.global_transform
	query.collision_mask = 1 << 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	for result in get_world_3d().direct_space_state.intersect_shape(query, 8):
		var collider := result.get("collider") as Node
		if collider and collider.is_in_group("player"):
			return true
	return false


func _has_required_key() -> bool:
	var has_individual := not required_key_id.is_empty() and AccessManager.has_key(required_key_id)
	var has_master := not master_key_id.is_empty() and AccessManager.has_key(master_key_id)
	return has_individual or has_master


func _is_persistently_unlocked() -> bool:
	return not persistent_access_id.is_empty() and AccessManager.is_access_unlocked(persistent_access_id)


func _show_message(message: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.call("show_message", message)
