extends Node3D

## Structural/runtime checks complement, rather than replace, in-editor images
## and a real Web export performance pass.
const CAMPUS := preload("res://scenes/levels/campus/PrisonCampusPrototype.tscn")
const FACTORY := preload("res://scripts/levels/greybox_factory.gd")
const SURFACES := preload("res://scripts/levels/surface_materials.gd")
const PROFILES := preload("res://scripts/systems/interior_lighting_profiles.gd")
const BANNED_ENVIRONMENT_PROPERTIES := ["glow_enabled", "ssao_enabled", "ssil_enabled", "ssr_enabled", "volumetric_fog_enabled", "sdfgi_enabled"]
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "Desktop rendering must remain Compatibility")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile") == "gl_compatibility", "Mobile/Web rendering must remain Compatibility")
	_validate_factory()
	_validate_materials()
	_validate_profile_definitions()
	var campus := CAMPUS.instantiate() as PrisonCampusPrototype
	campus.gameplay_enabled = false
	var cycle := campus.get_node("EnvironmentCycle") as CampusEnvironmentCycle
	cycle.cycle_enabled = false
	cycle.roll_weather_on_start = false
	cycle.start_time_hours = 12.0
	add_child(campus)
	for frame in range(4):
		await get_tree().process_frame
	await get_tree().physics_frame
	var zones := campus.get_node("WorldEnvironment") as EnvironmentZoneManager
	_check(zones != null, "Campus must use the reusable EnvironmentZoneManager")
	if zones == null:
		_finish()
		return
	_validate_environment(zones.exterior, "Exterior")
	_validate_environment(zones.interior, "Interior")
	_check(zones.exterior != zones.interior, "Interior and exterior environments must be independent resources")
	_check(zones.exterior.fog_enabled and is_equal_approx(zones.exterior.fog_density, 0.015), "Exterior must keep the requested cheap distance fog")
	_check(not zones.interior.fog_enabled, "Interior must never inherit outdoor fog")
	_check(is_equal_approx(zones.exterior.ambient_light_energy, 0.2), "Normal daytime exterior ambient must be 0.2")
	_check(is_equal_approx(zones.exterior.ambient_light_sky_contribution, 0.3), "Normal daytime sky contribution must be 0.3")
	var sun := campus.get_node("DirectionalLight3D") as DirectionalLight3D
	_check(sun.shadow_enabled and is_equal_approx(sun.light_energy, 1.0), "Normal daytime sun requires shadows and energy 1.0")
	_validate_building_volumes(campus)
	_validate_forbidden_nodes(campus)

	var camera := campus.get_node("PreviewCamera") as Camera3D
	camera.make_current()
	camera.global_position = Vector3(0, 1.7, 0)
	zones.refresh_from_viewer()
	_check(not zones.is_interior and zones.environment == zones.exterior and zones.environment.fog_enabled, "Yard view must select the foggy exterior")
	zones.set_interior(true)
	_check(zones.environment == zones.interior and not zones.environment.fog_enabled, "set_interior(true) must select a fog-free environment")
	zones.set_interior(false)
	_check(zones.environment == zones.exterior, "set_interior(false) must restore exterior")

	cycle.set_time_hours(22.0)
	var seen: Dictionary = {}
	for candidate in get_tree().get_nodes_in_group("campus_planned_rooms"):
		if not campus.is_ancestor_of(candidate):
			continue
		var room := candidate as Node3D
		var data: Dictionary = room.get_meta("room_data")
		var lighting_type := String(data.get("lighting_type", data.type))
		var profile_id := PROFILES.profile_id(lighting_type)
		if seen.has(profile_id):
			continue
		camera.global_position = room.to_global(Vector3(0, 1.65, 0))
		zones.refresh_from_viewer()
		_check(zones.is_interior, "%s room must fall inside its building environment volume" % room.name)
		_check(zones.active_profile == profile_id, "%s must select its declared %s lighting profile" % [room.name, profile_id])
		_check(not zones.environment.fog_enabled, "%s interior must remain clear of outdoor fog" % room.name)
		var profile: Dictionary = PROFILES.get_profile(lighting_type)
		_check(is_equal_approx(zones.interior.ambient_light_energy, float(profile.ambient) * 0.65), "%s must apply its own night ambient level" % profile_id)
		var light := room.get_parent().get_node_or_null("AutomaticInteriorLight") as OmniLight3D
		if light != null and room.has_meta("lighting_anchor"):
			_check(light.light_color.is_equal_approx(profile.color), "%s room emitter must consume the profile color" % profile_id)
			_check(light.global_position.is_equal_approx(room.to_global(room.get_meta("lighting_anchor"))), "%s room emitter must originate at the room fixture" % profile_id)
		seen[profile_id] = str(room.get_path())
	_check(seen.size() == 6, "Runtime review must visit all six distinct lighting profiles, found %s" % [seen.keys()])
	for profile_id in seen:
		print("VISUAL_PROFILE_CHECK ", profile_id, " -> ", seen[profile_id])
	for room in get_tree().get_nodes_in_group("environment_rooms"):
		if not campus.is_ancestor_of(room): continue
		var bounds: AABB = room.get_meta("environment_bounds")
		camera.global_position = room.to_global(bounds.get_center())
		zones.refresh_from_viewer()
		_check(zones.active_profile == "office", "Cellhouse guard quarter must select the office ambient profile")
		_check(not zones.environment.fog_enabled, "Guard quarter must remain fog-free")
		camera.global_position = room.to_global(Vector3(1.3, 1.7, 0))
		zones.refresh_from_viewer()
		_check(zones.active_profile == "cellblock", "Adjacent elevator lobby must not inherit guard-quarter ambient")

	# Moving to the yard after a basement/medical view must restore fog even if
	# the clock or weather changed while the player was inside.
	cycle.set_weather_mode(CampusEnvironmentCycle.WeatherMode.RAINY)
	camera.global_position = Vector3(0, 1.7, 0)
	zones.refresh_from_viewer()
	_check(not zones.is_interior and zones.environment.fog_enabled, "Leaving indoors in rain must restore exterior fog")
	_check(not zones.interior.fog_enabled, "Weather must not contaminate the separate indoor resource")
	var grade := campus.get_node_or_null("ScreenGrade") as CanvasLayer
	_check(grade != null and grade.layer < 0, "World grading must render before HUD, not bloom UI text")
	campus.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_factory() -> void:
	var fixture := Node3D.new()
	add_child(fixture)
	var factory := FACTORY.new(fixture)
	var wall: MeshInstance3D = factory.box("ShadowWall", Vector3.ZERO, Vector3(6, 3, 0.2), Color.GRAY)
	var angled: MeshInstance3D = factory.oriented_box("AngledWall", Transform3D(Basis(Vector3.UP, 0.5), Vector3(8, 0, 0)), Vector3(6, 3, 0.2), Color.GRAY)
	_check(wall.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Factory box walls must cast shadows by default")
	_check(angled.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Factory oriented walls must cast shadows by default")
	_check(fixture.get_node("Collision").get_child_count() == 2, "Visual pass must preserve structural collision")
	fixture.queue_free()


func _validate_materials() -> void:
	var count := 0
	for file in DirAccess.get_files_at("res://materials/props"):
		if not file.ends_with(".tres"):
			continue
		var material := load("res://materials/props/" + file) as StandardMaterial3D
		_check(material != null, file + " must remain a normal reusable material")
		if material == null:
			continue
		count += 1
		var local_mapping: bool = material.get_meta("mapping_space", "world") == "local"
		_check(material.uv1_triplanar and material.uv1_world_triplanar != local_mapping, file + " requires texture-ready mapping in its declared space")
		_check(material.albedo_texture != null and material.roughness_texture != null, file + " must have valid albedo and roughness textures")
		if material.normal_enabled:
			_check(material.normal_texture != null, file + " missing normal texture")
	_check(count >= 17, "Material audit must cover the full palette")
	_check(SURFACES.GRIME.width == 256 and SURFACES.GRIME.height == 256 and SURFACES.ROUGHNESS.width == 256, "Noise textures must stay within the 256px budget")


func _validate_profile_definitions() -> void:
	for kind in ["cellblock", "medical", "office", "wellness", "food", "service"]:
		var light := OmniLight3D.new()
		PROFILES.apply_to_light(light, kind)
		_check(light.light_color.is_equal_approx(PROFILES.YELLOW_LIGHT), "%s light must emit uniform yellow light" % kind)
		light.free()
	var lab_light := OmniLight3D.new()
	PROFILES.apply_to_light(lab_light, "laboratory")
	_check(lab_light.light_color.is_equal_approx(PROFILES.WHITE_LIGHT), "Laboratory light must emit sterile white light")
	lab_light.free()
	_check(PROFILES.get_profile("cellblock").ambient == PROFILES.UNIFORM_AMBIENT, "Ambient lighting must be uniform across interior profiles to avoid glitchy transitions")


func _validate_building_volumes(campus: Node3D) -> void:
	var count := 0
	for building in get_tree().get_nodes_in_group("campus_buildings"):
		if not campus.is_ancestor_of(building):
			continue
		count += 1
		var area := building.get_node_or_null("InteriorEnvironmentZone") as Area3D
		_check(area != null, "%s needs exactly one environment Area" % building.name)
		if area == null:
			continue
		var shapes := area.find_children("*", "CollisionShape3D", false, false)
		_check(shapes.size() == 1 and shapes[0].shape is BoxShape3D, "%s zone needs one footprint box" % building.name)
		if shapes.size() != 1 or not shapes[0].shape is BoxShape3D:
			continue
		var footprint: Vector3 = building.get_meta("footprint_size")
		var size: Vector3 = shapes[0].shape.size
		var inset := float(area.get_meta("doorway_inset_meters", 0.0))
		_check(is_equal_approx(inset, 2.0), "%s Area must keep a 2m doorway buffer" % building.name)
		_check(is_equal_approx(size.x, footprint.x - inset * 2.0) and is_equal_approx(size.z, footprint.z - inset * 2.0), "%s Area must derive inset dimensions from its shell footprint" % building.name)
		_check(size.y >= footprint.y, "%s Area must include all vertical floors" % building.name)
		_check(area.collision_layer == 0 and area.collision_mask == 2, "%s zone must detect players without blocking movement" % building.name)
		_check(area.body_entered.get_connections().size() == 1 and area.body_exited.get_connections().size() == 1, "%s zone signals must connect once" % building.name)
	_check(count == 7, "Campus must retain all seven buildings and their environment volumes")
	var actual_zones := 0
	for area in get_tree().get_nodes_in_group("interior_environment_zones"):
		if campus.is_ancestor_of(area):
			actual_zones += 1
	_check(actual_zones == 7, "Do not generate duplicate environment zones")


func _validate_environment(environment: Environment, label: String) -> void:
	for property in BANNED_ENVIRONMENT_PROPERTIES:
		_check(environment.get(property) != true, "%s must not enable unsupported %s" % [label, property])


func _validate_forbidden_nodes(node: Node) -> void:
	_check(not node.get_class() in ["FogVolume", "VoxelGI", "ReflectionProbe"], "Compatibility campus must not include " + node.get_class())
	if node is WorldEnvironment and node.environment:
		_validate_environment(node.environment, str(node.get_path()))
	for child in node.get_children():
		_validate_forbidden_nodes(child)


func _finish() -> void:
	if _failures.is_empty():
		print("VISUAL_OVERHAUL_VALIDATION_OK buildings=7 lighting_profiles=6 renderer=gl_compatibility")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
