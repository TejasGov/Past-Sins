extends FirearmVisualBase
class_name SniperRifleVisual

## Low-poly modern precision-rifle presentation. Simulation, damage and ammo
## remain in FirearmComponent; this script owns only geometry and feedback.

const BOLT_RECOIL_OFFSET := Vector3(0, 0, 0.18)

var _reload_pivot: Node3D
var _kick_pivot: Node3D
var _bolt_pivot: Node3D
var _magazine: Node3D
var _loose_round: Node3D
var _muzzle_flash: MeshInstance3D
var _left_hand: Node3D
var _right_hand: Node3D
var _model: Node3D
var _reload_tween: Tween
var _kick_tween: Tween
var _flash_tween: Tween
var _magazine_home := Vector3.ZERO
var _left_hand_home := Vector3(-0.09, -0.01, -0.86)
var _reload_playing := false
var _individual_load_playing := false


func _ready() -> void:
	_build_visual()


func play_fire_feedback(rounds_remaining: int) -> void:
	if not first_person:
		return
	_stop_tween(_kick_tween)
	_stop_tween(_flash_tween)
	_kick_pivot.position = Vector3.ZERO
	_kick_pivot.rotation_degrees = Vector3.ZERO
	_bolt_pivot.position = BOLT_RECOIL_OFFSET
	_muzzle_flash.visible = true
	_muzzle_flash.scale = Vector3.ONE * randf_range(0.9, 1.15) * get_muzzle_flash_multiplier()
	_kick_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_kick_tween.tween_property(_kick_pivot, "position", Vector3(0, 0.025, 0.13), 0.055)
	_kick_tween.parallel().tween_property(_kick_pivot, "rotation_degrees", Vector3(6.8, 0.35, 0.2), 0.055)
	_kick_tween.tween_property(_kick_pivot, "position", Vector3.ZERO, 0.18)
	_kick_tween.parallel().tween_property(_kick_pivot, "rotation_degrees", Vector3.ZERO, 0.18)
	_kick_tween.parallel().tween_property(_bolt_pivot, "position", Vector3.ZERO if rounds_remaining > 0 else BOLT_RECOIL_OFFSET, 0.16)
	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.045)
	_flash_tween.tween_callback(func() -> void: _muzzle_flash.visible = false)


func play_reload(duration: float, _was_empty: bool) -> void:
	if not first_person or duration <= 0.0:
		return
	cancel_weapon_animation()
	_reload_playing = true
	var s := duration / 2.5
	_reload_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_reload_tween.tween_property(_reload_pivot, "position", Vector3(0.12, -0.16, 0.15), 0.38 * s)
	_reload_tween.parallel().tween_property(_reload_pivot, "rotation_degrees", Vector3(8, -7, -18), 0.38 * s)
	_reload_tween.parallel().tween_property(_left_hand, "position", Vector3(-0.02, -0.28, -0.12), 0.38 * s)
	_reload_tween.tween_property(_magazine, "position", _magazine_home + Vector3(0, -0.52, 0.08), 0.48 * s)
	_reload_tween.parallel().tween_property(_left_hand, "position", Vector3(0, -0.52, 0.0), 0.48 * s)
	_reload_tween.tween_callback(func() -> void: _magazine.visible = false)
	_reload_tween.tween_interval(0.24 * s)
	_reload_tween.tween_callback(func() -> void: _magazine.visible = true)
	_reload_tween.tween_property(_magazine, "position", _magazine_home, 0.50 * s)
	_reload_tween.parallel().tween_property(_left_hand, "position", Vector3(-0.03, -0.20, -0.28), 0.50 * s)
	_reload_tween.tween_property(_bolt_pivot, "position", BOLT_RECOIL_OFFSET, 0.20 * s)
	_reload_tween.tween_property(_bolt_pivot, "position", Vector3.ZERO, 0.20 * s)
	_reload_tween.tween_property(_reload_pivot, "position", Vector3.ZERO, 0.35 * s)
	_reload_tween.parallel().tween_property(_reload_pivot, "rotation_degrees", Vector3.ZERO, 0.35 * s)
	_reload_tween.parallel().tween_property(_left_hand, "position", _left_hand_home, 0.35 * s)
	_reload_tween.tween_callback(func() -> void: _reload_playing = false)


func play_individual_round_load(duration: float) -> void:
	if not first_person or duration <= 0.0:
		return
	cancel_weapon_animation()
	_individual_load_playing = true
	_loose_round.visible = true
	var s := duration / 1.5
	_reload_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_reload_tween.tween_property(_reload_pivot, "position", Vector3(0.08, -0.08, 0.12), 0.25 * s)
	_reload_tween.parallel().tween_property(_reload_pivot, "rotation_degrees", Vector3(4, -12, -10), 0.25 * s)
	_reload_tween.tween_property(_loose_round, "position", Vector3(0.16, 0.10, -0.02), 0.55 * s)
	_reload_tween.parallel().tween_property(_left_hand, "position", Vector3(0.12, 0.06, -0.02), 0.55 * s)
	_reload_tween.tween_callback(func() -> void: _loose_round.visible = false)
	_reload_tween.tween_interval(0.18 * s)
	_reload_tween.tween_property(_reload_pivot, "position", Vector3.ZERO, 0.45 * s)
	_reload_tween.parallel().tween_property(_reload_pivot, "rotation_degrees", Vector3.ZERO, 0.45 * s)
	_reload_tween.parallel().tween_property(_left_hand, "position", _left_hand_home, 0.45 * s)
	_reload_tween.tween_callback(func() -> void: _individual_load_playing = false)


func finish_reload(rounds_loaded: int) -> void:
	_stop_tween(_reload_tween)
	_reload_playing = false
	_individual_load_playing = false
	_reset_pose()
	set_slide_locked(rounds_loaded <= 0)


func cancel_weapon_animation() -> void:
	_stop_tween(_reload_tween)
	_stop_tween(_kick_tween)
	_stop_tween(_flash_tween)
	_reload_playing = false
	_individual_load_playing = false
	_reset_pose()


func set_slide_locked(locked: bool) -> void:
	if _bolt_pivot:
		_bolt_pivot.position = BOLT_RECOIL_OFFSET if locked else Vector3.ZERO


func set_ads_blend(blend: float) -> void:
	# At full magnification the physical scope housing must not obscure the
	# optical image. The overlay remains centered while the rifle fades out at
	# the very end of the smooth shoulder transition.
	var show_model := blend < 0.96
	if _model: _model.visible = show_model
	if _right_hand: _right_hand.visible = show_model
	if _left_hand: _left_hand.visible = show_model


func is_reload_playing() -> bool: return _reload_playing
func is_individual_round_load_playing() -> bool: return _individual_load_playing
func is_magazine_visible() -> bool: return _magazine != null and _magazine.visible
func is_muzzle_flash_visible() -> bool: return _muzzle_flash != null and _muzzle_flash.visible
func get_magazine_offset() -> float: return _magazine.position.distance_to(_magazine_home) if _magazine else 0.0


func _reset_pose() -> void:
	if _reload_pivot:
		_reload_pivot.position = Vector3.ZERO
		_reload_pivot.rotation_degrees = Vector3.ZERO
	if _kick_pivot:
		_kick_pivot.position = Vector3.ZERO
		_kick_pivot.rotation_degrees = Vector3.ZERO
	if _bolt_pivot: _bolt_pivot.position = Vector3.ZERO
	if _magazine:
		_magazine.position = _magazine_home
		_magazine.visible = true
	if _loose_round:
		_loose_round.position = Vector3(0.20, -0.30, 0.18)
		_loose_round.visible = false
	if _left_hand: _left_hand.position = _left_hand_home
	if _muzzle_flash: _muzzle_flash.visible = false


func _stop_tween(tween: Tween) -> void:
	if tween and tween.is_valid(): tween.kill()


func _build_visual() -> void:
	_reload_pivot = Node3D.new(); _reload_pivot.name = "ReloadPivot"; add_child(_reload_pivot)
	_kick_pivot = Node3D.new(); _kick_pivot.name = "KickPivot"; _reload_pivot.add_child(_kick_pivot)
	_model = Node3D.new(); _model.name = "WeaponModel"; _kick_pivot.add_child(_model)
	var model := _model
	_bolt_pivot = Node3D.new(); _bolt_pivot.name = "BoltPivot"; model.add_child(_bolt_pivot)

	var metal := _gunmetal_material(Color("20272a"), 0.34)
	var edge := _gunmetal_material(Color("566166"), 0.26)
	var polymer := _material(Color("151b1d"), 0.8)
	var rubber := _material(Color("0b0f10"), 0.95)
	var glass := _material(Color("16343e"), 0.16, true, 0.24)
	var mark := _material(Color("ccd7d2"), 0.45)
	var brass := _material(Color("b18b3d"), 0.3)

	_add_box("Receiver", Vector3(0, 0.08, -0.12), Vector3(0.25, 0.25, 0.82), metal, Vector3.ZERO, model)
	_add_box("ReceiverRail", Vector3(0, 0.245, -0.20), Vector3(0.20, 0.07, 0.78), edge, Vector3.ZERO, model)
	_add_box("EjectionPort", Vector3(0.13, 0.12, -0.20), Vector3(0.018, 0.09, 0.28), rubber, Vector3.ZERO, model)
	_add_box("BoltBody", Vector3(0.055, 0.15, -0.12), Vector3(0.13, 0.08, 0.34), edge, Vector3.ZERO, _bolt_pivot)
	_add_cylinder("BoltHandle", Vector3(0.20, 0.12, 0.0), 0.022, 0.18, metal, Vector3(0, 0, 90), _bolt_pivot)
	_add_capsule("BoltKnob", Vector3(0.30, 0.12, 0.0), 0.038, 0.09, rubber, Vector3(0, 0, 90), _bolt_pivot)

	_add_box("ForeEnd", Vector3(0, 0.03, -0.92), Vector3(0.30, 0.20, 0.96), polymer, Vector3.ZERO, model)
	_add_box("ForeEndRail", Vector3(0, 0.16, -0.91), Vector3(0.20, 0.055, 0.92), edge, Vector3.ZERO, model)
	_add_cylinder("PrecisionBarrel", Vector3(0, 0.10, -1.77), 0.035, 1.35, metal, Vector3(90, 0, 0), model)
	_add_cylinder("MuzzleBrake", Vector3(0, 0.10, -2.49), 0.062, 0.17, edge, Vector3(90, 0, 0), model)
	_add_cylinder("MuzzleBore", Vector3(0, 0.10, -2.585), 0.025, 0.025, rubber, Vector3(90, 0, 0), model)

	_add_box("StockBeam", Vector3(0, 0.04, 0.56), Vector3(0.17, 0.16, 0.72), polymer, Vector3.ZERO, model)
	_add_box("AdjustableCheekRest", Vector3(0, 0.23, 0.58), Vector3(0.20, 0.11, 0.48), polymer, Vector3(-3, 0, 0), model)
	_add_box("ButtStock", Vector3(0, -0.01, 1.02), Vector3(0.25, 0.36, 0.24), polymer, Vector3.ZERO, model)
	_add_box("RubberButtPad", Vector3(0, -0.01, 1.16), Vector3(0.27, 0.38, 0.055), rubber, Vector3.ZERO, model)
	_add_box("PistolGrip", Vector3(0, -0.25, 0.19), Vector3(0.16, 0.37, 0.18), polymer, Vector3(14, 0, 0), model)
	_add_box("TriggerGuard", Vector3(0, -0.11, -0.05), Vector3(0.18, 0.05, 0.24), metal, Vector3.ZERO, model)
	_add_box("Trigger", Vector3(0, -0.10, -0.08), Vector3(0.026, 0.12, 0.025), edge, Vector3(-18, 0, 0), model)

	_magazine = Node3D.new(); _magazine.name = "DetachableBoxMagazine"; _magazine.position = Vector3(0, -0.20, -0.20); _kick_pivot.add_child(_magazine)
	_add_box("MagazineFeed", Vector3.ZERO, Vector3(0.17, 0.13, 0.20), metal, Vector3.ZERO, _magazine)
	_add_box("FiveRoundMagazine", Vector3(0, -0.15, 0.015), Vector3(0.18, 0.25, 0.23), polymer, Vector3(2, 0, 0), _magazine)
	_add_box("MagazineFloorPlate", Vector3(0, -0.29, 0.025), Vector3(0.20, 0.035, 0.25), edge, Vector3.ZERO, _magazine)
	_magazine_home = _magazine.position

	# Full optic silhouette: tube, objective/eyepiece, mounting rings and turrets.
	_add_cylinder("ScopeBody", Vector3(0, 0.48, -0.20), 0.085, 0.86, polymer, Vector3(90, 0, 0), model)
	_add_cylinder("ScopeObjectiveHousing", Vector3(0, 0.48, -0.68), 0.15, 0.20, polymer, Vector3(90, 0, 0), model)
	_add_cylinder("ScopeObjectiveLens", Vector3(0, 0.48, -0.79), 0.125, 0.018, glass, Vector3(90, 0, 0), model)
	_add_cylinder("ScopeEyepiece", Vector3(0, 0.48, 0.29), 0.12, 0.24, polymer, Vector3(90, 0, 0), model)
	_add_cylinder("ScopeRearGlass", Vector3(0, 0.48, 0.42), 0.095, 0.018, glass, Vector3(90, 0, 0), model)
	_add_cylinder("ScopeRingFront", Vector3(0, 0.48, -0.43), 0.105, 0.075, edge, Vector3(90, 0, 0), model)
	_add_cylinder("ScopeRingRear", Vector3(0, 0.48, 0.08), 0.105, 0.075, edge, Vector3(90, 0, 0), model)
	_add_box("ScopeMountFront", Vector3(0, 0.34, -0.43), Vector3(0.16, 0.17, 0.10), metal, Vector3.ZERO, model)
	_add_box("ScopeMountRear", Vector3(0, 0.34, 0.08), Vector3(0.16, 0.17, 0.10), metal, Vector3.ZERO, model)
	_add_cylinder("ElevationTurret", Vector3(0, 0.61, -0.13), 0.05, 0.12, edge, Vector3.ZERO, model)
	_add_cylinder("WindageTurret", Vector3(0.12, 0.48, -0.13), 0.045, 0.12, edge, Vector3(0, 0, 90), model)

	# Folded bipod stays tight against the fore-end until future deployment work.
	_add_cylinder("FoldedBipodLeft", Vector3(-0.13, -0.10, -1.13), 0.018, 0.72, edge, Vector3(88, -8, 0), model)
	_add_cylinder("FoldedBipodRight", Vector3(0.13, -0.10, -1.13), 0.018, 0.72, edge, Vector3(88, 8, 0), model)
	_add_box("BipodHinge", Vector3(0, -0.04, -0.84), Vector3(0.30, 0.08, 0.10), metal, Vector3.ZERO, model)

	_loose_round = Node3D.new(); _loose_round.name = "LooseRound"; _loose_round.position = Vector3(0.20, -0.30, 0.18); _kick_pivot.add_child(_loose_round)
	_add_cylinder("RoundCase", Vector3.ZERO, 0.018, 0.12, brass, Vector3(90, 0, 0), _loose_round)
	_add_tapered_cylinder("RoundProjectile", Vector3(0, 0, -0.075), 0.0, 0.017, 0.055, mark, Vector3(90, 0, 0), _loose_round)
	_loose_round.visible = false

	var flash := _material(Color("fff1ad"), 0.08, true, 3.6)
	_muzzle_flash = _add_cylinder("MuzzleFlash", Vector3(0, 0.10, -2.72), 0.11, 0.22, flash, Vector3(90, 0, 0), model)
	_muzzle_flash.visible = false

	_add_anchor(model, "MuzzlePoint", Vector3(0, 0.10, -2.60))
	_add_anchor(model, "MuzzleFlashPoint", Vector3(0, 0.10, -2.72))
	_add_anchor(model, "MagazineSocket", _magazine_home)
	_add_anchor(model, "SuppressorAttachmentPoint", Vector3(0, 0.10, -2.62))
	_add_anchor(model, "ADSAnchor", Vector3(0, 0.48, 0.25))
	_add_anchor(model, "RearSightAimPoint", Vector3(0, 0.48, 0.24))
	_add_anchor(model, "FrontSightAimPoint", Vector3(0, 0.48, -0.72))
	_add_anchor(model, "HipAnchor", Vector3.ZERO)
	_add_anchor(model, "InteractionAnchor", Vector3(0, 0.18, -0.20))
	if first_person: _build_hands()


func _build_hands() -> void:
	var skin := _material(FirstPersonBodyStyle.SKIN_COLOR, FirstPersonBodyStyle.SKIN_ROUGHNESS)
	var sleeve := _material(FirstPersonBodyStyle.SLEEVE_COLOR, FirstPersonBodyStyle.SLEEVE_ROUGHNESS)
	_right_hand = Node3D.new(); _right_hand.name = "RightHand"; _right_hand.position = Vector3(0.03, -0.29, 0.21); _kick_pivot.add_child(_right_hand)
	_add_capsule("RightHandPalm", Vector3.ZERO, 0.09, 0.29, skin, Vector3.ZERO, _right_hand)
	_add_tapered_cylinder("RightSleeve", Vector3(0.05, -0.30, 0.36), 0.11, 0.17, 0.68, sleeve, Vector3(-66, 0, 0), _right_hand)
	_left_hand = Node3D.new(); _left_hand.name = "LeftHand"; _left_hand.position = _left_hand_home; _kick_pivot.add_child(_left_hand)
	_add_capsule("LeftHandPalm", Vector3.ZERO, 0.09, 0.28, skin, Vector3(0, 0, 72), _left_hand)
	_add_tapered_cylinder("LeftSleeve", Vector3(-0.17, -0.27, 0.30), 0.11, 0.16, 0.68, sleeve, Vector3(-54, -22, 0), _left_hand)


func _add_anchor(parent: Node3D, anchor_name: String, anchor_position: Vector3) -> Marker3D:
	var anchor := Marker3D.new(); anchor.name = anchor_name; anchor.position = anchor_position; parent.add_child(anchor); return anchor
