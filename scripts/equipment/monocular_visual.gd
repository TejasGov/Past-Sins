extends Node3D
class_name MonocularVisual

const BodyStyle := preload("res://scripts/weapons/first_person_body_style.gd")

@export var first_person := false
var model: Node3D


func _ready() -> void:
	_build()


func _build() -> void:
	model = Node3D.new(); model.name = "ItemRoot"; add_child(model)
	var body_mat := _material(Color("1c2524"), 0.83)
	var rubber := _material(Color("101414"), 0.96)
	var ring_mat := _material(Color("303b39"), 0.72)
	var glass := _material(Color("31525a"), 0.18, true)
	_add_cylinder("Body", Vector3.ZERO, 0.13, 0.55, body_mat, Vector3(90, 0, 0))
	_add_cylinder("Eyecup", Vector3(0, 0, 0.315), 0.16, 0.13, rubber, Vector3(90, 0, 0))
	_add_cylinder("ObjectiveHousing", Vector3(0, 0, -0.33), 0.19, 0.18, body_mat, Vector3(90, 0, 0))
	_add_cylinder("ObjectiveLens", Vector3(0, 0, -0.425), 0.155, 0.018, glass, Vector3(90, 0, 0))
	_add_cylinder("FocusRing", Vector3(0, 0, -0.08), 0.148, 0.12, ring_mat, Vector3(90, 0, 0))
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		_add_box("FocusRib%02d" % index, Vector3(cos(angle) * 0.15, sin(angle) * 0.15, -0.08), Vector3(0.025, 0.055, 0.13), rubber, Vector3(0, 0, rad_to_deg(angle)))
	_add_cylinder("GripBand", Vector3(0, 0, 0.13), 0.143, 0.16, rubber, Vector3(90, 0, 0))
	var strap := _add_cylinder("WristStrap", Vector3(0.18, -0.13, 0.24), 0.012, 0.48, rubber, Vector3(35, 0, -35))
	strap.scale = Vector3(1, 1, 0.65)
	_add_marker("InteractionAnchor", Vector3.ZERO)
	if first_person:
		model.position = Vector3(0.48, -0.60, -1.02)
		model.rotation_degrees = Vector3(-12, -18, 8)
		var skin := _material(BodyStyle.SKIN_COLOR, BodyStyle.SKIN_ROUGHNESS)
		var sleeve := _material(BodyStyle.SLEEVE_COLOR, BodyStyle.SLEEVE_ROUGHNESS)
		_add_capsule("RightHandPalm", Vector3(0.04, -0.18, 0.12), BodyStyle.PALM_RADIUS, BodyStyle.PALM_HEIGHT, skin, Vector3(8, 0, 0))
		_add_cylinder("RightCuff", Vector3(0.08, -0.34, 0.24), BodyStyle.CUFF_RADIUS, BodyStyle.CUFF_HEIGHT, sleeve, Vector3(-55, 0, 0))
		_add_tapered("RightSleeve", Vector3(0.17, -0.57, 0.43), 0.11, 0.17, 0.62, sleeve, Vector3(-55, 0, -8))


func set_use_blend(blend: float) -> void:
	if model == null: return
	var t := clampf(blend, 0.0, 1.0)
	model.position = Vector3(0.48, -0.60, -1.02).lerp(Vector3(0.72, -0.20, -1.05), t)
	model.rotation_degrees = Vector3(-12, -18, 8).lerp(Vector3(-2, 5, 0), t)


func _material(color: Color, roughness: float, emissive := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = roughness
	if emissive: mat.emission_enabled = true; mat.emission = color; mat.emission_energy_multiplier = 0.8
	return mat


func _add_box(name_value: String, pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = name_value
	var mesh := BoxMesh.new(); mesh.size = size; node.mesh = mesh
	_configure(node, pos, rot, mat); return node


func _add_cylinder(name_value: String, pos: Vector3, radius: float, height: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = name_value
	var mesh := CylinderMesh.new(); mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height; mesh.radial_segments = 12; node.mesh = mesh
	_configure(node, pos, rot, mat); return node


func _add_tapered(name_value: String, pos: Vector3, top: float, bottom: float, height: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = name_value
	var mesh := CylinderMesh.new(); mesh.top_radius = top; mesh.bottom_radius = bottom; mesh.height = height; mesh.radial_segments = 8; node.mesh = mesh
	_configure(node, pos, rot, mat); return node


func _add_capsule(name_value: String, pos: Vector3, radius: float, height: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = name_value
	var mesh := CapsuleMesh.new(); mesh.radius = radius; mesh.height = height; mesh.radial_segments = 8; mesh.rings = 3; node.mesh = mesh
	_configure(node, pos, rot, mat); return node


func _configure(node: MeshInstance3D, pos: Vector3, rot: Vector3, mat: Material) -> void:
	node.position = pos; node.rotation_degrees = rot; node.material_override = mat; node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; model.add_child(node)


func _add_marker(name_value: String, pos: Vector3) -> void:
	var marker := Marker3D.new(); marker.name = name_value; marker.position = pos; model.add_child(marker)
