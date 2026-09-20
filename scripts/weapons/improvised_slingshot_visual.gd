extends MeleeVisualBase
class_name ImprovisedSlingshotVisual

var model: Node3D
var pouch: Node3D
var left_band: MeshInstance3D
var right_band: MeshInstance3D
var rear_hand_rig: Node3D
var frame_rig: Node3D
var reload_tween: Tween
var draw_amount := 0.0
var aim_amount := 0.0


func _ready() -> void:
	_build_visual()


func set_draw_amount(value: float) -> void:
	draw_amount = clampf(value, 0.0, 1.0)
	_update_pose()


func set_aim_amount(value: float) -> void:
	aim_amount = clampf(value, 0.0, 1.0)
	_update_pose()


func play_release() -> void:
	set_draw_amount(0.0)
	if frame_rig:
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(frame_rig, "position:z", -0.10, 0.045)
		tween.tween_property(frame_rig, "position:z", 0.0, 0.16)


func play_reload(duration: float) -> void:
	if not first_person or rear_hand_rig == null: return
	if reload_tween and reload_tween.is_valid(): reload_tween.kill()
	reload_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	reload_tween.tween_property(rear_hand_rig, "position", Vector3(0.34, -0.34, 0.22), duration * 0.28)
	reload_tween.tween_callback(func(): if is_instance_valid(pouch): pouch.visible = true)
	reload_tween.tween_property(rear_hand_rig, "position", Vector3.ZERO, duration * 0.32)


func _build_visual() -> void:
	model = Node3D.new()
	model.name = "SlingshotModel"
	add_child(model)
	if first_person: model.scale = Vector3.ONE * 0.72
	var worn_metal := _material(Color("707a7d"), 0.48, 0.65)
	var edge_metal := _material(Color("a0a7a6"), 0.36, 0.72)
	var wrap := _material(Color("2a2926"), 0.94)
	var elastic := _material(Color("b05b37"), 0.68)
	var pouch_mat := _material(Color("392d25"), 0.96)
	frame_rig = Node3D.new()
	frame_rig.name = "ThreeProngFrame"
	model.add_child(frame_rig)
	_add_tapered("GripCore", Vector3(0, -0.38, 0), 0.075, 0.095, 0.58, worn_metal, Vector3.ZERO, frame_rig)
	for y in [-0.18, -0.30, -0.42, -0.54]: _add_cylinder("GripWrap%02d" % int(absf(y) * 100), Vector3(0, y, 0), 0.102, 0.075, wrap, Vector3.ZERO, frame_rig, 8)
	_add_box("ForkBridge", Vector3(0, -0.03, 0), Vector3(0.44, 0.13, 0.12), worn_metal, Vector3.ZERO, frame_rig)
	_add_cylinder("LeftProng", Vector3(-0.22, 0.25, 0), 0.052, 0.63, worn_metal, Vector3(0, 0, -22), frame_rig, 8)
	_add_cylinder("RightProng", Vector3(0.22, 0.25, 0), 0.052, 0.63, worn_metal, Vector3(0, 0, 22), frame_rig, 8)
	# A short center index pin gives the improvised frame a usable aiming reference
	# without turning its silhouette into a three-tined fork.
	_add_cylinder("CenterProng", Vector3(0, 0.035, -0.025), 0.025, 0.13, edge_metal, Vector3.ZERO, frame_rig, 8)
	for x in [-0.335, 0.335]: _add_cylinder("ProngCap%s" % str(x), Vector3(x, 0.54, 0), 0.061, 0.075, edge_metal, Vector3.ZERO, frame_rig, 8)
	pouch = Node3D.new()
	pouch.name = "AmmoAnchor"
	model.add_child(pouch)
	_add_box("Pouch", Vector3.ZERO, Vector3(0.20, 0.075, 0.075), pouch_mat, Vector3.ZERO, pouch)
	_add_cylinder("AmmoVisual", Vector3(0, 0.02, -0.07), 0.018, 0.18, edge_metal, Vector3(90, 0, 0), pouch, 6)
	left_band = _band("LeftElastic", elastic)
	right_band = _band("RightElastic", elastic)
	_add_anchor(model, "GripAnchor", Vector3(0, -0.38, 0))
	_add_anchor(model, "ImpactPoint", Vector3(0, 0.12, -0.2))
	_add_anchor(model, "HipAnchor", Vector3(0.42, -0.42, 0))
	_add_anchor(model, "AimAnchor", Vector3(0, -0.02, 0))
	_add_anchor(model, "FrontHandAnchor", Vector3(0, -0.28, 0))
	_add_anchor(model, "RearHandAnchor", Vector3(0, 0.06, 0.38))
	_add_anchor(model, "InteractionAnchor", Vector3(0, 0.05, 0))
	if first_person:
		var skin := _material(FirstPersonBodyStyle.SKIN_COLOR, FirstPersonBodyStyle.SKIN_ROUGHNESS)
		var sleeve := _material(FirstPersonBodyStyle.SLEEVE_COLOR, FirstPersonBodyStyle.SLEEVE_ROUGHNESS)
		var front_palm := _add_capsule("FrontHand", Vector3(0.05, -0.40, 0.06), FirstPersonBodyStyle.PALM_RADIUS, FirstPersonBodyStyle.PALM_HEIGHT, skin, Vector3.ZERO, model)
		front_palm.scale = Vector3.ONE * 1.22
		var front_sleeve := _add_tapered("FrontSleeve", Vector3(0.16, -0.67, 0.20), 0.11, 0.17, 0.62, sleeve, Vector3(-28, 0, -12), model)
		front_sleeve.scale = Vector3.ONE * 1.18
		var front_cuff := _add_cylinder("FrontCuff", Vector3(0.08, -0.50, 0.09), FirstPersonBodyStyle.CUFF_RADIUS, FirstPersonBodyStyle.CUFF_HEIGHT, sleeve, Vector3(-28, 0, -12), model, 8)
		front_cuff.scale = Vector3.ONE * 1.18
		rear_hand_rig = Node3D.new()
		rear_hand_rig.name = "RearHandRig"
		pouch.add_child(rear_hand_rig)
		var rear_palm := _add_capsule("RearHand", Vector3(0.03, -0.035, 0.10), FirstPersonBodyStyle.PALM_RADIUS, FirstPersonBodyStyle.PALM_HEIGHT, skin, Vector3(88, 0, 0), rear_hand_rig)
		rear_palm.scale = Vector3.ONE * 1.12
		var rear_sleeve := _add_tapered("RearSleeve", Vector3(0.23, -0.18, 0.20), 0.11, 0.17, 0.62, sleeve, Vector3(-48, 12, -48), rear_hand_rig)
		rear_sleeve.scale = Vector3.ONE * 1.08
		var rear_cuff := _add_cylinder("RearCuff", Vector3(0.08, -0.09, 0.12), FirstPersonBodyStyle.CUFF_RADIUS, FirstPersonBodyStyle.CUFF_HEIGHT, sleeve, Vector3(88, 0, 0), rear_hand_rig, 8)
		rear_cuff.scale = Vector3.ONE * 1.08
	_update_pose()


func _band(piece_name: String, material: Material) -> MeshInstance3D:
	var band := _add_cylinder(piece_name, Vector3.ZERO, 0.032, 1.0, material, Vector3.ZERO, model, 8)
	return band


func _update_pose() -> void:
	if model == null: return
	model.position = Vector3(0.38, -0.47, -0.78).lerp(Vector3(0, -0.20, -0.92), aim_amount)
	model.rotation_degrees = Vector3(-8, -12, -12).lerp(Vector3.ZERO, aim_amount)
	var eased_draw := ease(draw_amount, 0.72)
	# Depth supplies the actual pull; the small down/right screen-space arc makes
	# that depth motion readable in first person without bringing the hand into
	# the camera or covering the target.
	var pouch_position := Vector3(lerpf(0.0, 0.075, eased_draw), lerpf(0.12, -0.035, eased_draw), lerpf(0.02, 0.43, eased_draw))
	pouch.position = pouch_position
	_update_band(left_band, Vector3(-0.335, 0.52, 0), pouch_position + Vector3(-0.085, 0, 0))
	_update_band(right_band, Vector3(0.335, 0.52, 0), pouch_position + Vector3(0.085, 0, 0))


func _update_band(band: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	if band == null: return
	var direction := end - start
	band.position = (start + end) * 0.5
	band.scale = Vector3(1, direction.length(), 1)
	band.basis = Basis(Quaternion(Vector3.UP, direction.normalized())).scaled(band.scale)
