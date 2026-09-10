extends KeyPickup
class_name CampusMountedKey

@export var rack_label := ""

func _ready() -> void:
	super._ready()
	if not rack_label.is_empty():
		$PickupVisual/KeyLabel.text = rack_label
	$PickupVisual/KeyLabel.font_size = 24
	$PickupVisual/KeyLabel.pixel_size = 0.003

func _start_float_animation() -> void:
	# The key card hangs from a real rack hook. Collection and AccessManager
	# behaviour are inherited from KeyPickup, including duplicate protection.
	$PickupVisual.position = Vector3.ZERO
	$PickupVisual/AccessCard.position = Vector3.ZERO
	$PickupVisual/AccessCard.rotation = Vector3.ZERO
	$PickupVisual/KeyRing.position = Vector3(0, 0.38, 0)
	$PickupVisual/KeyLabel.position = Vector3(0, 0.7, 0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.9, 0.2)
	$CollisionShape3D.shape = shape
	$CollisionShape3D.position.y = 0.05
