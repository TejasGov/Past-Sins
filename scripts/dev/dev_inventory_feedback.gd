extends CanvasLayer
class_name DevInventoryFeedback

@onready var panel: PanelContainer = $Panel
@onready var label: Label = $Panel/Message

var _hide_tween: Tween


func _ready() -> void:
	layer = 160
	panel.visible = false
	if not DevModeManager.is_enabled():
		queue_free()
		return
	if not InventoryManager.feedback_requested.is_connected(show_feedback):
		InventoryManager.feedback_requested.connect(show_feedback)


func show_feedback(message: String) -> void:
	if message.is_empty():
		return
	if _hide_tween and _hide_tween.is_valid():
		_hide_tween.kill()
	label.text = message
	panel.modulate.a = 0.0
	panel.visible = true
	_hide_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_hide_tween.tween_property(panel, "modulate:a", 1.0, 0.1)
	_hide_tween.tween_interval(1.45)
	_hide_tween.tween_property(panel, "modulate:a", 0.0, 0.25)
	_hide_tween.tween_callback(func() -> void: panel.visible = false)
