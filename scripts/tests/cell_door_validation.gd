extends Node

const MAIN_SCENE := preload("res://scenes/levels/CellBlockPrototype.tscn")
const MASTER_KEY_ID: StringName = &"cell_master_key"


func _ready() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	var level := MAIN_SCENE.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().physics_frame

	var cell_doors := get_tree().get_nodes_in_group("cell_doors")
	var cell_keys := get_tree().get_nodes_in_group("cell_key_pickups")
	var storage_door := level.get_node("Interactables/EvidenceStorageDoor") as NormalDoor
	assert(storage_door.is_locked and storage_door.required_key_id == &"security_key", "Floor 4 cell-key storage is not secured")
	assert(cell_doors.size() == 31, "Expected 31 prisoner-cell doors; Floor 3's final east bay is maintenance")
	assert(cell_keys.size() == cell_doors.size(), "Every prisoner cell must have exactly one stored individual key")

	var access_ids := {}
	var required_keys := {}
	var parth_gate: PrisonSlidingGate
	for item in cell_doors:
		var door := item as PrisonSlidingGate
		assert(door != null)
		assert(not door.required_key_id.is_empty(), "%s has no individual key" % door.name)
		assert(door.master_key_id == MASTER_KEY_ID, "%s does not accept the future master key" % door.name)
		assert(not access_ids.has(door.persistent_access_id), "Duplicate cell access ID: %s" % door.persistent_access_id)
		assert(not required_keys.has(door.required_key_id), "Duplicate individual cell key: %s" % door.required_key_id)
		access_ids[door.persistent_access_id] = true
		required_keys[door.required_key_id] = true
		if door.name == "ParthCellGate":
			parth_gate = door
		else:
			assert(door.is_locked, "%s should begin locked" % door.name)
	assert(parth_gate != null and not parth_gate.is_locked, "Parth must retain an unlocked spawn exit")

	for item in cell_keys:
		var key := item as KeyPickup
		assert(key != null and required_keys.has(key.key_id), "%s is not paired to a cell door" % key.name)
		assert(key.global_position.y >= 12.0, "%s is not stored on Floor 4" % key.name)
		assert(key.global_position.x > 15.5 and key.global_position.z > 11.0, "%s is outside the secure key-storage wall" % key.name)
	assert(not required_keys.has(MASTER_KEY_ID), "Master key must not replace an individual cell key")
	assert(not AccessManager.has_key(MASTER_KEY_ID), "Future police-chief master key was granted prematurely")

	var glass_doors := get_tree().get_nodes_in_group("high_security_glass_doors")
	assert(glass_doors.size() == 8, "Each of the four high-security zones needs two reinforced see-through doors")
	for item in glass_doors:
		var glass_door := item as PrisonSlidingGate
		assert(glass_door.bulletproof_glass)
		assert(glass_door.get_node("GateLeaf/Visuals").has_node("BallisticGlassLeft"), "%s lacks a glass panel" % glass_door.name)

	# Verify individual and master authorization without placing the master key.
	var individual_test := level.get_node("Interactables/Floor2WestCell02Gate") as PrisonSlidingGate
	assert(AccessManager.add_key(individual_test.required_key_id, "Cell Test Key"))
	individual_test.animation_duration = 0.05
	individual_test.interact(null)
	await get_tree().create_timer(0.4).timeout
	assert(not individual_test.is_locked and individual_test.is_open and individual_test.blocker.disabled)

	var master_test := level.get_node("Interactables/Floor2EastCell02Gate") as PrisonSlidingGate
	assert(AccessManager.add_key(MASTER_KEY_ID, "Police Chief Master Key"))
	master_test.animation_duration = 0.05
	master_test.interact(null)
	await get_tree().create_timer(0.4).timeout
	assert(not master_test.is_locked and master_test.is_open and master_test.blocker.disabled)

	print("CELL_DOOR_VALIDATION: PASS — 31 keyed cell doors, 31 Floor 4 keys, 8 ballistic-glass special doors")
	get_tree().quit(0)
