extends MemoryShard
class_name CampusRestingMemory

func _start_float_animation() -> void:
	# Preserve the original memory ID, clue and HUD sequence, with the physical
	# shard resting on a supported shelf instead of bobbing in open space.
	$ShardVisual.rotation = Vector3.ZERO
	$ShardVisual.position = Vector3.ZERO
	$ShardVisual/Ring.visible = false
	$Glow.visible = false
