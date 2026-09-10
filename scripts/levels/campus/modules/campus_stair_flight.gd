extends Node3D
class_name CampusStairFlight

## Exact, lip-free ramp collision with supported visual stair treads. Local +Z
## is ascent, and local origin is the finished floor at the bottom of the run.
const Factory := preload("res://scripts/levels/greybox_factory.gd")

@export var run := 6.4
@export var rise := 2.8
@export var width := 1.6
@export var steps := 16
@export var concrete_color := Color("4a504c")
@export_flags_3d_render var visual_layer_mask := 1


func _ready() -> void:
	add_to_group("campus_stair_flights")
	var g = Factory.new(self, visual_layer_mask)
	var body := StaticBody3D.new()
	body.name = "ExactRamp"
	add_child(body)
	var shape_node := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var corners := PackedVector3Array()
	for x in [-width * 0.5, width * 0.5]:
		for end in [0.0, 1.0]:
			for thickness in [-0.14, 0.0]:
				corners.append(Vector3(x, rise * end + thickness, run * end))
	shape.points = corners
	shape_node.shape = shape
	body.add_child(shape_node)

	var step_depth := run / float(steps)
	var step_rise := rise / float(steps)
	for index in range(steps):
		# Treads intersect the supporting stringers and differ from the smooth
		# walking surface by at most half a riser, rather than hovering over it.
		var z := (float(index) + 0.5) * step_depth
		var y := (float(index) + 0.5) * step_rise
		g.box("%sStep%02d" % [name, index], Vector3(0, y - 0.04, z), Vector3(width, 0.08, step_depth + 0.015), concrete_color, false)
	for side in [-1.0, 1.0]:
		var x: float = side * (width * 0.5 - 0.065)
		var start := Vector3(x, 0, 0)
		var end := Vector3(x, rise, run)
		g.bar_between("StructuralStringer", start - Vector3.UP * 0.09, end - Vector3.UP * 0.09, concrete_color.darkened(0.2), 0.18)
		g.railing(start, end, Color("626963"))
	set_meta("route_start", Vector3.ZERO)
	set_meta("route_end", Vector3(0, rise, run))
