extends Node

signal noise_emitted(position: Vector3, intensity: float, surface_type: StringName, source: Node)
signal weapon_noise_emitted(event: Dictionary)


func emit_noise(position: Vector3, intensity: float, surface_type: StringName, source: Node = null) -> void:
	noise_emitted.emit(position, clampf(intensity, 0.0, 1.0), surface_type, source)


func emit_weapon_noise(position: Vector3, weapon_id: StringName, base_radius: float, effective_radius: float, suppressor_type: StringName, source: Node = null) -> void:
	var safe_base := maxf(1.0, base_radius)
	var safe_radius := clampf(effective_radius, 0.0, safe_base)
	var event := {
		"origin": position,
		"weapon_id": weapon_id,
		"suppressed": not suppressor_type.is_empty(),
		"suppressor_type": suppressor_type,
		"base_noise_radius": safe_base,
		"effective_noise_radius": safe_radius,
		"source": source,
	}
	weapon_noise_emitted.emit(event)
	# Preserve the existing normalized listener contract for current/future AI.
	emit_noise(position, safe_radius / safe_base, &"WEAPON", source)
