extends Node

signal suspicion_changed(value: float)
signal suspicion_state_changed(state: StringName)
signal alert_triggered

const STATE_NORMAL: StringName = &"NORMAL"
const STATE_WATCHING: StringName = &"WATCHING"
const STATE_SUSPICIOUS: StringName = &"SUSPICIOUS"
const STATE_SEARCHING: StringName = &"SEARCHING"
const STATE_ALERT: StringName = &"ALERT"

@export_range(0.0, 20.0, 0.1) var decay_per_second := 4.5
@export_range(0.0, 5.0, 0.1) var decay_delay := 0.65

var _value := 0.0
var value: float:
	get:
		return _value
	set(next_value):
		_set_value(next_value)
var state: StringName = STATE_NORMAL
var _seconds_since_gain := 99.0


func _process(delta: float) -> void:
	_seconds_since_gain += delta
	if _seconds_since_gain >= decay_delay and value > 0.0 and value < 100.0:
		_set_value(value - decay_per_second * delta)


func add_suspicion(amount: float) -> void:
	if not is_finite(amount) or amount <= 0.0 or value >= 100.0:
		return
	_seconds_since_gain = 0.0
	_set_value(value + amount)


func reduce_suspicion(amount: float) -> void:
	if is_finite(amount) and amount > 0.0:
		_set_value(value - amount)


func reset() -> void:
	_seconds_since_gain = 99.0
	_set_value(0.0)


func get_state_for_value(amount: float) -> StringName:
	if amount >= 100.0:
		return STATE_ALERT
	if amount >= 75.0:
		return STATE_SEARCHING
	if amount >= 50.0:
		return STATE_SUSPICIOUS
	if amount >= 25.0:
		return STATE_WATCHING
	return STATE_NORMAL


func _set_value(next_value: float) -> void:
	if not is_finite(next_value):
		return
	var previous_state := state
	var previous_value := _value
	_value = clampf(next_value, 0.0, 100.0)
	state = get_state_for_value(_value)
	if not is_equal_approx(previous_value, _value):
		suspicion_changed.emit(_value)
	if state != previous_state:
		suspicion_state_changed.emit(state)
		if state == STATE_ALERT:
			alert_triggered.emit()
