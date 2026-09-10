extends Node3D

## Geometry-only integration test: opens real leaf poses without granting keys,
## then probes their visible swept surfaces against neighboring solid collision.
const CAMPUS := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn")
var _failures: Array[String] = []
var _failed_groups: Dictionary = {}
var _samples: Dictionary = {}
var _tested := 0


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var campus := CAMPUS.instantiate() as Node3D
	campus.set("phase_two_enabled", true)
	campus.set("campus_interiors_enabled", true)
	add_child(campus)
	await get_tree().process_frame
	var actors := campus.get_node("Actors")
	actors.process_mode = Node.PROCESS_MODE_DISABLED
	for collision in actors.find_children("*", "CollisionShape3D", true, false):
		collision.disabled = true
	var gates: Array[PrisonSlidingGate] = []
	for node in campus.find_children("*", "Node3D", true, false):
		if node is PrisonSlidingGate:
			gates.append(node as PrisonSlidingGate)
		if node is PrisonSlidingGate or node is NormalDoor:
			node.call("_apply_pose", true)
			node.set("is_open", true)
			(node.get("blocker") as CollisionShape3D).disabled = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	for gate in gates:
		_tested += 1
		if gate is CampusTelescopicGate:
			var panels: Array = gate.get("_panels")
			var closed: Array = gate.get("_panel_closed")
			for index in range(panels.size()):
				var panel := panels[index] as Node3D
				for fraction in [0.25, 0.5, 0.75, 1.0]:
					var origin: Vector3 = panel.get_parent().to_global((closed[index] as Vector3).lerp(panel.position, fraction))
					_probe(gate, panel, Vector3(gate.gate_width * 0.25 - 0.006, gate.gate_height - 0.08, 0.05), origin, fraction)
		else:
			for fraction in [0.25, 0.5, 0.75, 1.0]:
				var closed: Vector3 = gate.get("_closed_position")
				var origin: Vector3 = gate.leaf.get_parent().to_global(closed.lerp(gate.leaf.position, fraction))
				_probe(gate, gate.leaf, Vector3(gate.gate_width - 0.006, gate.gate_height - 0.08, 0.13), origin, fraction)
	print("Gate travel: %d gates tested; %d solid overlaps across %s" % [_tested, _failures.size(), _failed_groups])
	for samples in _samples.values():
		for message in samples:
			push_error(message)
	if _failures.is_empty():
		print("PASS: gate leaves clear neighboring solids throughout sampled opening travel")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _probe(gate: PrisonSlidingGate, moving: Node3D, size: Vector3, origin: Vector3, fraction: float) -> void:
	moving.force_update_transform()
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	query.shape = shape
	query.transform = moving.global_transform
	query.transform.origin = origin
	query.transform.origin += moving.global_basis.y * (gate.gate_height * 0.5)
	query.collision_mask = 1
	query.exclude = [gate.leaf.get_rid()]
	var hits := get_world_3d().direct_space_state.intersect_shape(query, 16)
	for hit in hits:
		var collider := hit.get("collider") as CollisionObject3D
		if collider == null or gate.is_ancestor_of(collider):
			continue
		var owner_id := collider.shape_find_owner(int(hit.get("shape", 0)))
		var owner := collider.shape_owner_get_owner(owner_id) as CollisionShape3D
		var group := "Campus exterior"
		var gate_path := String(gate.get_path())
		var marker := gate_path.find("/Buildings/")
		if marker >= 0:
			group = gate_path.substr(marker + 11).get_slice("/", 0)
		_failed_groups[group] = int(_failed_groups.get(group, 0)) + 1
		var description := String(collider.get_path())
		if owner != null:
			var hit_size := str((owner.shape as BoxShape3D).size) if owner.shape is BoxShape3D else owner.shape.get_class()
			description = "%s at %s size %s" % [owner.get_path(), owner.global_position, hit_size]
		var message := "%s/%s at %d%% open, leaf centered %s overlaps %s; query basis=%s gate basis=%s" % [gate.get_path(), moving.name, int(fraction * 100), query.transform.origin, description, query.transform.basis, gate.global_basis]
		_failures.append(message)
		if not _samples.has(group):
			_samples[group] = []
		if _samples[group].size() < 2:
			_samples[group].append(message)
