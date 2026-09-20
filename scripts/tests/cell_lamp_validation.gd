extends Node3D

var failures: Array[String] = []
var capture := false

func _ready() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	var campus := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn").instantiate()
	var cycle := campus.get_node("EnvironmentCycle")
	cycle.cycle_enabled = false
	cycle.roll_weather_on_start = false
	cycle.start_time_hours = 22.0
	add_child(campus)
	for frame in range(8): await get_tree().physics_frame
	for guard in get_tree().get_nodes_in_group("guards"): guard.set_physics_process(false)
	var cell := campus.get_node("Buildings/CellhouseA/Interior/ParthCell") as Node3D
	var lamp := cell.get_node("CellTubeLight") as CellLamp
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	check(player != null, "Actual campus player must spawn")
	if player == null:
		finish()
		return
	var camera := player.get_node("Head/Camera3D") as Camera3D
	# Stand INSIDE the real cell, within normal E reach. No synthetic interaction.
	player.global_position = cell.to_global(Vector3(0, 0.95, 0.1))
	player.velocity = Vector3.ZERO
	camera.look_at(lamp.to_global(Vector3(0, 0, 0.15)))
	for frame in range(12): await get_tree().physics_frame
	var lamps := get_tree().get_nodes_in_group("cell_lamps")
	check(lamps.size() == 69, "All 45 A and 24 B cells must have a lamp")
	for fixture in lamps:
		var tube := fixture.get_node_or_null("TubeDiffuser") as MeshInstance3D
		check(tube != null and tube.mesh is CylinderMesh, "Live tube must survive batching: " + str(fixture.get_path()))
		if tube:
			check(absf(tube.global_basis.y.normalized().y) < 0.001, "Tube axis must be horizontal")
		check(fixture.has_node("LampCollider") and fixture.collision_layer == 1, "Lamp must support the normal interaction ray")
		check(fixture.local_light_enabled, "Every cell must request real source lighting")
		var front_ray := PhysicsRayQueryParameters3D.create(fixture.to_global(Vector3(0, -0.4, 1.2)), fixture.to_global(Vector3(0, 0, 0.15)), 1)
		var front_hit := get_world_3d().direct_space_state.intersect_ray(front_ray)
		check(not front_hit.is_empty() and front_hit.collider == fixture, "Every lamp must be reachable from inside its cell: %s at %s; ray hit %s" % [fixture.get_path(), fixture.position, front_hit])
		var backing_ray := PhysicsRayQueryParameters3D.create(fixture.to_global(Vector3(0, 0, -0.5)), fixture.to_global(Vector3(0, 0, 0.2)), 1)
		var backing_hit := get_world_3d().direct_space_state.intersect_ray(backing_ray)
		check(not backing_hit.is_empty() and backing_hit.collider != fixture, "Every lamp must have a solid wall backing: " + str(fixture.get_path()))
	check(get_tree().get_nodes_in_group("cell_lamp_pooled_lights").size() == 4, "Real lights must stay in a four-light pool")
	check(player.get("_current_interactable") == lamp, "Aiming at Parth's tube must show E prompt; got " + str(player.get("_current_interactable")))
	var prompt := campus.get_node("HUD/HUDControl/InteractionPrompt") as Label
	check(prompt.text == "[E] Turn Off Lamp", "HUD must display the actual lamp prompt")
	check(lamp.is_on, "Night lamp starts on")
	check(has_source(lamp), "Parth's lit lamp must own an active light at its source")
	await screenshot("on")
	await press_e()
	check(not lamp.is_on, "Actual E input turns Parth's lamp off")
	check(prompt.text == "[E] Turn On Lamp", "HUD must update after switching off")
	check(not has_source(lamp), "Off lamp must stop illuminating the room")
	await screenshot("off")
	cycle.set_time_hours(12.0)
	cycle.set_time_hours(22.0)
	check(not lamp.is_on, "Clock must not override manual OFF")
	await press_e()
	check(lamp.is_on and has_source(lamp), "Second E restores light and emission")
	cycle.set_time_hours(12.0)
	check(lamp.is_on, "Clock must not override manual ON")
	var query := PhysicsRayQueryParameters3D.create(lamp.to_global(Vector3(0, 0, -0.5)), lamp.to_global(Vector3(0, 0, 0.2)), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and hit.collider != lamp, "Wall behind lamp must block interaction from adjacent cell")
	finish()

func has_source(lamp: CellLamp) -> bool:
	for light in get_tree().get_nodes_in_group("cell_lamp_pooled_lights"):
		if light.visible and light.get_meta("source_lamp", NodePath()) == lamp.get_path():
			return light.global_position.distance_to(lamp.get_light_origin()) < 0.001 and light.light_energy > 0.0
	return false

func press_e() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	for frame in range(3): await get_tree().physics_frame
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	Input.parse_input_event(event)
	for frame in range(3): await get_tree().physics_frame

func screenshot(state: String) -> void:
	if not capture: return
	for frame in range(8): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/blacksite-parth-lamp-%s.png" % state
	check(get_viewport().get_texture().get_image().save_png(path) == OK, "Save " + path)
	print("CELL LAMP SCREENSHOT: ", path)

func finish() -> void:
	for message in failures: push_error(message)
	print("CELL LAMP VALIDATION: ", "PASS" if failures.is_empty() else "FAIL", " — 69 fixtures, real E input, sourced illumination, manual overrides, wall occlusion")
	get_tree().quit(0 if failures.is_empty() else 1)
