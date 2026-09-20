extends Node
class_name CampusPhaseTwoGameplay

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const GUARD_SCENE := preload("res://scenes/npc/Guard.tscn")
const GATE_SCENE := preload("res://scenes/interactables/PrisonSlidingGate.tscn")

var _campus: Node3D
var _failure_in_progress := false
var _restart_scheduled := false


func _ready() -> void:
	call_deferred("_activate_phase_two")


func _activate_phase_two() -> void:
	_campus = get_parent() as Node3D
	if _campus == null:
		push_error("CampusPhaseTwoGameplay must be a child of PrisonCampusPrototype.")
		return
	SuspicionSystem.reset()
	_spawn_exterior_gates()
	_spawn_player()
	_spawn_guard_patrol()


func _spawn_player() -> void:
	var spawn := _campus.get_node_or_null("Buildings/CellhouseA/Interior/ParthCell/ParthPlayableSpawn") as Marker3D
	if spawn == null:
		push_error("Phase 2 Parth spawn marker is missing.")
		return
	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.name = "Parth"
	_campus.get_node("Actors").add_child(player)
	player.global_transform = spawn.global_transform
	# Campus actors spawn deferred, after the HUD's initial player lookup.
	# Bind its existing generic interaction listener now that Parth exists.
	var hud := _campus.get_node_or_null("HUD/HUDControl")
	if hud != null:
		hud.call("_connect_player")
	var preview := _campus.get_node_or_null("PreviewCamera") as Camera3D
	if preview != null:
		preview.current = false


func _spawn_exterior_gates() -> void:
	for marker_node in get_tree().get_nodes_in_group("cellhouse_a_access_markers"):
		var marker := marker_node as Marker3D
		if marker == null or not _campus.is_ancestor_of(marker):
			continue
		var gate := _new_gate()
		gate.name = marker.name.trim_suffix("Marker")
		gate.display_name = str(marker.get_meta("display_name", "Cellhouse A Gate"))
		gate.required_key_id = &""
		gate.persistent_access_id = StringName(marker.name.to_snake_case())
		gate.starts_locked = false
		gate.gate_width = float(marker.get_meta("gate_width", 2.4))
		gate.slide_distance = float(marker.get_meta("slide_distance", 2.8))
		gate.open_direction = 1.0
		gate.reader_light_enabled = false
		gate.panel_label = "YARD" if String(marker.name).contains("Yard") else "CELLHOUSE A"
		gate.add_to_group("campus_exterior_gates")
		var access_root := _campus.get_node("Interactables") as Node3D
		# AnimatableBody3D records its initial physics transform on tree entry.
		# Configure the parent pose first or its leaf can retain identity rotation
		# even though the root was subsequently turned to face the doorway.
		gate.transform = access_root.global_transform.affine_inverse() * marker.global_transform
		access_root.add_child(gate)

	_disable_shell_placeholder("Buildings/CellhouseA/MainEntranceWest/PlaceholderDoor")
	_disable_shell_placeholder("Buildings/CellhouseA/YardExitEast/PlaceholderDoor")


func _new_gate() -> PrisonSlidingGate:
	return GATE_SCENE.instantiate() as PrisonSlidingGate


func _disable_shell_placeholder(path: String) -> void:
	var placeholder := _campus.get_node_or_null(path) as StaticBody3D
	if placeholder == null:
		push_error("Missing shell placeholder at %s" % path)
		return
	var collision := placeholder.get_node_or_null("Collision") as CollisionShape3D
	var mesh := placeholder.get_node_or_null("Mesh") as MeshInstance3D
	if collision != null:
		collision.set_deferred("disabled", true)
	if mesh != null:
		mesh.visible = false


func _spawn_guard_patrol() -> void:
	var patrol_nodes: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("cellhouse_a_patrol_points"):
		if node is Node3D and _campus.is_ancestor_of(node):
			patrol_nodes.append(node as Node3D)
	patrol_nodes.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
	if patrol_nodes.is_empty():
		push_error("Cellhouse A patrol route is missing.")
		return
	var guard := GUARD_SCENE.instantiate() as GuardController
	guard.name = "CellhouseADayroomGuard"
	guard.debug_detection = false
	guard.view_distance = 14.0
	guard.patrol_speed = 1.8
	_campus.get_node("Actors").add_child(guard)
	guard.global_position = patrol_nodes[0].global_position + Vector3.UP * 0.95
	guard.set_patrol_nodes(patrol_nodes)
	if not guard.caught_player.is_connected(_on_player_caught):
		guard.caught_player.connect(_on_player_caught)


func _on_player_caught(_guard: Node) -> void:
	if DevModeManager.blocks_player_failure():
		SuspicionSystem.reset()
		return
	if _failure_in_progress:
		return
	_failure_in_progress = true
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.call("set_failure_locked")
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
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
