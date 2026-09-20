extends Node3D

const WEAPON_RESOURCE_DIRECTORY := "res://resources/weapons"

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var directory := DirAccess.open(WEAPON_RESOURCE_DIRECTORY)
	_check(directory != null, "Weapon resource directory must exist")
	if directory == null:
		_finish()
		return

	var resource_files := PackedStringArray()
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir() and file_name.ends_with(".tres"):
			resource_files.append(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	resource_files.sort()
	_check(not resource_files.is_empty(), "At least one firearm definition must be registered")

	var weapon_ids := {}
	for resource_file in resource_files:
		var path := "%s/%s" % [WEAPON_RESOURCE_DIRECTORY, resource_file]
		var resource := load(path)
		# The shared weapon directory also contains independently validated melee
		# definitions; this suite owns the firearm contract only.
		if resource is MeleeDefinition:
			continue
		var definition := resource as FirearmDefinition
		_check(definition != null, "%s must load as FirearmDefinition or MeleeDefinition" % path)
		if definition == null: continue
		_check(definition.is_valid_firearm_definition(), "%s must contain a valid firearm definition" % path)
		var weapon_id := definition.normalized_weapon_id()
		_check(not weapon_ids.has(weapon_id), "Firearm weapon_id must be unique: %s" % weapon_id)
		weapon_ids[weapon_id] = true
		await _validate_visual_scene(definition, definition.first_person_visual_scene, true)
		await _validate_visual_scene(definition, definition.world_visual_scene, false)

	_finish()


func _validate_visual_scene(definition: FirearmDefinition, scene: PackedScene, first_person: bool) -> void:
	var label := "first-person" if first_person else "world"
	_check(scene != null, "%s requires a %s visual scene" % [definition.display_name, label])
	if scene == null:
		return
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var visual := _find_firearm_visual(instance)
	_check(visual != null, "%s %s scene must extend or contain FirearmVisualBase" % [definition.display_name, label])
	if visual:
		_check(visual.first_person == first_person, "%s %s scene has an incorrect first_person setting" % [definition.display_name, label])
		for failure in visual.validate_visual_contract():
			_check(false, "%s %s visual: %s" % [definition.display_name, label, failure])
		if first_person:
			var rear := visual.get_visual_anchor(&"RearSightAimPoint")
			var front := visual.get_visual_anchor(&"FrontSightAimPoint")
			var muzzle := visual.get_visual_anchor(&"MuzzlePoint")
			if rear and front and muzzle:
				var rear_local := visual.to_local(rear.global_position)
				var front_local := visual.to_local(front.global_position)
				var muzzle_local := visual.to_local(muzzle.global_position)
				_check(front_local.z < rear_local.z, "%s front sight must be forward of its rear sight" % definition.display_name)
				_check(muzzle_local.z < rear_local.z, "%s muzzle must be forward of its rear sight" % definition.display_name)
	instance.queue_free()
	await get_tree().process_frame


func _find_firearm_visual(root: Node) -> FirearmVisualBase:
	if root is FirearmVisualBase:
		return root as FirearmVisualBase
	for child in root.get_children():
		var found := _find_firearm_visual(child)
		if found:
			return found
	return null


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FIREARM ARCHITECTURE VALIDATION: PASS — all firearm resources use the shared visual contract and standardized anchors")
	else:
		for failure in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
