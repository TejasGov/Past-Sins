extends Node3D
class_name SlingshotProjectile

signal impacted(surface_type: StringName, intensity: float, hit_position: Vector3)
signal body_hit(zone: BodyHitZone, damage: float, toxin: bool)

var definition: SlingshotDefinition
var velocity := Vector3.ZERO
var toxin := false
var source: Node3D
var lifetime := 0.0
var maximum_lifetime := 6.0
var recovery_chance_override := -1.0


func _ready() -> void:
	add_to_group("slingshot_projectiles")


func setup(projectile_definition: SlingshotDefinition, initial_velocity: Vector3, toxin_coated: bool, source_node: Node3D) -> void:
	definition = projectile_definition
	velocity = initial_velocity
	toxin = toxin_coated
	source = source_node


func _physics_process(delta: float) -> void:
	lifetime += delta
	if lifetime >= maximum_lifetime:
		queue_free()
		return
	var start := global_position
	velocity += Vector3.DOWN * definition.projectile_gravity * delta
	var end := start + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(start, end, 1 | 32)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if source is CollisionObject3D:
		query.exclude = [(source as CollisionObject3D).get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		global_position = end
		if velocity.length_squared() > 0.01: look_at(global_position + velocity.normalized(), Vector3.UP)
		return
	_resolve_hit(result)


func _resolve_hit(result: Dictionary) -> void:
	var collider := result.collider as Node
	var hit_position := result.position as Vector3
	if collider is BodyHitZone:
		var zone := collider as BodyHitZone
		zone.apply_damage(definition.damage_for_zone(zone.get_hit_zone_id()))
		body_hit.emit(zone, definition.damage_for_zone(zone.get_hit_zone_id()), toxin)
		if toxin: _apply_toxin(zone)
		WorldNoiseSystem.emit_noise(hit_position, 0.35, &"BODY", source)
		impacted.emit(&"BODY", 0.35, hit_position)
		queue_free()
		return
	var surface := StringName(str(collider.get_meta("surface_type", "CONCRETE")).to_upper()) if collider else &"CONCRETE"
	var intensity := 0.25
	if surface == &"METAL": intensity = 0.6
	elif surface in [&"GLASS", &"LIGHT"]: intensity = 0.9
	if collider and collider.has_method("on_slingshot_projectile_impact"):
		collider.call("on_slingshot_projectile_impact", self, hit_position)
	elif collider:
		var owner_node: Node = collider.get_meta("breakable_owner", null)
		if owner_node and owner_node.has_method("on_slingshot_projectile_impact"):
			owner_node.call("on_slingshot_projectile_impact", self, hit_position)
	WorldNoiseSystem.emit_noise(hit_position, intensity, surface, source)
	impacted.emit(surface, intensity, hit_position)
	if not toxin and randf() <= (recovery_chance_override if recovery_chance_override >= 0.0 else definition.normal_nail_recovery_chance):
		_spawn_recoverable(hit_position, result.normal as Vector3)
	queue_free()


func _apply_toxin(zone: BodyHitZone) -> void:
	var target := zone.damageable_owner
	if target == null: return
	var status := target.get_node_or_null("ToxinStatusComponent") as ToxinStatusComponent
	if status: status.apply_fictional_toxin()


func _spawn_recoverable(hit_position: Vector3, normal: Vector3) -> void:
	var pickup := preload("res://scenes/weapons/SlingshotAmmoPickup.tscn").instantiate() as SlingshotAmmoPickup
	pickup.item_definition = definition.normal_ammo
	var parent := get_tree().current_scene.get_node_or_null("Interactables")
	(parent if parent else get_tree().current_scene).add_child(pickup)
	pickup.global_position = hit_position + normal * 0.06
