extends Node3D

## Explicit render benchmark. Never used as the shipping main scene.
## Measures delivered frame intervals, not estimated CPU-only process time.
## Keep the browser tab visible and do not resize it during a measured run.
const CAMPUS := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn")
const VIEWS := [
	{"id": "cellblock", "time": 22.0, "position": Vector3(-45, 9.7, 9), "target": Vector3(-68, 7.0, -7)},
	{"id": "yard_night", "time": 22.0, "position": Vector3(0, 1.7, 20), "target": Vector3(25, 5, -36.5)},
	{"id": "yard_day", "time": 12.0, "position": Vector3(0, 1.7, 20), "target": Vector3(25, 5, -36.5)},
	{"id": "medical", "time": 22.0, "plan": "medical-ground", "room": "ward"},
	{"id": "kitchen", "time": 22.0, "plan": "food-ground", "room": "kitchen"},
	{"id": "security", "time": 22.0, "plan": "hq-1", "room": "control"},
	{"id": "service", "time": 22.0, "plan": "maintenance-b1", "room": "distribution"},
]
@export_range(1.0, 10.0) var warmup_seconds := 2.0
@export_range(1.0, 20.0) var sample_seconds := 3.0
var _campus: Node3D
var _camera: Camera3D
var _cycle: CampusEnvironmentCycle
var _zones: EnvironmentZoneManager
var _status: Label
var _results_label: Label
var _button: Button
var _running := false
var _results: Array[Dictionary] = []
var _tab_hidden := false
var _viewport_changed := false
var _initial_size := Vector2i.ZERO


func _ready() -> void:
	_build_status_ui()
	if DisplayServer.get_name() == "headless":
		push_error("BENCHMARK_UNAVAILABLE: headless mode cannot measure rendered/browser frame rate")
		get_tree().quit(2)
		return
	call_deferred("_load_campus")


func _load_campus() -> void:
	_campus = CAMPUS.instantiate()
	# Keep real campus gameplay, lights, weather, HUD and background simulation.
	# Only player input is held still while the review camera changes rooms.
	_campus.gameplay_enabled = true
	_cycle = _campus.get_node("EnvironmentCycle") as CampusEnvironmentCycle
	_cycle.cycle_enabled = false
	_cycle.roll_weather_on_start = false
	_cycle.start_time_hours = 22.0
	add_child(_campus)
	_camera = Camera3D.new()
	_camera.name = "BenchmarkCamera"
	_camera.fov = 78.0
	_camera.far = 220.0
	add_child(_camera)
	for frame in range(8):
		await get_tree().process_frame
	_zones = _campus.get_node("WorldEnvironment") as EnvironmentZoneManager
	for player in get_tree().get_nodes_in_group("player"):
		if _campus.is_ancestor_of(player) and player.has_method("set_control_enabled"):
			player.call("set_control_enabled", false)
	_camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_view(VIEWS[0])
	_status.text = "READY — Browser render benchmark\nKeep this tab visible. Seven real campus views.\n%.0f s warmup + %.0f s measured per view; current display/VSync limits apply." % [warmup_seconds, sample_seconds]
	_button.disabled = false
	_publish({"state": "ready", "view_count": VIEWS.size()}, "BLACKSITE_BENCHMARK_READY")


func _build_status_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BenchmarkStatus"
	layer.layer = 250
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(700, 210)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.04, 0.94)
	style.border_color = Color(0.9, 0.72, 0.25)
	style.set_border_width_all(2)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)
	_status = Label.new()
	_status.text = "Loading actual campus…\nNo FPS values are estimated or fabricated."
	_status.add_theme_font_size_override("font_size", 16)
	stack.add_child(_status)
	_button = Button.new()
	_button.text = "START BENCHMARK"
	_button.custom_minimum_size.y = 38
	_button.disabled = true
	_button.pressed.connect(_run_benchmark)
	stack.add_child(_button)
	_results_label = Label.new()
	_results_label.add_theme_font_size_override("font_size", 15)
	stack.add_child(_results_label)


func _run_benchmark() -> void:
	if _running:
		return
	_running = true
	_button.disabled = true
	_results.clear()
	_results_label.text = ""
	_tab_hidden = false
	_viewport_changed = false
	_initial_size = Vector2i(get_viewport().get_visible_rect().size)
	for index in VIEWS.size():
		var view: Dictionary = VIEWS[index]
		if not _set_view(view):
			_publish({"state": "failed", "reason": "Missing room", "view": view.id}, "BLACKSITE_BENCHMARK_FAILED")
			_status.text = "FAILED — Missing expected campus room: " + String(view.id)
			_running = false
			_button.disabled = false
			return
		_status.text = "WARMUP %d / %d — %s\nKeep browser visible; don't resize. Sampling starts in %.0f seconds." % [index + 1, VIEWS.size(), view.id, warmup_seconds]
		await _wait_rendered_seconds(warmup_seconds)
		_status.text = "MEASURING %d / %d — %s\nRecording delivered frame intervals for %.0f seconds." % [index + 1, VIEWS.size(), view.id, sample_seconds]
		# Warmup and view-switch costs are intentionally excluded. Each sample
		# spans a complete engine frame and includes browser/GPU scheduling.
		var samples := PackedFloat64Array()
		var process_ms_sum := 0.0
		var physics_ms_sum := 0.0
		var draw_calls_sum := 0.0
		var start_us := Time.get_ticks_usec()
		var previous_us := start_us
		while float(Time.get_ticks_usec() - start_us) / 1000000.0 < sample_seconds:
			await get_tree().process_frame
			var now_us := Time.get_ticks_usec()
			samples.append(float(now_us - previous_us) / 1000.0)
			previous_us = now_us
			process_ms_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			physics_ms_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			draw_calls_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			if samples.size() % 15 == 0:
				_check_measurement_conditions()
		_check_measurement_conditions()
		var result := _summarize(String(view.id), samples)
		var frames := maxf(float(samples.size()), 1.0)
		result["average_cpu_process_ms"] = process_ms_sum / frames
		result["average_cpu_physics_ms"] = physics_ms_sum / frames
		result["average_draw_calls"] = draw_calls_sum / frames
		result["active_shadow_lights"] = _active_shadow_light_count(_campus)
		result["interior"] = _zones.is_interior
		result["lighting_profile"] = _zones.active_profile if _zones.is_interior else "exterior"
		result["hour"] = view.time
		result["fog_enabled"] = _zones.environment.fog_enabled
		_results.append(result)
		_results_label.text += "%s: %.1f FPS | avg %.2f ms | p95 %.2f ms | %d frames\n   CPU %.2f ms | %.0f draws | %d shadow lights\n" % [view.id, result.fps, result.average_ms, result.p95_ms, result.frames, result.average_cpu_process_ms, result.average_draw_calls, result.active_shadow_lights]
		_publish(result, "BLACKSITE_BENCHMARK_VIEW")
	var report := {
		"state": "complete",
		"platform": "web" if OS.has_feature("web") else OS.get_name(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"video_vendor": RenderingServer.get_video_adapter_vendor(),
		"device_model": OS.get_model_name(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"viewport": [int(_initial_size.x), int(_initial_size.y)],
		"render_target_pixels": [int(get_viewport().get_texture().get_size().x), int(get_viewport().get_texture().get_size().y)],
		"warmup_seconds_per_view": warmup_seconds,
		"sample_seconds_per_view": sample_seconds,
		"clock": "monotonic delivered-frame intervals; display/VSync cap retained",
		"gameplay": "real campus simulation; stationary player; room review camera",
		"tab_hidden_during_run": _tab_hidden,
		"viewport_changed_during_run": _viewport_changed,
		"conditions_valid": not _tab_hidden and not _viewport_changed,
		"results": _results,
	}
	_status.text = "BENCHMARK COMPLETE — %s\n%d × %d viewport. %s\nAdapter: %s" % ["WEB" if OS.has_feature("web") else OS.get_name(), _initial_size.x, _initial_size.y, "Conditions valid." if report.conditions_valid else "INVALID CONDITIONS: tab hidden or viewport resized. Run again.", String(report.video_adapter).left(75)]
	_button.text = "RUN AGAIN"
	_button.disabled = false
	_running = false
	_publish(report, "BLACKSITE_BENCHMARK_COMPLETE")


func _set_view(view: Dictionary) -> bool:
	_cycle.set_weather_mode(CampusEnvironmentCycle.WeatherMode.NORMAL)
	_cycle.set_time_hours(float(view.time))
	if view.has("position"):
		_camera.global_position = view.position
		_camera.look_at(view.target)
	else:
		var selected: Node3D
		for candidate in get_tree().get_nodes_in_group("campus_planned_rooms"):
			if _campus.is_ancestor_of(candidate) and candidate.get_meta("plan_id") == view.plan and candidate.get_meta("room_data").id == view.room:
				selected = candidate
				break
		if selected == null:
			return false
		var data: Dictionary = selected.get_meta("room_data")
		_camera.global_position = selected.to_global(Vector3(float(data.w) * 0.27, 1.7, float(data.d) * 0.34))
		_camera.look_at(selected.to_global(Vector3(-float(data.w) * 0.15, 1.35, -float(data.d) * 0.20)))
	_camera.make_current()
	_zones.refresh_from_viewer()
	return true


func _wait_rendered_seconds(seconds: float) -> void:
	var start_us := Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - start_us) / 1000000.0 < seconds:
		await get_tree().process_frame
	_check_measurement_conditions()


func _check_measurement_conditions() -> void:
	if Vector2i(get_viewport().get_visible_rect().size) != _initial_size:
		_viewport_changed = true
	if OS.has_feature("web") and bool(JavaScriptBridge.eval("document.hidden", true)):
		_tab_hidden = true


func _summarize(view_id: String, samples: PackedFloat64Array) -> Dictionary:
	var total_ms := 0.0
	var slow_frames := 0
	for milliseconds in samples:
		total_ms += milliseconds
		if milliseconds > 33.333:
			slow_frames += 1
	var sorted := samples.duplicate()
	sorted.sort()
	var count := sorted.size()
	var average_ms := total_ms / maxf(1.0, float(count))
	var p95_index := maxi(0, ceili(float(count) * 0.95) - 1)
	return {
		"view": view_id,
		"frames": count,
		"sampled_seconds": total_ms / 1000.0,
		"average_ms": average_ms,
		"p95_ms": sorted[p95_index] if count else 0.0,
		"max_ms": sorted[count - 1] if count else 0.0,
		"fps": 1000.0 / maxf(average_ms, 0.001),
		"frames_over_33ms_percent": float(slow_frames) * 100.0 / maxf(1.0, float(count)),
		"draw_calls_last_frame": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	}


func _active_shadow_light_count(node: Node) -> int:
	var count := 0
	if node is Light3D and node.is_visible_in_tree() and node.shadow_enabled and node.light_energy > 0.0:
		count = 1
	for child in node.get_children():
		count += _active_shadow_light_count(child)
	return count


func _publish(data: Dictionary, event_name: String) -> void:
	var json := JSON.stringify(data)
	print(event_name, " ", json)
	if OS.has_feature("web"):
		# Dev/test-only JS bridge: exposes precisely the same visible results so
		# browser tools can retrieve them without parsing a canvas screenshot.
		JavaScriptBridge.eval("window.blacksiteBenchmarkResults = " + json + ";", true)
