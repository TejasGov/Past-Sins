extends Node

signal memory_collected(memory_data: Dictionary)
signal clue_learned(clue: String)

var _collected_memories: Dictionary = {}
var _known_clues: Dictionary = {}


func collect_memory(memory_id: StringName, title: String, transcript: String, clue: String = "") -> bool:
	if _collected_memories.has(memory_id):
		return false
	var memory_data := {
		"id": memory_id,
		"title": title,
		"transcript": transcript,
		"clue": clue,
	}
	_collected_memories[memory_id] = memory_data
	if not clue.is_empty():
		_known_clues[clue] = memory_id
		clue_learned.emit(clue)
	memory_collected.emit(memory_data)
	return true


func has_memory(memory_id: StringName) -> bool:
	return _collected_memories.has(memory_id)


func knows_clue(clue: String) -> bool:
	return _known_clues.has(clue)


func get_memory(memory_id: StringName) -> Dictionary:
	return _collected_memories.get(memory_id, {})


func get_collected_memories() -> Array:
	return _collected_memories.values()

