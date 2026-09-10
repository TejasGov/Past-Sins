extends Node

const MAIN_SCENE := preload("res://scenes/levels/CellBlockPrototype.tscn")
const GATE_SCENE := preload("res://scenes/interactables/PrisonSlidingGate.tscn")


func _ready() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	var level := MAIN_SCENE.instantiate()
	add_child(level)
	await get_tree().process_frame

	var cell_gate := level.get_node("Interactables/ParthCellGate") as PrisonSlidingGate
	assert(cell_gate.get_interaction_prompt(null) == "[E] Open Gate")
	var player := level.get_node("Actors/Player") as PlayerController
	assert(not player.test_move(player.global_transform, Vector3.RIGHT * 0.75))
	assert(player.test_move(player.global_transform, Vector3.RIGHT * 2.0))
	cell_gate.interact(null)
	await get_tree().create_timer(cell_gate.animation_duration + 0.15).timeout
	await get_tree().process_frame
	assert(cell_gate.is_open and cell_gate.blocker.disabled)
	assert(not player.test_move(player.global_transform, Vector3.RIGHT * 2.0))

	var gate := level.get_node("Interactables/Floor3NorthWingGate") as PrisonSlidingGate
	assert(gate.get_interaction_prompt(null) == "[E] Locked")
	gate.interact(null)
	assert(gate.is_locked)

	var pickup := level.get_node("Interactables/CellBlockKeyPickup") as KeyPickup
	pickup.interact(null)
	await get_tree().process_frame
	assert(AccessManager.has_key(&"cellblock_key"))
	assert(not AccessManager.add_key(&"cellblock_key", "Cell Block Key"))
	assert(gate.get_interaction_prompt(null) == "[E] Unlock Gate")

	gate.interact(null)
	assert(not gate.is_locked)
	await get_tree().create_timer(gate.animation_duration + 0.4).timeout
	assert(gate.is_open)
	await get_tree().process_frame
	assert(gate.blocker.disabled)
	assert(gate.get_interaction_prompt(null) == "[E] Close Gate")

	player.global_position = gate.global_position + Vector3.UP * 0.9
	await get_tree().physics_frame
	await get_tree().physics_frame
	gate.interact(null)
	assert(gate.is_open)
	player.global_position = Vector3(-14.2, 8.95, -8.5)
	await get_tree().physics_frame

	gate.interact(null)
	await get_tree().create_timer(gate.animation_duration + 0.15).timeout
	await get_tree().process_frame
	assert(not gate.is_open and not gate.blocker.disabled)
	assert(gate.get_interaction_prompt(null) == "[E] Open Gate")

	var restored_gate := GATE_SCENE.instantiate() as PrisonSlidingGate
	restored_gate.persistent_access_id = &"floor3_north_wing_gate"
	restored_gate.required_key_id = &"cellblock_key"
	restored_gate.starts_locked = true
	add_child(restored_gate)
	await get_tree().process_frame
	assert(not restored_gate.is_locked)
	restored_gate.queue_free()

	var door := level.get_node("Interactables/ShowerDoor") as NormalDoor
	assert(door.get_interaction_prompt(null) == "[E] Open Door")
	door.interact(null)
	await get_tree().create_timer(door.animation_duration + 0.15).timeout
	await get_tree().process_frame
	assert(door.is_open and door.blocker.disabled)
	assert(door.get_interaction_prompt(null) == "[E] Close Door")
	player.global_position = door.global_position + Vector3.UP * 0.9
	await get_tree().physics_frame
	await get_tree().physics_frame
	door.interact(null)
	assert(door.is_open)
	player.global_position = Vector3(0, 0.95, 0)
	await get_tree().physics_frame
	door.interact(null)
	await get_tree().create_timer(door.animation_duration + 0.15).timeout
	await get_tree().process_frame
	assert(not door.is_open and not door.blocker.disabled)

	var service_pickup := level.get_node("Interactables/ServiceKeyPickup") as KeyPickup
	var medical_pickup := level.get_node("Interactables/MedicalKeyPickup") as KeyPickup
	service_pickup.interact(null)
	medical_pickup.interact(null)
	await get_tree().process_frame
	assert(AccessManager.has_key(&"service_key"))
	assert(AccessManager.has_key(&"medical_key"))
	assert(not AccessManager.has_key(&"security_key"))
	assert(not AccessManager.has_key(&"lab_key"))

	print("ACCESS_WORKFLOW_VALIDATION: PASS")
	get_tree().quit(0)
