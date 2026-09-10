extends Node3D

func _ready() -> void:
	call_deferred("_review")

func _review() -> void:
	var campus := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn").instantiate()
	campus.set("gameplay_enabled", false)
	add_child(campus)
	var player := preload("res://scenes/player/Player.tscn").instantiate() as PlayerController
	campus.get_node("Actors").add_child(player)
	player.set_physics_process(false)
	await get_tree().process_frame
	var map := get_tree().get_first_node_in_group("minimap") as PrisonMinimap
	map._find_player()
	var door: NormalDoor
	for candidate in get_tree().get_nodes_in_group("normal_doors"):
		if String(candidate.get_path()).contains("MedicalGround/Access_gym"):
			door = candidate
			break
	assert(door != null)
	for side in [1.0, -1.0]:
		player.global_position = door.to_global(Vector3(0, 1.0, side * 2.5))
		player.camera.look_at(door.to_global(Vector3(0, 1.4, 0)))
		await _capture("door-front" if side > 0 else "door-back")
	player.global_position = Vector3(-27, 1.6, 48)
	player.camera.look_at(Vector3(-14, -0.8, 42.5))
	await _capture("pool-deck")
	player.global_position = Vector3(-14, -1.48, 42.5)
	player.camera.look_at(Vector3(-5, -1.1, 42.5))
	await _capture("pool-underwater")
	player.global_position = Vector3(-14, 0.95, 49)
	player.camera.look_at(Vector3(-5, -0.5, 42.5))
	await _capture("pool-surfaced")
	get_tree().quit()

func _capture(label: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png("/tmp/campus-feedback-%s.png" % label)
	print("VISUAL ", label, " ", error_string(result))
