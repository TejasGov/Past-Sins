extends Node3D
class_name CampusInteriorAssembly

const FLOOR := preload("res://scenes/levels/campus/interiors/CampusBlueprintFloor.tscn")
const STAIR := preload("res://scenes/levels/campus/modules/CampusSwitchbackStair.tscn")
const GATE := preload("res://scenes/levels/campus/modules/CampusTelescopicGate.tscn")
const ANNEX := preload("res://scenes/levels/campus/zones/CampusRecreationAnnex.tscn")
const Factory := preload("res://scripts/levels/greybox_factory.gd")
const PlanCompactor := preload("res://scripts/levels/campus/interiors/campus_plan_compactor.gd")
@export var furnishings_enabled := true
var floors: Dictionary = {}
var _campus: Node3D

func _ready() -> void:
	_campus = get_parent() as Node3D
	var document = JSON.parse_string(FileAccess.get_file_as_string("res://data/campus/floor_plans.json"))
	var assignments := {
		"food-ground": "FoodServices", "medical-ground": "MedicalWellness",
		"cellhouse-b-0": "CellhouseB", "cellhouse-b-1": "CellhouseB",
		"hq-0": "SecurityHQ", "hq-1": "SecurityHQ", "nidra-b2": "SecurityHQ",
		"maintenance-ground": "Maintenance", "maintenance-b1": "Maintenance", "admin-ground": "Administration"
	}
	for data in document.plans:
		if not assignments.has(String(data.id)): continue
		var shell := _campus.get_node("Buildings/" + assignments[String(data.id)]) as Node3D
		var floor_node := FLOOR.instantiate() as CampusBlueprintFloor
		floor_node.name = String(data.id).to_pascal_case()
		floor_node.plan_id = String(data.id)
		floor_node.plan = PlanCompactor.compact(data)
		floor_node.furnishings_enabled = furnishings_enabled
		floor_node.story_height = 4.8 if String(data.id) in ["food-ground", "medical-ground", "maintenance-ground", "admin-ground"] else 4.0
		floor_node.position.y = float(data.elevation)
		shell.add_child(floor_node)
		floors[String(data.id)] = floor_node
	for name in ["FoodServices", "MedicalWellness", "CellhouseB", "SecurityHQ", "Maintenance", "Administration"]:
		_remove_placeholder_doors(_campus.get_node("Buildings/" + name))
	_connect_stairs("cellhouse-b-0", "cellhouse-b-1", "stairn")
	_connect_stairs("cellhouse-b-0", "cellhouse-b-1", "stairs")
	_connect_stairs("hq-0", "hq-1", "stairs")
	_connect_stairs("maintenance-b1", "maintenance-ground", "stair")
	_build_nidra_shaft()
	_cellhouse_b_sector_gates()
	if furnishings_enabled:
		var annex := ANNEX.instantiate()
		annex.name = "RecreationAnnex"
		_campus.get_node("EnvironmentalProps").add_child(annex)
	_add_wayfinding()
	var furniture_batcher := preload("res://scripts/levels/campus/furnishing/campus_furniture_batcher.gd")
	for building in _campus.get_node("Buildings").get_children():
		if building is Node3D:
			furniture_batcher.consolidate_building_furnishings(building as Node3D)
	_apply_interior_visibility_ranges()
	preload("res://scripts/levels/campus/modules/campus_static_batching.gd").cellhouse(_campus.get_node("Buildings/CellhouseA/Interior"))
	for stair in get_tree().get_nodes_in_group("campus_switchback_stairs"):
		if _campus.is_ancestor_of(stair):
			preload("res://scripts/levels/campus/furnishing/campus_furniture_batcher.gd").consolidate(stair)

func _apply_interior_visibility_ranges() -> void:
	# Compatibility/Web has no default occlusion pass. Interior meshes are
	# therefore distance culled as a group: a player can still see every tier
	# and bridge in the current building, while distant sealed buildings do not
	# consume draw calls through their walls. Colliders and gameplay nodes remain
	# untouched, and 46m exceeds every building's local room/atrium sightline.
	const INTERIOR_DRAW_DISTANCE := 46.0
	for building in _campus.get_node("Buildings").get_children():
		if not building is Node3D:
			continue
		for node in building.find_children("*", "", true, false):
			if node is GeometryInstance3D:
				var visual := node as GeometryInstance3D
				if visual.visibility_range_end <= 0.0:
					visual.visibility_range_end = INTERIOR_DRAW_DISTANCE
					visual.set_meta("interior_distance_culled", true)

func _remove_placeholder_doors(root: Node) -> void:
	for child in root.get_children():
		if child is StaticBody3D and child.name == "PlaceholderDoor":
			child.collision_layer = 0
			child.visible = false
		else:
			_remove_placeholder_doors(child)

func _entrance(floor_node: CampusBlueprintFloor, id: String) -> Dictionary:
	var r: Dictionary = floor_node.room_node(id).get_meta("room_data")
	for d in floor_node.door_records:
		if d.a != id and d.b != id: continue
		# Cellhouse B's secondary staff door can share the surrounding landing
		# ring, but the primary doorway toward the spine defines flight approach.
		if d.kind == "staff" and id == "stairn" and floor_node.plan_id.begins_with("cellhouse-b"): continue
		if d.axis == "x":
			return {"side": "n" if absf(float(d.y) - float(r.y)) < 0.01 else "s", "offset": float(d.x) - float(r.x) - float(r.w) * 0.5}
		return {"side": "w" if absf(float(d.x) - float(r.x)) < 0.01 else "e", "offset": float(d.y) - float(r.y) - float(r.d) * 0.5}
	return {"side": "s", "offset": 0.0}

func _connect_stairs(lower_id: String, upper_id: String, room_id: String, build_lower := true, continues := false) -> CampusSwitchbackStair:
	var lower: CampusBlueprintFloor = floors[lower_id]
	var upper: CampusBlueprintFloor = floors[upper_id]
	var room := lower.room_node(room_id)
	var r: Dictionary = room.get_meta("room_data")
	var entrance := _entrance(lower, room_id)
	var exit_info := _entrance(upper, room_id)
	var stair := STAIR.instantiate() as CampusSwitchbackStair
	stair.name = "Stair_" + room_id
	stair.width = float(r.w)
	stair.depth = float(r.d)
	stair.position = room.position
	stair.lower_entrance_side = entrance.side
	stair.lower_entrance_offset = entrance.offset
	stair.upper_entrance_side = exit_info.side
	stair.upper_entrance_offset = exit_info.offset
	stair.build_lower_landing = build_lower
	stair.continues_above = continues
	if lower_id == "cellhouse-b-0" and room_id == "stairn":
		stair.secondary_upper_entrances.assign([{"side": "e", "offset": -3.85, "width": 1.1}])
		stair.secondary_lower_entrances.assign([{"side": "e", "offset": -3.85, "width": 1.1}])
	lower.add_child(stair)
	return stair

func _build_nidra_shaft() -> void:
	var b2: CampusBlueprintFloor = floors["nidra-b2"]
	var room := b2.room_node("stairn")
	var shell := b2.get_parent() as Node3D
	var shaft := Node3D.new()
	shaft.name = "NidraSealedB1StairShaft"
	shaft.position = Vector3(room.position.x, -4.0, room.position.z)
	shell.add_child(shaft)
	var g = Factory.new(shaft)
	for x in [-3.0, 3.0]:
		g.box("ShaftSide", Vector3(x, 2, 0), Vector3(0.22, 4, 9.22), Color("676f66"))
	for z in [-4.5, 4.5]:
		g.box("ShaftEnd", Vector3(0, 2, z), Vector3(6.0, 4, 0.22), Color("676f66"))
	for elevation in [-8.0, -4.0]:
		var stair := STAIR.instantiate() as CampusSwitchbackStair
		stair.name = "NidraStair%d" % int(-elevation)
		stair.position = Vector3(room.position.x, elevation, room.position.z)
		stair.lower_entrance_side = "s"
		stair.upper_entrance_side = "s"
		stair.continues_above = true
		stair.build_lower_landing = elevation == -8.0
		shell.add_child(stair)
	_connect_stairs("hq-0", "hq-1", "stairn", false, false)

func _cellhouse_b_sector_gates() -> void:
	var shell := _campus.get_node("Buildings/CellhouseB") as Node3D
	var footprint: Vector3 = shell.get_meta("footprint_size")
	for config in [{"name": "SecurityPerimeterWestGate", "width": 3.0, "pos": Vector3(-(footprint.x + 8.0) * 0.5 - 0.28, 0, 0), "yaw": -PI * 0.5}, {"name": "SecurityPerimeterNorthGate", "width": 7.2, "pos": Vector3(0, 0, -(footprint.z + 8.0) * 0.5 - 0.28), "yaw": PI}]:
		var placeholder := shell.get_node(config.name) as StaticBody3D
		placeholder.collision_layer = 0
		placeholder.visible = false
		var gate := GATE.instantiate() as PrisonSlidingGate
		gate.name = "Operable" + String(config.name)
		gate.gate_width = config.width
		gate.gate_height = 3.6
		gate.required_key_id = &"security_key"
		gate.persistent_access_id = StringName(config.name)
		gate.position = config.pos
		gate.rotation.y = config.yaw
		gate.reader_light_enabled = false
		shell.add_child(gate)

func _add_wayfinding() -> void:
	# Grounded wayfinding boards at decisions, not in primary corridors.
	var g = Factory.new(self)
	for config in [{"pos": Vector3(-27.5, 0, 8), "text": "CELLHOUSE A  ←\nCAFETERIA  ↑\nMEDICAL / GYM / POOL  ↓"}, {"pos": Vector3(27.5, 0, 8), "text": "HIGH SECURITY  →\nSECURITY HQ  ↑\nMAINTENANCE  ↓"}]:
		var p: Vector3 = config.pos
		g.box("WayfindingPost", p + Vector3(0, 1.2, 0), Vector3(0.12, 2.4, 0.12), Color("3a443d"))
		g.box("WayfindingBoard", p + Vector3(0, 2.1, 0), Vector3(2.5, 1.0, 0.1), Color("263b30"), false)
		g.sign(config.text, p + Vector3(0, 2.1, 0.06), Vector3.ZERO, Color("d9dfc9"), 0.003)
