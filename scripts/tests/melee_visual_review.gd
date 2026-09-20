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
	var controller := player.get_node("MeleeController") as PlayerMeleeController
	var target := range_scene.get_node("Stations/MeleeResetTarget") as DamageableHumanDummy
	player.global_position = target.global_position + Vector3(0, 0, 1.2)
	player.camera.look_at((target.get_node("Body/Torso/ChestVisual") as MeshInstance3D).global_position, Vector3.UP)

	for data in [
		[preload("res://resources/weapons/kitchen_knife.tres"), "/tmp/blacksite-knife-hip.png", "/tmp/blacksite-knife-swing.png"],
	]:
		controller.unequip_current()
		InventoryManager.clear_melee_slot()
		InventoryManager.add_item(data[0] as MeleeDefinition)
		controller.equip_melee_slot()
		for frame in range(3): await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(String(data[1]))
		controller.attack()
		for frame in range(9): await get_tree().physics_frame
		get_viewport().get_texture().get_image().save_png(String(data[2]))
		for frame in range(50): await get_tree().physics_frame

	print("MELEE VISUAL REVIEW: PASS")
	InventoryManager.clear_all_inventory(false)
	DevModeManager.set_enabled(false)
	get_tree().quit(0)
