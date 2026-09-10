extends StaticBody3D
class_name DevRangeFirearmControl


func get_interaction_prompt(_player: Node) -> String:
	return "[E] Refill Pistol Ammo" if DevModeManager.is_enabled() else ""


func interact(player: Node) -> void:
	if not DevModeManager.is_enabled():
		return
	var controller := player.get_node_or_null("WeaponController") as PlayerWeaponController
	if controller and controller.refill_firearm_ammo(&"pistol"):
		return
	InventoryManager.request_feedback("PISTOL REQUIRED")
