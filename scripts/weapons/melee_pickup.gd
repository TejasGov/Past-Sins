extends StaticBody3D
class_name MeleePickup

@export var definition: MeleeDefinition

@onready var visual_mount: Node3D = $VisualMount
@onready var label: Label3D = $Label

var collected := false


func _ready() -> void:
	add_to_group("melee_pickups")
	if definition == null or not definition.is_valid_melee_definition():
		push_error("MeleePickup requires a valid MeleeDefinition")
		queue_free()
		return
	if definition.dev_only and not DevModeManager.is_enabled():
		queue_free()
		return
	label.text = "%s\n[E] PICK UP" % definition.display_name.to_upper()
	var instance := definition.world_visual_scene.instantiate()
	visual_mount.add_child(instance)
	var visual := _find_melee_visual(instance)
	if visual == null:
		push_error("World melee visual must contain MeleeVisualBase: %s" % definition.world_visual_scene.resource_path)
		queue_free()
		return
	for failure in visual.validate_visual_contract():
		push_error("%s world visual: %s" % [definition.display_name, failure])
	set_meta("melee_id", definition.normalized_melee_id())
	preload("res://scripts/props/interaction_affordance.gd").paint_pickup_trim(visual_mount)


func get_interaction_prompt(_player: Node) -> String:
	if collected or definition == null:
		return ""
	if not InventoryManager.can_add_item(definition):
		return "%s — [G] DROP EQUIPPED" % InventoryComponent.MELEE_SLOT_FULL
	return "[E] Pick Up %s" % definition.display_name


func interact(_player: Node) -> void:
	if collected or definition == null or (definition.dev_only and not DevModeManager.is_enabled()):
		return
	if not InventoryManager.add_item(definition):
		return
	collected = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	queue_free()


func _find_melee_visual(root: Node) -> MeleeVisualBase:
	if root is MeleeVisualBase: return root as MeleeVisualBase
	for child in root.get_children():
		var found := _find_melee_visual(child)
		if found: return found
	return null
