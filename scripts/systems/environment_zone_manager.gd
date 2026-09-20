extends WorldEnvironment
class_name EnvironmentZoneManager

## One inset, footprint-derived Area per building.  Polling cached bounds also
## handles teleports, spawn-inside and free-camera reviews without waiting for
## overlap.  The horizontal inset keeps the environment boundary away from a
## doorway threshold, where a player may pause while a door animates.
const LIGHTING := preload("res://scripts/systems/interior_lighting_profiles.gd")
const DEFAULT_DOORWAY_INSET_METERS := 2.0
@export var exterior_template: Environment = preload("res://resources/environments/env_exterior.tres")
@export var interior_template: Environment = preload("res://resources/environments/env_interior.tres")
@export_range(0.0, 5.0, 0.1) var doorway_inset_meters := DEFAULT_DOORWAY_INSET_METERS
var exterior: Environment
var interior: Environment
var is_interior := false
var active_profile := "cellblock"
var _zones: Array[Dictionary] = []
var _rooms: Array[Node3D] = []
var _custom_rooms: Array[Node3D] = []
var _elapsed := 0.0
var _night := false
var _active_floor: Node3D

func _ready() -> void:
	exterior = exterior_template.duplicate(true)
	interior = interior_template.duplicate(true)
	# Same evolving sky when looking out a window; indoor air remains clear.
	interior.background_mode = Environment.BG_SKY
	interior.sky = exterior.sky
	environment = exterior
	add_to_group("environment_zone_managers")
	call_deferred("_register_buildings")

func _register_buildings() -> void:
	var campus := get_parent()
	for building in get_tree().get_nodes_in_group("campus_buildings"):
		if not campus.is_ancestor_of(building): continue
		var size: Vector3 = building.get_meta("footprint_size")
		var bottom := 0.0
		for child in building.get_children():
			if child is Node3D: bottom = minf(bottom, child.position.y)
		var area := Area3D.new()
		area.name = "InteriorEnvironmentZone"
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitorable = false
		area.position.y = (bottom + size.y) * 0.5
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		# Keep each boundary roughly two metres inside every exterior doorway.
		# This leaves a short vestibule/threshold buffer so standing in a doorway
		# cannot alternate the environment state on every physics tick.
		var inset := clampf(doorway_inset_meters, 0.0, minf(size.x, size.z) * 0.49)
		box.size = Vector3(
			maxf(1.0, size.x - inset * 2.0),
			maxf(0.1, size.y - bottom),
			maxf(1.0, size.z - inset * 2.0)
		)
		shape.shape = box
		area.add_child(shape)
		building.add_child(area)
		area.add_to_group("interior_environment_zones")
		area.set_meta("doorway_inset_meters", inset)
		area.set_meta("source_footprint_size", size)
		area.body_entered.connect(_body_changed)
		area.body_exited.connect(_body_changed)
		_zones.append({"building": building, "area": area, "size": box.size})
	for room in get_tree().get_nodes_in_group("campus_planned_rooms"):
		if campus.is_ancestor_of(room): _rooms.append(room)
	for room in get_tree().get_nodes_in_group("environment_rooms"):
		if campus.is_ancestor_of(room) and room.has_meta("environment_bounds"):
			_custom_rooms.append(room)
	refresh_from_viewer()

func _body_changed(body: Node3D) -> void:
	if body.is_in_group("player"): refresh_from_viewer()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.15:
		_elapsed = 0.0
		refresh_from_viewer()

func set_interior(enabled: bool) -> void:
	is_interior = enabled
	environment = interior if enabled else exterior
	interior.fog_enabled = false

func set_time_state(night: bool) -> void:
	_night = night
	_apply_ambient()
	refresh_from_viewer()

func _apply_ambient() -> void:
	interior.ambient_light_color = Color(0.95, 0.88, 0.72)
	interior.ambient_light_energy = 0.22 * (0.65 if _night else 1.0)
	interior.ambient_light_sky_contribution = 0.0

func refresh_from_viewer() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var current_building: Node3D = null
	for zone in _zones:
		var point: Vector3 = zone.area.to_local(camera.global_position)
		var half: Vector3 = zone.size * 0.5
		if absf(point.x) <= half.x and absf(point.y) <= half.y and absf(point.z) <= half.z:
			current_building = zone.building
			break
	set_interior(current_building != null)
	var selected: Node3D = null
	if current_building:
		active_profile = "cellblock" if "Cellhouse" in str(current_building.name) else "office"
		for room in _rooms:
			if not current_building.is_ancestor_of(room): continue
			var p := room.to_local(camera.global_position)
			var data: Dictionary = room.get_meta("room_data")
			var height: float = room.get_parent().story_height
			if absf(p.x) < float(data.w) * 0.5 and absf(p.z) < float(data.d) * 0.5 and p.y >= 0 and p.y < height:
				selected = room
				active_profile = LIGHTING.profile_id(String(data.get("lighting_type", data.type)))
				break
		for room in _custom_rooms:
			if not current_building.is_ancestor_of(room): continue
			var bounds: AABB = room.get_meta("environment_bounds")
			if bounds.has_point(room.to_local(camera.global_position)):
				active_profile = LIGHTING.profile_id(String(room.get_meta("lighting_type", "office")))
				selected = null
				break
	_apply_ambient()
	if is_instance_valid(_active_floor) and (selected == null or selected.get_parent() != _active_floor):
		var previous := _active_floor.get_node_or_null("AutomaticInteriorLight") as OmniLight3D
		if previous:
			previous.visible = false
			previous.shadow_enabled = false
	_active_floor = selected.get_parent() as Node3D if selected else null
	for zone in _zones:
		for floor_node in zone.building.get_children():
			var inactive := floor_node.get_node_or_null("AutomaticInteriorLight") as OmniLight3D
			if inactive and floor_node != _active_floor:
				inactive.visible = false
				inactive.shadow_enabled = false
	if selected and selected.has_meta("lighting_anchor"):
		var light := _active_floor.get_node_or_null("AutomaticInteriorLight") as OmniLight3D
		if light:
			var data: Dictionary = selected.get_meta("room_data")
			LIGHTING.apply_to_light(light, String(data.get("lighting_type", data.type)))
			light.global_position = selected.to_global(selected.get_meta("lighting_anchor"))
			light.omni_range = minf(18.0, maxf(float(data.w), float(data.d)) * 0.72 + 2.0)
			light.visible = _night or bool(light.get_meta("always_on", false))
			light.shadow_enabled = light.visible
			if String(data.type) == "cell": light.visible = false
