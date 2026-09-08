extends Control

signal memory_sequence_finished
signal detention_fade_finished

@onready var interaction_label: Label = %InteractionPrompt
@onready var suspicion_value: Label = %SuspicionValue
@onready var suspicion_state: Label = %SuspicionState
@onready var suspicion_bar: ProgressBar = %SuspicionBar
@onready var memory_overlay: ColorRect = %MemoryOverlay
@onready var memory_title: Label = %MemoryTitle
@onready var memory_transcript: Label = %MemoryTranscript
@onready var memory_clue: Label = %MemoryClue
@onready var failure_overlay: ColorRect = %FailureOverlay
@onready var status_message: Label = %StatusMessage

var _memory_playing := false
var _message_tween: Tween


func _ready() -> void:
	add_to_group("hud")
	memory_overlay.visible = false
	failure_overlay.visible = false
	status_message.visible = false
	if not SuspicionSystem.suspicion_changed.is_connected(_on_suspicion_changed):
		SuspicionSystem.suspicion_changed.connect(_on_suspicion_changed)
	if not SuspicionSystem.suspicion_state_changed.is_connected(_on_suspicion_state_changed):
		SuspicionSystem.suspicion_state_changed.connect(_on_suspicion_state_changed)
	_on_suspicion_changed(SuspicionSystem.value)
	_on_suspicion_state_changed(SuspicionSystem.state)
	call_deferred("_connect_player")


func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_signal("interaction_prompt_changed") and not player.is_connected("interaction_prompt_changed", _on_interaction_prompt_changed):
		player.connect("interaction_prompt_changed", _on_interaction_prompt_changed)


func play_memory_sequence(data: Dictionary) -> void:
	if _memory_playing:
		return
	_memory_playing = true
	interaction_label.text = ""
	memory_title.text = str(data.get("title", "MEMORY RECOVERED")).to_upper()
	memory_transcript.text = str(data.get("transcript", ""))
	var clue := str(data.get("clue", ""))
	memory_clue.text = "PRACTICAL CLUE RECOVERED:  %s" % clue if not clue.is_empty() else ""
	memory_overlay.modulate.a = 0.0
	memory_overlay.visible = true
	var sequence := create_tween().set_trans(Tween.TRANS_SINE)
	sequence.tween_property(memory_overlay, "modulate:a", 1.0, 0.45)
	sequence.tween_interval(5.2)
	sequence.tween_property(memory_overlay, "modulate:a", 0.0, 0.55)
	sequence.tween_callback(_finish_memory_sequence)


func _finish_memory_sequence() -> void:
	memory_overlay.visible = false
	_memory_playing = false
	memory_sequence_finished.emit()


func show_detained() -> void:
	interaction_label.text = ""
	failure_overlay.modulate.a = 0.0
	failure_overlay.visible = true
	var tween := create_tween().set_trans(Tween.TRANS_QUAD)
	tween.tween_property(failure_overlay, "modulate:a", 1.0, 0.8)
	tween.tween_callback(_finish_detention_fade)


func show_message(message: String, duration := 1.5) -> void:
	if _message_tween and _message_tween.is_valid():
		_message_tween.kill()
	status_message.text = message
	status_message.modulate.a = 0.0
	status_message.visible = true
	_message_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_message_tween.tween_property(status_message, "modulate:a", 1.0, 0.12)
	_message_tween.tween_interval(maxf(0.25, duration))
	_message_tween.tween_property(status_message, "modulate:a", 0.0, 0.28)
	_message_tween.tween_callback(func() -> void: status_message.visible = false)


func _finish_detention_fade() -> void:
	detention_fade_finished.emit()


func _on_interaction_prompt_changed(prompt: String) -> void:
	if not _memory_playing:
		interaction_label.text = prompt


func _on_suspicion_changed(value: float) -> void:
	suspicion_value.text = "%03d%%" % roundi(value)
	suspicion_bar.value = value


func _on_suspicion_state_changed(state: StringName) -> void:
	suspicion_state.text = str(state)
	var color := Color("8ed6b0")
	if state == SuspicionSystem.STATE_WATCHING:
		color = Color("e7d678")
	elif state == SuspicionSystem.STATE_SUSPICIOUS:
		color = Color("e8a45e")
	elif state == SuspicionSystem.STATE_SEARCHING:
		color = Color("e65f4f")
	elif state == SuspicionSystem.STATE_ALERT:
		color = Color("ff253a")
	suspicion_state.modulate = color
