extends Node3D
class_name CampusSessionContent

const Factory := preload("res://scripts/levels/greybox_factory.gd")
const KEY := preload("res://scenes/levels/campus/gameplay/CampusMountedKey.tscn")
const MEMORY := preload("res://scenes/levels/campus/gameplay/CampusRestingMemory.tscn")
const LOCKER := preload("res://scenes/levels/campus/gameplay/CampusKeypadLocker.tscn")
var _campus: Node3D
var _built := false
var cell_key_count := 0

func _ready() -> void:
	build.call_deferred()

func build() -> void:
	if _built: return
	_campus = get_parent() as Node3D
	var interiors := _campus.get_node_or_null("CampusInteriors")
	if interiors == null or not interiors.get("floors") is Dictionary:
		push_error("CampusSessionContent requires the completed CampusInteriors assembly.")
		return
	_built = true
	_memory_shelf()
	_starter_access_rack()
	var floors: Dictionary = interiors.get("floors")
	if floors.has("hq-0"):
		_cell_key_racks(floors["hq-0"].room_node("keys"))
	if floors.has("maintenance-ground"):
		_maintenance_locker(floors["maintenance-ground"].room_node("tool"))

func _memory_shelf() -> void:
	var cell := _campus.get_node_or_null("Buildings/CellhouseA/Interior/ParthCell") as Node3D
	if cell == null:
		push_error("CampusSessionContent cannot find Parth's existing cell.")
		return
	var shelf := Node3D.new()
	shelf.name = "MemoryBedsideShelf"
	shelf.position = Vector3(1.5, 0, -2.4)
	cell.add_child(shelf)
	var g = Factory.new(shelf)
	g.box("WallBackplate", Vector3(0, 0.7, 0), Vector3(0.76, 0.44, 0.05), Color("73756a"), false)
	g.box("ShelfBoard", Vector3(0, 0.82, 0.24), Vector3(0.76, 0.1, 0.48), Color("75634d"))
	for x in [-0.25, 0.25]:
		g.box("ShelfBracket", Vector3(x, 0.72, 0.19), Vector3(0.06, 0.12, 0.4), Color("333c36"), false)
	var memory := MEMORY.instantiate() as MemoryShard
	memory.name = "Memory001"
	memory.memory_id = &"memory_001"
	memory.position = Vector3(0, 1.22, 0.24)
	memory.add_to_group("campus_memory_shards")
	shelf.add_child(memory)

func _starter_access_rack() -> void:
	var interior := _campus.get_node("Buildings/CellhouseA/Interior") as Node3D
	var rack := Node3D.new()
	rack.name = "TemporaryExplorationKeyRack"
	# Floor 1 south-east dayroom side: no stair run, gallery gate or bridge.
	rack.position = Vector3(10.5, 0, 2.8)
	interior.add_child(rack)
	var g = Factory.new(rack)
	g.box("RackPanel", Vector3(0, 1.45, 0), Vector3(2.5, 1.25, 0.1), Color("52615a"))
	for x in [-1.04, 1.04]:
		g.box("RackLeg", Vector3(x, 0.56, 0), Vector3(0.1, 1.12, 0.1), Color("343b35"))
		g.box("RackFoot", Vector3(x, 0.04, 0), Vector3(0.42, 0.08, 0.72), Color("343b35"))
	_sign(rack, "TEMPORARY EXPLORATION KEYS", Vector3(0, 2.25, 0.06))
	g.box("HeaderSupports", Vector3(0, 2.08, 0), Vector3(0.06, 0.35, 0.06), Color("343b35"), false)
	var entries := [
		{"id": "cellblock_key", "label": "Cell Block Key", "short": "CELL BLOCK"},
		{"id": "service_key", "label": "Service Key", "short": "SERVICE"},
		{"id": "medical_key", "label": "Medical Key", "short": "MEDICAL"},
	]
	for i in range(entries.size()):
		_mounted_key(rack, Vector3(-0.8 + i * 0.8, 1.42, 0.14), entries[i], 0.72)

func _cell_key_racks(room: Node3D) -> void:
	var entries: Dictionary = {}
	# A's initially unlocked Parth door still receives its individual key ID.
	for cell in get_tree().get_nodes_in_group("campus_cells"):
		if not _campus.is_ancestor_of(cell): continue
		var id := String(cell.get_meta("cell_access_id", ""))
		if not id.is_empty():
			entries[id + "_key"] = {"id": id + "_key", "label": String(cell.get("cell_display_name")) + " Key", "short": id.replace("cellhouse_a_", "A ").replace("floor", "F").replace("cell_", "").replace("north", "N").replace("south", "S").replace("_", " ")}
	_collect_cell_gate_keys(_campus, entries)
	var ids := entries.keys()
	ids.sort()
	cell_key_count = ids.size()
	var r: Dictionary = room.get_meta("room_data")
	var half_width := float(r.w) * 0.5
	for side in [-1.0, 1.0]:
		var rack := Node3D.new()
		rack.name = "CellKeyRackWest" if side < 0 else "CellKeyRackEast"
		rack.position = Vector3(side * (half_width - 0.11), 0, 0)
		rack.rotation.y = -side * PI * 0.5
		room.add_child(rack)
		var g = Factory.new(rack)
		g.box("WallMountedKeyPanel", Vector3(0, 1.65, 0.04), Vector3(6.3, 2.45, 0.08), Color("48564d"))
		_sign(rack, "INDIVIDUAL CELL KEY REGISTER", Vector3(0, 3.0, 0.065))
		for slot in range(36):
			var index: int = slot + (0 if side < 0 else 36)
			if index >= ids.size(): break
			var column := slot % 9
			var row := int(slot / 9.0)
			_mounted_key(rack, Vector3(-2.68 + column * 0.67, 0.66 + row * 0.62, 0.14), entries[ids[index]], 0.55)
	room.set_meta("individual_cell_key_count", cell_key_count)

func _collect_cell_gate_keys(node: Node, entries: Dictionary) -> void:
	if node is PrisonSlidingGate:
		var id := String(node.required_key_id)
		if id.begins_with("cell_") and id != "cell_master_key":
			entries[id] = {"id": id, "label": node.display_name + " Key", "short": id.replace("cell_cellhouse-b-", "B ").replace("_", " ")}
	for child in node.get_children():
		_collect_cell_gate_keys(child, entries)

func _mounted_key(parent: Node3D, at: Vector3, entry: Dictionary, size: float) -> void:
	var key := KEY.instantiate() as KeyPickup
	key.name = String(entry.id).validate_node_name()
	key.key_id = StringName(entry.id)
	key.display_name = entry.label
	key.set("rack_label", entry.short)
	key.position = at
	key.scale = Vector3.ONE * size
	key.add_to_group("campus_key_pickups")
	if String(entry.id).begins_with("cellhouse_") or String(entry.id).begins_with("cell_cellhouse"):
		key.add_to_group("cell_key_pickups")
	parent.add_child(key)
	var g = Factory.new(parent)
	g.box("KeyHook", Vector3(at.x, at.y + 0.44 * size, 0.105), Vector3(0.035, 0.04, 0.17), Color("a4aaa1"), false)

func _maintenance_locker(room: Node3D) -> void:
	var r: Dictionary = room.get_meta("room_data")
	var locker := LOCKER.instantiate() as KeypadLocker
	locker.name = "MaintenanceKeypadLocker"
	locker.correct_code = "2718"
	# Centre of the south wall is the tool↔utilities doorway. Use its east
	# wall pocket, leaving both the through-route and outward door swing clear.
	locker.position = Vector3(2.6, 1.1, float(r.d) * 0.5 - 0.62)
	locker.set_meta("content_id", "maintenance_keypad_locker")
	locker.add_to_group("campus_keypad_lockers")
	room.add_child(locker)

func _sign(parent: Node3D, text: String, at: Vector3) -> void:
	var g = Factory.new(parent)
	g.box("SignBacking", at - Vector3(0, 0, 0.025), Vector3(2.45, 0.28, 0.05), Color("29362d"), false)
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 26
	label.pixel_size = 0.003
	parent.add_child(label)
