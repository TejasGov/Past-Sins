extends Control
class_name PrisonMinimap

## Lightweight north-up schematic minimap. It deliberately avoids a second
## Camera3D/SubViewport so the map remains inexpensive in Web exports.

const UPDATE_INTERVAL := 0.08

var _player: Node3D
var _elapsed := 0.0
var _floor_id := "F3"
var _floor_y := 8.0
var _bounds := Rect2(-17.0, -21.0, 34.0, 42.0)
var _campus_mode := false
var _campus_maps: Array[Dictionary] = []
var _active_map: Dictionary = {}
var _access_cache: Array[Node] = []
var _map_title := ""


func _ready() -> void:
	add_to_group("minimap")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	call_deferred("_find_player")


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_minimap"):
		toggle_minimap()
	if not is_instance_valid(_player):
		_find_player()
	_elapsed += delta
	if _elapsed < UPDATE_INTERVAL:
		return
	_elapsed = 0.0
	_update_floor()
	queue_redraw()


func toggle_minimap() -> void:
	visible = not visible


func get_floor_id() -> String:
	return _floor_id


func get_visible_access_marker_count() -> int:
	var count := 0
	for item in _get_access_nodes():
		if _is_on_current_map(item as Node3D):
			count += 1
	return count


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_campus_mode = _find_campus_root() != null
	if _campus_mode and _campus_maps.is_empty(): _cache_campus_maps()
	_update_floor()
	queue_redraw()


func _update_floor() -> void:
	if not is_instance_valid(_player):
		return
	var position := _player.global_position
	if _campus_mode:
		_update_campus_map(position)
		return
	if position.y < -10.0:
		_set_floor("B2", -12.0)
	elif position.y < -6.0:
		_set_floor("B1", -8.0)
	elif position.y < -2.0:
		if position.z > 20.5:
			_floor_id = "YARD"
			_floor_y = -4.0
			_bounds = Rect2(-27.0, 20.5, 54.0, 50.5)
		else:
			_set_floor("GROUND", -4.0)
	elif position.y < 2.0:
		_set_floor("F1", 0.0)
	elif position.y < 6.0:
		_set_floor("F2", 4.0)
	elif position.y < 10.0:
		_set_floor("F3", 8.0)
	elif position.y < 14.0:
		_set_floor("F4", 12.0)
	else:
		_set_floor("ROOF", 16.0)


func _set_floor(floor_id: String, floor_y: float) -> void:
	_floor_id = floor_id
	_floor_y = floor_y
	_bounds = Rect2(-17.0, -21.0, 34.0, 42.0)


func _cache_campus_maps() -> void:
	var campus := _find_campus_root()
	if campus == null: return
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/campus/floor_plans.json"))
	for source_plan in data.plans:
		var plan: Dictionary = source_plan
		var shell: Node3D
		if String(plan.id).begins_with("cellhouse-a"):
			shell = campus.get_node("Buildings/CellhouseA")
		else:
			for floor_node in get_tree().get_nodes_in_group("campus_blueprint_floors"):
				if campus.is_ancestor_of(floor_node) and floor_node.plan_id == plan.id:
					shell = floor_node.get_parent() as Node3D
					plan = floor_node.plan
					break
		if shell:
			var footprint: Vector3 = shell.get_meta("footprint_size")
			_campus_maps.append({"plan": plan, "shell": shell, "rect": Rect2(-footprint.x * 0.5, -footprint.z * 0.5, footprint.x, footprint.z)})
	for door in get_tree().get_nodes_in_group("map_access"):
		if campus.is_ancestor_of(door): _access_cache.append(door)


func _update_campus_map(position: Vector3) -> void:
	_active_map = {}
	var best_y := -INF
	# Feet determine the occupied storey; jumping never selects the floor above.
	var feet_y := position.y - float(_player.get("standing_height") if _player is PlayerController else 1.8) * 0.5
	for entry in _campus_maps:
		if not is_instance_valid(entry.shell): continue
		var local: Vector3 = entry.shell.to_local(position)
		if not (entry.rect as Rect2).has_point(Vector2(local.x, local.z)): continue
		var floor_y: float = entry.shell.global_position.y + float(entry.plan.elevation)
		var roof_y: float = entry.shell.global_position.y + (entry.shell.get_meta("footprint_size") as Vector3).y
		# A continuous stair shaft can span an unoccupied level (HQ B1).
		# Stay on the lower destination map until the next actual floor exists.
		if feet_y + 0.35 >= floor_y and feet_y < roof_y + 0.1 and floor_y > best_y:
			best_y = floor_y
			_active_map = entry
	if _active_map.is_empty():
		_floor_id = "CAMPUS"
		_map_title = "CAMPUS"
		_floor_y = position.y
		_bounds = Rect2(-78, -94, 156, 188)
	else:
		_floor_id = String(_active_map.plan.id)
		var level := String(_active_map.plan.level).get_slice("/", 0).strip_edges()
		var building := String(_active_map.plan.name).replace("Administration & Intake", "Admin / Intake")
		_map_title = (building + " / " + level).to_upper().replace("FLOOR ", "F")
		if _floor_id == "nidra-b2" and feet_y > best_y + 4.2: _map_title = "SECURITY HQ / B2 ACCESS STAIR"
		_floor_y = best_y
		_bounds = (_active_map.rect as Rect2).grow(1.0)


func get_map_title() -> String:
	return _map_title if _campus_mode else _floor_id


func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	draw_rect(panel, Color(0.012, 0.025, 0.03, 0.9), true)
	draw_rect(panel, Color(0.18, 0.55, 0.58, 0.82), false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(12, 20), get_map_title(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 48, 12, Color("a6c9ca"))
	draw_string(font, Vector2(size.x - 30, 20), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d9c675"))
	draw_line(Vector2(size.x - 25, 28), Vector2(size.x - 25, 37), Color("d9c675"), 2.0)
	draw_line(Vector2(size.x - 25, 28), Vector2(size.x - 29, 33), Color("d9c675"), 2.0)
	draw_line(Vector2(size.x - 25, 28), Vector2(size.x - 21, 33), Color("d9c675"), 2.0)

	var map_area := _map_area()
	draw_rect(map_area, Color(0.035, 0.06, 0.065, 0.92), true)
	draw_rect(map_area, Color(0.23, 0.38, 0.39, 0.8), false, 1.0)
	_draw_grid(map_area)
	_draw_floor_layout()
	_draw_access_markers()
	_draw_player_marker()
	draw_string(font, Vector2(12, size.y - 7), "M  TOGGLE   RED LOCKED   GREEN OPEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.48, 0.66, 0.67, 0.9))


func _map_area() -> Rect2:
	var available := Vector2(maxf(20.0, size.x - 24.0), maxf(20.0, size.y - 58.0))
	var scale_factor := minf(available.x / _bounds.size.x, available.y / _bounds.size.y)
	var map_size := _bounds.size * scale_factor
	return Rect2(Vector2(12, 40) + (available - map_size) * 0.5, map_size)


func _draw_grid(area: Rect2) -> void:
	for index in range(1, 4):
		var ratio := float(index) / 4.0
		var x := lerpf(area.position.x, area.end.x, ratio)
		var y := lerpf(area.position.y, area.end.y, ratio)
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color(0.18, 0.3, 0.31, 0.24), 1.0)
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(0.18, 0.3, 0.31, 0.24), 1.0)


func _draw_floor_layout() -> void:
	if not _active_map.is_empty():
		_draw_building_layout()
		return
	var room_rects: Array[Rect2] = []
	match _floor_id:
		"CAMPUS":
			# Use the live shell metadata so later layout tuning cannot leave a
			# stale overview behind.
			var seen: Dictionary = {}
			for entry in _campus_maps:
				var shell: Node3D = entry.shell
				if seen.has(shell): continue
				seen[shell] = true
				var footprint: Vector3 = shell.get_meta("footprint_size")
				room_rects.append(Rect2(Vector2(shell.global_position.x - footprint.x * 0.5, shell.global_position.z - footprint.z * 0.5), Vector2(footprint.x, footprint.z)))
		"B2", "B1":
			room_rects = [Rect2(-16.8, -20.8, 14.4, 19.3), Rect2(2.4, -20.8, 14.4, 19.3), Rect2(-16.8, 1.5, 14.4, 19.3), Rect2(2.4, 1.5, 14.4, 19.3)]
		"GROUND":
			room_rects = [Rect2(-16.8, -20.8, 24.8, 33.0), Rect2(8.0, -20.8, 8.8, 30.3), Rect2(-6.0, 12.3, 17.5, 8.5)]
		"F1":
			room_rects = [Rect2(-16.8, -20.8, 12.8, 8.8), Rect2(-4.0, -20.8, 20.8, 8.8), Rect2(-16.8, -12.0, 33.6, 24.0), Rect2(-16.8, 12.0, 33.6, 8.8)]
		"F2", "F3":
			room_rects = [Rect2(-16.8, -20.0, 3.8, 40.0), Rect2(13.0, -20.0, 3.8, 40.0), Rect2(-13.0, -20.0, 6.0, 40.0), Rect2(7.0, -20.0, 6.0, 40.0)]
		"F4":
			room_rects = [Rect2(-16.8, -20.8, 33.6, 6.8), Rect2(-16.8, -14.0, 33.6, 9.5), Rect2(-16.8, 4.8, 11.8, 16.0), Rect2(6.0, 4.8, 10.8, 16.0)]
		"ROOF":
			room_rects = [Rect2(-16.8, -20.8, 33.6, 41.6)]
		"YARD":
			# Draw the walking-track footprint first so the court, pool, and
			# garden remain legible on top of it.
			room_rects = [Rect2(-24.5, 24.0, 49.0, 44.0), Rect2(-16.0, 26.5, 15.5, 23.0), Rect2(5.0, 46.8, 17.0, 10.4), Rect2(3.0, 38.0, 17.0, 7.0)]
	for rect in room_rects:
		_draw_world_rect(rect, Color(0.12, 0.23, 0.24, 0.5), Color(0.35, 0.62, 0.63, 0.72))
	if _floor_id == "CAMPUS":
		_draw_world_rect(Rect2(-26, -27, 52, 54), Color(0.08, 0.2, 0.13, 0.58), Color(0.45, 0.7, 0.5, 0.8))
		_draw_world_rect(Rect2(-24, 37.5, 20, 10), Color("346d83"), Color("95bfc4"))
	if _floor_id in ["F1", "F2", "F3"]:
		_draw_world_rect(Rect2(-7.0, -12.0, 14.0, 24.0), Color(0.005, 0.012, 0.014, 0.95), Color(0.38, 0.58, 0.58, 0.7))
	if _floor_id == "GROUND":
		var exit_point := _world_to_map(Vector3(0, _floor_y, 20.0))
		draw_string(ThemeDB.fallback_font, exit_point + Vector2(-32, -5), "YARD EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ffe183"))


func _draw_world_rect(world_rect: Rect2, fill: Color, outline: Color) -> void:
	var top_left := _plane_to_map(world_rect.position)
	var bottom_right := _plane_to_map(world_rect.end)
	var screen_rect := Rect2(top_left, bottom_right - top_left)
	draw_rect(screen_rect, fill, true)
	draw_rect(screen_rect, outline, false, 1.0)


func _draw_building_layout() -> void:
	var plan: Dictionary = _active_map.plan
	var origin := Vector2(float(plan.width), float(plan.depth)) * -0.5
	for room in plan.rooms:
		var rect := Rect2(origin + Vector2(room.x, room.y), Vector2(room.w, room.d))
		var fill := Color("253b3d")
		if room.type == "void": fill = Color("070e10")
		elif room.type in ["corridor", "gallery"]: fill = Color("3e5556")
		elif room.type in ["stair", "lift"]: fill = Color("675c37")
		_draw_world_rect(rect, fill, Color("789596"))
		var left := _plane_to_map(rect.position)
		var right := _plane_to_map(rect.end)
		if right.x - left.x > 20 and right.y - left.y > 14:
			var label := String(room.label).replace("\n", " ")
			if room.type == "stair": label = "STAIR"
			elif room.type == "lift": label = "LIFT"
			draw_string(ThemeDB.fallback_font, Vector2(left.x + 2, (left.y + right.y) * 0.5 + 3), label, HORIZONTAL_ALIGNMENT_LEFT, right.x - left.x - 4, 8, Color("c0d6d3"))
	# Intentional openings from the same data used to assemble room walls.
	for door in plan.doors:
		var center := origin + Vector2(door.x, door.y)
		var axis := Vector2.RIGHT if door.axis == "x" else Vector2.DOWN
		var a := _plane_to_map(center - axis * float(door.width) * 0.5)
		var b := _plane_to_map(center + axis * float(door.width) * 0.5)
		draw_line(a, b, Color("6daca0") if door.kind == "open" else Color("c6b76f"), 2.0)


func _draw_access_markers() -> void:
	for item in _get_access_nodes():
		var node := item as Node3D
		if not _is_on_current_map(node):
			continue
		var color := Color("d0aa55")
		if item.get("is_locked"):
			color = Color("dc5260")
		elif item.get("is_open"):
			color = Color("62d99a")
		var point := _world_to_map(node.global_position)
		draw_rect(Rect2(point - Vector2(2.5, 2.5), Vector2(5, 5)), color, true)


func _draw_player_marker() -> void:
	if not is_instance_valid(_player) or not _is_on_current_map(_player):
		return
	var center := _world_to_map(_player.global_position)
	var world_forward := _player.global_transform.basis * Vector3.FORWARD
	var direction := Vector2(world_forward.x, world_forward.z).normalized()
	var side := Vector2(-direction.y, direction.x)
	var points := PackedVector2Array([center + direction * 9.0, center - direction * 6.0 + side * 5.0, center - direction * 6.0 - side * 5.0])
	draw_colored_polygon(points, Color("79ecf2"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color("d8ffff"), 1.25)


func _get_access_nodes() -> Array[Node]:
	if _campus_mode:
		if not _active_map.is_empty(): return _access_cache
		var exterior: Array[Node] = []
		for node in _access_cache:
			if is_instance_valid(node) and (node.is_in_group("campus_exterior_gates") or node.is_in_group("campus_recreation_gates")):
				exterior.append(node)
		return exterior
	# HUD can be instanced below either the playable level or a validation
	# harness, so resolve the nearest owning level instead of current_scene.
	var ancestor: Node = self
	while ancestor != null:
		var root := ancestor.get_node_or_null("Interactables")
		if root != null:
			var result: Array[Node] = root.get_children()
			if _campus_mode:
				for access in get_tree().get_nodes_in_group("campus_exterior_gates"):
					if ancestor.is_ancestor_of(access) and not result.has(access): result.append(access)
			return result
		ancestor = ancestor.get_parent()
	return []


func _is_on_current_map(node: Node3D) -> bool:
	if node == null:
		return false
	if (not _campus_mode or not _active_map.is_empty()) and node != _player and absf(node.global_position.y - _floor_y) > 1.45:
		return false
	var position := node.global_position
	if not _active_map.is_empty(): position = _active_map.shell.to_local(position)
	return _bounds.has_point(Vector2(position.x, position.z))


func _find_campus_root() -> Node:
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.has_node("CampusShell") and ancestor.has_node("Buildings"):
			return ancestor
		ancestor = ancestor.get_parent()
	return null


func _world_to_map(world_position: Vector3) -> Vector2:
	if not _active_map.is_empty(): world_position = _active_map.shell.to_local(world_position)
	return _plane_to_map(Vector2(world_position.x, world_position.z))


func _plane_to_map(position: Vector2) -> Vector2:
	var area := _map_area()
	var normalized_x := inverse_lerp(_bounds.position.x, _bounds.end.x, position.x)
	var normalized_z := inverse_lerp(_bounds.position.y, _bounds.end.y, position.y)
	return Vector2(lerpf(area.position.x, area.end.x, normalized_x), lerpf(area.position.y, area.end.y, normalized_z))
