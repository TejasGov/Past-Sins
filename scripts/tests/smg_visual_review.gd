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
	var pickup := range_scene.get_node("Interactables/SMGPickup") as FirearmPickup
	if pickup:
		pickup.interact(player)
	for frame in range(4):
		await get_tree().process_frame
	var standard := range_scene.get_node("Stations/StandardVest") as DamageableHumanDummy
	if standard:
		player.global_position = standard.global_position + Vector3(0, 0.95, 5.0)
		player.camera.look_at((standard.get_node("Body/Torso/ChestVisual") as MeshInstance3D).global_position, Vector3.UP)
	await get_tree().physics_frame
	await get_tree().process_frame
	print("SMG hip render: ", error_string(get_viewport().get_texture().get_image().save_png("/tmp/blacksite-smg-hip.png")))
	var controller := player.get_node("WeaponController") as PlayerWeaponController
	var aim_event := InputEventAction.new()
	aim_event.action = &"aim"
	aim_event.pressed = true
	controller._unhandled_input(aim_event)
	for frame in range(45):
		controller._process(1.0 / 60.0)
		await get_tree().process_frame
	await get_tree().process_frame
	print("SMG shared sight metrics: ", controller.get_sight_alignment_pixels())
	print("SMG ADS render: ", error_string(get_viewport().get_texture().get_image().save_png("/tmp/blacksite-smg-ads.png")))
	aim_event.pressed = false
	controller._unhandled_input(aim_event)
	for frame in range(40):
		controller._process(1.0 / 60.0)
		await get_tree().process_frame
	if controller.current_firearm:
		controller.current_firearm.refill_ammo()
		controller.fire()
	await get_tree().process_frame
	for frame in range(40):
		await get_tree().physics_frame
	if controller.current_firearm:
		controller.current_firearm.magazine_ammo = 1
		controller.current_firearm.reserve_ammo = 25
		controller.fire()
	for frame in range(10):
		await get_tree().physics_frame
	await get_tree().process_frame
	for frame in range(32):
		await get_tree().physics_frame
	controller.reload()
	for frame in range(20):
		await get_tree().process_frame
	await get_tree().process_frame

	# Rack review
	var rack_copy := preload("res://scenes/weapons/FirearmPickup.tscn").instantiate() as FirearmPickup
	rack_copy.definition = preload("res://resources/weapons/smg.tres")
	range_scene.get_node("Interactables").add_child(rack_copy)
	rack_copy.position = Vector3(-15.8, 0.9, 39.95)
	player.camera.current = false
	var review_camera := Camera3D.new()
	review_camera.current = true
	add_child(review_camera)
	review_camera.position = Vector3(-15.8, 2.35, 42.3)
	review_camera.look_at(Vector3(-15.8, 1.25, 39.5), Vector3.UP)
	for frame in range(4):
		await get_tree().process_frame

	print("SMG VISUAL REVIEW: PASS")
	InventoryManager.clear_all_inventory(false)
	DevModeManager.set_enabled(false)
	get_tree().quit(0)
