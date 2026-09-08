extends Area3D
class_name RestrictedZone

@export_range(1.0, 10.0, 0.1) var suspicion_multiplier := 3.0
@export var zone_type: StringName = &"MAINTENANCE"


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 1 << 1
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func configure(size: Vector3, multiplier: float = 3.0, type: StringName = &"MAINTENANCE") -> void:
	suspicion_multiplier = multiplier
	zone_type = type
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node:
		var box := BoxShape3D.new()
		box.size = size
		shape_node.shape = box
	var visual := get_node_or_null("DebugVolume") as MeshInstance3D
	if visual:
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("enter_restricted_zone"):
		body.call("enter_restricted_zone", self, suspicion_multiplier)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("exit_restricted_zone"):
		body.call("exit_restricted_zone", self)
