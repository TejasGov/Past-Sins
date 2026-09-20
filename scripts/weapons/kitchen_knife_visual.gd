extends MeleeVisualBase
class_name KitchenKnifeVisual

var _attack_pivot: Node3D
var _attack_tween: Tween
var _attack_playing := false


func _ready() -> void:
	_build_visual()


func play_attack(duration: float, impact_time: float) -> void:
	if not first_person or _attack_pivot == null:
		return
	cancel_melee_animation()
	_attack_playing = true
	var windup := minf(impact_time * 0.45, duration * 0.25)
	var slash := maxf(0.06, impact_time - windup)
	var recover := maxf(0.08, duration - impact_time)
	_attack_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.tween_property(_attack_pivot, "rotation_degrees", Vector3(-10, -24, 28), windup)
	_attack_tween.parallel().tween_property(_attack_pivot, "position", Vector3(0.08, -0.03, 0.06), windup)
	_attack_tween.tween_property(_attack_pivot, "rotation_degrees", Vector3(8, 42, -34), slash)
	_attack_tween.parallel().tween_property(_attack_pivot, "position", Vector3(-0.18, 0.05, -0.32), slash)
	_attack_tween.tween_property(_attack_pivot, "rotation_degrees", Vector3.ZERO, recover)
	_attack_tween.parallel().tween_property(_attack_pivot, "position", Vector3.ZERO, recover)
	_attack_tween.tween_callback(func() -> void: _attack_playing = false)


func play_impact(_heavy: bool) -> void:
	if _attack_pivot:
		_attack_pivot.position.z -= 0.035


func cancel_melee_animation() -> void:
	if _attack_tween and _attack_tween.is_valid(): _attack_tween.kill()
	_attack_playing = false
	if _attack_pivot:
		_attack_pivot.position = Vector3.ZERO
		_attack_pivot.rotation_degrees = Vector3.ZERO


func is_attack_playing() -> bool:
	return _attack_playing


func _build_visual() -> void:
	_attack_pivot = Node3D.new()
	_attack_pivot.name = "AttackPivot"
	add_child(_attack_pivot)
	var model := Node3D.new()
	model.name = "KnifeModel"
	_attack_pivot.add_child(model)
	var steel := _material(Color("aeb7b7"), 0.23, 0.72)
	var edge := _material(Color("d8dfdc"), 0.14, 0.82)
	var worn := _material(Color("747d7c"), 0.38, 0.60)
	var handle := _material(Color("24282a"), 0.86)
	var rivet := _material(Color("b4b8b5"), 0.28, 0.75)

	# A single extruded side profile gives the blade a continuous kitchen-knife
	# silhouette. The spine runs straight from the bolster, then tapers into an
	# acute point while the cutting edge sweeps upward to meet it.
	var blade_profile: Array[Vector2] = [
		Vector2(0.11, 0.02),
		Vector2(0.11, -0.58),
		Vector2(-0.015, -0.94),
		Vector2(-0.11, -0.64),
		Vector2(-0.11, 0.02),
	]
	_add_profile_prism("Blade", blade_profile, 0.045, steel, model)
	var edge_profile: Array[Vector2] = [
		Vector2(-0.074, 0.02),
		Vector2(-0.11, 0.02),
		Vector2(-0.11, -0.64),
		Vector2(-0.015, -0.94),
		Vector2(0.004, -0.90),
		Vector2(-0.074, -0.59),
	]
	_add_profile_prism("CuttingEdge", edge_profile, 0.049, edge, model)
	_add_profile_prism("BladeTip", [Vector2(0.11, -0.58), Vector2(-0.015, -0.94), Vector2(-0.11, -0.64)], 0.047, steel, model)
	_add_box("BladeSpineWear", Vector3(0.024, 0.102, -0.30), Vector3(0.008, 0.012, 0.52), worn, Vector3.ZERO, model)
	_add_box("Tang", Vector3(0, 0, -0.04), Vector3(0.065, 0.11, 0.22), worn, Vector3.ZERO, model)
	_add_box("Handle", Vector3(0, -0.005, 0.25), Vector3(0.13, 0.18, 0.48), handle, Vector3(-2, 0, 0), model)
	_add_box("HandleEnd", Vector3(0, -0.01, 0.51), Vector3(0.145, 0.20, 0.07), handle, Vector3.ZERO, model)
	for z in [0.10, 0.28, 0.44]:
		_add_cylinder("HandleRivet%02d" % int(z * 100), Vector3(0.071, 0.0, z), 0.025, 0.012, rivet, Vector3(0, 0, 90), model, 8)
	_add_anchor(model, "GripAnchor", Vector3(0, 0, 0.28))
	_add_anchor(model, "ImpactPoint", Vector3(0, -0.015, -0.94))
	_add_anchor(model, "HipAnchor", Vector3.ZERO)
	_add_anchor(model, "InteractionAnchor", Vector3(0, 0, -0.18))
	if first_person:
		var skin := _material(Color("8a6b58"), 0.92)
		var sleeve := _material(Color("263238"), 0.94)
		_add_capsule("RightHand", Vector3(0.02, -0.05, 0.29), 0.095, 0.31, skin, Vector3(88, 0, 0), model)
		_add_tapered("RightSleeve", Vector3(0.08, -0.22, 0.62), 0.11, 0.17, 0.64, sleeve, Vector3(-58, -5, 0), model)


func _add_profile_prism(piece_name: String, profile: Array[Vector2], thickness: float, material: Material, parent: Node3D) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_width := thickness * 0.5
	# Triangulate both broad blade faces from the first profile vertex.
	for index in range(1, profile.size() - 1):
		_add_triangle(surface, _profile_vertex(half_width, profile[0]), _profile_vertex(half_width, profile[index]), _profile_vertex(half_width, profile[index + 1]))
		_add_triangle(surface, _profile_vertex(-half_width, profile[0]), _profile_vertex(-half_width, profile[index + 1]), _profile_vertex(-half_width, profile[index]))
	# Close the thin perimeter so the point reads correctly from every angle.
	for index in range(profile.size()):
		var next := (index + 1) % profile.size()
		var front_a := _profile_vertex(half_width, profile[index])
		var front_b := _profile_vertex(half_width, profile[next])
		var back_a := _profile_vertex(-half_width, profile[index])
		var back_b := _profile_vertex(-half_width, profile[next])
		_add_triangle(surface, front_a, back_b, front_b)
		_add_triangle(surface, front_a, back_a, back_b)
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = piece_name
	instance.mesh = surface.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _profile_vertex(width: float, point: Vector2) -> Vector3:
	return Vector3(width, point.x, point.y)


func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
