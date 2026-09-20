extends Node3D

## Focused native Compatibility captures of the six authored surface additions.
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
	for frame in range(8): await get_tree().process_frame
	var zones := campus.get_node("WorldEnvironment") as EnvironmentZoneManager
	for hour in [22.0, 12.0]:
		cycle.set_time_hours(hour)
		var suffix := "night" if hour > 18.0 else "day"
		for id in ["gym", "showers", "toilets"]:
			var room: Node3D
			for candidate in get_tree().get_nodes_in_group("campus_planned_rooms"):
				if candidate.get_meta("plan_id") == "medical-ground" and candidate.get_meta("room_data").id == id:
					room = candidate
					break
			assert(room != null)
			var data: Dictionary = room.get_meta("room_data")
			camera.global_position = room.to_global(Vector3(float(data.w) * 0.27, 1.7, float(data.d) * 0.34))
			camera.look_at(room.to_global(Vector3(-float(data.w) * 0.15, 0.9, -float(data.d) * 0.2)))
			zones.refresh_from_viewer()
			await _capture(id + "-" + suffix)
	cycle.set_time_hours(12.0)
	var yard := campus.get_node("CampusShell/CentralYard") as Node3D
	camera.global_position = yard.to_global(Vector3(-4, 1.7, 6))
	camera.look_at(yard.to_global(Vector3(-17, 0, -2)))
	zones.refresh_from_viewer()
	await _capture("court-day")
	cycle.set_time_hours(22.0)
	for cell in get_tree().get_nodes_in_group("campus_cells"):
		if cell is CampusPrisonCell and cell.is_parth_cell:
			camera.global_position = cell.to_global(Vector3(cell.front_direction * 1.25, 1.65, 0.2))
			camera.look_at(cell.to_global(Vector3(0.1, 0.8, -1.8)))
			zones.refresh_from_viewer()
			await _capture("cell-cupboard")
			camera.look_at(cell.to_global(Vector3(0.25, 0.6, 1.45)))
			await _capture("cell-chair")
			break
	campus.free()
	camera.free()
	for frame in range(3): await get_tree().process_frame
	print("AUTHORED_SURFACE_REVIEW_OK")
	get_tree().quit()

func _capture(label: String) -> void:
	for frame in range(25): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/blacksite-surface-%s.png" % label
	assert(get_viewport().get_texture().get_image().save_png(path) == OK)
	print("SURFACE REVIEW: ", label, " -> ", path)
