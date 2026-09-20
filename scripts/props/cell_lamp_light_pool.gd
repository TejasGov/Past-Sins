extends Node3D

## At most four nearby cell lamps cast real light/shadows. Each pooled light
## stays at its source; distant fixture meshes retain their on/off appearance.
const MAX_LIGHTS := 4
const ACTIVE_DISTANCE := 9.0
var _lights: Array[OmniLight3D] = []
var _elapsed := 0.0

func _ready() -> void:
	add_to_group("cell_lamp_light_pools")
	for index in range(MAX_LIGHTS):
		var light := OmniLight3D.new()
		light.name = "NearbyCellLamp%d" % index
		light.add_to_group("cell_lamp_pooled_lights")
		light.visible = false
		light.shadow_enabled = true
		light.shadow_bias = 0.03
		light.omni_attenuation = 1.25
		add_child(light)
		_lights.append(light)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.1:
		_elapsed = 0.0
		refresh()

func refresh() -> void:
	if not is_inside_tree(): return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var candidates: Array[Dictionary] = []
	for lamp in get_tree().get_nodes_in_group("cell_lamps"):
		if not get_parent().is_ancestor_of(lamp) or not lamp.local_light_enabled or not lamp.is_visually_lit(): continue
		var distance: float = camera.global_position.distance_squared_to(lamp.get_light_origin())
		if distance < ACTIVE_DISTANCE * ACTIVE_DISTANCE:
			candidates.append({"lamp": lamp, "distance": distance})
	candidates.sort_custom(func(a, b): return a.distance < b.distance)
	for index in range(_lights.size()):
		var light := _lights[index]
		light.visible = index < candidates.size()
		light.set_meta("source_lamp", NodePath())
		if not light.visible: continue
		var lamp: Node3D = candidates[index].lamp
		light.global_position = lamp.get_light_origin()
		light.light_color = lamp.lamp_color
		light.light_energy = lamp.lamp_energy
		light.omni_range = lamp.lamp_range
		light.light_cull_mask = lamp.visual_layer_mask
		light.set_meta("source_lamp", lamp.get_path())
