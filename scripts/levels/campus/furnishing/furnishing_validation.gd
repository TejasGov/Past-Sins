extends SceneTree

const Furnisher := preload("res://scripts/levels/campus/furnishing/campus_room_furnisher.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/planning/campus_floor_plans.json"))
	var room_count := 0
	var source_meshes := 0
	var materials := 0
	for plan in data.plans:
		if String(plan.id).begins_with("cellhouse-a"):
			continue
		for room in plan.rooms:
			var local := Node3D.new()
			local.name = String(plan.id).replace("-", "_") + "_" + String(room.id)
			root.add_child(local)
			var doorways: Array = []
			for door in plan.doors:
				if door.a != room.id and door.b != room.id:
					continue
				doorways.append({"position": Vector3(float(door.x) - float(room.x) - float(room.w) * 0.5, 0, float(door.y) - float(room.y) - float(room.d) * 0.5), "width": door.width, "axis": door.axis, "kind": door.kind})
			Furnisher.dress(local, plan.id, room, doorways)
			if local.has_node("Furnishings"):
				var furnishing := local.get_node("Furnishings")
				room_count += 1
				source_meshes += int(furnishing.get_meta("source_mesh_count", 0))
				materials += int(furnishing.get_meta("batched_material_count", 0))
				var omissions: Array = furnishing.get_meta("clearance_omissions", [])
				if not omissions.is_empty():
					print("Clearance omissions ", local.name, ": ", omissions)
				if plan.id == "food-ground" and room.id == "dining":
					_check(_count_group(local, "campus_dining_table_sets") == 12, "Dining requires 12 complete table sets")
				if plan.id == "medical-ground":
					if room.id == "ward": _check(_count_group(local, "campus_clinical_bed_bays") == 6, "Ward requires 6 bed bays")
					if room.id == "showers": _check(_count_group(local, "campus_shower_heads") == 10, "Showers require 10 heads")
					if room.id == "toilets":
						_check(_count_group(local, "campus_toilets") == 8, "Toilets require 8 pots")
						_check(_count_group(local, "campus_urinals") == 8, "Toilets require 8 urinals")
				_check_door_collision(local, doorways)
				for prop in get_nodes_in_group("campus_placed_furniture"):
					if not local.is_ancestor_of(prop): continue
					var bounds: AABB = prop.get_meta("furniture_bounds", AABB())
					if prop.get_meta("support_type", "") == "floor":
						_check(absf(bounds.position.y) < 0.015, "%s/%s not on floor (%.3f)" % [local.name, prop.name, bounds.position.y])
					_check(bounds.position.x >= -float(room.w) * 0.5 - 0.01 and bounds.end.x <= float(room.w) * 0.5 + 0.01, "%s/%s exceeds room x bounds" % [local.name, prop.name])
					_check(bounds.position.z >= -float(room.d) * 0.5 - 0.01 and bounds.end.z <= float(room.d) * 0.5 + 0.01, "%s/%s exceeds room z bounds" % [local.name, prop.name])
			local.free()
	print("Furnishing audit: %d rooms; %d source meshes merged into %d material batches" % [room_count, source_meshes, materials])
	for message in failures:
		push_error(message)
	quit(0 if failures.is_empty() else 1)

func _count_group(ancestor: Node, group: String) -> int:
	var count := 0
	for node in get_nodes_in_group(group):
		if ancestor.is_ancestor_of(node): count += 1
	return count

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _check_door_collision(room: Node3D, doors: Array) -> void:
	for door in doors:
		if String(door.kind) in ["hatch", "window"]: continue
		var p: Vector3 = door.position
		var size := Vector3(float(door.width) + 0.1, 2.1, 2.4)
		if door.axis == "z": size = Vector3(2.4, 2.1, float(door.width) + 0.1)
		var passage := AABB(p + Vector3(0, 1.08, 0) - size * 0.5, size)
		for node in room.find_children("*", "CollisionShape3D", true, false):
			if node.disabled or not node.shape: continue
			var native: AABB = node.shape.get_debug_mesh().get_aabb()
			var actual: AABB = room.global_transform.affine_inverse() * node.global_transform * native
			_check(not actual.intersects(passage), "%s fixture %s obstructs doorway" % [room.name, node.get_parent().get_parent().name])
