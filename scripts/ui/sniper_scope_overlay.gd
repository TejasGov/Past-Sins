extends Control
class_name SniperScopeOverlay

## Lightweight, resolution-independent scope mask. The reticle is drawn at the
## exact viewport center used by the camera hitscan ray.
@export_range(0.25, 0.48, 0.01) var viewport_radius_ratio := 0.39
@export var mask_color := Color(0.002, 0.004, 0.005, 0.985)
@export var reticle_color := Color(0.72, 0.82, 0.75, 0.92)

var _scope_blend := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func set_scope_blend(value: float) -> void:
	_scope_blend = clampf(value, 0.0, 1.0)
	modulate.a = _scope_blend


func get_reticle_center() -> Vector2:
	return size * 0.5


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * viewport_radius_ratio
	if radius <= 1.0:
		return

	# Four large masks plus sampled corner wedges create a circular view without
	# a shader, texture, transparency stack, or post-processing pass.
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, center.y - radius)), mask_color)
	draw_rect(Rect2(Vector2(0, center.y + radius), Vector2(size.x, size.y - center.y - radius)), mask_color)
	draw_rect(Rect2(Vector2(0, center.y - radius), Vector2(center.x - radius, radius * 2.0)), mask_color)
	draw_rect(Rect2(Vector2(center.x + radius, center.y - radius), Vector2(size.x - center.x - radius, radius * 2.0)), mask_color)
	_draw_corner_mask(center, radius, -1.0, -1.0)
	_draw_corner_mask(center, radius, 1.0, -1.0)
	_draw_corner_mask(center, radius, -1.0, 1.0)
	_draw_corner_mask(center, radius, 1.0, 1.0)

	draw_arc(center, radius, 0.0, TAU, 96, Color(0.08, 0.11, 0.10, 1), 4.0, true)
	var gap := 8.0
	draw_line(center + Vector2(-radius * 0.72, 0), center + Vector2(-gap, 0), reticle_color, 1.4)
	draw_line(center + Vector2(gap, 0), center + Vector2(radius * 0.72, 0), reticle_color, 1.4)
	draw_line(center + Vector2(0, -radius * 0.72), center + Vector2(0, -gap), reticle_color, 1.4)
	draw_line(center + Vector2(0, gap), center + Vector2(0, radius * 0.72), reticle_color, 1.4)
	draw_circle(center, 2.0, reticle_color)
	for index in range(1, 5):
		var offset := float(index) * 22.0
		draw_line(center + Vector2(-4, offset), center + Vector2(4, offset), reticle_color, 1.0)
		draw_line(center + Vector2(-4, -offset), center + Vector2(4, -offset), reticle_color, 1.0)
		draw_circle(center + Vector2(offset, 0), 1.6, reticle_color)
		draw_circle(center + Vector2(-offset, 0), 1.6, reticle_color)


func _draw_corner_mask(center: Vector2, radius: float, x_sign: float, y_sign: float) -> void:
	var points := PackedVector2Array()
	points.append(center + Vector2(x_sign * radius, 0))
	points.append(center + Vector2(x_sign * radius, y_sign * radius))
	points.append(center + Vector2(0, y_sign * radius))
	for step in range(13):
		var angle := lerpf(PI * 0.5, 0.0, float(step) / 12.0)
		points.append(center + Vector2(x_sign * cos(angle) * radius, y_sign * sin(angle) * radius))
	draw_colored_polygon(points, mask_color)
