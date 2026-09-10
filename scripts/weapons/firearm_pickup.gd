extends StaticBody3D
class_name FirearmPickup

@export var definition: FirearmDefinition
@export var saved_magazine := -1
@export var saved_reserve := -1

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
		visual_mount.add_child(definition.world_visual_scene.instantiate())
	set_meta("weapon_id", definition.normalized_weapon_id())


func get_interaction_prompt(_player: Node) -> String:
	if collected or definition == null:
		return ""
	if not InventoryManager.can_add_item(definition):
		return "[E] %s" % InventoryComponent.FIREARM_SLOTS_FULL
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
	if not InventoryManager.add_item(definition):
		return
	collected = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	queue_free()
