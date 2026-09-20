extends FirearmVisualBase
class_name CarbineARVisual

## Low-poly AK-pattern carbine presentation. Firearm simulation remains in the
## shared FirearmComponent; this script owns only model construction and poses.

const BOLT_RECOIL_OFFSET := Vector3(0, 0, 0.09)

var _reload_pivot: Node3D
var _kick_pivot: Node3D
var _bolt_pivot: Node3D
var _magazine: Node3D
var _muzzle_flash: MeshInstance3D
var _right_hand: Node3D
var _left_hand: Node3D

var _kick_tween: Tween
var _bolt_tween: Tween
var _flash_tween: Tween
var _reload_tween: Tween

var _magazine_home_position := Vector3.ZERO
var _magazine_home_rotation := Vector3.ZERO
var _left_hand_home_position := Vector3(-0.055, 0.015, -0.68)
var _left_hand_home_rotation := Vector3(8, 18, -26)
var _reload_playing := false


func _ready() -> void:
	_build_visual()


func play_fire_feedback(rounds_remaining: int) -> void:
	if not first_person or _kick_pivot == null:
		return
	_stop_tween(_kick_tween)
	_stop_tween(_bolt_tween)
	_stop_tween(_flash_tween)
	_kick_pivot.position = Vector3.ZERO
	_kick_pivot.rotation_degrees = Vector3.ZERO
	_muzzle_flash.visible = true
	_muzzle_flash.scale = Vector3.ONE * randf_range(0.9, 1.25) * get_muzzle_flash_multiplier()

	_kick_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_kick_tween.tween_property(_kick_pivot, "position", Vector3(randf_range(-0.002, 0.002), randf_range(0.009, 0.016), randf_range(0.05, 0.065)), 0.022)
	_kick_tween.parallel().tween_property(_kick_pivot, "rotation_degrees", Vector3(randf_range(2.4, 3.6), randf_range(-0.35, 0.35), randf_range(-0.25, 0.25)), 0.022)
	_kick_tween.tween_property(_kick_pivot, "position", Vector3.ZERO, 0.045)
	_kick_tween.parallel().tween_property(_kick_pivot, "rotation_degrees", Vector3.ZERO, 0.045)

	_bolt_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bolt_tween.tween_property(_bolt_pivot, "position", BOLT_RECOIL_OFFSET, 0.014)
	if rounds_remaining > 0:
		_bolt_tween.tween_property(_bolt_pivot, "position", Vector3.ZERO, 0.025)

	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.025)
	_flash_tween.tween_callback(func() -> void: _muzzle_flash.visible = false)


func set_slide_locked(locked: bool) -> void:
	if _bolt_pivot == null:
		return
	_stop_tween(_bolt_tween)
	_bolt_pivot.position = BOLT_RECOIL_OFFSET if locked else Vector3.ZERO


func play_reload(duration: float, was_empty: bool) -> void:
	if not first_person or _reload_pivot == null or duration <= 0.0:
		return
	cancel_weapon_animation()
	set_slide_locked(was_empty)
	_reload_playing = true
	var scale_time := duration / 1.5
	var magazine_out := _magazine_home_position + Vector3(0.02, -0.54, 0.10)

	_reload_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Rotate the longer receiver clear of view while the support hand reaches the
	# curved magazine. All pieces remain attached to their proper pivots.
	_reload_tween.tween_property(_reload_pivot, "position", Vector3(0.08, -0.15, 0.08), 0.22 * scale_time)
	_reload_tween.parallel().tween_property(_reload_pivot, "rotation_degrees", Vector3(10, -4, -20), 0.22 * scale_time)
	_reload_tween.parallel().tween_property(_left_hand, "position", Vector3(-0.01, -0.22, -0.12), 0.22 * scale_time)
	_reload_tween.parallel().tween_property(_left_hand, "rotation_degrees", Vector3(18, 6, -12), 0.22 * scale_time)

	_reload_tween.tween_property(_magazine, "position", magazine_out, 0.26 * scale_time)
	_reload_tween.parallel().tween_property(_magazine, "rotation_degrees", _magazine_home_rotation + Vector3(18, 0, 8), 0.26 * scale_time)
	_reload_tween.parallel().tween_property(_left_hand, "position", Vector3(-0.02, -0.56, 0.02), 0.26 * scale_time)
	_reload_tween.tween_callback(func() -> void: _magazine.visible = false)
	_reload_tween.tween_interval(0.10 * scale_time)
	_reload_tween.tween_callback(func() -> void:
		_magazine.position = magazine_out
		_magazine.rotation_degrees = _magazine_home_rotation
		_magazine.visible = true
	)
	_reload_tween.tween_property(_magazine, "position", _magazine_home_position, 0.28 * scale_time)
	_reload_tween.parallel().tween_property(_left_hand, "position", Vector3(-0.02, -0.25, -0.12), 0.28 * scale_time)
	_reload_tween.tween_interval(0.08 * scale_time)

	if was_empty:
		_reload_tween.tween_property(_left_hand, "position", Vector3(0.12, 0.12, -0.05), 0.10 * scale_time)
		_reload_tween.parallel().tween_property(_left_hand, "rotation_degrees", Vector3(5, -30, 32), 0.10 * scale_time)
		_reload_tween.tween_callback(func() -> void: set_slide_locked(false))
		_reload_tween.tween_interval(0.04 * scale_time)

	_reload_tween.tween_property(_reload_pivot, "position", Vector3.ZERO, 0.40 * scale_time)
	_reload_tween.parallel().tween_property(_reload_pivot, "rotation_degrees", Vector3.ZERO, 0.40 * scale_time)
	_reload_tween.parallel().tween_property(_left_hand, "position", _left_hand_home_position, 0.40 * scale_time)
	_reload_tween.parallel().tween_property(_left_hand, "rotation_degrees", _left_hand_home_rotation, 0.40 * scale_time)
	_reload_tween.tween_callback(func() -> void: _reload_playing = false)


func finish_reload(rounds_loaded: int) -> void:
	_stop_tween(_reload_tween)
	_reload_playing = false
	_reset_pose()
	set_slide_locked(rounds_loaded <= 0)


func cancel_weapon_animation() -> void:
	_stop_tween(_reload_tween)
	_stop_tween(_kick_tween)
	_stop_tween(_flash_tween)
	_reload_playing = false
	_reset_pose()
	if _muzzle_flash:
		_muzzle_flash.visible = false


func is_slide_locked() -> bool:
	return _bolt_pivot != null and _bolt_pivot.position.distance_to(BOLT_RECOIL_OFFSET) < 0.001


func is_reload_playing() -> bool:
	return _reload_playing


func is_magazine_visible() -> bool:
	return _magazine != null and _magazine.visible


func is_muzzle_flash_visible() -> bool:
	return _muzzle_flash != null and _muzzle_flash.visible


func get_magazine_offset() -> float:
	return _magazine.position.distance_to(_magazine_home_position) if _magazine else 0.0


func _stop_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()


func _reset_pose() -> void:
	if _reload_pivot:
		_reload_pivot.position = Vector3.ZERO
		_reload_pivot.rotation_degrees = Vector3.ZERO
	if _kick_pivot:
		_kick_pivot.position = Vector3.ZERO
		_kick_pivot.rotation_degrees = Vector3.ZERO
	if _magazine:
		_magazine.visible = true
		_magazine.position = _magazine_home_position
		_magazine.rotation_degrees = _magazine_home_rotation
	if _left_hand:
		_left_hand.position = _left_hand_home_position
		_left_hand.rotation_degrees = _left_hand_home_rotation


func _build_visual() -> void:
	_reload_pivot = Node3D.new()
	_reload_pivot.name = "ReloadPivot"
	add_child(_reload_pivot)
	_kick_pivot = Node3D.new()
	_kick_pivot.name = "KickPivot"
	_reload_pivot.add_child(_kick_pivot)
	var model := Node3D.new()
	model.name = "WeaponModel"
	_kick_pivot.add_child(model)
	_bolt_pivot = Node3D.new()
	_bolt_pivot.name = "BoltPivot"
	model.add_child(_bolt_pivot)

	var blued_steel := _gunmetal_material(Color("202629"), 0.35)
	var receiver_steel := _gunmetal_material(Color("30383b"), 0.42)
	var worn_edge := _gunmetal_material(Color("596164"), 0.28)
	var deep_black := _material(Color("121617"), 0.82)
	var walnut := _ak_wood_material()
	var walnut_highlight := _ak_wood_material(true)
	var sight_mark := _material(Color("d7ddd7"), 0.42)
	var brass := _material(Color("aa8537"), 0.34)

	# Stamped receiver and removable dust cover establish the AK-pattern center.
	_add_box("Receiver", Vector3(0, 0.08, -0.10), Vector3(0.22, 0.22, 0.72), receiver_steel, Vector3.ZERO, model)
	_add_box("DustCover", Vector3(0, 0.205, -0.055), Vector3(0.19, 0.055, 0.60), blued_steel, Vector3.ZERO, model)
	_add_box("ReceiverLower", Vector3(0, -0.055, -0.12), Vector3(0.205, 0.055, 0.60), deep_black, Vector3.ZERO, model)
	_add_box("TrunnionBlock", Vector3(0, 0.09, -0.48), Vector3(0.225, 0.23, 0.18), blued_steel, Vector3.ZERO, model)
	_add_box("EjectionPort", Vector3(0.112, 0.13, -0.05), Vector3(0.012, 0.075, 0.22), deep_black, Vector3.ZERO, model)
	_add_box("Chamber", Vector3(0.098, 0.13, -0.05), Vector3(0.018, 0.045, 0.12), brass, Vector3.ZERO, model)
	_add_box("SafetyLever", Vector3(0.122, 0.055, 0.02), Vector3(0.014, 0.028, 0.29), worn_edge, Vector3(-5, 0, 0), model)

	# Charging handle moves with the bolt but remains a distinct readable cue.
	_add_box("BoltCarrier", Vector3(0.045, 0.125, -0.04), Vector3(0.105, 0.07, 0.28), worn_edge, Vector3.ZERO, _bolt_pivot)
	_add_cylinder("ChargingHandle", Vector3(0.16, 0.125, -0.02), 0.018, 0.105, blued_steel, Vector3(0, 0, 90), _bolt_pivot)
	_add_cylinder("ChargingHandleKnob", Vector3(0.215, 0.125, -0.02), 0.026, 0.035, deep_black, Vector3(0, 0, 90), _bolt_pivot)

	# Long gas system, separate walnut upper/lower handguards and barrel.
	_add_cylinder("Barrel", Vector3(0, 0.08, -0.96), 0.032, 0.92, blued_steel, Vector3(90, 0, 0), model)
	_add_cylinder("GasTube", Vector3(0, 0.19, -0.70), 0.035, 0.62, blued_steel, Vector3(90, 0, 0), model)
	_add_box("GasBlock", Vector3(0, 0.145, -0.93), Vector3(0.12, 0.16, 0.12), blued_steel, Vector3.ZERO, model)
	_add_box("UpperHandguard", Vector3(0, 0.175, -0.64), Vector3(0.18, 0.12, 0.46), walnut, Vector3.ZERO, model)
	_add_box("LowerHandguard", Vector3(0, 0.015, -0.66), Vector3(0.25, 0.16, 0.50), walnut, Vector3(-2, 0, 0), model)

	_add_cylinder("Muzzle", Vector3(0, 0.08, -1.45), 0.048, 0.12, worn_edge, Vector3(90, 0, 0), model)
	_add_cylinder("MuzzleBore", Vector3(0, 0.08, -1.515), 0.029, 0.015, deep_black, Vector3(90, 0, 0), model)

	# Rugged iron sights: tangent-style rear block and hooded front post.
	_add_box("RearSightBlock", Vector3(0, 0.25, -0.43), Vector3(0.15, 0.10, 0.16), blued_steel, Vector3.ZERO, model)
	_add_box("RearSightLeaf", Vector3(0, 0.302, -0.38), Vector3(0.07, 0.025, 0.25), worn_edge, Vector3(-3, 0, 0), model)
	_add_box("RearSightNotchLeft", Vector3(-0.034, 0.326, -0.28), Vector3(0.025, 0.055, 0.035), deep_black, Vector3.ZERO, model)
	_add_box("RearSightNotchRight", Vector3(0.034, 0.326, -0.28), Vector3(0.025, 0.055, 0.035), deep_black, Vector3.ZERO, model)
	_add_box("FrontSightBase", Vector3(0, 0.17, -1.23), Vector3(0.13, 0.18, 0.12), blued_steel, Vector3.ZERO, model)
	_add_box("FrontSightLeft", Vector3(-0.052, 0.285, -1.23), Vector3(0.022, 0.16, 0.055), blued_steel, Vector3.ZERO, model)
	_add_box("FrontSightRight", Vector3(0.052, 0.285, -1.23), Vector3(0.022, 0.16, 0.055), blued_steel, Vector3.ZERO, model)
	_add_box("FrontSightPost", Vector3(0, 0.326, -1.23), Vector3(0.014, 0.11, 0.035), sight_mark, Vector3.ZERO, model)

	# Open trigger guard, trigger and wood pistol grip.
	_add_box("TriggerGuardLeft", Vector3(-0.085, -0.115, -0.18), Vector3(0.022, 0.028, 0.24), blued_steel, Vector3(-8, 0, 0), model)
	_add_box("TriggerGuardRight", Vector3(0.085, -0.115, -0.18), Vector3(0.022, 0.028, 0.24), blued_steel, Vector3(-8, 0, 0), model)
	_add_box("TriggerGuardBow", Vector3(0, -0.17, -0.30), Vector3(0.18, 0.035, 0.04), blued_steel, Vector3(-10, 0, 0), model)
	_add_box("Trigger", Vector3(0, -0.09, -0.17), Vector3(0.028, 0.11, 0.025), worn_edge, Vector3(-22, 0, 0), model)
	_add_box("PistolGrip", Vector3(0, -0.27, 0.10), Vector3(0.15, 0.34, 0.18), walnut, Vector3(16, 0, 0), model)

	# Slightly descending fixed wood stock, kept practical rather than oversized.
	_add_box("StockTang", Vector3(0, 0.07, 0.34), Vector3(0.15, 0.13, 0.24), blued_steel, Vector3.ZERO, model)
	_add_box("WoodStock", Vector3(0, -0.005, 0.68), Vector3(0.20, 0.25, 0.58), walnut, Vector3(-8, 0, 0), model)
	_add_box("StockButtPlate", Vector3(0, -0.045, 0.99), Vector3(0.22, 0.30, 0.045), worn_edge, Vector3(-8, 0, 0), model)

	# Curved 30-round magazine: four joined, progressively angled segments form
	# a readable AK-style banana profile while remaining inexpensive geometry.
	_magazine = Node3D.new()
	_magazine.name = "Magazine"
	_magazine.position = Vector3(0, -0.18, -0.13)
	_magazine.rotation_degrees = Vector3(8, 0, 0)
	_kick_pivot.add_child(_magazine)
	_add_box("MagazineFeed", Vector3(0, 0.02, 0), Vector3(0.15, 0.13, 0.18), blued_steel, Vector3.ZERO, _magazine)
	_add_box("CurvedMagazineSegment1", Vector3(0, -0.10, -0.015), Vector3(0.16, 0.16, 0.19), deep_black, Vector3(5, 0, 0), _magazine)
	_add_box("CurvedMagazineSegment2", Vector3(0, -0.235, -0.055), Vector3(0.155, 0.16, 0.18), deep_black, Vector3(11, 0, 0), _magazine)
	_add_box("CurvedMagazineSegment3", Vector3(0, -0.36, -0.12), Vector3(0.145, 0.15, 0.17), deep_black, Vector3(18, 0, 0), _magazine)
	_add_box("MagazineFloorPlate", Vector3(0, -0.445, -0.18), Vector3(0.17, 0.035, 0.19), worn_edge, Vector3(22, 0, 0), _magazine)
	_magazine_home_position = _magazine.position
	_magazine_home_rotation = _magazine.rotation_degrees

	var flash_material := _material(Color("fff0a0"), 0.1, true, 3.4)
	_muzzle_flash = _add_cylinder("MuzzleFlash", Vector3(0, 0.08, -1.62), 0.105, 0.17, flash_material, Vector3(90, 0, 0), model)
	_muzzle_flash.visible = false

	_add_anchor(model, "MuzzlePoint", Vector3(0, 0.08, -1.53))
	_add_anchor(model, "MuzzleFlashPoint", Vector3(0, 0.08, -1.62))
	_add_anchor(model, "MagazineSocket", _magazine_home_position)
	_add_anchor(model, "SuppressorAttachmentPoint", Vector3(0, 0.08, -1.55))
	_add_anchor(model, "ADSAnchor", Vector3(0, 0.326, -0.22))
	_add_anchor(model, "RearSightAimPoint", Vector3(0, 0.326, -0.28))
	_add_anchor(model, "FrontSightAimPoint", Vector3(0, 0.326, -1.23))
	_add_anchor(model, "HipAnchor", Vector3.ZERO)
	_add_anchor(model, "InteractionAnchor", Vector3(0, 0.10, 0.05))

	if first_person:
		_build_hands()


func _build_hands() -> void:
	var skin := _material(FirstPersonBodyStyle.SKIN_COLOR, FirstPersonBodyStyle.SKIN_ROUGHNESS)
	var sleeve := _material(FirstPersonBodyStyle.SLEEVE_COLOR, FirstPersonBodyStyle.SLEEVE_ROUGHNESS)
	_right_hand = Node3D.new()
	_right_hand.name = "RightHand"
	_right_hand.position = Vector3(0.02, -0.29, 0.11)
	_right_hand.rotation_degrees = Vector3(15, 0, 0)
	_kick_pivot.add_child(_right_hand)
	_add_capsule("RightHandPalm", Vector3.ZERO, 0.09, 0.29, skin, Vector3.ZERO, _right_hand)
	_add_tapered_cylinder("RightSleeve", Vector3(0.04, -0.30, 0.35), 0.11, 0.17, 0.68, sleeve, Vector3(-66, 0, 0), _right_hand)
	_add_cylinder("RightCuff", Vector3(0.02, -0.14, 0.09), 0.12, 0.08, sleeve, Vector3(-66, 0, 0), _right_hand)

	_left_hand = Node3D.new()
	_left_hand.name = "LeftHand"
	_left_hand.position = _left_hand_home_position
	_left_hand.rotation_degrees = _left_hand_home_rotation
	_kick_pivot.add_child(_left_hand)
	_add_capsule("LeftHandPalm", Vector3.ZERO, 0.09, 0.28, skin, Vector3(0, 0, 72), _left_hand)
	_add_tapered_cylinder("LeftSleeve", Vector3(-0.17, -0.27, 0.30), 0.11, 0.16, 0.68, sleeve, Vector3(-54, -22, 0), _left_hand)
	_add_cylinder("LeftCuff", Vector3(-0.08, -0.12, 0.07), 0.12, 0.08, sleeve, Vector3(-54, -22, 0), _left_hand)


func _add_anchor(parent: Node3D, anchor_name: String, anchor_position: Vector3) -> Marker3D:
	var anchor := Marker3D.new()
	anchor.name = anchor_name
	anchor.position = anchor_position
	parent.add_child(anchor)
	return anchor
