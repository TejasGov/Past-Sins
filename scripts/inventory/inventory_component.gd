extends Node
class_name InventoryComponent

## Reusable, data-driven inventory and loadout-slot owner. This component knows
## only categories and quantities; future item behavior belongs elsewhere.
signal inventory_changed
signal item_added(item_id: StringName, quantity: int)
signal item_removed(item_id: StringName, quantity: int)
signal feedback_requested(message: String)

const FIREARM_SLOT_1 := 0
const FIREARM_SLOT_2 := 1
const FIREARM_SLOT_COUNT := 2
const MELEE_SLOT := 0

const ITEM_ACQUIRED := "ITEM ACQUIRED"
const FIREARM_SLOTS_FULL := "FIREARM SLOTS FULL"
const MELEE_SLOT_FULL := "MELEE SLOT FULL"
const ITEM_ALREADY_OWNED := "ITEM ALREADY OWNED"
const INVENTORY_CLEARED := "INVENTORY CLEARED"
const INVALID_ITEM := "INVALID ITEM"

var _firearm_slots: Array[ItemDefinition] = [null, null]
var _melee_slot: ItemDefinition
## Non-loadout items are stored as {definition: ItemDefinition, count: int}.
var _items: Dictionary = {}
var _last_feedback := ""


func can_add_item(item_definition: ItemDefinition, quantity := 1) -> bool:
	return _get_add_rejection(item_definition, quantity).is_empty()


func add_item(item_definition: ItemDefinition, quantity := 1, emit_feedback := true) -> bool:
	var rejection := _get_add_rejection(item_definition, quantity)
	if not rejection.is_empty():
		_set_feedback(rejection, emit_feedback)
		return false
	var item_id := item_definition.normalized_id()
	match item_definition.category:
		ItemDefinition.Category.FIREARM:
			var slot := _first_empty_firearm_slot()
			_firearm_slots[slot] = item_definition
		ItemDefinition.Category.MELEE:
			_melee_slot = item_definition
		_:
			var previous_count := get_item_count(item_id)
			_items[item_id] = {"definition": item_definition, "count": previous_count + quantity}
	item_added.emit(item_id, quantity)
	inventory_changed.emit()
	_set_feedback(ITEM_ACQUIRED, emit_feedback)
	return true


func remove_item(item_id: StringName, quantity := 1, emit_feedback := false) -> bool:
	var normalized := _normalize_id(item_id)
	if normalized.is_empty() or quantity <= 0:
		return false
	for index in range(FIREARM_SLOT_COUNT):
		var firearm := _firearm_slots[index]
		if firearm != null and firearm.normalized_id() == normalized:
			_firearm_slots[index] = null
			item_removed.emit(normalized, 1)
			inventory_changed.emit()
			return true
	if _melee_slot != null and _melee_slot.normalized_id() == normalized:
		_melee_slot = null
		item_removed.emit(normalized, 1)
		inventory_changed.emit()
		return true
	if not _items.has(normalized):
		return false
	var entry: Dictionary = _items[normalized]
	var removed := mini(quantity, int(entry.count))
	var remaining := int(entry.count) - removed
	if remaining <= 0:
		_items.erase(normalized)
	else:
		entry.count = remaining
		_items[normalized] = entry
	item_removed.emit(normalized, removed)
	inventory_changed.emit()
	return true


func has_item(item_id: StringName) -> bool:
	return get_item_count(item_id) > 0


func get_item_count(item_id: StringName) -> int:
	var normalized := _normalize_id(item_id)
	for firearm in _firearm_slots:
		if firearm != null and firearm.normalized_id() == normalized:
			return 1
	if _melee_slot != null and _melee_slot.normalized_id() == normalized:
		return 1
	return int((_items.get(normalized, {}) as Dictionary).get("count", 0))


func get_item_definition(item_id: StringName) -> ItemDefinition:
	var normalized := _normalize_id(item_id)
	for firearm in _firearm_slots:
		if firearm != null and firearm.normalized_id() == normalized:
			return firearm
	if _melee_slot != null and _melee_slot.normalized_id() == normalized:
		return _melee_slot
	if _items.has(normalized):
		return (_items[normalized] as Dictionary).definition as ItemDefinition
	return null


func get_firearm_slot(index: int) -> ItemDefinition:
	return _firearm_slots[index] if index >= 0 and index < FIREARM_SLOT_COUNT else null


func set_firearm_slot(index: int, item: ItemDefinition, emit_feedback := true) -> bool:
	if index < 0 or index >= FIREARM_SLOT_COUNT or item == null or item.category != ItemDefinition.Category.FIREARM or not item.is_valid_definition():
		_set_feedback(INVALID_ITEM, emit_feedback)
		return false
	if _firearm_slots[index] != null:
		_set_feedback(FIREARM_SLOTS_FULL, emit_feedback)
		return false
	if has_item(item.normalized_id()):
		_set_feedback(ITEM_ALREADY_OWNED, emit_feedback)
		return false
	_firearm_slots[index] = item
	item_added.emit(item.normalized_id(), 1)
	inventory_changed.emit()
	_set_feedback(ITEM_ACQUIRED, emit_feedback)
	return true


func clear_firearm_slot(index: int) -> bool:
	if index < 0 or index >= FIREARM_SLOT_COUNT or _firearm_slots[index] == null:
		return false
	var removed_id := _firearm_slots[index].normalized_id()
	_firearm_slots[index] = null
	item_removed.emit(removed_id, 1)
	inventory_changed.emit()
	return true


func clear_firearm_slots() -> void:
	for index in range(FIREARM_SLOT_COUNT):
		clear_firearm_slot(index)


func get_melee_slot() -> ItemDefinition:
	return _melee_slot


func set_melee_slot(item: ItemDefinition, emit_feedback := true) -> bool:
	if item == null or item.category != ItemDefinition.Category.MELEE or not item.is_valid_definition():
		_set_feedback(INVALID_ITEM, emit_feedback)
		return false
	if _melee_slot != null:
		_set_feedback(MELEE_SLOT_FULL, emit_feedback)
		return false
	if has_item(item.normalized_id()):
		_set_feedback(ITEM_ALREADY_OWNED, emit_feedback)
		return false
	_melee_slot = item
	item_added.emit(item.normalized_id(), 1)
	inventory_changed.emit()
	_set_feedback(ITEM_ACQUIRED, emit_feedback)
	return true


func clear_melee_slot() -> bool:
	if _melee_slot == null:
		return false
	var removed_id := _melee_slot.normalized_id()
	_melee_slot = null
	item_removed.emit(removed_id, 1)
	inventory_changed.emit()
	return true


func clear_equipment() -> void:
	_clear_categories([ItemDefinition.Category.EQUIPMENT])


func clear_dev_only_items() -> void:
	for index in range(FIREARM_SLOT_COUNT):
		var firearm := _firearm_slots[index]
		if firearm != null and firearm.dev_only:
			clear_firearm_slot(index)
	if _melee_slot != null and _melee_slot.dev_only:
		clear_melee_slot()
	var ids: Array[StringName] = []
	for item_id in _items.keys():
		var definition := (_items[item_id] as Dictionary).definition as ItemDefinition
		if definition != null and definition.dev_only:
			ids.append(item_id as StringName)
	for item_id in ids:
		remove_item(item_id, get_item_count(item_id))


func clear_all_inventory(emit_feedback := true) -> void:
	for index in range(FIREARM_SLOT_COUNT):
		clear_firearm_slot(index)
	clear_melee_slot()
	var ids: Array[StringName] = []
	for item_id in _items.keys():
		ids.append(item_id as StringName)
	for item_id in ids:
		remove_item(item_id, get_item_count(item_id))
	_set_feedback(INVENTORY_CLEARED, emit_feedback)


func get_inventory_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in _items.keys():
		var entry: Dictionary = _items[item_id]
		result.append({"item_id": item_id, "definition": entry.definition, "count": int(entry.count)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.item_id).naturalnocasecmp_to(str(b.item_id)) < 0
	)
	return result


func get_items_in_category(category: ItemDefinition.Category) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in get_inventory_entries():
		if (entry.definition as ItemDefinition).category == category:
			result.append(entry)
	return result


func get_last_feedback() -> String:
	return _last_feedback


func request_feedback(message: String) -> void:
	_set_feedback(message, true)


func _get_add_rejection(item_definition: ItemDefinition, quantity: int) -> String:
	if item_definition == null or not item_definition.is_valid_definition() or quantity <= 0:
		return INVALID_ITEM
	var item_id := item_definition.normalized_id()
	match item_definition.category:
		ItemDefinition.Category.FIREARM:
			if _first_empty_firearm_slot() < 0:
				return FIREARM_SLOTS_FULL
			if has_item(item_id):
				return ITEM_ALREADY_OWNED
		ItemDefinition.Category.MELEE:
			if _melee_slot != null:
				return MELEE_SLOT_FULL
			if has_item(item_id):
				return ITEM_ALREADY_OWNED
		_:
			var existing_count := get_item_count(item_id)
			if existing_count > 0 and not item_definition.stackable:
				return ITEM_ALREADY_OWNED
			if item_definition.max_stack_size > 0 and existing_count + quantity > item_definition.max_stack_size:
				return "ITEM STACK FULL"
	return ""


func _first_empty_firearm_slot() -> int:
	for index in range(FIREARM_SLOT_COUNT):
		if _firearm_slots[index] == null:
			return index
	return -1


func _clear_categories(categories: Array[int]) -> void:
	var ids: Array[StringName] = []
	for item_id in _items.keys():
		var definition := (_items[item_id] as Dictionary).definition as ItemDefinition
		if definition != null and int(definition.category) in categories:
			ids.append(item_id as StringName)
	for item_id in ids:
		remove_item(item_id, get_item_count(item_id))


func _set_feedback(message: String, should_emit: bool) -> void:
	_last_feedback = message
	if should_emit:
		feedback_requested.emit(message)


func _normalize_id(raw_id: StringName) -> StringName:
	return StringName(str(raw_id).strip_edges().to_lower())
