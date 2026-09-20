extends Node3D

## Native Compatibility review; test-only, no shipping spawn/clock changes.
func _ready() -> void:
	call_deferred("_review")

func _review() -> void:
	var campus := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn").instantiate()
	campus.gameplay_enabled = false
	var cycle := campus.get_node("EnvironmentCycle") as CampusEnvironmentCycle
	cycle.cycle_enabled = false
	cycle.roll_weather_on_start = false
	cycle.start_time_hours = 22.0
	add_child(campus)
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 78.0
	add_child(camera)
	for frame in range(12): await get_tree().process_frame
	var manager := campus.get_node("WorldEnvironment") as EnvironmentZoneManager
	var views := [
		["cellblock", Vector3(-45, 9.7, 9), Vector3(-68, 7.0, -7)],
		["yard-night", Vector3(0, 1.7, 20), Vector3(25, 5, -36.5)],
		["medical", "medical-ground", "ward"],
		["gym", "medical-ground", "gym"],
		["showers", "medical-ground", "showers"],
		["kitchen", "food-ground", "kitchen"],
		["cafeteria", "food-ground", "dining"],
		["security", "hq-1", "control"],
		["laboratory", "nidra-b2", "lab"],
		["tunnel", "maintenance-b1", "distribution"],
	]
	for view in views:
		if view[1] is Vector3:
			camera.global_position = view[1]
			camera.look_at(view[2])
		else:
			var room: Node3D
			for candidate in get_tree().get_nodes_in_group("campus_planned_rooms"):
				if candidate.get_meta("plan_id") == view[1] and candidate.get_meta("room_data").id == view[2]:
					room = candidate
					break
			assert(room != null)
			var data: Dictionary = room.get_meta("room_data")
			camera.global_position = room.to_global(Vector3(float(data.w) * 0.27, 1.7, float(data.d) * 0.34))
			camera.look_at(room.to_global(Vector3(-float(data.w) * 0.15, 1.35, -float(data.d) * 0.20)))
		manager.refresh_from_viewer()
		await _capture(String(view[0]), manager)
	cycle.set_time_hours(12.0)
	camera.global_position = Vector3(0, 1.7, 20)
	camera.look_at(Vector3(25, 5, -36.5))
	manager.refresh_from_viewer()
	await _capture("yard-day", manager)
	get_tree().quit()

func _capture(label: String, manager: EnvironmentZoneManager) -> void:
	for frame in range(45): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/overhaul-%s.png" % label
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("OVERHAUL REVIEW: ", label, " ", error_string(result), " profile=", manager.active_profile, " indoors=", manager.is_interior, " fog=", manager.environment.fog_enabled, " FPS=", Engine.get_frames_per_second())
