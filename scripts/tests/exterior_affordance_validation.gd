extends Node3D

const CAMPUS := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn")
const Affordance := preload("res://scripts/props/interaction_affordance.gd")
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var campus := CAMPUS.instantiate() as Node3D
	campus.set("gameplay_enabled", false)
	var cycle := campus.get_node("EnvironmentCycle")
	cycle.set("cycle_enabled", false)
	cycle.set("roll_weather_on_start", false)
	cycle.set("start_time_hours", 22.0)
	add_child(campus)
	for frame in range(5): await get_tree().physics_frame
	var beams := campus.find_children("SearchlightBeam", "SpotLight3D", true, false)
	_check(beams.size() == 3, "Exterior must retain only three real tower beams")
	for beam: SpotLight3D in beams:
		_check(beam.visible and beam.shadow_enabled, "Night floodlight must be visible and shadow casting")
		var forward := -beam.global_basis.z.normalized()
		_check(forward.y < -0.45, "Spotlight must pitch toward the ground, not emit horizontally")
		_check(forward.dot(beam.get_parent().global_basis.z.normalized()) > 0.999, "Light direction must match its physical +Z lens")
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(beam.global_position, beam.global_position + forward * beam.spot_range, 1))
		_check(not hit.is_empty(), "Searchlight axis must actually reach collision-backed yard/service ground")
		if not hit.is_empty():
			print("FLOODLIGHT AXIS: ", beam.get_parent().get_parent().get_parent().name, " -> ", hit.position, " ", hit.collider.get_path())
			_check((hit.position as Vector3).y < 0.3, "Light cannot be blocked by its own roof or an adjacent building")
		_check(beam.spot_angle <= 28.0, "Narrow beam pools must retain dark gaps")
	cycle.call("set_time_hours", 12.0)
	for beam: SpotLight3D in beams: _check(not beam.visible, "Tower beam must switch off during daylight")
	var gate := preload("res://scenes/interactables/PrisonSlidingGate.tscn").instantiate() as PrisonSlidingGate
	gate.reader_light_enabled = false
	gate.position = Vector3(0, 0, 250)
	add_child(gate)
	_check(gate.get_node("KeyReader/ReaderBody").material_override == Affordance.HAZARD, "Usable gate reader must have consistent painted trim")
	_check(gate.is_locked and not gate.blocker.disabled, "Affordance changes must not unlock gate or clear collision")
	_check(gate.get_node("KeyReader/StatusLED").material_override.emission_energy_multiplier <= 1.3, "Indicator must be a modest colored point, not a room lamp")
	await get_tree().physics_frame
	var reader := gate.get_node("KeyReader") as StaticBody3D
	var reader_hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(reader.to_global(Vector3(0, 0, 1)), reader.global_position, 5))
	_check(not reader_hit.is_empty() and reader_hit.collider == reader, "Painted reader itself must be reachable by the existing player interaction ray")
	_check(reader.collision_layer == 4, "Control affordance must not introduce a walking obstruction")
	var locker := preload("res://scenes/interactables/KeypadLocker.tscn").instantiate() as KeypadLocker
	locker.position = Vector3(4, 0, 250)
	add_child(locker)
	_check(locker.keypad.material_override == Affordance.HAZARD, "Usable locker keypad must share hazard bezel")
	_check(locker.keypad.has_node("StatusLED") and locker.keypad.has_node("KeypadFace"), "Locker must have separate dark face and tiny status light")
	_check(not locker.is_open and not locker.blocker.disabled, "Locker interaction state must be preserved")
	# Test source world scenes directly: same reusable visual marking method as
	# pickups, without granting inventory, loading a combat scene or emitting lights.
	for resource_path in ["res://resources/weapons/pistol.tres", "res://resources/weapons/smg.tres", "res://resources/weapons/carbine_ar.tres", "res://resources/weapons/sniper_rifle.tres", "res://resources/weapons/kitchen_knife.tres", "res://resources/weapons/improvised_slingshot.tres", "res://resources/items/monocular.tres"]:
		var definition := load(resource_path) as Resource
		var visual := (definition.get("world_visual_scene") as PackedScene).instantiate()
		add_child(visual)
		var mesh_count := visual.find_children("*", "MeshInstance3D", true, false).size()
		Affordance.paint_pickup_trim(visual)
		var marked := false
		for piece in visual.find_children("*", "MeshInstance3D", true, false):
			if piece.has_meta("pickup_affordance_trim"):
				marked = true
				_check(piece.material_override == Affordance.HAZARD, "World item trim must use shared painted material")
		_check(marked, "Pickup visual must expose readable existing trim: " + resource_path)
		_check(visual.find_children("*", "MeshInstance3D", true, false).size() == mesh_count, "Pickup affordance must add no meshes/lights")
		visual.queue_free()
	for message in failures: push_error(message)
	print("EXTERIOR / AFFORDANCE VALIDATION: ", "PASS" if failures.is_empty() else "FAIL", " — three downward night beams, physical source alignment, shared painted access cues, no added pickup meshes")
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
