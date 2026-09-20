extends Node3D

const RANGE := preload("res://scenes/dev/WeaponRange.tscn")
const SLINGSHOT: SlingshotDefinition = preload("res://resources/weapons/improvised_slingshot.tres")


func _ready() -> void:
	DevModeManager.set_enabled(true)
	var range_scene := RANGE.instantiate()
	add_child(range_scene)
	for _frame in range(8): await get_tree().process_frame
	InventoryManager.clear_all_inventory(false)
	InventoryManager.add_item(SLINGSHOT)
	InventoryManager.add_item(SLINGSHOT.normal_ammo, 12)
	var player := DevModeManager.get_player()
	var controller := player.get_node("MeleeController") as PlayerMeleeController
	controller.equip_melee_slot()
	for _frame in range(6): await get_tree().process_frame
	await _capture("/tmp/blacksite-slingshot-idle.png")
	controller._aim_held = true
	for _frame in range(24): await get_tree().process_frame
	await _capture("/tmp/blacksite-slingshot-aim.png")
	controller.current_slingshot.begin_draw()
	for _frame in range(45): await get_tree().physics_frame
	await _capture("/tmp/blacksite-slingshot-full-draw.png")
	controller.current_slingshot.release_draw(player.get_node("Head/Camera3D") as Camera3D, player)
	for _frame in range(5): await get_tree().physics_frame
	await _capture("/tmp/blacksite-slingshot-flight.png")
	get_tree().quit()


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
