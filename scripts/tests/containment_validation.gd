extends Node

const MAIN_SCENE := preload("res://scenes/levels/CellBlockPrototype.tscn")

var _space_state: PhysicsDirectSpaceState3D


func _ready() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	var level := MAIN_SCENE.instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_space_state = get_viewport().world_3d.direct_space_state

	var audit_issues: PackedStringArray = level.get_node("ContainmentAudit").run_audit()
	assert(audit_issues.is_empty(), "Structural visual/collision audit reported: %s" % [audit_issues])

	# B2 — interrogation is bounded by the observation divider and entered only
	# through its door opening.
	await _open(level.get_node("Interactables/InterrogationDoor"))
	_assert_blocked("B2 interrogation wall", Vector3(9.0, -11.0, -1.5))
	_assert_clear("B2 interrogation doorway", Vector3(5.0, -11.0, -1.5))
	_assert_blocked("B2 secure corridor north seam", Vector3(-2.2, -11.0, -20.0))
	_assert_clear("B2 north secure doorway", Vector3(-2.2, -11.0, -10.75))

	# B1 — the infirmary corridor wall reaches the outer shell and its door is
	# the usable route through that boundary.
	await _open(level.get_node("Interactables/InfirmaryDoor"))
	_assert_blocked("B1 infirmary corridor wall", Vector3(-2.5, -7.0, -7.0))
	_assert_clear("B1 infirmary doorway", Vector3(-2.5, -7.0, -10.0))
	_assert_blocked("B1 maintenance east wall", Vector3(2.5, -7.0, 17.0))
	_assert_clear("B1 maintenance doorway", Vector3(-2.5, -7.0, 13.5))
	await _open(level.get_node("Interactables/StorageDoor"))
	_assert_blocked("B1 storage west wall", Vector3(7.0, -7.0, 5.0))
	_assert_clear("B1 storage doorway", Vector3(7.0, -7.0, 8.0))

	# Ground — the cafeteria south perimeter is solid except for the deliberate
	# main archway.
	_assert_blocked("Ground cafeteria south wall", Vector3(-6.0, -3.0, 12.3))
	_assert_clear("Ground cafeteria main entrance", Vector3(0.0, -3.0, 12.3))
	_assert_blocked("Ground food-service south wall", Vector3(10.8, -3.0, 9.5))
	_assert_clear("Ground B1 arrival threshold", Vector3(14.25, -3.0, 9.5))

	# Floor 1 — showers remain separate from the gym and retain their working
	# doorway.
	await _open(level.get_node("Interactables/ShowerDoor"))
	_assert_blocked("Floor 1 shower wall", Vector3(8.0, 1.0, -12.0))
	_assert_clear("Floor 1 shower doorway", Vector3(3.75, 1.0, -12.0))

	# Floor 2 — one cell-front panel is solid and the center cell opening remains
	# the only way into that cell after its individual sliding gate is opened.
	_assert_blocked("Floor 2 cell front", Vector3(13.0, 5.0, 1.0))
	var floor2_cell_gate := level.get_node("Interactables/Floor2EastCell05Gate") as PrisonSlidingGate
	assert(AccessManager.add_key(floor2_cell_gate.required_key_id, "Containment Test Cell Key"))
	await _open(floor2_cell_gate)
	_assert_clear("Floor 2 cell doorway", Vector3(13.0, 5.0, 2.5))
	_assert_blocked("Floor 2 cell side wall", Vector3(15.0, 5.0, 0.0))
	_assert_blocked("Floor 2 cell rear wall", Vector3(16.85, 5.0, 2.5))

	# Floor 3 — Parth's front panel blocks side entry and the aligned gate clears
	# completely when opened.
	await _open(level.get_node("Interactables/ParthCellGate"))
	_assert_blocked("Floor 3 Parth cell front", Vector3(-13.0, 9.0, -14.0))
	_assert_clear("Floor 3 Parth cell gate", Vector3(-12.88, 9.0, -12.5))

	# Floor 4 — office perimeter and its intended door agree visually and in
	# physics.
	await _open(level.get_node("Interactables/SecurityOfficeDoor"))
	_assert_blocked("Floor 4 security office wall", Vector3(-13.0, 13.0, 4.8))
	_assert_clear("Floor 4 security office doorway", Vector3(-10.0, 13.0, 4.8))
	assert(AccessManager.add_key(&"security_key", "Containment Test Security Key"))
	await _open(level.get_node("Interactables/EvidenceStorageDoor"))
	_assert_blocked("Floor 4 evidence wall", Vector3(13.0, 13.0, 4.8))
	_assert_clear("Floor 4 evidence doorway", Vector3(9.0, 13.0, 4.8))

	print("CONTAINMENT_VALIDATION: PASS — B2, B1, Ground, F1, F2, F3, F4")
	get_tree().quit(0)


func _open(interactable: Node) -> void:
	interactable.set("animation_duration", 0.05)
	interactable.call("interact", null)
	await get_tree().create_timer(0.4).timeout
	await get_tree().physics_frame


func _assert_blocked(label: String, center: Vector3) -> void:
	assert(_world_collision_at(center), "%s has a physical gap" % label)


func _assert_clear(label: String, center: Vector3) -> void:
	assert(not _world_collision_at(center), "%s is obstructed by world collision" % label)


func _world_collision_at(center: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	# Match the standing player's collision dimensions so a "clear" doorway is
	# genuinely traversable by the real controller, not merely by a point probe.
	capsule.radius = 0.35
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not _space_state.intersect_shape(query, 8).is_empty()
