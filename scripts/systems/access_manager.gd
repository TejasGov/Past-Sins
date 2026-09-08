extends Node

signal key_added(key_id: StringName)
signal access_unlocked(access_id: StringName)

var _keys: Dictionary = {}
var _key_labels: Dictionary = {}
var _unlocked_access: Dictionary = {}


func has_key(key_id: StringName) -> bool:
	var normalized := _normalize_id(key_id)
	return not normalized.is_empty() and _keys.has(normalized)


func add_key(key_id: StringName, display_name := "") -> bool:
	var normalized := _normalize_id(key_id)
	if normalized.is_empty() or _keys.has(normalized):
		return false
	_keys[normalized] = true
	if not display_name.strip_edges().is_empty():
		_key_labels[normalized] = display_name.strip_edges()
	key_added.emit(normalized)
	return true


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
	return true


func is_access_unlocked(access_id: StringName) -> bool:
	var normalized := _normalize_id(access_id)
	return not normalized.is_empty() and _unlocked_access.has(normalized)


func get_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	for key_id in _keys.keys():
		keys.append(key_id as StringName)
	return keys


func _normalize_id(raw_id: StringName) -> StringName:
	return StringName(str(raw_id).strip_edges().to_lower())
