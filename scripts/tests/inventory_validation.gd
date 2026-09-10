extends Node

const RANGE := preload("res://scenes/dev/WeaponRange.tscn")
const FIREARM_A: ItemDefinition = preload("res://resources/items/dev/test_firearm_a.tres")
const FIREARM_B: ItemDefinition = preload("res://resources/items/dev/test_firearm_b.tres")
const FIREARM_C: ItemDefinition = preload("res://resources/items/dev/test_firearm_c.tres")
const MELEE_A: ItemDefinition = preload("res://resources/items/dev/test_melee_a.tres")
const MELEE_B: ItemDefinition = preload("res://resources/items/dev/test_melee_b.tres")
const EQUIPMENT: ItemDefinition = preload("res://resources/items/dev/test_equipment.tres")
const STACKABLE: ItemDefinition = preload("res://resources/items/dev/test_stackable_equipment.tres")

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	DevModeManager.set_enabled(false)
	InventoryManager.clear_all_inventory(false)
	_check(DevModeManager.get_node_or_null("DevMenu") == null, "Play Mode must not expose inventory test UI")
	_check(ItemDefinition.Category.keys() == ["FIREARM", "MELEE", "EQUIPMENT", "KEY", "ACCESS_CARD", "MISSION_ITEM", "AMMO"], "Required data-driven item categories are incomplete")

	_check(InventoryManager.add_item(FIREARM_A, 1, false), "First firearm must be accepted")
	_check(InventoryManager.get_firearm_slot(InventoryComponent.FIREARM_SLOT_1) == FIREARM_A, "First firearm must fill firearm slot 1")
	_check(InventoryManager.add_item(FIREARM_B, 1, false), "Second firearm must be accepted")
	_check(InventoryManager.get_firearm_slot(InventoryComponent.FIREARM_SLOT_2) == FIREARM_B, "Second firearm must fill firearm slot 2")
	_check(not InventoryManager.add_item(FIREARM_C, 1, false), "Third firearm must be rejected")
	_check(InventoryManager.get_last_feedback() == InventoryComponent.FIREARM_SLOTS_FULL and not InventoryManager.has_item(FIREARM_C.item_id), "Full firearm slots must report FIREARM SLOTS FULL without replacement")

	_check(InventoryManager.add_item(MELEE_A, 1, false), "First melee item must fill the melee slot")
	_check(InventoryManager.get_melee_slot() == MELEE_A, "Melee slot did not retain its item")
	_check(not InventoryManager.add_item(MELEE_B, 1, false), "Second melee item must be rejected")
	_check(InventoryManager.get_last_feedback() == InventoryComponent.MELEE_SLOT_FULL and InventoryManager.get_melee_slot() == MELEE_A, "Occupied melee slot must report MELEE SLOT FULL without replacement")

	_check(InventoryManager.add_item(EQUIPMENT, 1, false), "Unique equipment must be accepted")
	_check(InventoryManager.get_firearm_slot(0) == FIREARM_A and InventoryManager.get_melee_slot() == MELEE_A, "Equipment must not consume or replace weapon slots")
	_check(not InventoryManager.add_item(EQUIPMENT, 1, false) and InventoryManager.get_last_feedback() == InventoryComponent.ITEM_ALREADY_OWNED, "Unique equipment must reject duplicate ownership")
	_check(InventoryManager.add_item(STACKABLE, 1, false) and InventoryManager.add_item(STACKABLE, 1, false), "Stackable equipment must accept repeated additions")
	_check(InventoryManager.get_item_count(STACKABLE.item_id) == 2, "Stackable equipment quantity must increment")
	var access_card := ItemDefinition.new()
	access_card.item_id = &"validation_access_card"
	access_card.display_name = "Validation Access Card"
	access_card.category = ItemDefinition.Category.ACCESS_CARD
	_check(InventoryManager.add_item(access_card, 1, false) and AccessManager.has_key(access_card.item_id), "Access cards in generic inventory must remain compatible with existing doors")
	_check(AccessManager.remove_key(access_card.item_id) and not InventoryManager.has_item(access_card.item_id), "Existing AccessManager removal must update generic inventory")

	DevModeManager.set_enabled(true)
	await get_tree().process_frame
	var range_scene := RANGE.instantiate() as WeaponRange
	add_child(range_scene)
	await get_tree().process_frame
	var pickups := _owned_group(range_scene, "dev_inventory_pickups")
	_check(pickups.size() == 7, "Weapons Test Range must place all seven DEV inventory placeholders")
	for pickup in pickups:
		_check((pickup as DevInventoryPickup).item_definition.dev_only, "Range inventory pickups must use DEV-only definitions")

	var menu := DevModeManager.get_node_or_null("DevMenu") as DevMenu
	_check(menu != null, "Dev Mode must create the inventory test menu")
	if menu:
		menu.refresh_all()
		var summary_found := false
		for child in menu.find_children("*", "RichTextLabel", true, false):
			var text := (child as RichTextLabel).text
			if text.contains("FIREARM SLOT 1: TEST FIREARM A") and text.contains("FIREARM SLOT 2: TEST FIREARM B") and text.contains("MELEE SLOT: TEST MELEE A") and text.contains("TEST STACKABLE EQUIPMENT  x2"):
				summary_found = true
		_check(summary_found, "Dev Menu must display firearm, melee and equipment inventory state")

	DevModeManager.clear_all_inventory()
	_check(InventoryManager.get_firearm_slot(0) == null and InventoryManager.get_firearm_slot(1) == null, "Clear all inventory must empty both firearm slots")
	_check(InventoryManager.get_melee_slot() == null and InventoryManager.get_inventory_entries().is_empty(), "Clear all inventory must empty melee and equipment")
	_check(InventoryManager.get_last_feedback() == InventoryComponent.INVENTORY_CLEARED, "Clear all inventory must report INVENTORY CLEARED")

	range_scene.free()
	DevModeManager.set_enabled(false)
	await get_tree().process_frame
	_check(DevModeManager.get_node_or_null("DevMenu") == null, "Returning to Play Mode must remove inventory test UI")
	_check(InventoryManager.get_inventory_entries().is_empty() and InventoryManager.get_firearm_slot(0) == null and InventoryManager.get_melee_slot() == null, "Play Mode must not retain DEV placeholder inventory")

	if _failures.is_empty():
		print("INVENTORY VALIDATION: PASS — slots, rejection feedback, unique/stack rules, range pickups, Dev Menu and Play Mode isolation")
	else:
		for failure in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _owned_group(root: Node, group: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for node in get_tree().get_nodes_in_group(group):
		if root.is_ancestor_of(node):
			result.append(node)
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
