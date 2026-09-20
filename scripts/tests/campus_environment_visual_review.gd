extends Node3D

func _ready() -> void:
	call_deferred("_review")


func _review() -> void:
	var campus := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn").instantiate() as PrisonCampusPrototype
	campus.gameplay_enabled = false
	var cycle := campus.get_node("EnvironmentCycle") as CampusEnvironmentCycle
	cycle.cycle_enabled = false
	cycle.roll_weather_on_start = false
	add_child(campus)
	var preview := campus.get_node("PreviewCamera") as Camera3D
	preview.current = false
	var camera := Camera3D.new()
	camera.current = true
	add_child(camera)
	camera.position = Vector3(-4, 12, 46)
	camera.look_at(Vector3(0, 2, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	for state in [["morning", 7.0], ["day", 12.0], ["evening", 18.0], ["night", 22.0]]:
		cycle.set_weather_mode(CampusEnvironmentCycle.WeatherMode.NORMAL)
		cycle.set_time_hours(float(state[1]))
		for frame in range(5): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var result := get_viewport().get_texture().get_image().save_png("/tmp/campus-environment-%s.png" % state[0])
		print("Environment render ", state[0], ": ", error_string(result))
	# Confirm the automatic fixtures illuminate Cellhouse A itself, including
	# the ceiling-flush cell tubes and shared amber floor light.
	camera.position = Vector3(-50.0, 1.7, 0.0)
	camera.look_at(Vector3(-50.0, 1.8, -13.8))
	for frame in range(8): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var interior_result := get_viewport().get_texture().get_image().save_png("/tmp/campus-environment-night-interior.png")
	print("Environment render night interior: ", error_string(interior_result))
	camera.position = Vector3(-4, 12, 46)
	camera.look_at(Vector3(0, 2, 0))
	cycle.set_time_hours(12.0)
	cycle.set_weather_mode(CampusEnvironmentCycle.WeatherMode.RAINY)
	cycle.call("_update_rain_shelter")
	for frame in range(40): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var rain_result := get_viewport().get_texture().get_image().save_png("/tmp/campus-environment-rainy.png")
	print("Environment render rainy: ", error_string(rain_result))
	cycle.set_weather_mode(CampusEnvironmentCycle.WeatherMode.NORMAL)
	campus.free()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().quit()
