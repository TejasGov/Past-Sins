extends Node

const MAIN_SCENE := preload("res://scenes/levels/CellBlockPrototype.tscn")


func _ready() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	var level := MAIN_SCENE.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().create_timer(0.12).timeout
	var minimap := level.get_node("CanvasLayer/HUD/Minimap") as PrisonMinimap
	var player := level.get_node("Actors/Player") as PlayerController
	assert(minimap != null and minimap.visible, "Minimap should be visible by default")
	assert(minimap.find_children("*", "Camera3D", true, false).is_empty(), "Minimap must not use a second 3D camera")
	assert(minimap.find_children("*", "SubViewport", true, false).is_empty(), "Minimap must not use a render texture")
	assert(minimap.get_floor_id() == "F3", "Spawn should display Floor 3")
	assert(minimap.get_visible_access_marker_count() > 10, "Floor 3 access markers are missing")

	player.global_position = Vector3(0, -3.05, 35.0)
	await get_tree().create_timer(0.12).timeout
	assert(minimap.get_floor_id() == "YARD", "Minimap did not switch to the outdoor yard")
	player.global_position = Vector3(0, -3.05, 0.0)
	await get_tree().create_timer(0.12).timeout
	assert(minimap.get_floor_id() == "GROUND", "Minimap did not return to the Ground Floor")
	minimap.toggle_minimap()
	assert(not minimap.visible, "Minimap toggle did not hide the map")
	minimap.toggle_minimap()
	assert(minimap.visible, "Minimap toggle did not restore the map")

	print("MINIMAP_VALIDATION: PASS — north-up current-floor map, access markers, yard switching, and toggle verified")
	get_tree().quit(0)
