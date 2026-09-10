extends PrisonSlidingGate
class_name CampusTelescopicGate

## Four lightweight sliding panels stack beside the aperture on two surface
## tracks. Unlike a single full-width leaf this fits 4 m circulation spines.
## Access, prompts, authorization and occupied-doorway safety are inherited.
var _panels: Array[Node3D] = []
var _panel_closed: Array[Vector3] = []

func _build_gate_visuals() -> void:
	var original_visuals := visuals
	var quarter := gate_width * 0.25
	var metal := preload("res://materials/props/door_hardware.tres")
	for index in range(4):
		var panel := Node3D.new()
		panel.name = "SlidingPanel%d" % index
		panel.position = Vector3((float(index) - 1.5) * quarter, 0, 0.065 * float(index % 2))
		original_visuals.add_child(panel)
		_panels.append(panel)
		_panel_closed.append(panel.position)
		visuals = panel
		for x in [-quarter * 0.5 + 0.025, 0.0, quarter * 0.5 - 0.025]:
			_add_visual_box("Bar", Vector3(x, gate_height * 0.5, 0), Vector3(0.045, gate_height, 0.05), metal)
		for y in [0.10, gate_height * 0.48, gate_height - 0.1]:
			_add_visual_box("Rail", Vector3(0, y, 0), Vector3(quarter, 0.09, 0.055), metal)
		if bulletproof_glass:
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.35, 0.57, 0.6, 0.23)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.cull_mode = BaseMaterial3D.CULL_DISABLED
			_add_visual_box("BallisticGlass", Vector3(0, gate_height * 0.5, 0), Vector3(quarter - 0.05, gate_height - 0.12, 0.04), glass)
		preload("res://scripts/levels/campus/furnishing/campus_furniture_batcher.gd").consolidate(panel)
	visuals = original_visuals
	# A real supported track; the wall behind the pockets is never removed.
	_add_visual_box("SurfaceTrack", Vector3(0, gate_height + 0.17, 0.035), Vector3(gate_width * 1.5 + 0.15, 0.14, 0.22), metal)
	for x in [-gate_width * 0.5 - 0.1, gate_width * 0.5 + 0.1]:
		_add_visual_box("TrackSupport", Vector3(x, gate_height * 0.5, 0.04), Vector3(0.09, gate_height, 0.22), metal)

func _target(index: int, opened: bool) -> Vector3:
	var p := _panel_closed[index]
	if opened:
		p.x = (gate_width * 0.625 + 0.05) * (-1.0 if index < 2 else 1.0)
	return p

func _apply_pose(opened: bool) -> void:
	for index in range(_panels.size()):
		_panels[index].position = _target(index, opened)

func _animate_to(opened: bool) -> void:
	if _transition and _transition.is_valid():
		_transition.kill()
	_moving = true
	is_open = opened
	blocker.set_deferred("disabled", true)
	_transition = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	for index in range(_panels.size()):
		_transition.tween_property(_panels[index], "position", _target(index, opened), animation_duration)
	_transition.chain().tween_callback(_finish_transition.bind(opened))
