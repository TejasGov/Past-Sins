extends Node3D
class_name GuardVisual

@export_range(1.0, 14.0, 0.25) var walk_cycle_speed := 7.0
@export_range(0.0, 35.0, 1.0) var arm_swing_degrees := 18.0
@export_range(0.0, 35.0, 1.0) var leg_swing_degrees := 20.0
@export_range(1.0, 20.0, 0.5) var pose_blend_speed := 9.0
@export_range(0.01, 1.0, 0.01) var movement_threshold := 0.08

@onready var left_arm: Node3D = $LeftArmPivot
@onready var right_arm: Node3D = $RightArmPivot
@onready var left_leg: Node3D = $LeftLegPivot
@onready var right_leg: Node3D = $RightLegPivot

var _cycle := 0.0
var _movement_blend := 0.0


func _process(delta: float) -> void:
	var horizontal_speed := 0.0
	var actor := get_parent() as CharacterBody3D
	if actor:
		horizontal_speed = Vector2(actor.velocity.x, actor.velocity.z).length()

	var target_blend := 1.0 if horizontal_speed > movement_threshold else 0.0
	_movement_blend = move_toward(_movement_blend, target_blend, pose_blend_speed * delta)
	if target_blend > 0.0:
		var speed_scale := clampf(horizontal_speed / 2.0, 0.65, 1.65)
		_cycle = fmod(_cycle + delta * walk_cycle_speed * speed_scale, TAU)

	var wave := sin(_cycle) * _movement_blend
	var arm_swing := deg_to_rad(arm_swing_degrees) * wave
	var leg_swing := deg_to_rad(leg_swing_degrees) * wave
	left_arm.rotation.x = -arm_swing
	right_arm.rotation.x = arm_swing
	left_leg.rotation.x = leg_swing
	right_leg.rotation.x = -leg_swing

