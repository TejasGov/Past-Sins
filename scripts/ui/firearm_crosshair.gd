extends Control
class_name FirearmCrosshair

## A lightweight screen-space crosshair. The firearm controller decides when it
## is visible; this control only renders a precisely centered, configurable mark.
@export_range(2.0, 32.0, 1.0) var line_length := 8.0:
	set(value):
		line_length = value
		queue_redraw()
@export_range(0.0, 24.0, 1.0) var center_gap := 5.0:
	set(value):
		center_gap = value
		queue_redraw()
@export_range(1.0, 6.0, 0.5) var line_thickness := 2.0:
	set(value):
		line_thickness = value
		queue_redraw()
@export var crosshair_color := Color(0.86, 0.92, 0.9, 0.92):
	set(value):
		crosshair_color = value
		queue_redraw()
@export_range(0.25, 1.0, 0.05) var ads_scale := 0.55:
	set(value):
		ads_scale = value
		queue_redraw()

var _aiming := false
var _spread_pixels := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_aiming(aiming: bool) -> void:
	if _aiming == aiming:
		return
	_aiming = aiming
	queue_redraw()


func set_spread(spread_pixels: float) -> void:
	var next_spread := maxf(0.0, spread_pixels)
	if is_equal_approx(_spread_pixels, next_spread):
		return
	_spread_pixels = next_spread
	queue_redraw()


func get_spread() -> float:
	return _spread_pixels


func _draw() -> void:
	var center := size * 0.5
	var scale_factor := ads_scale if _aiming else 1.0
	var gap := center_gap * scale_factor + _spread_pixels
	var length := line_length * scale_factor
	draw_line(center + Vector2(0, -gap), center + Vector2(0, -gap - length), crosshair_color, line_thickness)
	draw_line(center + Vector2(0, gap), center + Vector2(0, gap + length), crosshair_color, line_thickness)
	draw_line(center + Vector2(-gap, 0), center + Vector2(-gap - length, 0), crosshair_color, line_thickness)
	draw_line(center + Vector2(gap, 0), center + Vector2(gap + length, 0), crosshair_color, line_thickness)
