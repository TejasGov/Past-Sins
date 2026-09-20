extends Node3D
class_name SuppressorVisual

@export var makeshift := false


func _ready() -> void:
	_build()


func _build() -> void:
	var body := StandardMaterial3D.new()
	body.albedo_color = Color("34383a") if makeshift else Color("171c1e")
	body.roughness = 0.88 if makeshift else 0.52
	var collar := StandardMaterial3D.new()
	collar.albedo_color = Color("202426") if makeshift else Color("3c4447")
	collar.roughness = 0.72 if makeshift else 0.34
	var binding := StandardMaterial3D.new()
	binding.albedo_color = Color("4a4138")
	binding.roughness = 1.0
	_add_cylinder("MountingCollar", Vector3(0, 0, -0.055), 0.075 if makeshift else 0.072, 0.11, collar)
	_add_cylinder("SuppressorBody", Vector3(0, 0, -0.36), 0.102 if makeshift else 0.092, 0.62, body, 10 if makeshift else 14)
	_add_cylinder("EndCap", Vector3(0, 0, -0.68), 0.095 if makeshift else 0.088, 0.045, collar, 10 if makeshift else 14)
	if makeshift:
		# Fictional abstract bindings only; this intentionally communicates no
		# real construction method or internal structure.
		for index in range(4):
			var band := _add_cylinder("RoughBinding%02d" % index, Vector3(0, 0, -0.18 - index * 0.145), 0.111, 0.038, binding, 9)
			band.rotation_degrees.z = 2.0 if index % 2 == 0 else -3.0
		$SuppressorBody.scale.x = 1.0
		$SuppressorBody.scale.y = 0.94
	else:
		# Sparse collar rings read as machining/wear breaks without extra textures.
		_add_cylinder("FrontWearRing", Vector3(0, 0, -0.62), 0.094, 0.016, collar, 14)
		_add_cylinder("RearWearRing", Vector3(0, 0, -0.16), 0.094, 0.012, collar, 14)


func _add_cylinder(piece_name: String, piece_position: Vector3, radius: float, length: float, material: Material, segments := 12) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = piece_name
	instance.position = piece_position
	instance.rotation_degrees.x = 90.0
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = segments
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance
