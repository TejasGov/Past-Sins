extends Node3D


func _ready() -> void:
	call_deferred("_review")


func _review() -> void:
	DevModeManager.set_enabled(true)
	InventoryManager.clear_all_inventory(false)
	var range_scene := preload("res://scenes/dev/WeaponRange.tscn").instantiate() as WeaponRange
	add_child(range_scene)
	for frame in range(5): await get_tree().process_frame
	var player := range_scene.get_node("Actors/WeaponRangePlayer") as PlayerController
	var pickup := range_scene.get_node("Interactables/SniperRiflePickup") as FirearmPickup
	pickup.interact(player)
	for frame in range(5): await get_tree().process_frame
	var target := range_scene.get_node("Stations/AdvancedVest") as DamageableHumanDummy
	player.global_position = target.global_position + Vector3(0, 0.95, 8.0)
	player.camera.look_at((target.get_node("Body/Torso/ChestVisual") as MeshInstance3D).global_position, Vector3.UP)
	await get_tree().process_frame
	var controller := player.get_node("WeaponController") as PlayerWeaponController
	print("Sniper hip render: ", error_string(get_viewport().get_texture().get_image().save_png("/tmp/blacksite-sniper-hip.png")))
	controller._set_aim_held(true)
	for frame in range(50):
		controller._process(1.0 / 60.0)
		await get_tree().process_frame
	print("Sniper shared sight metrics: ", controller.get_sight_alignment_pixels())
	print("Sniper ADS render: ", error_string(get_viewport().get_texture().get_image().save_png("/tmp/blacksite-sniper-ads.png")))
	controller.fire()
	await get_tree().process_frame
	print("Sniper fire render: ", error_string(get_viewport().get_texture().get_image().save_png("/tmp/blacksite-sniper-fire.png")))
	controller._set_aim_held(false)
	for frame in range(25): await get_tree().process_frame
	controller.current_firearm.magazine_ammo = 0
	controller.current_firearm.reserve_ammo = 5
	controller.reload()
	for frame in range(55): await get_tree().process_frame
	print("Sniper reload render: ", error_string(get_viewport().get_texture().get_image().save_png("/tmp/blacksite-sniper-reload.png")))

	var rack_copy := preload("res://scenes/weapons/FirearmPickup.tscn").instantiate() as FirearmPickup
	rack_copy.definition = preload("res://resources/weapons/sniper_rifle.tres")
	range_scene.get_node("Interactables").add_child(rack_copy)
	rack_copy.position = Vector3(-3.8, 0.9, 39.95)
	player.camera.current = false
	var review_camera := Camera3D.new()
	review_camera.current = true
	add_child(review_camera)
	review_camera.position = Vector3(-3.8, 2.5, 43.0)
	review_camera.look_at(Vector3(-3.8, 1.2, 39.7), Vector3.UP)
	for frame in range(5): await get_tree().process_frame
	print("Sniper rack render: ", error_string(get_viewport().get_texture().get_image().save_png("/tmp/blacksite-sniper-rack.png")))
	print("SNIPER RIFLE VISUAL REVIEW: PASS")
	InventoryManager.clear_all_inventory(false)
	DevModeManager.set_enabled(false)
	get_tree().quit(0)
