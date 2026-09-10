extends Node3D


func _ready() -> void:
	call_deferred("_review")


func _review() -> void:
	DevModeManager.set_enabled(true)
	var campus := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn").instantiate() as PrisonCampusPrototype
	campus.gameplay_enabled = false
	add_child(campus)
	for frame in range(5): await get_tree().process_frame
	DevModeManager.set_menu_open(true)
	for frame in range(4): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("Dev menu render: ", error_string(get_viewport().get_texture().get_image().save_png("/tmp/blacksite-dev-menu.png")))
	DevModeManager.set_menu_open(false)
	campus.free()
	await get_tree().process_frame

	var hub := preload("res://scenes/dev/DevTestHub.tscn").instantiate() as DevTestHub
	add_child(hub)
	await get_tree().process_frame
	var player_camera := get_viewport().get_camera_3d()
	if player_camera: player_camera.current = false
	var camera := Camera3D.new()
	camera.current = true
	add_child(camera)
	camera.position = Vector3(0, 18, 31)
	camera.look_at(Vector3(0, 1.5, 0))
	for frame in range(4): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("Dev hub render: ", error_string(get_viewport().get_texture().get_image().save_png("/tmp/blacksite-dev-test-hub.png")))
	hub.free()
	DevModeManager.set_enabled(false)
	await get_tree().process_frame
	get_tree().quit()
