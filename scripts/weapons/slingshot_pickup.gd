extends MeleePickup
class_name SlingshotPickup

@export_range(0, 48, 1) var starter_nails := 12


func interact(player_node: Node) -> void:
	if collected or definition == null or (definition.dev_only and not DevModeManager.is_enabled()): return
	if not InventoryManager.add_item(definition): return
	if starter_nails > 0 and definition is SlingshotDefinition:
		InventoryManager.add_item((definition as SlingshotDefinition).normal_ammo, starter_nails)
	collected = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	queue_free()
