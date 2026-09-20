extends Node3D

const CAMPUS := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn")
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var campus := CAMPUS.instantiate() as PrisonCampusPrototype
	campus.gameplay_enabled = false
	var cycle := campus.get_node("EnvironmentCycle") as CampusEnvironmentCycle
	cycle.cycle_enabled = false
	cycle.roll_weather_on_start = false
	cycle.start_time_hours = 22.0
	add_child(campus)
	for frame in 5: await get_tree().process_frame
	await get_tree().physics_frame
	var interior := campus.get_node("Buildings/CellhouseA/Interior") as Node3D
	var camera := campus.get_node("PreviewCamera") as Camera3D
	camera.make_current()
	var lights := get_tree().get_nodes_in_group("campus_gallery_lights")
	_check(lights.size() == 3, "Gallery coverage must reuse exactly three lights")
	for light in lights:
		# Neutral view keeps the pure-distance coverage/hysteresis test separate
		# from the camera-facing selection regression below.
		light.view_bias_distance = 0.0
		var floor_number := int(light.get("floor_number"))
		var y := float(floor_number - 1) * 4.0 + 1.65
		var positions: PackedVector3Array = light.get("fixture_positions")
		_check(positions.size() == 4, "Each tier must register its four real gallery fixtures")
		for index in positions.size():
			camera.global_position = interior.to_global(Vector3(positions[index].x, y, positions[index].z))
			light.call("refresh", true)
			_check(light.get_meta("source_fixture_index") == index, "Floor %d fixture %d must cover a viewer underneath it" % [floor_number, index])
			_check(light.position.is_equal_approx(positions[index]), "A real gallery light must stay below a fixed fixture")
			_check(light.visible and light.light_energy > 0.0, "Selected night fixture must actually illuminate")
			_check(light.global_position.distance_to(camera.global_position) < light.omni_range, "Southern/eastern galleries must be within the chosen source's range")
		# Tiny movements across the north gallery midpoint must not alternate
		# between light sources. Moving decisively to the other side should.
		camera.global_position = interior.to_global(Vector3(-10, y, -9.25))
		light.call("refresh", true)
		for x in [-0.1, 0.1, -0.1, 0.1]:
			camera.global_position = interior.to_global(Vector3(x, y, -9.25))
			light.call("refresh", true)
			_check(light.get_meta("source_fixture_index") == 0, "Midpoint movements must respect source hysteresis")
		camera.global_position = interior.to_global(Vector3(7, y, -9.25))
		light.call("refresh")
		_check(light.get_meta("source_fixture_index") == 0, "An ordinary source switch must begin with a fade at the old fixture")
		for step in range(8):
			light.call("_process", 0.025)
			_check(light.position.is_equal_approx(positions[0]) or light.position.is_equal_approx(positions[1]), "Transition must not slide a light through empty air")
		_check(light.get_meta("source_fixture_index") == 1, "Moving well beyond hysteresis must select the east fixture")
		var core := interior.get_node("Floor%dGuardElevatorCore" % floor_number) as Node3D
		_check(core.is_in_group("environment_rooms") and core.get_meta("lighting_type") == "office", "Guard core must register office environment metadata")
		camera.global_position = core.to_global(Vector3(-1.2, 1.65, 0.7))
		light.call("refresh", true)
		_check(light.get_meta("lighting_profile") == "office" and light.shadow_enabled, "Occupied guard quarters need warm room lighting with wall shadows")
		_check(light.global_position.is_equal_approx(core.to_global(core.get_meta("lighting_anchor"))), "Guard lighting must originate below its own visible ceiling fixture")
		cycle.set_time_hours(12.0)
		light.call("refresh", true)
		_check(light.visible, "Working guard quarters must remain lit during daytime")
		camera.global_position = core.to_global(Vector3(1.2, 1.65, 1.65))
		light.call("refresh", true)
		_check(light.get_meta("lighting_profile") == "cellblock", "The elevator lobby must not be mistaken for the guard office")
		_check(not light.visible, "Unoccupied gallery emitters must still follow the daytime clock")
		cycle.set_time_hours(22.0)
		light.call("refresh", true)
		_check(light.visible, "Gallery lighting must return at night")
	# Exact native review regression: nearby southeast fixtures are behind the
	# camera. At least the current tier must now light a fixed fixture in view.
	camera.global_position = Vector3(-45, 9.7, 9)
	camera.look_at(Vector3(-68, 7, -7))
	for light in lights:
		light.view_bias_distance = 20.0
		light.call("refresh", true)
		_check(-camera.to_local(light.global_position).z > 0.0, "Across-atrium view must not stack every source behind the camera")
		_check(light.global_position.distance_to(camera.global_position) < light.omni_range, "View-aware selection must retain coverage of the viewer's vicinity")
		_check(light.get_meta("source_fixture_position").is_equal_approx(light.global_position), "View-aware source must remain at its supported fixture")
		print("GALLERY REVIEW SOURCE: ", light.name, " position=", light.global_position, " energy=", light.light_energy, " range=", light.omni_range, " depth=", -camera.to_local(light.global_position).z)
	for failure in failures: push_error(failure)
	print("GALLERY LIGHTING VALIDATION: %s — 12 fixed fixtures, 3 reused lights, all gallery quadrants, hysteresis, 3 guard rooms and clock rules" % ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
