extends Node

signal key_added(key_id: StringName)
signal key_removed(key_id: StringName)
signal access_unlocked(access_id: StringName)
signal inventory_changed

var _key_labels: Dictionary = {}
var _known_access_items: Dictionary = {}
var _unlocked_access: Dictionary = {}


func _ready() -> void:
	if not InventoryManager.item_added.is_connected(_on_inventory_item_added):
		InventoryManager.item_added.connect(_on_inventory_item_added)
	if not InventoryManager.item_removed.is_connected(_on_inventory_item_removed):
		InventoryManager.item_removed.connect(_on_inventory_item_removed)


func has_key(key_id: StringName) -> bool:
	var normalized := _normalize_id(key_id)
	if normalized.is_empty():
		return false
	var definition := InventoryManager.get_item_definition(normalized) as ItemDefinition
	return definition != null and definition.category in [ItemDefinition.Category.KEY, ItemDefinition.Category.ACCESS_CARD]


func add_key(key_id: StringName, display_name := "") -> bool:
	var normalized := _normalize_id(key_id)
	if normalized.is_empty() or has_key(normalized):
		return false
	var definition := ItemDefinition.new()
	definition.item_id = normalized
	definition.display_name = display_name.strip_edges() if not display_name.strip_edges().is_empty() else str(normalized).replace("_", " ").capitalize()
	definition.category = ItemDefinition.Category.KEY
	definition.stackable = false
	_key_labels[normalized] = definition.display_name
	if InventoryManager.add_item(definition, 1, false):
		return true
	_key_labels.erase(normalized)
	return false


func remove_key(key_id: StringName) -> bool:
	var normalized := _normalize_id(key_id)
	if normalized.is_empty() or not has_key(normalized):
		return false
	return InventoryManager.remove_item(normalized)


func get_key_display_name(key_id: StringName) -> String:
	var normalized := _normalize_id(key_id)
	if _key_labels.has(normalized):
		return str(_key_labels[normalized])
	return str(normalized).replace("_", " ").capitalize()


func unlock_access(access_id: StringName) -> bool:
	var normalized := _normalize_id(access_id)
	if normalized.is_empty() or _unlocked_access.has(normalized):
		return false
	_unlocked_access[normalized] = true
	access_unlocked.emit(normalized)
	inventory_changed.emit()
	return true


func is_access_unlocked(access_id: StringName) -> bool:
	var normalized := _normalize_id(access_id)
	return not normalized.is_empty() and _unlocked_access.has(normalized)


func get_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	for entry in InventoryManager.get_inventory_entries():
		var definition := entry.definition as ItemDefinition
		if definition.category in [ItemDefinition.Category.KEY, ItemDefinition.Category.ACCESS_CARD]:
			keys.append(entry.item_id as StringName)
	return keys


func get_unlocked_access_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for access_id in _unlocked_access.keys():
		ids.append(access_id as StringName)
	return ids


func _normalize_id(raw_id: StringName) -> StringName:
	return StringName(str(raw_id).strip_edges().to_lower())


func _on_inventory_item_added(item_id: StringName, _quantity: int) -> void:
	var definition := InventoryManager.get_item_definition(item_id) as ItemDefinition
	if definition == null or definition.category not in [ItemDefinition.Category.KEY, ItemDefinition.Category.ACCESS_CARD]:
		return
	_known_access_items[item_id] = true
	key_added.emit(item_id)
	inventory_changed.emit()


func _on_inventory_item_removed(item_id: StringName, _quantity: int) -> void:
	# item_removed is emitted after the backing record is removed, so the label
	# registry identifies keys that were created through the compatibility API.
	if not _known_access_items.has(item_id):
		return
	_known_access_items.erase(item_id)
	_key_labels.erase(item_id)
	key_removed.emit(item_id)
	inventory_changed.emit()
