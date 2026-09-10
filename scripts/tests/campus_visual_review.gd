extends Node3D

## Developer-only native renderer review. Generates local screenshots, never
## changes the game save, input bindings, or shipped player spawn.
func _ready() -> void:
	call_deferred("_review")

func _review() -> void:
	var campus := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn").instantiate()
	campus.gameplay_enabled = false
	add_child(campus)
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 78.0
	add_child(camera)
	var views := [
		["campus-overview", Vector3(0, 156, 22), Vector3(0, 0, 0)],
		["campus-oblique", Vector3(-112, 92, 122), Vector3(0, 0, 0)],
		["cellhouse", Vector3(-45, 9.7, 9), Vector3(-68, 7.0, -7)],
		["cellhouse-b-duty", Vector3(48, 1.7, -8), Vector3(50, 1.2, 1)],
		["cafeteria", Vector3(-48, 1.7, -45), Vector3(-57, 1.2, -52)],
		["kitchen", Vector3(-48, 1.7, -57), Vector3(-38, 1.2, -63)],
		["medical", Vector3(-61, 1.7, 54), Vector3(-55, 1.1, 48)],
		["gym", Vector3(-42, 1.7, 55), Vector3(-36, 1.2, 48)],
		["showers", Vector3(-48, 1.7, 64), Vector3(-48, 1.2, 57)],
		["lab", Vector3(48, -6.3, -48), Vector3(48, -6.8, -55)],
		["hq", Vector3(48, 5.7, -48), Vector3(48, 5.2, -55)],
		["maintenance", Vector3(48, 1.7, 46), Vector3(48, 1.2, 54)],
		["administration", Vector3(0, 1.7, 65), Vector3(0, 1.2, 73)],
		["central-yard", Vector3(0, 9, 22), Vector3(0, 0.5, 0)],
		["annex", Vector3(-31, 10, 51), Vector3(-14, 0.4, 42.5)]
	]
	for view in views:
		camera.global_position = view[1]
		camera.look_at(view[2])
		for frame in range(4): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var result := get_viewport().get_texture().get_image().save_png("/tmp/campus-review-%s.png" % view[0])
		print("Native render ", view[0], ": ", error_string(result))
	get_tree().quit()
