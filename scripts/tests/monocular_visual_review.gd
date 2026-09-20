extends Node3D

const RANGE := preload("res://scenes/dev/WeaponRange.tscn")
const MONOCULAR: ItemDefinition = preload("res://resources/items/monocular.tres")


func _ready() -> void:
	DevModeManager.set_enabled(true)
	var range_scene := RANGE.instantiate() as WeaponRange; add_child(range_scene)
	for _frame in range(8): await get_tree().process_frame
	InventoryManager.clear_all_inventory(false); InventoryManager.add_item(MONOCULAR, 1, false)
	var player := DevModeManager.get_player() as PlayerController
	player.global_transform = range_scene.get_node("ObservationSpawn").global_transform
	var equipment: Variant = player.get_node("EquipmentController")
	equipment.toggle_selected(); equipment.activate()
	for _frame in range(35): await get_tree().process_frame
	await _capture("/tmp/blacksite-monocular-1x.png")
	equipment.set_zoom_state(1)
	for _frame in range(45): equipment._process(0.016)
	await _capture("/tmp/blacksite-monocular-3x.png")
	equipment.set_zoom_state(2)
	for _frame in range(45): equipment._process(0.016)
	await _capture("/tmp/blacksite-monocular-6x.png")
	equipment.set_zoom_state(3)
	for _frame in range(45): equipment._process(0.016)
	await _capture("/tmp/blacksite-monocular-8x.png")
	get_tree().quit()


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
