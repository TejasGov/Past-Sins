extends StaticBody3D
class_name DevRangeFirearmControl


func get_interaction_prompt(player: Node) -> String:
	if not DevModeManager.is_enabled():
		return ""
	var controller := player.get_node_or_null("WeaponController") as PlayerWeaponController if player else null
	if controller and controller.current_firearm and controller.current_firearm.definition:
		return "[E] Refill %s Ammo" % controller.current_firearm.definition.display_name
	return "[E] Refill Firearm Ammo"


func interact(player: Node) -> void:
	if not DevModeManager.is_enabled():
		return
	var controller := player.get_node_or_null("WeaponController") as PlayerWeaponController
	if controller:
		if controller.current_firearm and controller.current_firearm.definition:
			if controller.refill_firearm_ammo(controller.current_firearm.definition.weapon_id):
				return
		if controller.refill_firearm_ammo(&"pistol"):
			return
		if controller.refill_firearm_ammo(&"smg"):
			return
		if controller.refill_firearm_ammo(&"carbine_ar"):
			return
		if controller.refill_firearm_ammo(&"sniper_rifle"):
			return
	InventoryManager.request_feedback("FIREARM REQUIRED")
