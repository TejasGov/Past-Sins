extends Node

const MAIN_SCENE := preload("res://scenes/levels/CellBlockPrototype.tscn")


func _ready() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	var level := MAIN_SCENE.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().physics_frame

	var dressing := level.get_node("EnvironmentalDressing")
	var required_placements := [
		"B1HospitalBed00", "B1ExamTable00", "B1SecureMedicineStorage",
		"B1MedicineWallSafe", "B1DiagnosticMachine", "B1Wheelchair",
		"B2Microscope", "B2Centrifuge", "B2NidraTerminal", "B2InstrumentTable",
		"B2SubjectStorageA", "B2LargeEvidenceSafe", "B2RestraintChair",
		"B2MetalExamTable", "B2RecordingCamera", "B2InterrogationMonitor",
	]
	for prop_name in required_placements:
		assert(dressing.has_node(prop_name), "Missing B1/B2 dressing: %s" % prop_name)

	var clinical_props := get_tree().get_nodes_in_group("medical_lab_props")
	assert(clinical_props.size() >= 58, "Expected at least 58 placed clinical/lab props, found %d" % clinical_props.size())

	var safes := get_tree().get_nodes_in_group("secure_safe_props")
	assert(safes.size() == 3, "Expected all three reusable safe sizes in-world, found %d" % safes.size())
	for safe in safes:
		assert(safe.get_meta("locked", false), "%s should be visually locked" % safe.name)
		assert(safe.get_meta("future_interactable", "") == "safe", "%s is not prepared for later safe interaction" % safe.name)
		assert(not safe.find_children("*", "CollisionShape3D", true, false).is_empty(), "%s has no collision" % safe.name)

	var bed := dressing.get_node("B1HospitalBed00") as Node3D
	for part_name in ["BedFrame", "Mattress", "Pillow"]:
		assert(bed.has_node(part_name), "Hospital bed lacks required part: %s" % part_name)
	assert(bed.find_children("BedLeg*", "MeshInstance3D", false, false).size() == 4, "Hospital bed does not have four visible supports")

	var medicine_room := dressing.get_node("B1SecureMedicineStorage") as Node3D
	assert(medicine_room.has_node("RearWall"), "Medicine storage has no rear wall")
	assert(medicine_room.find_children("SideWall*", "MeshInstance3D", false, false).size() == 2, "Medicine storage is not enclosed on both sides")
	var medicine_door := level.get_node("Interactables/MedicineStorageDoor") as NormalDoor
	assert(medicine_door != null and medicine_door.is_locked, "Medicine storage door must start secured")
	assert(medicine_door.required_key_id == &"medical_key")
	assert(medicine_door.get_interaction_prompt(null) == "[E] Locked")
	assert(AccessManager.add_key(&"medical_key", "Medical Key"))
	medicine_door.interact(null)
	await get_tree().create_timer(medicine_door.animation_duration + 0.15).timeout
	await get_tree().process_frame
	assert(not medicine_door.is_locked and medicine_door.is_open, "Medical key did not unlock/open secured storage")
	assert(medicine_door.blocker.disabled, "Open medicine door still blocks its doorway")

	var nidra_terminal := dressing.get_node("B2NidraTerminal") as Node3D
	var nidra_labels := nidra_terminal.find_children("*", "Label3D", true, false)
	assert(not nidra_labels.is_empty(), "NIDRA terminal has no environmental label")
	assert((nidra_labels[0] as Label3D).text.contains("NEURAL RESPONSE"))

	# This pass must not add collectible story content.
	assert(get_tree().get_nodes_in_group("memory_shards").size() <= 1, "Environmental pass added story collectibles")

	print("MEDICAL_LAB_VALIDATION: PASS — B1 clinical security and B2 NIDRA/interrogation dressing verified")
	get_tree().quit(0)
