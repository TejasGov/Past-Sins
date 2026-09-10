extends Resource
class_name ItemDefinition

## Data-only description shared by pickups, inventories and future item systems.
## It intentionally contains no weapon, attack, ammunition or combat behavior.
enum Category {
	FIREARM,
	MELEE,
	EQUIPMENT,
	KEY,
	ACCESS_CARD,
	MISSION_ITEM,
	AMMO,
}

@export var item_id: StringName = &""
@export var display_name := "Item"
@export var category: Category = Category.EQUIPMENT
@export var stackable := false
## Zero means unlimited. This is inventory capacity only; AMMO remains an inert
## future category with no firing/reload semantics.
@export_range(0, 999, 1) var max_stack_size := 0
@export var dev_only := false


func is_valid_definition() -> bool:
	return not normalized_id().is_empty() and not display_name.strip_edges().is_empty()


func normalized_id() -> StringName:
	return StringName(str(item_id).strip_edges().to_lower())


func is_unique() -> bool:
	return not stackable


func category_name() -> String:
	return Category.keys()[int(category)].capitalize()
