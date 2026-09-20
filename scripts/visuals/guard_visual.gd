extends ModularCharacter
class_name GuardVisual

## Guard visual instance utilizing the shared Characters PSX + Mixamo rig.
## Faction appearance is a palette-only material variant of the shared mesh.


func _init() -> void:
	character_type = CharacterType.GUARD
	show_cap = true
	show_vest = true
	show_belt = true
