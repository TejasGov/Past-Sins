extends ItemDefinition
class_name SuppressorDefinition

enum Type { PROPER, MAKESHIFT }

@export var suppressor_type: Type = Type.PROPER
@export var compatible_weapon_ids: Array[StringName] = []
@export_range(0.05, 1.0, 0.01) var noise_radius_multiplier := 0.3
@export_range(0.02, 1.0, 0.01) var muzzle_flash_multiplier := 0.2
## Zero means durable/reusable.
@export_range(0, 20, 1) var max_magazine_uses := 0
@export_range(0.1, 2.0, 0.01) var visual_length := 0.72
@export var attachment_visual_scene: PackedScene
@export var world_visual_scene: PackedScene


func is_valid_suppressor() -> bool:
	return is_valid_definition() and category == Category.EQUIPMENT and not stackable \
		and not compatible_weapon_ids.is_empty() and noise_radius_multiplier > 0.0 \
		and muzzle_flash_multiplier > 0.0 and attachment_visual_scene != null \
		and world_visual_scene != null and (suppressor_type != Type.MAKESHIFT or max_magazine_uses > 0)


func supports_weapon(weapon_id: StringName) -> bool:
	var normalized := StringName(str(weapon_id).strip_edges().to_lower())
	for supported_id in compatible_weapon_ids:
		if StringName(str(supported_id).strip_edges().to_lower()) == normalized:
			return true
	return false


func type_name() -> String:
	return Type.keys()[int(suppressor_type)]

