extends Node

const CAMPUS := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn")
const CONTENT := preload("res://scenes/levels/campus/gameplay/CampusSessionContent.tscn")
const KEY := preload("res://scenes/levels/campus/gameplay/CampusMountedKey.tscn")
const MEMORY := preload("res://scenes/levels/campus/gameplay/CampusRestingMemory.tscn")
const LOCKER := preload("res://scenes/levels/campus/gameplay/CampusKeypadLocker.tscn")
var failures: Array[String] = []
@onready var root: Window = get_tree().root

class TestPlayer extends Node:
	var control_enabled := true
	func set_control_enabled(enabled: bool) -> void:
		control_enabled = enabled

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var campus := CAMPUS.instantiate()
	campus.gameplay_enabled = false
	root.add_child(campus)
	var session := campus.get_node_or_null("CampusSessionContent")
	if not session:
		session = CONTENT.instantiate()
		session.name = "CampusSessionContent"
		campus.add_child(session)
	session.build()
	var keys := get_tree().get_nodes_in_group("campus_key_pickups")
	var unique: Dictionary = {}
	for key in keys:
		_check(not unique.has(key.key_id), "Duplicate campus key pickup ID: " + String(key.key_id))
		unique[key.key_id] = true
		_check(not String(key.key_id) in ["security_key", "lab_key", "cell_master_key"], "High-security/master key must stay unavailable")
	_check(int(session.cell_key_count) == 69, "Expected 45 Cellhouse A and 24 Cellhouse B individual keys")
	_check(keys.size() == 72, "Expected 69 cell keys and 3 starter access keys")
	_check(get_tree().get_nodes_in_group("campus_memory_shards").size() == 1, "Expected one memory_001 shard")
	_check(get_tree().get_nodes_in_group("campus_keypad_lockers").size() == 1, "Expected one maintenance keypad locker")
	campus.free()
	await get_tree().process_frame
	var access: Node = root.get_node("AccessManager")
	var memory_manager: Node = root.get_node("MemoryManager")
	var key := KEY.instantiate() as KeyPickup
	key.key_id = &"test_mounted_key"
	root.add_child(key)
	var pos: Vector3 = key.get_node("PickupVisual").position
	await get_tree().create_timer(0.1).timeout
	_check(key.get_node("PickupVisual").position == pos, "Mounted keys must not bob")
	key.interact(null)
	key.interact(null)
	_check(access.has_key(&"test_mounted_key"), "Mounted key did not populate existing AccessManager")
	_check(access.get_keys().size() == 1, "Duplicate interaction should add exactly one key")
	await get_tree().process_frame
	var player := TestPlayer.new()
	root.add_child(player)
	var locker := LOCKER.instantiate() as KeypadLocker
	root.add_child(locker)
	locker.interact(player)
	_check(not locker.is_open, "Locker opened before learning clue")
	var shard := MEMORY.instantiate() as MemoryShard
	root.add_child(shard)
	shard.interact(player)
	shard.interact(player)
	_check(memory_manager.has_memory(&"memory_001"), "Original memory ID was not preserved")
	_check(memory_manager.knows_clue("2718"), "Original practical clue was not preserved")
	_check(memory_manager.get_collected_memories().size() == 1, "Memory collected twice")
	_check(player.control_enabled, "Memory fallback failed to restore control")
	locker.interact(player)
	_check(locker.is_open, "Remembered 2718 did not open maintenance locker")
	await get_tree().create_timer(0.85).timeout
	_check(locker.get_node("DoorPivot").rotation.y > 1.8, "Cabinet door must open outward")
	for message in failures: push_error(message)
	print("Campus session content: 69 unique cell keys, 3 starter keys, mounted pickup single collection, memory_001 → 2718 locker workflow; failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
