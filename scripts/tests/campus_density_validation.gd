extends Node3D

## Regression coverage for the deliberate environmental-density pass. This
## verifies semantic coverage and support metadata without prescribing exact
## decorative coordinates or changing the authored floor plans.
const CAMPUS := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var campus := CAMPUS.instantiate() as Node3D
	campus.set("gameplay_enabled", false)
	add_child(campus)
	await get_tree().process_frame
	await get_tree().process_frame

	var details: Dictionary = {}
	for node in get_tree().get_nodes_in_group("campus_detail_props"):
		if campus.is_ancestor_of(node):
			var kind := String(node.get_meta("detail_kind", "unknown"))
			details[kind] = int(details.get(kind, 0)) + 1
	var required_details := {
		"security_sign": 6,
		"electrical_box": 2,
		"utility_pipe_run": 3,
		"monitor_wall": 2,
		"radio_set": 2,
		"key_cabinet": 1,
		"incident_board": 3,
		"security_map": 3,
		"tool_board": 1,
		"mechanical_parts": 1,
		"electrical_panel": 1,
		"food_containers": 2,
		"fence_sign": 3,
	}
	for kind in required_details:
		_check(int(details.get(kind, 0)) >= int(required_details[kind]), "Density recipe missing %s detail (%d/%d)" % [kind, details.get(kind, 0), required_details[kind]])

	var cells := _campus_group(campus, "campus_cells")
	_check(cells.size() == 45, "Cellhouse A must retain 45 reusable cells, found %d" % cells.size())
	var variation_signatures: Dictionary = {}
	for cell in cells:
		_check(cell.get_node_or_null("SlidingBarDoor") is PrisonSlidingGate, "%s has no reusable sliding cell door" % cell.name)
		var numbered := false
		var signature := str(cell.get_meta("personal_detail_variant", "missing"))
		for child in cell.find_children("*", "Node", true, false):
			if child is Label3D and String(child.name).begins_with("Sign_A-"):
				numbered = true
		_check(numbered, "%s has no visible cell number" % cell.name)
		variation_signatures[signature] = true
	_check(variation_signatures.size() >= 4, "Cell personal effects need at least four deterministic variants")

	var dining_count := _campus_group(campus, "campus_dining_table_sets").size()
	var bed_count := _campus_group(campus, "campus_clinical_bed_bays").size()
	var shower_count := _group_in_plan(campus, "campus_shower_heads", "medical-ground").size()
	var toilet_count := _group_in_plan(campus, "campus_toilets", "medical-ground").size()
	var urinal_count := _group_in_plan(campus, "campus_urinals", "medical-ground").size()
	_check(dining_count == 12, "Food Services must retain 12 supported dining table sets (found %d)" % dining_count)
	_check(bed_count == 6, "Medical requires six supported clinical bed bays (found %d)" % bed_count)
	_check(shower_count == 10, "Medical wet area requires 10 showers (found %d)" % shower_count)
	_check(toilet_count == 8, "Medical wet area requires 8 toilets (found %d)" % toilet_count)
	_check(urinal_count == 8, "Medical wet area requires 8 urinals (found %d)" % urinal_count)
	_check(_campus_group(campus, "watchtowers").size() == 8, "Campus requires 8 detailed watchtowers")
	_check(_campus_group(campus, "cctv_cameras").size() >= 12, "Campus security coverage is too sparse")

	var unsupported := 0
	for prop in _campus_group(campus, "campus_placed_furniture"):
		if String(prop.get_meta("support_type", "")).is_empty():
			unsupported += 1
	_check(unsupported == 0, "%d room props are missing explicit support metadata" % unsupported)

	print("CAMPUS DENSITY: %d detail assemblies %s; %d CCTV; %d cell variants" % [_sum(details), details, _campus_group(campus, "cctv_cameras").size(), variation_signatures.size()])
	if _failures.is_empty():
		print("CAMPUS DENSITY VALIDATION: PASS")
	else:
		for message in _failures:
			push_error(message)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _campus_group(campus: Node, group: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for node in get_tree().get_nodes_in_group(group):
		if campus.is_ancestor_of(node):
			result.append(node)
	return result


func _group_in_plan(campus: Node, group: StringName, plan_id: String) -> Array[Node]:
	var result: Array[Node] = []
	for node in _campus_group(campus, group):
		var ancestor := node.get_parent()
		while ancestor != null and ancestor != campus:
			if ancestor.is_in_group("campus_blueprint_floors") and String(ancestor.get("plan_id")) == plan_id:
				result.append(node)
				break
			ancestor = ancestor.get_parent()
	return result


func _sum(values: Dictionary) -> int:
	var total := 0
	for value in values.values():
		total += int(value)
	return total


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
