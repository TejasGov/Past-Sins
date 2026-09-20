extends StaticBody3D
class_name FirearmPickup

@export var definition: FirearmDefinition
@export var saved_magazine := -1
@export var saved_reserve := -1
@export var attached_suppressor: SuppressorDefinition
@export var suppressor_remaining_uses := -1
@export var suppressor_used_this_magazine := false

@onready var visual_mount: Node3D = $VisualMount
@onready var label: Label3D = $Label

var collected := false


func _ready() -> void:
	add_to_group("firearm_pickups")
	if definition == null or not definition.is_valid_firearm_definition():
		push_error("FirearmPickup requires a valid FirearmDefinition")
		queue_free()
		return
	if definition.dev_only and not DevModeManager.is_enabled():
		queue_free()
		return
	label.text = "%s\n[E] PICK UP" % definition.display_name.to_upper()
	if definition.world_visual_scene:
		var world_instance := definition.world_visual_scene.instantiate()
		visual_mount.add_child(world_instance)
		var visual_contract := _find_firearm_visual(world_instance)
		if visual_contract == null:
			push_error("World firearm visual must contain a FirearmVisualBase: %s" % definition.world_visual_scene.resource_path)
			queue_free()
			return
		var contract_failures := visual_contract.validate_visual_contract()
		if not contract_failures.is_empty():
			for failure in contract_failures:
				push_error("%s world visual: %s" % [definition.display_name, failure])
			queue_free()
			return
		if attached_suppressor and not visual_contract.set_suppressor_visual(attached_suppressor, definition.normalized_weapon_id()):
			push_error("Dropped suppressor is incompatible or lacks a valid socket")
			queue_free()
			return
	set_meta("weapon_id", definition.normalized_weapon_id())
	preload("res://scripts/props/interaction_affordance.gd").paint_pickup_trim(visual_mount)


func _find_firearm_visual(root: Node) -> FirearmVisualBase:
	if root is FirearmVisualBase:
		return root as FirearmVisualBase
	for child in root.get_children():
		var found := _find_firearm_visual(child)
		if found:
			return found
	return null


func get_interaction_prompt(_player: Node) -> String:
	if collected or definition == null:
		return ""
	if not InventoryManager.can_add_item(definition):
		return "%s — [G] DROP EQUIPPED" % InventoryComponent.FIREARM_SLOTS_FULL
	if attached_suppressor and InventoryManager.has_item(attached_suppressor.normalized_id()):
		return "SUPPRESSOR ALREADY OWNED"
	return "[E] Pick Up %s" % definition.display_name


func interact(player: Node) -> void:
	if collected or definition == null or (definition.dev_only and not DevModeManager.is_enabled()):
		return
	if not InventoryManager.can_add_item(definition):
		InventoryManager.add_item(definition)
		return
	var controller := player.get_node_or_null("WeaponController") as PlayerWeaponController
	if controller:
		controller.register_ammo_snapshot(definition.normalized_weapon_id(), saved_magazine, saved_reserve)
	if attached_suppressor:
		if not InventoryManager.add_item(attached_suppressor, 1, false):
			return
		if controller:
			controller.register_suppressor_snapshot(definition.normalized_weapon_id(), attached_suppressor, suppressor_remaining_uses, suppressor_used_this_magazine)
	if not InventoryManager.add_item(definition):
		if attached_suppressor: InventoryManager.remove_item(attached_suppressor.normalized_id(), 1, false)
		return
	collected = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	queue_free()
