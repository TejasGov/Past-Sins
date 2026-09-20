extends Node3D
class_name KeypadLocker

const Affordance := preload("res://scripts/props/interaction_affordance.gd")

@export var correct_code := "2718"
var is_open := false
var _keypad_tween: Tween
var _status_material: StandardMaterial3D

@onready var door: MeshInstance3D = $DoorPivot/Door
@onready var keypad: MeshInstance3D = $DoorPivot/Keypad
@onready var blocker: CollisionShape3D = $DoorPivot/StaticBody3D/CollisionShape3D
@onready var access_card: Label3D = $Interior/AccessCard


func _ready() -> void:
	_status_material = Affordance.add_keypad_face(keypad)
	access_card.visible = false


func get_interaction_prompt(_player: Node) -> String:
	if is_open:
		return ""
	if MemoryManager.knows_clue(correct_code):
		return "[E] Enter remembered code"
	return "[E] Examine keypad"


func interact(_player: Node) -> void:
	if is_open:
		return
	if not MemoryManager.knows_clue(correct_code):
		_flash_keypad(Color(0.9, 0.12, 0.08))
		return
	is_open = true
	_flash_keypad(Color(0.15, 1.0, 0.45))
	blocker.set_deferred("disabled", true)
	access_card.visible = true
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property($DoorPivot, "rotation:y", deg_to_rad(-105.0), 0.75)


func _flash_keypad(color: Color) -> void:
	if _keypad_tween and _keypad_tween.is_valid():
		_keypad_tween.kill()
	var material := _status_material
	if material:
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
	_keypad_tween = create_tween()
	_keypad_tween.tween_interval(0.65)
	_keypad_tween.tween_callback(func() -> void:
		if material:
			material.albedo_color = Color("63b9ac")
			material.emission = Color("63b9ac")
	)
