extends Area3D
class_name KeyPickup

@export var key_id: StringName = &"cellblock_key"
@export var display_name := "Cell Block Key"

var collected := false


func _ready() -> void:
	collision_layer = 1 << 2
	collision_mask = 0
	$PickupVisual/KeyLabel.text = display_name.to_upper()
	# A real painted access tag, not a whole glowing/floating light source.
	$PickupVisual/AccessCard.material_override = preload("res://materials/props/hazard_yellow.tres")
	collected = AccessManager.has_key(key_id)
	visible = not collected
	monitorable = not collected
	if collected:
		collision_layer = 0
	else:
		_start_float_animation()


func get_interaction_prompt(_player: Node) -> String:
	return "" if collected else "[E] Pick Up Key"


func interact(_player: Node) -> void:
	if collected:
		return
	collected = true
	set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	if AccessManager.add_key(key_id, display_name):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_message"):
			hud.call("show_message", "%s ACQUIRED" % display_name.to_upper(), 2.0)
	queue_free()


func _start_float_animation() -> void:
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($PickupVisual, "position:y", 0.18, 1.0)
	tween.tween_property($PickupVisual, "position:y", -0.05, 1.0)
