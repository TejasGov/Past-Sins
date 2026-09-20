extends OmniLight3D
class_name GalleryLighting

## One real source per tier, reused among its fixed visible fixtures. Never drag
## a glowing source through empty air: fade down, relocate, then fade back up.
const PROFILES := preload("res://scripts/systems/interior_lighting_profiles.gd")
@export var floor_number := 1
@export var fixture_positions := PackedVector3Array()
@export_range(0.5, 4.0, 0.1) var switch_hysteresis := 2.0
@export_range(0.04, 0.25, 0.01) var switch_fade_seconds := 0.10
@export var gallery_range := 18.0
@export_range(0.0, 30.0, 0.5) var view_bias_distance := 20.0
@export_range(1.0, 6.0, 0.25) var nearby_priority_radius := 3.5
var _source := -1
var _pending_source := -1
var _fade := 1.0
var _elapsed := 0.0
var _base_energy := 1.0
var _cycle: Node
var _guard_core: Node3D
var _previous_view_position := Vector3.INF


func _ready() -> void:
	add_to_group("campus_gallery_lights")
	add_to_group("campus_indoor_lights")
	set_meta("automatic_night_light", true)
	# Registration is deferred because the reusable guard core is assembled
	# after the gallery structure, but before the first rendered frame.
	call_deferred("refresh", true)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.12:
		_elapsed = 0.0
		refresh()
	if _pending_source != -1:
		_fade = move_toward(_fade, 0.0, delta / switch_fade_seconds)
		if _fade <= 0.0:
			_commit_source(_pending_source)
			_pending_source = -1
	else:
		_fade = move_toward(_fade, 1.0, delta / switch_fade_seconds)
	light_energy = _base_energy * _fade
	_update_visibility()


func refresh(immediate := false) -> void:
	if not is_inside_tree() or fixture_positions.is_empty(): return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	if not is_instance_valid(_cycle):
		for candidate in get_tree().get_nodes_in_group("campus_environment_cycle"):
			if candidate.get_parent().is_ancestor_of(self):
				_cycle = candidate
				break
	if not is_instance_valid(_guard_core):
		for candidate in get_tree().get_nodes_in_group("campus_guard_elevator_cores"):
			if get_parent().is_ancestor_of(candidate) and int(candidate.get_meta("campus_floor_number")) == floor_number:
				_guard_core = candidate
				break
	var desired := _nearest_source(camera.global_position, -camera.global_basis.z)
	var teleported := _previous_view_position.is_finite() and camera.global_position.distance_to(_previous_view_position) > 8.0
	_previous_view_position = camera.global_position
	if immediate or _source == -1 or teleported or not visible:
		_pending_source = -1
		_fade = 1.0
		_commit_source(desired)
	elif desired != _source:
		_pending_source = desired
	else:
		_pending_source = -1
	_update_visibility()


func _nearest_source(view_position: Vector3, view_direction: Vector3) -> int:
	# Guard-room occupancy uses the real western bay bounds, not the entire
	# core: stepping into the eastern elevator lobby must not select an office.
	if is_instance_valid(_guard_core):
		var bounds: AABB = _guard_core.get_meta("environment_bounds")
		if bounds.has_point(_guard_core.to_local(view_position)):
			return fixture_positions.size()
	var local_view := (get_parent() as Node3D).to_local(view_position)
	var local_direction := (get_parent() as Node3D).global_basis.inverse() * view_direction
	local_direction.y = 0.0
	local_direction = local_direction.normalized()
	var best := 0
	var best_score := INF
	for index in fixture_positions.size():
		var score := _source_score(fixture_positions[index], local_view, local_direction)
		if score < best_score:
			best_score = score
			best = index
	if _source >= 0 and _source < fixture_positions.size() and best != _source:
		if _source_score(fixture_positions[_source], local_view, local_direction) - best_score < switch_hysteresis:
			return _source
	return best


func _source_score(fixture: Vector3, viewer: Vector3, forward: Vector3) -> float:
	var toward_fixture := fixture - viewer
	var distance := toward_fixture.length()
	toward_fixture.y = 0.0
	var horizontal_distance := toward_fixture.length()
	# A source directly overhead must always light the player's walking path.
	# Farther away, prefer a visible fixture over one behind the camera. Pure
	# nearest selection stacked all three sources behind an across-atrium view.
	var view_weight := smoothstep(nearby_priority_radius, nearby_priority_radius + 2.0, horizontal_distance)
	var behind := maxf(0.0, -toward_fixture.normalized().dot(forward))
	return distance + behind * view_bias_distance * view_weight


func _commit_source(index: int) -> void:
	_source = index
	var in_guard_room := index == fixture_positions.size() and is_instance_valid(_guard_core)
	PROFILES.apply_to_light(self, "office" if in_guard_room else "cellblock")
	_base_energy = light_energy
	if in_guard_room:
		global_position = _guard_core.to_global(_guard_core.get_meta("lighting_anchor"))
		omni_range = 6.0
	else:
		position = fixture_positions[index]
		omni_range = gallery_range
	# Bound the cost: only an occupied enclosed office needs another shadowed
	# source. The three existing gallery bounce lights retain their old budget.
	shadow_enabled = in_guard_room
	set_meta("source_fixture_index", index)
	set_meta("source_fixture_position", global_position)
	light_energy = _base_energy * _fade


func _update_visibility() -> void:
	var night := bool(_cycle.call("is_dark")) if is_instance_valid(_cycle) else false
	visible = night or bool(get_meta("always_on", false))
