extends Node3D


func _ready() -> void:
	call_deferred("_review")


func _review() -> void:
	DevModeManager.set_enabled(true)
	var range_scene := preload("res://scenes/dev/WeaponRange.tscn").instantiate() as WeaponRange
	add_child(range_scene)
	for frame in range(4): await get_tree().process_frame
	var ceiling := range_scene.get_node_or_null("Geometry/ConcreteCeiling") as MeshInstance3D
	if ceiling: ceiling.visible = false
	var player_camera := get_viewport().get_camera_3d()
	if player_camera: player_camera.current = false
	var camera := Camera3D.new()
	camera.current = true
	add_child(camera)
	camera.position = Vector3(0, 62, 25)
	camera.look_at(Vector3(0, 0.8, -2))
	for frame in range(4): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("Weapon range overview render: ", error_string(get_viewport().get_texture().get_image().save_png("/tmp/blacksite-weapon-range-overview.png")))
	if ceiling: ceiling.visible = true
	camera.position = Vector3(0, 2.0, 43.5)
	camera.look_at(Vector3(0, 1.5, -18))
	for frame in range(4): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("Weapon range interior render: ", error_string(get_viewport().get_texture().get_image().save_png("/tmp/blacksite-weapon-range-interior.png")))
	DevModeManager.set_enabled(false)
	get_tree().quit()
