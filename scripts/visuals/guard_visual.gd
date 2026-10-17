extends OperatorCharacter
class_name GuardVisual

## Guard visual instance using the Mixamo Auto-Rigger "Ch35" operator rig.
## The mesh already ships as one tactical-geared unit (gas mask/vest/etc. are
## baked into the geometry), so there are no separate accessory toggles here
## unlike the old PSX pipeline.

const SMG_WORLD_SCENE: PackedScene = preload("res://scenes/weapons/visuals/SMG_World.tscn")

# Tuned by rendering tools/screenshot_rig.gd against GuardVisual.tscn and
# eyeballing the result -- the SMG's own local origin (its pistol grip point)
# doesn't line up with the Mixamo hand bone's origin, so this places/rotates
# the whole weapon so the grip sits in the guard's right hand.
const SMG_GRIP_POSITION := Vector3(0.198619, -0.046383, 0.055879)
const SMG_GRIP_ROTATION_DEGREES := Vector3(12.281, -11.703, 73.923)

var _held_smg: Node3D


func _init() -> void:
	character_type = CharacterType.GUARD


func _ready() -> void:
	super._ready()
	_equip_smg()


func _equip_smg() -> void:
	if is_instance_valid(_held_smg):
		return
	_held_smg = attach_to_bone(SMG_WORLD_SCENE, &"mixamorig_RightHand", SMG_GRIP_POSITION, SMG_GRIP_ROTATION_DEGREES)
	if _held_smg == null:
		return
	# The pickup collider is only meaningful when the weapon is a free-floating
	# world pickup; a guard's held copy shouldn't carry stray collision shapes.
	var pickup_collider := _held_smg.find_child("PickupCollider", false, false)
	if pickup_collider:
		pickup_collider.queue_free()
