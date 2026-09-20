extends StaticBody3D
class_name BodyHitZone

enum Type {
	HEAD,
	TORSO,
	LOWER_BODY,
}

const ID_BY_TYPE := {
	Type.HEAD: &"HEAD",
	Type.TORSO: &"TORSO",
	Type.LOWER_BODY: &"LOWER_BODY",
}

@export var zone_type: Type = Type.TORSO
var health_component: HealthComponent
var damageable_owner: Node3D
var _materials: Array[StandardMaterial3D] = []


func configure(type: Type, component: HealthComponent, owner_node: Node3D) -> void:
	zone_type = type
	health_component = component
	damageable_owner = owner_node
	name = String(get_hit_zone_id()).to_pascal_case()
	set_meta("hit_zone", get_hit_zone_id())
	set_meta("damageable_owner", owner_node)


func add_box_segment(segment_name: String, center: Vector3, size: Vector3, color: Color) -> void:
	var visual := MeshInstance3D.new()
	visual.name = "%sVisual" % segment_name
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = center
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	_materials.append(material)
	var collider := CollisionShape3D.new()
	collider.name = "%sCollider" % segment_name
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position = center
	add_child(collider)


func add_cylinder_segment(segment_name: String, center: Vector3, radius: float, height: float, color: Color) -> void:
	var visual := MeshInstance3D.new()
	visual.name = "%sVisual" % segment_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	visual.mesh = mesh
	visual.position = center
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	_materials.append(material)
	var collider := CollisionShape3D.new()
	collider.name = "%sCollider" % segment_name
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collider.shape = shape
	collider.position = center
	add_child(collider)


func apply_test_damage(amount: float) -> float:
	return apply_damage(amount)


func apply_damage(amount: float) -> float:
	if health_component == null:
		return 0.0
	return health_component.apply_damage(amount, get_hit_zone_id())


func apply_melee_hit(lethal: bool, fallback_damage: float) -> bool:
	if health_component == null or health_component.is_dead():
		return false
	if lethal and health_component.apply_lethal_melee(get_hit_zone_id()):
		return true
	health_component.apply_damage(fallback_damage, get_hit_zone_id())
	return health_component.is_dead()


func get_hit_zone_id() -> StringName:
	return StringName(ID_BY_TYPE.get(zone_type, &"TORSO"))


func set_dead_visual(dead: bool) -> void:
	for material in _materials:
		material.albedo_color = Color("733e3e") if dead else Color(material.get_meta("alive_color", material.albedo_color))


func remember_alive_colors() -> void:
	for material in _materials:
		material.set_meta("alive_color", material.albedo_color)
