extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const GUARD_SCENE := preload("res://scenes/npc/Guard.tscn")
const MEMORY_SCENE := preload("res://scenes/interactables/MemoryShard.tscn")
const LOCKER_SCENE := preload("res://scenes/interactables/KeypadLocker.tscn")
const ZONE_SCENE := preload("res://scenes/interactables/RestrictedZone.tscn")
const NORMAL_DOOR_SCENE := preload("res://scenes/interactables/NormalDoor.tscn")
const PRISON_GATE_SCENE := preload("res://scenes/interactables/PrisonSlidingGate.tscn")
const KEY_PICKUP_SCENE := preload("res://scenes/interactables/KeyPickup.tscn")

const FLOOR_3_Y := 8.0
const FLOOR_3_VISUAL_LAYER := 64

@onready var actors: Node3D = $Actors
@onready var interactables: Node3D = $Interactables
@onready var patrols: Node3D = $PatrolPoints

var _failure_in_progress := false
var _restart_scheduled := false


func _ready() -> void:
	SuspicionSystem.reset()
	_spawn_floor_3_gameplay()
	_spawn_access_content()
	_spawn_high_security_guards()


func _spawn_floor_3_gameplay() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	actors.add_child(player)
	_set_visual_layer(player, FLOOR_3_VISUAL_LAYER)
	player.position = Vector3(-14.2, FLOOR_3_Y + 0.95, -12.5)
	player.rotation.y = deg_to_rad(-90.0)

	var memory := MEMORY_SCENE.instantiate() as MemoryShard
	actors.add_child(memory)
	_set_visual_layer(memory, FLOOR_3_VISUAL_LAYER)
	memory.position = Vector3(-15.6, FLOOR_3_Y + 1.25, -13.35)

	var locker := LOCKER_SCENE.instantiate() as KeypadLocker
	actors.add_child(locker)
	_set_visual_layer(locker, FLOOR_3_VISUAL_LAYER)
	locker.position = Vector3(16.0, FLOOR_3_Y + 1.1, 17.5)
	locker.rotation.y = deg_to_rad(90.0)

	var zone := ZONE_SCENE.instantiate() as RestrictedZone
	actors.add_child(zone)
	_set_visual_layer(zone, FLOOR_3_VISUAL_LAYER)
	zone.position = Vector3(15.0, FLOOR_3_Y + 1.5, 17.5)
	zone.configure(Vector3(3.6, 3.0, 4.6), 3.25, &"MAINTENANCE")

	var patrol_positions := [
		Vector3(-10, FLOOR_3_Y, -10),
		Vector3(-10, FLOOR_3_Y, -6),
		Vector3(-6, FLOOR_3_Y, -6),
		Vector3(6, FLOOR_3_Y, -6),
		Vector3(10, FLOOR_3_Y, -6),
		Vector3(10, FLOOR_3_Y, 9),
		Vector3(6, FLOOR_3_Y, 9),
		Vector3(-6, FLOOR_3_Y, 9),
		Vector3(-10, FLOOR_3_Y, 9),
	]
	var points: Array[Node3D] = []
	for index in range(patrol_positions.size()):
		var point := Marker3D.new()
		point.name = "Floor3PatrolPoint%02d" % index
		patrols.add_child(point)
		point.position = patrol_positions[index]
		points.append(point)

	var guard := GUARD_SCENE.instantiate() as GuardController
	actors.add_child(guard)
	_set_visual_layer(guard, FLOOR_3_VISUAL_LAYER)
	guard.position = Vector3(-10, FLOOR_3_Y + 1.0, -4)
	guard.set_patrol_nodes(points)
	if not guard.caught_player.is_connected(_on_player_caught):
		guard.caught_player.connect(_on_player_caught)


func _spawn_access_content() -> void:
	# Ordinary room doors. Slide motion is used where a swing leaf would compete
	# with narrow service corridors; larger rooms use conventional swing doors.
	_spawn_normal_door("ShowerDoor", Vector3(3.75, 0, -12), 0.0, "Shower Door", NormalDoor.MotionType.SWING, 1.0, 16)
	_spawn_normal_door("GymDoor", Vector3(-6.75, 0, 12), 0.0, "Gym Door", NormalDoor.MotionType.SWING, -1.0, 16)
	_spawn_normal_door("InfirmaryDoor", Vector3(-2.5, -8, -10), 90.0, "Infirmary Door", NormalDoor.MotionType.SLIDE, -1.0, 4)
	_spawn_normal_door("MedicineStorageDoor", Vector3(-14.3, -8, -2.25), 0.0, "Secured Medicine Storage", NormalDoor.MotionType.SLIDE, 1.0, 4, &"medical_key", &"medicine_storage", true)
	_spawn_normal_door("KitchenDoor", Vector3(2.5, -8, -12), 90.0, "Kitchen Door", NormalDoor.MotionType.SLIDE, 1.0, 4)
	_spawn_normal_door("StorageDoor", Vector3(7, -8, 8), 90.0, "Storage Door", NormalDoor.MotionType.SLIDE, 1.0, 4)
	_spawn_normal_door("SecurityOfficeDoor", Vector3(-10, 12, 4.8), 0.0, "Security Office Door", NormalDoor.MotionType.SWING, 1.0, 128)
	_spawn_normal_door("EvidenceStorageDoor", Vector3(9, 12, 4.8), 0.0, "Evidence Storage Door", NormalDoor.MotionType.SLIDE, 1.0, 128)
	_spawn_normal_door("InterrogationDoor", Vector3(5, -12, -1.5), 0.0, "Interrogation Door", NormalDoor.MotionType.SLIDE, 1.0, 2)

	# Prison gates fill the open center passage in the static barred thresholds.
	# High-security B2/F4 keys intentionally have no pickup in this prototype.
	_spawn_prison_gate("ParthCellGate", Vector3(-12.88, 8, -12.5), 90.0, "Cell 07 Gate", &"", &"parth_cell_gate", 1.0, 64, 1.2, 1.4, false)
	_spawn_prison_gate("Floor3NorthWingGate", Vector3(-10, 8, -14.0), 0.0, "Floor 3 North Wing Gate", &"cellblock_key", &"floor3_north_wing_gate", 1.0, 64)
	_spawn_prison_gate("Floor2WingGate", Vector3(10, 4, 14.0), 0.0, "Floor 2 Wing Gate", &"cellblock_key", &"floor2_wing_gate", 1.0, 32)
	_spawn_prison_gate("Floor2NorthWestGate", Vector3(-10, 4, -14.0), 0.0, "Floor 2 North High Security Gate", &"cellblock_key", &"floor2_north_west_gate", -1.0, 32)
	_spawn_prison_gate("Floor2NorthEastGate", Vector3(10, 4, -14.0), 0.0, "Floor 2 North High Security Gate", &"cellblock_key", &"floor2_north_east_gate", 1.0, 32)
	_spawn_prison_gate("Floor2SouthWestGate", Vector3(-10, 4, 14.0), 0.0, "Floor 2 South High Security Gate", &"cellblock_key", &"floor2_south_west_gate", -1.0, 32)
	_spawn_prison_gate("Floor3NorthEastGate", Vector3(10, 8, -14.0), 0.0, "Floor 3 North High Security Gate", &"cellblock_key", &"floor3_north_east_gate", 1.0, 64)
	_spawn_prison_gate("Floor3SouthWestGate", Vector3(-10, 8, 14.0), 0.0, "Floor 3 South High Security Gate", &"cellblock_key", &"floor3_south_west_gate", -1.0, 64)
	_spawn_prison_gate("Floor3SouthEastGate", Vector3(10, 8, 14.0), 0.0, "Floor 3 South High Security Gate", &"cellblock_key", &"floor3_south_east_gate", 1.0, 64)
	_spawn_prison_gate("GroundSecureGate", Vector3(12.75, -4, 9.5), 0.0, "Ground Secure Gate", &"service_key", &"ground_secure_gate", 1.0, 8, 1.3, 1.45)
	_spawn_prison_gate("YardSecurityGate", Vector3(0, -4, 20.82), 0.0, "Exercise Yard Gate", &"", &"yard_security_gate", 1.0, 8, 3.0, 3.25, false)
	_spawn_prison_gate("B1MedicalGate", Vector3(-4, -8, 1.5), 0.0, "Medical Service Gate", &"medical_key", &"b1_medical_gate", 1.0, 4)
	_spawn_prison_gate("B2AccessGate", Vector3(10.0, -12, 13.0), 90.0, "B2 Access Gate", &"lab_key", &"b2_access_gate", 1.0, 2, 1.3, 1.45)
	_spawn_prison_gate("Floor4SecurityGate", Vector3(3.75, 12, -4.5), 0.0, "Surveillance Security Gate", &"security_key", &"floor4_security_gate", 1.0, 128)
	_spawn_prison_gate("Floor4WestSecurityGate", Vector3(-6.75, 12, -4.5), 0.0, "Surveillance West Gate", &"security_key", &"floor4_west_security_gate", -1.0, 128)
	# The maintenance cell remains architecturally separate from the prisoner
	# gallery while preserving the existing service-key route.
	_spawn_prison_gate("Floor3StaffGate", Vector3(12.88, 8, 17.5), 90.0, "Maintenance Staff Gate", &"service_key", &"floor3_staff_gate", -1.0, 64, 1.3, 1.45)

	# Test keys sit on the valid initial exploration route and persist through a
	# detention reload via AccessManager.
	_spawn_key_pickup("CellBlockKeyPickup", Vector3(-10.2, 9.0, -8.5), &"cellblock_key", "Cell Block Key", 64)
	_spawn_key_pickup("ServiceKeyPickup", Vector3(-10.0, 5.0, 7.5), &"service_key", "Service Key", 32)
	_spawn_key_pickup("MedicalKeyPickup", Vector3(-5.0, -3.0, 16.0), &"medical_key", "Medical Key", 8)


func _spawn_high_security_guards() -> void:
	# One dedicated patrol remains inside each north/south high-security zone on
	# both cell-block floors. Their patrol points never leave the gated areas.
	_spawn_zone_guard("Floor2NorthSecurityGuard", 4.0, -1.0, 32)
	_spawn_zone_guard("Floor2SouthSecurityGuard", 4.0, 1.0, 32)
	_spawn_zone_guard("Floor3NorthSecurityGuard", 8.0, -1.0, 64)
	_spawn_zone_guard("Floor3SouthSecurityGuard", 8.0, 1.0, 64)


func _spawn_zone_guard(node_name: String, floor_y: float, zone_sign: float, visual_layer: int) -> void:
	var near_z := 16.0 * zone_sign
	var far_z := 19.0 * zone_sign
	var positions := [
		Vector3(-9.5, floor_y, near_z),
		Vector3(0, floor_y, near_z),
		Vector3(9.5, floor_y, near_z),
		Vector3(9.5, floor_y, far_z),
		Vector3(0, floor_y, far_z),
		Vector3(-9.5, floor_y, far_z),
	]
	var points: Array[Node3D] = []
	for index in range(positions.size()):
		var point := Marker3D.new()
		point.name = "%sPoint%02d" % [node_name, index]
		patrols.add_child(point)
		point.position = positions[index]
		points.append(point)
	var guard := GUARD_SCENE.instantiate() as GuardController
	guard.name = node_name
	guard.debug_detection = false
	guard.view_distance = 11.0
	guard.patrol_speed = 1.7
	guard.patrol_only = true
	actors.add_child(guard)
	guard.position = positions[0] + Vector3.UP * 0.95
	guard.set_patrol_nodes(points)
	_set_visual_layer(guard, visual_layer)
	if not guard.caught_player.is_connected(_on_player_caught):
		guard.caught_player.connect(_on_player_caught)


func _spawn_normal_door(node_name: String, world_position: Vector3, yaw_degrees: float, door_name: String, motion: int, direction: float, visual_layer: int, required_key_id: StringName = &"", access_id: StringName = &"", locked := false) -> void:
	var door := NORMAL_DOOR_SCENE.instantiate() as NormalDoor
	door.name = node_name
	door.position = world_position
	door.rotation_degrees.y = yaw_degrees
	door.display_name = door_name
	door.motion_type = motion
	door.open_direction = direction
	door.required_key_id = required_key_id
	door.persistent_access_id = access_id
	door.starts_locked = locked
	interactables.add_child(door)
	_set_visual_layer(door, visual_layer)


func _spawn_prison_gate(node_name: String, world_position: Vector3, yaw_degrees: float, gate_name: String, key_id: StringName, access_id: StringName, direction: float, visual_layer: int, width := 1.5, travel := 1.7, locked := true) -> void:
	var gate := PRISON_GATE_SCENE.instantiate() as PrisonSlidingGate
	gate.name = node_name
	gate.position = world_position
	gate.rotation_degrees.y = yaw_degrees
	gate.display_name = gate_name
	gate.required_key_id = key_id
	gate.persistent_access_id = access_id
	gate.starts_locked = locked
	gate.open_direction = direction
	gate.gate_width = width
	gate.slide_distance = travel
	interactables.add_child(gate)
	_set_visual_layer(gate, visual_layer)


func _spawn_key_pickup(node_name: String, world_position: Vector3, key_id: StringName, key_name: String, visual_layer: int) -> void:
	var pickup := KEY_PICKUP_SCENE.instantiate() as KeyPickup
	pickup.name = node_name
	pickup.position = world_position
	pickup.key_id = key_id
	pickup.display_name = key_name
	interactables.add_child(pickup)
	_set_visual_layer(pickup, visual_layer)


func _set_visual_layer(root: Node, layer_mask: int) -> void:
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).layers = layer_mask
	for child in root.get_children():
		_set_visual_layer(child, layer_mask)


func _on_player_caught(_guard: Node) -> void:
	if _failure_in_progress:
		return
	_failure_in_progress = true
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.call("set_failure_locked")
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		if not hud.is_connected("detention_fade_finished", _restart_after_detention):
			hud.connect("detention_fade_finished", _restart_after_detention, CONNECT_ONE_SHOT)
		hud.call("show_detained")
	else:
		_restart_after_detention()


func _restart_after_detention() -> void:
	if _restart_scheduled:
		return
	_restart_scheduled = true
	get_tree().create_timer(1.0).timeout.connect(_reload_level, CONNECT_ONE_SHOT)


func _reload_level() -> void:
	get_tree().reload_current_scene()
