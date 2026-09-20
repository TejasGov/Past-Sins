extends StaticBody3D
class_name CellLamp

## Horizontal wall tube. Local +Z faces into the room; origin is the wall face.
signal lamp_broken
const LIGHT_POOL := preload("res://scripts/props/cell_lamp_light_pool.gd")
@export var is_on := true
@export var lamp_color := Color("ffd39a")
@export var lamp_energy := 3.5
@export var lamp_range := 6.5
@export var local_light_enabled := true
@export var breakable := true
@export_flags_3d_render var visual_layer_mask := 1
var is_broken := false
var _manual_override := false
var _bulb_mesh: MeshInstance3D
var _on_material: StandardMaterial3D
var _off_material: StandardMaterial3D
var _pool: Node3D

func _ready() -> void:
	add_to_group("cell_lamps")
	add_to_group("environmental_props")
	set_meta("prop_kind", "cell_lamp")
	set_meta("placement_zone", "Cell")
	set_meta("surface_type", "LIGHT")
	collision_layer = 1
	collision_mask = 0
	_build_visuals()
	_apply_state()
	call_deferred("_register_light")

func _register_light() -> void:
	var world_root: Node = self
	while world_root.get_parent() != get_tree().root and not world_root.has_node("EnvironmentCycle"):
		world_root = world_root.get_parent()
	for candidate in get_tree().get_nodes_in_group("cell_lamp_light_pools"):
		if candidate.get_parent() == world_root:
			_pool = candidate
			break
	if _pool == null:
		_pool = LIGHT_POOL.new()
		_pool.name = "CellLampLightPool"
		world_root.add_child(_pool)
	_pool.call("refresh")

func get_interaction_prompt(_player: Node) -> String:
	if is_broken: return "[E] Lamp Broken"
	return "[E] Turn Off Lamp" if is_on else "[E] Turn On Lamp"

func interact(_player: Node) -> void:
	toggle()

func toggle() -> void:
	if is_broken: return
	_manual_override = true
	is_on = not is_on
	_apply_state()

func set_night_active(enabled: bool) -> void:
	# E overrides the automatic clock default until the scene is restarted.
	if not _manual_override and not is_broken:
		is_on = enabled
		_apply_state()

func is_visually_lit() -> bool:
	return is_on and not is_broken

func get_light_origin() -> Vector3:
	return to_global(Vector3(0, -0.10, 0.30))

func break_lamp() -> void:
	if is_broken or not breakable: return
	is_broken = true
	is_on = false
	_apply_state()
	lamp_broken.emit()

func on_slingshot_projectile_impact(_projectile, _hit_position: Vector3) -> void:
	break_lamp()

func on_hitscan_impact(_hit_position: Vector3) -> void:
	break_lamp()

func _apply_state() -> void:
	if is_instance_valid(_bulb_mesh):
		_bulb_mesh.material_override = _on_material if is_visually_lit() else _off_material
	if is_instance_valid(_pool): _pool.call("refresh")

func _build_visuals() -> void:
	var housing := StandardMaterial3D.new()
	housing.albedo_color = Color("b2b5a9")
	housing.roughness = 0.75
	_on_material = StandardMaterial3D.new()
	_on_material.albedo_color = lamp_color
	_on_material.emission_enabled = true
	_on_material.emission = lamp_color
	_on_material.emission_energy_multiplier = 3.0
	_off_material = StandardMaterial3D.new()
	_off_material.albedo_color = Color("92968b")
	_off_material.roughness = 0.85
	var plate := MeshInstance3D.new()
	plate.name = "WallBackplate"
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(1.48, 0.24, 0.10)
	plate.mesh = plate_mesh
	plate.position.z = 0.05
	plate.material_override = housing
	plate.layers = visual_layer_mask
	add_child(plate)
	_bulb_mesh = MeshInstance3D.new()
	_bulb_mesh.name = "TubeDiffuser"
	var tube := CylinderMesh.new()
	tube.height = 1.24
	tube.top_radius = 0.055
	tube.bottom_radius = 0.055
	tube.radial_segments = 12
	tube.rings = 1
	_bulb_mesh.mesh = tube
	_bulb_mesh.rotation.z = PI * 0.5
	_bulb_mesh.position.z = 0.145
	_bulb_mesh.layers = visual_layer_mask
	_bulb_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bulb_mesh)
	var collider := CollisionShape3D.new()
	collider.name = "LampCollider"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.48, 0.24, 0.22)
	collider.shape = shape
	collider.position.z = 0.11
	add_child(collider)
