extends Node3D
class_name CampusSwitchbackStair

## Floor origin is the lower finished surface, centered inside the reserved
## footprint. Parent slabs MUST omit the entire footprint on every level.
const Factory := preload("res://scripts/levels/greybox_factory.gd")
const FLIGHT_SCENE := preload("res://scenes/levels/campus/modules/CampusStairFlight.tscn")

@export var width := 6.0
@export var depth := 9.0
@export var floor_rise := 4.0
@export_enum("n", "s", "e", "w") var lower_entrance_side := "s"
@export_enum("n", "s", "e", "w") var upper_entrance_side := "s"
## Offset along the world-local side: +X for N/S, +Z for E/W.
@export var lower_entrance_offset := 0.0
@export var upper_entrance_offset := 0.0
@export var lower_entrance_width := 1.6
@export var upper_entrance_width := 1.6
## Additional doorways must meet a standing-height bypass, never the low
## intermediate landing. Entries: {side: "e", offset: -3.85, width: 1.1}.
@export var secondary_lower_entrances: Array[Dictionary] = []
@export var secondary_upper_entrances: Array[Dictionary] = []
@export var build_lower_landing := true
## Opens the shared landing toward a second module's ascending lower flight.
@export var continues_above := false
@export_flags_3d_render var visual_layer_mask := 1

var _layout: Node3D
var _inner_width := 6.0
var _inner_depth := 9.0
var _flight_width := 1.6
var _flight_x := 0.9
var _run_end := 3.2
var _mid_height := 1.2
const AISLE_WIDTH := 1.2
const LANDING_DEPTH := 1.3
const SLAB_THICKNESS := 0.16


func _ready() -> void:
	add_to_group("campus_switchback_stairs")
	_layout = Node3D.new()
	_layout.name = "StairStructure"
	# The lower entrance always reaches the low end of the first flight. For
	# E/W entrances rotate the arrangement and swap its internal dimensions,
	# preserving the caller's unchanged six-by-nine-metre footprint.
	match lower_entrance_side:
		"n": _layout.rotation.y = PI
		"e": _layout.rotation.y = PI * 0.5
		"w": _layout.rotation.y = -PI * 0.5
	if lower_entrance_side in ["e", "w"]:
		_inner_width = depth
		_inner_depth = width
	else:
		_inner_width = width
		_inner_depth = depth
	_run_end = _inner_depth * 0.5 - LANDING_DEPTH
	_flight_width = (_inner_width - AISLE_WIDTH * 2.0 - 0.3) * 0.5
	_flight_x = _flight_width * 0.5 + 0.15
	_mid_height = minf(1.2, floor_rise * 0.3)
	add_child(_layout)
	var g = Factory.new(_layout, visual_layer_mask)
	if build_lower_landing:
		_build_landing_ring(g, 0.0)
		# Close the lowest stair bay's centre as well as its circulation ring.
		# Upper segments omit this slab so descending flights remain open.
		g.box("LowestBayFloor", Vector3(0, -SLAB_THICKNESS * 0.5, 0), Vector3(_inner_width - AISLE_WIDTH * 2.0, SLAB_THICKNESS, _run_end * 2.0), Color("454b46"))
	_build_landing_ring(g, floor_rise)
	var inner_span := _inner_width - 2.0 * AISLE_WIDTH
	g.box("IntermediateLanding", Vector3(0, _mid_height - SLAB_THICKNESS * 0.5, -_inner_depth * 0.5 + LANDING_DEPTH * 0.5), Vector3(inner_span, SLAB_THICKNESS, LANDING_DEPTH), Color("535952"))
	_add_flight("LowerFlight", Vector3(-_flight_x, 0, _run_end), PI, _mid_height)
	_add_flight("UpperFlight", Vector3(_flight_x, _mid_height, -_run_end), 0, floor_rise - _mid_height)
	_build_rails(g)
	_build_supports(g)
	set_meta("footprint", Vector2(width, depth))
	set_meta("floor_rise", floor_rise)
	set_meta("upper_headroom_above_turn", floor_rise - SLAB_THICKNESS - _mid_height)


func _build_landing_ring(g, y: float) -> void:
	var color := Color("454b46")
	for side in [-1.0, 1.0]:
		g.box("LandingEnd", Vector3(0, y - SLAB_THICKNESS * 0.5, side * (_inner_depth * 0.5 - LANDING_DEPTH * 0.5)), Vector3(_inner_width, SLAB_THICKNESS, LANDING_DEPTH), color)
		g.box("LandingBypass", Vector3(side * (_inner_width * 0.5 - AISLE_WIDTH * 0.5), y - SLAB_THICKNESS * 0.5, 0), Vector3(AISLE_WIDTH, SLAB_THICKNESS, _run_end * 2.0), color)


func _add_flight(flight_name: String, start: Vector3, yaw: float, rise: float) -> void:
	var flight := FLIGHT_SCENE.instantiate() as CampusStairFlight
	flight.name = flight_name
	flight.position = start
	flight.rotation.y = yaw
	flight.run = _run_end * 2.0
	flight.rise = rise
	flight.width = _flight_width
	flight.steps = maxi(8, ceili(rise / 0.175))
	flight.visual_layer_mask = visual_layer_mask
	_layout.add_child(flight)


func _build_rails(g) -> void:
	var rail_color := Color("636b65")
	var edge_x := _inner_width * 0.5 - AISLE_WIDTH
	for side in [-1.0, 1.0]:
		# The upper bypass has its own level rail over both descending flights.
		g.railing(Vector3(side * edge_x, floor_rise, -_run_end), Vector3(side * edge_x, floor_rise, _run_end), rail_color)
		g.railing(Vector3(side * edge_x, _mid_height, -_inner_depth * 0.5), Vector3(side * edge_x, _mid_height, -_run_end), rail_color)
	g.railing(Vector3(-edge_x, floor_rise, -_run_end), Vector3(edge_x, floor_rise, -_run_end), rail_color)
	# The south upper landing opens ONLY at the ascending second flight.
	if continues_above:
		g.railing(Vector3(-edge_x, floor_rise, _run_end), Vector3(-_flight_x - _flight_width * 0.5 + 0.065, floor_rise, _run_end), rail_color)
		g.railing(Vector3(-_flight_x + _flight_width * 0.5 - 0.065, floor_rise, _run_end), Vector3(_flight_x - _flight_width * 0.5 + 0.065, floor_rise, _run_end), rail_color)
	else:
		g.railing(Vector3(-edge_x, floor_rise, _run_end), Vector3(_flight_x - _flight_width * 0.5 + 0.065, floor_rise, _run_end), rail_color)
	g.railing(Vector3(_flight_x + _flight_width * 0.5 - 0.065, floor_rise, _run_end), Vector3(edge_x, floor_rise, _run_end), rail_color)
	# Outer bounds normally meet the enclosing stair-room walls. A reusable
	# scene also needs its own safe upper perimeter when placed independently.
	var inverse := _layout.transform.affine_inverse()
	var entrances: Array[Dictionary] = [{"point": inverse * _entrance_point(upper_entrance_side, upper_entrance_offset, floor_rise, upper_entrance_width), "width": upper_entrance_width}]
	for extra in secondary_upper_entrances:
		var extra_width := float(extra.get("width", 1.2))
		entrances.append({"point": inverse * _entrance_point(String(extra.side), float(extra.get("offset", 0)), floor_rise, extra_width), "width": extra_width})
	for side_name in ["n", "s", "e", "w"]:
		var horizontal: bool = side_name in ["n", "s"]
		var edge := _inner_depth * 0.5 if horizontal else _inner_width * 0.5
		var span := _inner_width * 0.5 if horizontal else _inner_depth * 0.5
		var fixed := -edge if side_name in ["n", "w"] else edge
		var openings: Array[Vector2] = []
		for entry in entrances:
			var entrance: Vector3 = entry.point
			var entrance_fixed := entrance.z if horizontal else entrance.x
			if absf(entrance_fixed - fixed) > 0.05:
				continue
			var offset := entrance.x if horizontal else entrance.z
			# Rail end posts sit outside the specified clear opening.
			var half_opening := float(entry.width) * 0.5 + 0.05
			openings.append(Vector2(offset - half_opening, offset + half_opening))
		openings.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var intervals: Array[Vector2] = []
		var cursor := -span
		for opening in openings:
			intervals.append(Vector2(cursor, maxf(cursor, opening.x)))
			cursor = maxf(cursor, opening.y)
		intervals.append(Vector2(cursor, span))
		for interval in intervals:
			if interval.y - interval.x < 0.02:
				continue
			var start := Vector3(interval.x, floor_rise, fixed) if horizontal else Vector3(fixed, floor_rise, interval.x)
			var end := Vector3(interval.y, floor_rise, fixed) if horizontal else Vector3(fixed, floor_rise, interval.y)
			g.railing(start, end, rail_color)


func _build_supports(g) -> void:
	var steel := Color("333b35")
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			g.box("LandingColumn", Vector3(x_side * (_inner_width * 0.5 - 0.12), floor_rise * 0.5, z_side * (_inner_depth * 0.5 - 0.12)), Vector3(0.18, floor_rise, 0.18), steel)
		g.box("TurnLandingSupport", Vector3(x_side * (_inner_width * 0.5 - AISLE_WIDTH - 0.12), _mid_height * 0.5, -_inner_depth * 0.5 + 0.12), Vector3(0.18, _mid_height, 0.18), steel)


func _entrance_point(side: String, offset: float, y: float, opening_width := 1.6) -> Vector3:
	var corner_margin := opening_width * 0.5 + 0.1
	if side in ["n", "s"]:
		return Vector3(clampf(offset, -width * 0.5 + corner_margin, width * 0.5 - corner_margin), y, -depth * 0.5 if side == "n" else depth * 0.5)
	return Vector3(-width * 0.5 if side == "w" else width * 0.5, y, clampf(offset, -depth * 0.5 + corner_margin, depth * 0.5 - corner_margin))


func get_route_points() -> PackedVector3Array:
	# A real walking route used by regression checks: includes both turns and
	# the top bypass, rather than just sampling a capsule at the ramp midpoint.
	var inverse := _layout.transform.affine_inverse()
	var lower := inverse * _entrance_point(lower_entrance_side, lower_entrance_offset, 0, lower_entrance_width)
	var upper := inverse * _entrance_point(upper_entrance_side, upper_entrance_offset, floor_rise, upper_entrance_width)
	var south_z := _inner_depth * 0.5 - LANDING_DEPTH * 0.5
	var north_z := -south_z
	var ring_x := _inner_width * 0.5 - AISLE_WIDTH * 0.5
	var points: Array[Vector3] = [
		Vector3(lower.x, 0, south_z), Vector3(-_flight_x, 0, south_z),
		Vector3(-_flight_x, 0, _run_end),
		Vector3(-_flight_x, _mid_height, -_run_end),
		Vector3(-_flight_x, _mid_height, north_z),
		Vector3(_flight_x, _mid_height, north_z),
		Vector3(_flight_x, _mid_height, -_run_end),
		Vector3(_flight_x, floor_rise, _run_end),
		Vector3(_flight_x, floor_rise, south_z),
	]
	if upper.z > _inner_depth * 0.5 - 0.1:
		points.append(Vector3(upper.x, floor_rise, south_z))
	else:
		var side_x := -ring_x if upper.x < -0.1 else ring_x
		points.append(Vector3(side_x, floor_rise, south_z))
		if upper.z < -_inner_depth * 0.5 + 0.1:
			points.append(Vector3(side_x, floor_rise, north_z))
			points.append(Vector3(upper.x, floor_rise, north_z))
		else:
			points.append(Vector3(side_x, floor_rise, upper.z))
	var result := PackedVector3Array()
	for point in points:
		result.append(_layout.transform * point)
	return result
