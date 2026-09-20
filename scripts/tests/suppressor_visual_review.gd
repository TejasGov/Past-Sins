extends Node3D

const RANGE := preload("res://scenes/dev/WeaponRange.tscn")
const WEAPONS: Array[FirearmDefinition] = [
	preload("res://resources/weapons/pistol.tres"),
	preload("res://resources/weapons/smg.tres"),
	preload("res://resources/weapons/carbine_ar.tres"),
	preload("res://resources/weapons/sniper_rifle.tres"),
]
const MAKESHIFT: SuppressorDefinition = preload("res://resources/items/makeshift_suppressor.tres")
const PROPER: SuppressorDefinition = preload("res://resources/items/proper_suppressor.tres")


func _ready() -> void:
	DevModeManager.set_enabled(true)
	var range_scene := RANGE.instantiate() as WeaponRange; add_child(range_scene)
	for _frame in range(8): await get_tree().process_frame
	var player := DevModeManager.get_player() as PlayerController
	var controller := player.get_node("WeaponController") as PlayerWeaponController
	for definition in WEAPONS:
		InventoryManager.clear_all_inventory(false)
		InventoryManager.add_item(definition, 1, false)
		var suppressor := MAKESHIFT if definition.normalized_weapon_id() in [&"pistol", &"smg"] else PROPER
		InventoryManager.add_item(suppressor, 1, false)
		controller.equip_slot(0)
		controller.attach_suppressor(suppressor.item_id)
		for _frame in range(8): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/blacksite-%s-suppressed.png" % definition.normalized_weapon_id())
	get_tree().quit()

