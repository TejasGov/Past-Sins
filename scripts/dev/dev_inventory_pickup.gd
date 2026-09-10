extends StaticBody3D
class_name DevInventoryPickup

## Data-only range pickup. It grants an ItemDefinition to InventoryManager and
## deliberately has no equipping, attack, firing or item-use behavior.
@export var item_definition: ItemDefinition
@export_range(1, 99, 1) var pickup_quantity := 1

@onready var visual: MeshInstance3D = $Visual
@onready var item_label: Label3D = $ItemLabel

var collected := false


func _ready() -> void:
	add_to_group("dev_inventory_pickups")
	if not DevModeManager.is_enabled():
		queue_free()
		return
	if item_definition == null or not item_definition.is_valid_definition() or not item_definition.dev_only:
		push_error("DevInventoryPickup requires a valid DEV-only ItemDefinition")
		queue_free()
		return
	item_label.text = "%s\n[E] PICK UP" % item_definition.display_name
	var material := StandardMaterial3D.new()
	material.albedo_color = _category_color(item_definition.category)
	material.roughness = 0.72
	visual.material_override = material
	set_meta("item_id", item_definition.normalized_id())
	set_meta("item_category", item_definition.category_name())


func get_interaction_prompt(_player: Node) -> String:
	if collected or item_definition == null:
		return ""
	return "[E] Pick Up %s" % item_definition.display_name


func interact(_player: Node) -> void:
	if collected or not DevModeManager.is_enabled() or item_definition == null:
		return
	if InventoryManager.add_item(item_definition, pickup_quantity):
		collected = true
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		queue_free()


func _category_color(category: ItemDefinition.Category) -> Color:
	match category:
		ItemDefinition.Category.FIREARM:
			return Color("bd704f")
		ItemDefinition.Category.MELEE:
			return Color("d2aa48")
		_:
			return Color("4e9b87")
