extends FirearmVisualBase
class_name SMGVisual

## Tactical security submachine gun visual presentation. Shared by held (FP)
## and world pickup representations with zero collision or firearm simulation logic.
const BOLT_RECOIL_OFFSET := Vector3(0, 0, 0.08)

var _reload_pivot: Node3D
var _kick_pivot: Node3D
var _bolt_pivot: Node3D
var _magazine: Node3D
var _muzzle_flash: MeshInstance3D

var _kick_tween: Tween
var _bolt_tween: Tween
var _flash_tween: Tween
var _reload_tween: Tween

var _magazine_home_position := Vector3.ZERO
var _magazine_home_rotation := Vector3.ZERO
var _left_hand: Node3D
var _left_hand_home_position := Vector3(-0.06, 0.02, -0.36)
var _left_hand_home_rotation := Vector3(10, 22, -28)
var _reload_playing := false
var _bolt_locked := false

# Sockets and anchor references
var muzzle_point: Marker3D
var magazine_socket: Marker3D
var suppressor_point: Marker3D
var ads_anchor: Marker3D
var hip_anchor: Marker3D
var interaction_anchor: Marker3D


func _ready() -> void:
	_build_visual()


func play_fire_feedback(rounds_remaining: int) -> void:
	if not first_person or _kick_pivot == null:
		return
	if _kick_tween and _kick_tween.is_valid():
		_kick_tween.kill()
	if _bolt_tween and _bolt_tween.is_valid():
		_bolt_tween.kill()
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	_kick_pivot.position = Vector3.ZERO
	_kick_pivot.rotation_degrees = Vector3.ZERO
	_muzzle_flash.visible = true
	_muzzle_flash.scale = Vector3.ONE * randf_range(0.85, 1.25) * get_muzzle_flash_multiplier()

	_kick_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_kick_tween.tween_property(_kick_pivot, "position", Vector3(randf_range(-0.003, 0.003), randf_range(0.006, 0.012), randf_range(0.035, 0.045)), 0.02)
	_kick_tween.parallel().tween_property(_kick_pivot, "rotation_degrees", Vector3(randf_range(1.5, 2.8), randf_range(-0.6, 0.6), randf_range(-0.4, 0.4)), 0.02)
	_kick_tween.tween_property(_kick_pivot, "position", Vector3.ZERO, 0.03)
	_kick_tween.parallel().tween_property(_kick_pivot, "rotation_degrees", Vector3.ZERO, 0.03)

	_bolt_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bolt_tween.tween_property(_bolt_pivot, "position", BOLT_RECOIL_OFFSET, 0.015)
	if rounds_remaining > 0:
		_bolt_tween.tween_property(_bolt_pivot, "position", Vector3.ZERO, 0.02)

	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.02)
	_flash_tween.tween_callback(func() -> void: _muzzle_flash.visible = false)


func set_slide_locked(locked: bool) -> void:
	_bolt_locked = locked
	if _bolt_pivot == null:
		return
	if _bolt_tween and _bolt_tween.is_valid():
		_bolt_tween.kill()
	_bolt_pivot.position = BOLT_RECOIL_OFFSET if locked else Vector3.ZERO


func play_reload(duration: float, was_empty: bool) -> void:
	if not first_person or _reload_pivot == null or duration <= 0.0:
		return
	cancel_weapon_animation()
	set_slide_locked(was_empty)
	_reload_playing = true

	var scale_time := duration / 1.5
	var magazine_out := _magazine_home_position + Vector3(0, -0.42, 0.05)

	_reload_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# 1. Weapon tilts up & left; left hand leaves forend and reaches down to grab magazine
	_reload_tween.tween_property(_reload_pivot, "position", Vector3(0.06, -0.14, 0.06), 0.22 * scale_time)
	_reload_tween.parallel().tween_property(_reload_pivot, "rotation_degrees", Vector3(12, 0, -18), 0.22 * scale_time)
	if _left_hand:
		_reload_tween.parallel().tween_property(_left_hand, "position", Vector3(-0.02, -0.26, -0.06), 0.22 * scale_time)
		_reload_tween.parallel().tween_property(_left_hand, "rotation_degrees", Vector3(18, 5, -12), 0.22 * scale_time)

	# 2. Eject old magazine; left hand pulls it down and away
	_reload_tween.tween_property(_magazine, "position", magazine_out, 0.24 * scale_time)
	_reload_tween.parallel().tween_property(_magazine, "rotation_degrees", _magazine_home_rotation + Vector3(10, 0, 8), 0.24 * scale_time)
	if _left_hand:
		_reload_tween.parallel().tween_property(_left_hand, "position", Vector3(-0.04, -0.52, -0.01), 0.24 * scale_time)
		_reload_tween.parallel().tween_property(_left_hand, "rotation_degrees", Vector3(25, 0, -5), 0.24 * scale_time)

	_reload_tween.tween_callback(func() -> void: _magazine.visible = false)
	if _left_hand:
		_reload_tween.parallel().tween_property(_left_hand, "position", Vector3(-0.06, -0.62, 0.06), 0.12 * scale_time)
	else:
		_reload_tween.tween_interval(0.12 * scale_time)

	# 3. Insert fresh magazine; left hand drives new magazine into the magwell
	_reload_tween.tween_callback(func() -> void:
		_magazine.position = magazine_out
		_magazine.rotation_degrees = _magazine_home_rotation
		_magazine.visible = true
	)
	_reload_tween.tween_property(_magazine, "position", _magazine_home_position, 0.28 * scale_time)
	if _left_hand:
		_reload_tween.parallel().tween_property(_left_hand, "position", Vector3(-0.02, -0.22, -0.06), 0.28 * scale_time)
		_reload_tween.parallel().tween_property(_left_hand, "rotation_degrees", Vector3(15, 8, -15), 0.28 * scale_time)

	_reload_tween.tween_interval(0.10 * scale_time)

	# 4. Bolt release / slap if empty
	if was_empty:
		if _left_hand:
			_reload_tween.tween_property(_left_hand, "position", Vector3(-0.11, 0.08, -0.24), 0.10 * scale_time)
			_reload_tween.parallel().tween_property(_left_hand, "rotation_degrees", Vector3(5, 30, -35), 0.10 * scale_time)
		_reload_tween.tween_callback(func() -> void: set_slide_locked(false))
		_reload_tween.tween_interval(0.04 * scale_time)

	# 5. Return weapon and left hand back to ready forend grip
	_reload_tween.tween_property(_reload_pivot, "position", Vector3.ZERO, 0.40 * scale_time)
	_reload_tween.parallel().tween_property(_reload_pivot, "rotation_degrees", Vector3.ZERO, 0.40 * scale_time)
	if _left_hand:
		_reload_tween.parallel().tween_property(_left_hand, "position", _left_hand_home_position, 0.40 * scale_time)
		_reload_tween.parallel().tween_property(_left_hand, "rotation_degrees", _left_hand_home_rotation, 0.40 * scale_time)
	_reload_tween.tween_callback(func() -> void: _reload_playing = false)


func finish_reload(rounds_loaded: int) -> void:
	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()
	_reload_playing = false
	_reset_reload_pose()
	set_slide_locked(rounds_loaded <= 0)


func cancel_weapon_animation() -> void:
	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()
	_reload_playing = false
	_reset_reload_pose()
	if _kick_tween and _kick_tween.is_valid():
		_kick_tween.kill()
	if _kick_pivot:
		_kick_pivot.position = Vector3.ZERO
		_kick_pivot.rotation_degrees = Vector3.ZERO
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
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


func get_slide_offset() -> float:
	return _bolt_pivot.position.z if _bolt_pivot else 0.0


func get_magazine_offset() -> float:
	return _magazine.position.distance_to(_magazine_home_position) if _magazine else 0.0


func _reset_reload_pose() -> void:
	if _reload_pivot:
		_reload_pivot.position = Vector3.ZERO
		_reload_pivot.rotation_degrees = Vector3.ZERO
	if _magazine:
		_magazine.visible = true
		_magazine.position = _magazine_home_position
		_magazine.rotation_degrees = _magazine_home_rotation
	if _left_hand:
		_left_hand.position = _left_hand_home_position
		_left_hand.rotation_degrees = _left_hand_home_rotation


func _build_visual() -> void:
	# Hierarchy: ReloadPivot -> KickPivot -> (Receiver, Bolt, Sights, Magazine, Stock, etc.)
	_reload_pivot = Node3D.new()
	_reload_pivot.name = "ReloadPivot"
	add_child(_reload_pivot)

	_kick_pivot = Node3D.new()
	_kick_pivot.name = "KickPivot"
	_reload_pivot.add_child(_kick_pivot)

	var weapon_model := Node3D.new()
	weapon_model.name = "WeaponModel"
	_kick_pivot.add_child(weapon_model)

	_bolt_pivot = Node3D.new()
	_bolt_pivot.name = "BoltPivot"
	weapon_model.add_child(_bolt_pivot)

	# Materials
	var matte_metal := _gunmetal_material(Color("1e2326"), 0.4)
	var receiver_body := _gunmetal_material(Color("2c3337"), 0.5)
	var polymer_dark := _material(Color("181c1e"), 0.85)
	var steel_accent := _gunmetal_material(Color("586266"), 0.25)
	var sight_mark := _material(Color("d6e4dc"), 0.3)
	var brass_chamber := _material(Color("b38f38"), 0.35)
	var security_stripe := _material(Color("637074"), 0.6)

	# 1. RECEIVER
	_add_box("Receiver", Vector3(0, 0.08, -0.15), Vector3(0.18, 0.19, 0.58), receiver_body, Vector3.ZERO, weapon_model)
	_add_box("ReceiverTopCover", Vector3(0, 0.185, -0.15), Vector3(0.14, 0.035, 0.52), matte_metal, Vector3.ZERO, weapon_model)
	_add_box("ReceiverLowerChassis", Vector3(0, -0.015, -0.18), Vector3(0.16, 0.045, 0.44), polymer_dark, Vector3.ZERO, weapon_model)
	_add_box("ArmoryMarkingStripe", Vector3(0.091, 0.11, -0.22), Vector3(0.003, 0.04, 0.12), security_stripe, Vector3.ZERO, weapon_model)

	# 2. CHARGING HANDLE & BOLT DETAIL (inside BoltPivot)
	_add_box("Bolt", Vector3(0.035, 0.10, -0.14), Vector3(0.09, 0.08, 0.22), steel_accent, Vector3.ZERO, _bolt_pivot)
	_add_cylinder("ChargingHandle", Vector3(-0.115, 0.13, -0.25), 0.018, 0.065, matte_metal, Vector3(0, 0, 90), _bolt_pivot)
	_add_cylinder("ChargingHandleKnob", Vector3(-0.15, 0.13, -0.25), 0.024, 0.024, polymer_dark, Vector3(0, 0, 90), _bolt_pivot)

	# 3. EJECTION PORT
	_add_box("EjectionPort", Vector3(0.088, 0.11, -0.12), Vector3(0.012, 0.07, 0.16), polymer_dark, Vector3.ZERO, weapon_model)
	_add_box("EjectionChamberInner", Vector3(0.065, 0.11, -0.12), Vector3(0.025, 0.045, 0.11), brass_chamber, Vector3.ZERO, weapon_model)

	# 4. BARREL & MUZZLE
	_add_cylinder("Barrel", Vector3(0, 0.085, -0.52), 0.042, 0.24, steel_accent, Vector3(90, 0, 0), weapon_model)
	_add_cylinder("Muzzle", Vector3(0, 0.085, -0.66), 0.048, 0.075, matte_metal, Vector3(90, 0, 0), weapon_model)
	_add_cylinder("MuzzleBore", Vector3(0, 0.085, -0.70), 0.032, 0.015, polymer_dark, Vector3(90, 0, 0), weapon_model)

	# Flash hider port cuts
	for index in range(4):
		var angle := float(index) * 90.0
		_add_box("MuzzleComp%d" % index, Vector3(0, 0.085, -0.66), Vector3(0.012, 0.105, 0.03), polymer_dark, Vector3(0, 0, angle), weapon_model)

	# 5. FOREND / HANDGUARD
	_add_box("Handguard", Vector3(0, 0.07, -0.38), Vector3(0.19, 0.18, 0.24), polymer_dark, Vector3.ZERO, weapon_model)
	for rib_index in range(4):
		var rib_z := -0.30 - rib_index * 0.05
		_add_box("HandguardRib%d" % rib_index, Vector3(0, 0.07, rib_z), Vector3(0.205, 0.16, 0.018), matte_metal, Vector3.ZERO, weapon_model)
	_add_box("ForendHandstop", Vector3(0, -0.04, -0.48), Vector3(0.12, 0.05, 0.05), polymer_dark, Vector3(0, 0, 0), weapon_model)

	# 6. SIGHTS (Centered iron sights aligned for ADS view)
	_add_box("RearSight", Vector3(0, 0.22, 0.06), Vector3(0.07, 0.05, 0.04), matte_metal, Vector3.ZERO, weapon_model)
	_add_box("RearSightLeftPost", Vector3(-0.024, 0.24, 0.06), Vector3(0.016, 0.045, 0.035), matte_metal, Vector3.ZERO, weapon_model)
	_add_box("RearSightRightPost", Vector3(0.024, 0.24, 0.06), Vector3(0.016, 0.045, 0.035), matte_metal, Vector3.ZERO, weapon_model)
	_add_box("FrontSight", Vector3(0, 0.215, -0.56), Vector3(0.04, 0.08, 0.04), matte_metal, Vector3.ZERO, weapon_model)
	_add_box("FrontSightPost", Vector3(0, 0.248, -0.56), Vector3(0.012, 0.04, 0.025), sight_mark, Vector3.ZERO, weapon_model)
	_add_box("FrontSightHoodLeft", Vector3(-0.028, 0.24, -0.56), Vector3(0.008, 0.055, 0.04), matte_metal, Vector3.ZERO, weapon_model)
	_add_box("FrontSightHoodRight", Vector3(0.028, 0.24, -0.56), Vector3(0.008, 0.055, 0.04), matte_metal, Vector3.ZERO, weapon_model)

	# 7. TRIGGER & TRIGGER GUARD
	_add_box("TriggerGuard", Vector3(0, -0.12, -0.14), Vector3(0.12, 0.025, 0.19), polymer_dark, Vector3(-10, 0, 0), weapon_model)
	_add_box("TriggerGuardFront", Vector3(0, -0.09, -0.23), Vector3(0.12, 0.08, 0.025), polymer_dark, Vector3(0, 0, 0), weapon_model)
	_add_box("Trigger", Vector3(0, -0.065, -0.14), Vector3(0.022, 0.08, 0.025), steel_accent, Vector3(-18, 0, 0), weapon_model)

	# 8. PISTOL GRIP
	_add_box("PistolGrip", Vector3(0, -0.21, 0.02), Vector3(0.13, 0.24, 0.17), polymer_dark, Vector3(14, 0, 0), weapon_model)
	_add_box("GripLeftPanel", Vector3(-0.07, -0.21, 0.02), Vector3(0.012, 0.20, 0.13), matte_metal, Vector3(14, 0, 0), weapon_model)
	_add_box("GripRightPanel", Vector3(0.07, -0.21, 0.02), Vector3(0.012, 0.20, 0.13), matte_metal, Vector3(14, 0, 0), weapon_model)

	# 9. COLLAPSED STOCK / REAR SUPPORT
	_add_box("Stock", Vector3(0, 0.07, 0.24), Vector3(0.16, 0.18, 0.12), polymer_dark, Vector3.ZERO, weapon_model)
	_add_cylinder("StockStrutLeft", Vector3(-0.095, 0.08, 0.02), 0.014, 0.46, steel_accent, Vector3(90, 0, 0), weapon_model)
	_add_cylinder("StockStrutRight", Vector3(0.095, 0.08, 0.02), 0.014, 0.46, steel_accent, Vector3(90, 0, 0), weapon_model)
	_add_box("StockButtPad", Vector3(0, 0.06, 0.31), Vector3(0.14, 0.21, 0.04), matte_metal, Vector3.ZERO, weapon_model)

	# 10. MAGAZINE (Separate animated assembly inside KickPivot)
	_magazine = Node3D.new()
	_magazine.name = "Magazine"
	_magazine.position = Vector3(0, -0.25, -0.23)
	_magazine.rotation_degrees = Vector3(8, 0, 0)
	_kick_pivot.add_child(_magazine)

	_add_box("MagazineVisual", Vector3(0, 0, 0), Vector3(0.095, 0.34, 0.12), matte_metal, Vector3.ZERO, _magazine)
	_add_box("MagazineBasePlate", Vector3(0, -0.18, 0.01), Vector3(0.12, 0.035, 0.14), polymer_dark, Vector3.ZERO, _magazine)
	for ind in range(3):
		_add_box("MagazineRib%d" % ind, Vector3(0, -0.06 - ind * 0.07, 0), Vector3(0.102, 0.018, 0.11), steel_accent, Vector3.ZERO, _magazine)

	_magazine_home_position = _magazine.position
	_magazine_home_rotation = _magazine.rotation_degrees

	# 11. MUZZLE FLASH & SOCKETS
	var flash_mat := _material(Color("fff39e"), 0.1, true, 3.2)
	_muzzle_flash = _add_cylinder("MuzzleFlash", Vector3(0, 0.085, -0.79), 0.095, 0.14, flash_mat, Vector3(90, 0, 0), weapon_model)
	_muzzle_flash.visible = false

	# Sockets
	muzzle_point = Marker3D.new()
	muzzle_point.name = "MuzzlePoint"
	muzzle_point.position = Vector3(0, 0.085, -0.71)
	weapon_model.add_child(muzzle_point)

	var muzzle_flash_point := Marker3D.new()
	muzzle_flash_point.name = "MuzzleFlashPoint"
	muzzle_flash_point.position = Vector3(0, 0.085, -0.79)
	weapon_model.add_child(muzzle_flash_point)

	magazine_socket = Marker3D.new()
	magazine_socket.name = "MagazineSocket"
	magazine_socket.position = _magazine_home_position
	weapon_model.add_child(magazine_socket)

	suppressor_point = Marker3D.new()
	suppressor_point.name = "SuppressorAttachmentPoint"
	suppressor_point.position = Vector3(0, 0.085, -0.72)
	weapon_model.add_child(suppressor_point)

	ads_anchor = Marker3D.new()
	ads_anchor.name = "ADSAnchor"
	# Iron sight line is at Y = 0.248, X = 0.0
	ads_anchor.position = Vector3(0, 0.248, -0.2)
	weapon_model.add_child(ads_anchor)

	var rear_sight_aim_point := Marker3D.new()
	rear_sight_aim_point.name = "RearSightAimPoint"
	rear_sight_aim_point.position = Vector3(0, 0.248, 0.06)
	weapon_model.add_child(rear_sight_aim_point)

	var front_sight_aim_point := Marker3D.new()
	front_sight_aim_point.name = "FrontSightAimPoint"
	front_sight_aim_point.position = Vector3(0, 0.248, -0.56)
	weapon_model.add_child(front_sight_aim_point)

	hip_anchor = Marker3D.new()
	hip_anchor.name = "HipAnchor"
	hip_anchor.position = Vector3.ZERO
	weapon_model.add_child(hip_anchor)

	interaction_anchor = Marker3D.new()
	interaction_anchor.name = "InteractionAnchor"
	interaction_anchor.position = Vector3(0, 0.08, 0)
	weapon_model.add_child(interaction_anchor)

	# 12. FIRST-PERSON DUAL HANDS
	if first_person:
		var skin := _material(FirstPersonBodyStyle.SKIN_COLOR, FirstPersonBodyStyle.SKIN_ROUGHNESS)
		var sleeve := _material(FirstPersonBodyStyle.SLEEVE_COLOR, FirstPersonBodyStyle.SLEEVE_ROUGHNESS)

		# Right hand holding pistol grip
		var right_hand := Node3D.new()
		right_hand.name = "RightHand"
		right_hand.position = Vector3(0.02, -0.22, 0.04)
		right_hand.rotation_degrees = Vector3(14, 0, 0)
		_kick_pivot.add_child(right_hand)
		_add_capsule("RightHandPalm", Vector3(0, 0, 0), 0.09, 0.28, skin, Vector3.ZERO, right_hand)
		_add_tapered_cylinder("RightSleeve", Vector3(0.04, -0.28, 0.32), 0.11, 0.16, 0.65, sleeve, Vector3(-65, 0, 0), right_hand)
		_add_cylinder("RightCuff", Vector3(0.02, -0.14, 0.08), 0.12, 0.08, sleeve, Vector3(-65, 0, 0), right_hand)

		# Left hand supporting forend / handguard
		_left_hand = Node3D.new()
		_left_hand.name = "LeftHand"
		_left_hand.position = _left_hand_home_position
		_left_hand.rotation_degrees = _left_hand_home_rotation
		_kick_pivot.add_child(_left_hand)
		_add_capsule("LeftHandPalm", Vector3(0, 0, 0), 0.085, 0.26, skin, Vector3(0, 0, 70), _left_hand)
		_add_tapered_cylinder("LeftSleeve", Vector3(-0.16, -0.26, 0.28), 0.11, 0.15, 0.62, sleeve, Vector3(-55, -20, 0), _left_hand)
		_add_cylinder("LeftCuff", Vector3(-0.08, -0.12, 0.08), 0.115, 0.08, sleeve, Vector3(-55, -20, 0), _left_hand)
