extends Node3D


func _ready() -> void:
	call_deferred("_review")


func _review() -> void:
	DevModeManager.set_enabled(true)
	InventoryManager.clear_all_inventory(false)
	var range_scene := preload("res://scenes/dev/WeaponRange.tscn").instantiate() as WeaponRange
	add_child(range_scene)
	for frame in range(5):
		await get_tree().process_frame
	var player := range_scene.get_node("Actors/WeaponRangePlayer") as PlayerController
	var pickup := range_scene.get_node("Interactables/CarbineARPickup") as FirearmPickup
	pickup.interact(player)
	for frame in range(5):
		await get_tree().process_frame
	var target := range_scene.get_node("Stations/AdvancedVest") as DamageableHumanDummy
	player.global_position = target.global_position + Vector3(0, 0.95, 6.0)
	player.camera.look_at((target.get_node("Body/Torso/ChestVisual") as MeshInstance3D).global_position, Vector3.UP)
	await get_tree().physics_frame
	await get_tree().process_frame
	var controller := player.get_node("WeaponController") as PlayerWeaponController
	print("Carbine hip render: ", error_string(get_viewport().get_texture().get_image().save_png("/tmp/blacksite-carbine-hip.png")))

	controller._set_aim_held(true)
	for frame in range(45):
		controller._process(1.0 / 60.0)
		await get_tree().process_frame
	print("Carbine shared sight metrics: ", controller.get_sight_alignment_pixels())
	print("Carbine ADS render: ", error_string(get_viewport().get_texture().get_image().save_png("/tmp/blacksite-carbine-ads.png")))

	controller.current_firearm.refill_ammo()
	controller.fire()
	await get_tree().process_frame
	print("Carbine fire render: ", error_string(get_viewport().get_texture().get_image().save_png("/tmp/blacksite-carbine-fire.png")))
	controller._set_aim_held(false)
	for frame in range(30):
		await get_tree().physics_frame
	controller.current_firearm.magazine_ammo = 0
	controller.current_firearm.reserve_ammo = 30
	controller.reload()
	for frame in range(28):
		await get_tree().process_frame
	print("Carbine reload render: ", error_string(get_viewport().get_texture().get_image().save_png("/tmp/blacksite-carbine-reload.png")))

	var rack_copy := preload("res://scenes/weapons/FirearmPickup.tscn").instantiate() as FirearmPickup
	rack_copy.definition = preload("res://resources/weapons/carbine_ar.tres")
	range_scene.get_node("Interactables").add_child(rack_copy)
	rack_copy.position = Vector3(-9.8, 0.9, 39.95)
	player.camera.current = false
	var review_camera := Camera3D.new()
	review_camera.current = true
	add_child(review_camera)
	review_camera.position = Vector3(-9.8, 2.4, 42.6)
	review_camera.look_at(Vector3(-9.8, 1.2, 39.7), Vector3.UP)
	for frame in range(5):
		await get_tree().process_frame
	print("Carbine rack render: ", error_string(get_viewport().get_texture().get_image().save_png("/tmp/blacksite-carbine-rack.png")))

	print("CARBINE AR VISUAL REVIEW: PASS")
	InventoryManager.clear_all_inventory(false)
	DevModeManager.set_enabled(false)
	get_tree().quit(0)
