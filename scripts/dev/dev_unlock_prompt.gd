extends CanvasLayer
class_name DevUnlockPrompt

signal code_submitted(code: String)
signal cancelled

var _code_entry: LineEdit
var _feedback: Label


func _ready() -> void:
	layer = 210
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	call_deferred("_focus_entry")


func show_error(message: String = "ACCESS CODE REJECTED") -> void:
	_feedback.text = message
	_feedback.modulate = Color("ff7373")
	_code_entry.clear()
	_focus_entry()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		cancelled.emit()
		get_viewport().set_input_as_handled()


func _focus_entry() -> void:
	_code_entry.grab_focus()


func _submit(_ignored: String = "") -> void:
	code_submitted.emit(_code_entry.text)


func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.005, 0.008, 0.012, 0.82)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("10191d")
	panel_style.border_color = Color("d8a93f")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var title := Label.new()
	title.text = "BLACKSITE // DEVELOPER ACCESS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("f0c760"))
	content.add_child(title)

	var instruction := Label.new()
	instruction.text = "Enter development authorization code"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_color_override("font_color", Color("b8c8cc"))
	content.add_child(instruction)

	_code_entry = LineEdit.new()
	_code_entry.name = "CodeEntry"
	_code_entry.placeholder_text = "ACCESS CODE"
	_code_entry.secret = true
	_code_entry.secret_character = "•"
	_code_entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_entry.text_submitted.connect(_submit)
	content.add_child(_code_entry)

	_feedback = Label.new()
	_feedback.text = "Press Enter to authorize • Escape to cancel"
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_color_override("font_color", Color("81979d"))
	content.add_child(_feedback)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	var cancel_button := Button.new()
	cancel_button.text = "CANCEL"
	cancel_button.pressed.connect(func(): cancelled.emit())
	actions.add_child(cancel_button)
	var unlock_button := Button.new()
	unlock_button.text = "AUTHORIZE"
	unlock_button.pressed.connect(_submit)
	actions.add_child(unlock_button)
