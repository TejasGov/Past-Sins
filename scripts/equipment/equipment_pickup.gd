extends StaticBody3D
class_name EquipmentPickup

const MonocularDefinitionScript := preload("res://scripts/equipment/monocular_definition.gd")
const SuppressorDefinitionScript := preload("res://scripts/weapons/suppressor_definition.gd")

@export var definition: ItemDefinition
@onready var visual_mount: Node3D = $VisualMount
@onready var label: Label3D = $Label
var collected := false


func _ready() -> void:
	add_to_group("equipment_pickups")
	if definition == null or not definition.is_valid_definition() or definition.category != ItemDefinition.Category.EQUIPMENT:
		push_error("EquipmentPickup requires a valid EQUIPMENT definition"); queue_free(); return
	if definition.dev_only and not DevModeManager.is_enabled(): queue_free(); return
	label.text = "%s\n[E] PICK UP" % definition.display_name.to_upper()
	if definition is MonocularDefinitionScript:
		visual_mount.add_child(definition.get("world_visual_scene").instantiate())
	elif definition is SuppressorDefinitionScript:
		if not definition.call("is_valid_suppressor"):
			push_error("EquipmentPickup requires a valid suppressor definition"); queue_free(); return
		visual_mount.add_child(definition.get("world_visual_scene").instantiate())
	preload("res://scripts/props/interaction_affordance.gd").paint_pickup_trim(visual_mount)


func get_interaction_prompt(_player: Node) -> String:
	if collected or definition == null: return ""
	return "[E] Pick Up %s" % definition.display_name if InventoryManager.can_add_item(definition) else InventoryComponent.ITEM_ALREADY_OWNED


func interact(_player: Node) -> void:
	if collected or definition == null: return
	if not InventoryManager.add_item(definition): return
	collected = true
	set_deferred("collision_layer", 0)
	queue_free()
