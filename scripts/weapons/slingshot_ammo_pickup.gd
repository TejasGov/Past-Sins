extends StaticBody3D
class_name SlingshotAmmoPickup

@export var item_definition: ItemDefinition
@export_range(1, 48, 1) var quantity := 1
var collected := false


func _ready() -> void:
	add_to_group("slingshot_ammo_pickups")
	if item_definition == null or item_definition.category != ItemDefinition.Category.AMMO:
		push_error("SlingshotAmmoPickup requires an AMMO ItemDefinition")
		queue_free()
		return
	if item_definition.dev_only and not DevModeManager.is_enabled():
		queue_free()
		return
	$Label.text = "%s x%d\n[E] PICK UP" % [item_definition.display_name.to_upper(), quantity]
	var material := ($Nail.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	if item_definition.item_id == &"slingshot_nail_toxin": material.albedo_color = Color("6f925a")
	$Nail.material_override = material


func get_interaction_prompt(_player: Node) -> String:
	return "" if collected else "[E] Pick Up %s x%d" % [item_definition.display_name, quantity]


func interact(_player: Node) -> void:
	if collected or not InventoryManager.add_item(item_definition, quantity): return
	collected = true
	queue_free()
