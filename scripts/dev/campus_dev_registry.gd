extends Node
class_name CampusDevRegistry

## Resolves authored rooms into named Marker3D destinations after the campus
## finishes procedural assembly. It does nothing unless Dev Mode is active.
var _campus: Node3D


func _ready() -> void:
	if not DevModeManager.is_enabled():
		return
	call_deferred("_register_campus")


func _register_campus() -> void:
	_campus = get_parent() as Node3D
	if _campus == null:
		return
	_register_world_point(&"cellhouse_a_floor_1", "Floor 1 — Dayroom", "Cellhouse A", Vector3(-50.0, 0.95, 4.2), 0.0)
	_register_world_point(&"cellhouse_a_floor_2", "Floor 2 — Gallery Bridge", "Cellhouse A", Vector3(-50.0, 4.95, 0.0), 0.0)
	_register_world_point(&"cellhouse_a_floor_3", "Floor 3 — Parth's Tier", "Cellhouse A", Vector3(-50.0, 8.95, 0.0), 0.0)

	_register_room(&"cellhouse_b_floor_1", "Floor 1 — Secure Spine", "Cellhouse B", "cellhouse-b-0", "spine")
	_register_room(&"cellhouse_b_floor_2", "Floor 2 — Secure Spine", "Cellhouse B", "cellhouse-b-1", "spine")
	_register_room(&"food_services", "Food Services — Main Hall", "Food Services", "food-ground", "hall")
	_register_room(&"food_kitchen", "Kitchen / Preparation", "Food Services", "food-ground", "prep")
	_register_room(&"medical_ward", "Medical — Infirmary Ward", "Medical & Wellness", "medical-ground", "ward")
	_register_room(&"medical_gym", "Gym", "Medical & Wellness", "medical-ground", "gym")
	_register_room(&"medical_showers", "Showers / Changing", "Medical & Wellness", "medical-ground", "changing")
	_register_room(&"security_hq_ground", "Ground Floor — Security Lobby", "Security HQ", "hq-0", "northlobby")
	_register_room(&"security_hq_upper", "Upper Floor — Command", "Security HQ", "hq-1", "spine")
	_register_room(&"security_surveillance", "Upper Floor — Surveillance", "Security HQ", "hq-1", "surveillance")
	_register_room(&"maintenance_ground", "Ground Floor — Workshop Access", "Maintenance", "maintenance-ground", "landing")
	_register_room(&"maintenance_b1", "B1 — Service Plant", "Maintenance", "maintenance-b1", "landing")
	_register_room(&"administration", "Administration / Intake", "Administration", "admin-ground", "public")
	_register_room(&"nidra_b2", "B2 — NIDRA Secure Lobby", "B2 NIDRA", "nidra-b2", "northlobby")
	_register_room(&"nidra_laboratory", "B2 — NIDRA Laboratory", "B2 NIDRA", "nidra-b2", "lab")
	_register_room(&"nidra_interrogation", "B2 — Interrogation Wing", "B2 NIDRA", "nidra-b2", "crossw")

	_register_world_point(&"central_yard", "Central Yard", "Outdoor", Vector3(0.0, 0.95, 7.0), 0.0)
	var pool := get_tree().get_first_node_in_group("swimming_water") as SwimmingPool
	if pool and _campus.is_ancestor_of(pool):
		_register_world_point(&"pool_annex", "Pool Annex — Deck", "Outdoor", pool.to_global(Vector3(0.0, 0.95, pool.pool_size.y * 0.5 + 1.15)), 180.0)


func _register_room(id: StringName, label: String, category: String, plan_id: String, room_id: String) -> void:
	for node in get_tree().get_nodes_in_group("campus_blueprint_floors"):
		if node is CampusBlueprintFloor and _campus.is_ancestor_of(node) and String(node.plan_id) == plan_id:
			var room := node.room_node(room_id) as Node3D
			if room:
				_register_world_point(id, label, category, room.global_position + Vector3.UP * 0.95, 0.0)
			return


func _register_world_point(id: StringName, label: String, category: String, world_position: Vector3, yaw: float) -> void:
	var marker := Marker3D.new()
	marker.name = String(id).to_pascal_case()
	add_child(marker)
	marker.global_position = world_position
	marker.global_rotation_degrees.y = yaw
	marker.set_meta("dev_destination_id", id)
	marker.set_meta("dev_destination_name", label)
	DevModeManager.register_teleport_point(id, label, category, marker)
