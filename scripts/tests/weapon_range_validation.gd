extends Node3D

const RANGE := preload("res://scenes/dev/WeaponRange.tscn")
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	DevModeManager.set_enabled(false)
	var locked_range := RANGE.instantiate() as WeaponRange
	add_child(locked_range)
	await get_tree().process_frame
	_check(locked_range.is_in_group("dev_only_scene") and bool(locked_range.get_meta("dev_only", false)), "Range must be explicitly marked dev-only")
	_check(get_tree().get_first_node_in_group("player") == null, "Play Mode must not spawn a player in the Weapons Test Range")
	locked_range.free()
	await get_tree().process_frame

	DevModeManager.set_enabled(true)
	var range_scene := RANGE.instantiate() as WeaponRange
	add_child(range_scene)
	for frame in range(3): await get_tree().process_frame
	await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	_check(player != null, "Dev Mode must spawn a player in the range")
	_check(player != null and player.global_position.distance_to(range_scene.get_node("Spawn").global_position) < 0.05, "Player must use the authored range spawn")
	_check(_position_is_clear(range_scene.get_node("Spawn") as Marker3D), "Player spawn must not intersect range collision")

	var required_labels := [
		"PISTOL\n[E] PICK UP", "SMG\n[E] PICK UP", "CARBINE AR\n[E] PICK UP", "SNIPER RIFLE\n[E] PICK UP", "KITCHEN KNIFE\n[E] PICK UP", "IMPROVISED SLINGSHOT\n[E] PICK UP", "MONOCULAR",
		"TRANQUILIZER\nINJECTOR", "MAKESHIFT\nSUPPRESSOR", "PROPER\nSUPPRESSOR",
		"UNARMORED\n100 HP", "STANDARD VEST\n125 HP", "ADVANCED VEST\n150 HP",
		"UNAWARE INMATE", "UNAWARE GUARD", "GUARD FACING PLAYER", "GUARD FACING AWAY", "WITNESS NPC",
		"RESET TARGETS\n[E] AVAILABLE", "REFILL AMMO\n[E] AVAILABLE", "CLEAR LOADOUT\nAVAILABLE IN F8",
		"GIVE ALL TEST ITEMS\nAVAILABLE IN F8", "RESET SUSPICION\nAVAILABLE IN F8", "RESET PLAYER HEALTH\nAVAILABLE IN F8",
	]
	var visible_text := _all_label_text(range_scene)
	for label_text in required_labels:
		_check(visible_text.has(label_text), "Missing required range label: %s" % label_text.replace("\n", " / "))

	var targets := get_tree().get_nodes_in_group("weapon_range_targets")
	_check(targets.size() == 4, "Firing range must provide exactly four target distances")
	var found_distances: Array[int] = []
	for target in targets:
		if not range_scene.is_ancestor_of(target): continue
		var distance_m := float(target.get_meta("distance_m", -1.0))
		var firing_line_z := float(target.get_meta("firing_line_z", 0.0))
		found_distances.append(int(distance_m))
		_check(absf((firing_line_z - (target as Node3D).position.z) - distance_m) < 0.05, "Target placement does not match its distance label")
	found_distances.sort()
	_check(found_distances == [5, 15, 30, 60], "Target distances must be 5m, 15m, 30m and 60m")

	var damage_dummies := _owned_group(range_scene, "weapon_range_damage_dummies")
	_check(damage_dummies.size() == 6, "Damage area must provide armor, melee, inmate-toxin and guard-toxin targets")
	_check(_dummy_by_label(damage_dummies, "MELEE RESET TARGET") != null, "Damage area must provide a designated close, resettable melee target")
	for dummy in damage_dummies:
		for zone_name in ["Head", "Torso", "LowerBody"]:
			var zone := dummy.get_node_or_null("Body/%s" % zone_name) as BodyHitZone
			_check(zone != null, "%s dummy is missing reusable %s hit zone" % [dummy.name, zone_name])
			_check(zone != null and zone.collision_layer == 32 and zone.get_meta("hit_zone", &"") == zone.get_hit_zone_id(), "%s hit zone must be identifiable by future raycasts" % zone_name)
	_check(_owned_group(range_scene, "weapon_range_stealth_placeholders").size() == 5, "Stealth room must provide five labeled placeholder positions")
	_check(_owned_group(range_scene, "weapon_range_station").size() == 6, "Range must provide equipment, firing, damage, stealth, observation and controls stations")
	_check(_owned_group(range_scene, "dev_inventory_pickups").size() == 7, "Range must provide seven data-only DEV inventory pickups")
	await _validate_health_foundation(range_scene, damage_dummies)

	var terminal := range_scene.get_node_or_null("Interactables/ReturnToDevHub") as DevReturnTerminal
	_check(terminal != null, "Range must include an in-world return terminal")
	_check(terminal != null and terminal.target_scene_id == &"dev_test_hub", "Return terminal must target the Dev Test Hub")
	_check(_test_scene_path(&"weapons_test_range") == "res://scenes/dev/WeaponRange.tscn", "Dev Menu must register the dedicated range scene")
	_check(_test_scene_path(&"dev_test_hub") == "res://scenes/dev/DevTestHub.tscn", "Return destination must be registered")

	# Exercise the production player motor in the authored range rather than only
	# checking that its script exists.
	var start_position := player.global_position
	Input.action_press("move_forward")
	for frame in range(12): await get_tree().physics_frame
	Input.action_release("move_forward")
	_check(player.global_position.distance_to(start_position) > 0.15, "Player must be able to move from the range spawn")
	Input.action_press("crouch")
	for frame in range(10): await get_tree().physics_frame
	_check(player.is_crouching, "Player crouch must work in the range")
	Input.action_release("crouch")
	for frame in range(30): await get_tree().physics_frame
	_check(not player.is_crouching, "Player must stand again in the range")

	var mesh_count := range_scene.find_children("*", "MeshInstance3D", true, false).size()
	var light_count := range_scene.find_children("*", "Light3D", true, false).size()
	_check(mesh_count < 460, "Range mesh count must remain Web-friendly with weapon models and the long observation annex, found %d" % mesh_count)
	_check(light_count <= 5, "Range must use no more than five inexpensive lights including the breakable test light, found %d" % light_count)

	range_scene.free()
	DevModeManager.set_enabled(false)
	if _failures.is_empty():
		print("WEAPONS TEST RANGE VALIDATION: PASS — health/armor math, aimed hit zones, death lockout/reset, dev isolation, movement and range layout")
	else:
		for failure in _failures: push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _position_is_clear(marker: Marker3D) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = marker.global_transform
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_viewport().world_3d.direct_space_state.intersect_shape(query, 8).is_empty()


func _validate_health_foundation(range_scene: WeaponRange, dummy_nodes: Array[Node]) -> void:
	var unarmored := _dummy_by_label(dummy_nodes, "UNARMORED")
	var standard := _dummy_by_label(dummy_nodes, "STANDARD VEST")
	var advanced := _dummy_by_label(dummy_nodes, "ADVANCED VEST")
	_check(unarmored != null and unarmored.health.base_health == 100.0 and unarmored.health.armor_bonus == 0.0 and unarmored.get_current_health() == 100.0, "Unarmored health must be base 100 + armor 0 = 100")
	_check(standard != null and standard.health.base_health == 100.0 and standard.health.armor_bonus == 25.0 and standard.get_current_health() == 125.0, "Standard vest health must be base 100 + armor 25 = 125")
	_check(advanced != null and advanced.health.base_health == 100.0 and advanced.health.armor_bonus == 50.0 and advanced.get_current_health() == 150.0, "Advanced vest health must be base 100 + armor 50 = 150")
	if unarmored == null or standard == null or advanced == null:
		return
	var tool := range_scene.get_node_or_null("DamageTestTool") as DevDamageTestTool
	_check(tool != null, "Range must provide the DEV-only body health probe")
	if tool == null:
		return
	_check(tool.TEST_VALUES == [30, 40, 50, 70, 90, 100, 120, 140, 150, 200, 300, 400], "Health probe quick values are incomplete")
	var standard_torso := standard.get_node("Body/Torso") as BodyHitZone
	var standard_head := standard.get_node("Body/Head") as BodyHitZone
	var unarmored_head := unarmored.get_node("Body/Head") as BodyHitZone
	var advanced_lower := advanced.get_node("Body/LowerBody") as BodyHitZone
	var signal_state := {"count": 0}
	standard.health.health_changed.connect(func(_current: float, _total: float): signal_state.count += 1)
	_check(tool.apply_damage_to_zone(standard_torso, 70.0), "DEV tool must apply damage to an explicit hit zone")
	_check(standard.get_current_health() == 55.0 and not standard.is_dead(), "70 damage to 125 HP must leave 55 HP")
	_check(int(signal_state.count) > 0, "HealthComponent must emit health_changed after damage")
	_check(tool.get_last_readout() == "TARGET: STANDARD VEST\nHIT ZONE: TORSO\nDAMAGE: 70\nHEALTH: 55 / 125", "DEV readout must report target, zone, damage and remaining health")
	standard.reset_target()
	var death_state := {"count": 0}
	unarmored.health.died.connect(func(_zone: StringName): death_state.count += 1)
	_check(tool.apply_damage_to_zone(unarmored_head, 120.0) and unarmored.is_dead(), "120 damage must kill a 100 HP target")
	_check(int(death_state.count) == 1 and unarmored.status_label.text.contains("DEAD"), "Lethal damage must emit died and show a visible DEAD state")
	_check(tool.apply_damage_to_zone(standard_head, 120.0) and standard.get_current_health() == 5.0 and not standard.is_dead(), "120 damage must not kill a fresh 125 HP target")
	unarmored.reset_target()
	standard.reset_target()
	advanced.reset_target()
	tool.apply_damage_to_zone(unarmored_head, 150.0)
	tool.apply_damage_to_zone(standard_head, 150.0)
	tool.apply_damage_to_zone(advanced_lower, 150.0)
	_check(unarmored.is_dead() and standard.is_dead() and advanced.is_dead(), "150 damage must kill all three current armor states")
	var dead_health := advanced.get_current_health()
	_check(not tool.apply_damage_to_zone(advanced_lower, 30.0) and advanced.get_current_health() == dead_health, "Dead targets must ignore repeated meaningful damage")
	var reset_control := range_scene.get_node_or_null("Interactables/ResetTargetsControl") as DevRangeResetControl
	_check(reset_control != null, "Existing RESET TARGETS control must be an interactable")
	if reset_control:
		reset_control.interact(DevModeManager.get_player())
	_check(unarmored.get_current_health() == 100.0 and not unarmored.is_dead(), "RESET TARGETS must restore unarmored target")
	_check(standard.get_current_health() == 125.0 and not standard.is_dead(), "RESET TARGETS must restore standard vest target")
	_check(advanced.get_current_health() == 150.0 and not advanced.is_dead(), "RESET TARGETS must restore advanced vest target")
	# Aim an actual camera ray at the head collider to prove future weapon rays can
	# identify a zone without embedding any weapon damage in the zone itself.
	var player := DevModeManager.get_player()
	var head_visual := standard_head.get_node("HeadVisual") as MeshInstance3D
	player.global_position = standard.global_position + Vector3(0, 0.95, 5.0)
	player.velocity = Vector3.ZERO
	player.camera.look_at(head_visual.global_position, Vector3.UP)
	await get_tree().physics_frame
	var detected := tool.get_aimed_hit_zone()
	_check(detected == standard_head and detected.get_hit_zone_id() == &"HEAD", "Aimed DEV ray must detect the correct HEAD hit zone")


func _dummy_by_label(nodes: Array[Node], label_text: String) -> DamageableHumanDummy:
	for node in nodes:
		if node is DamageableHumanDummy and (node as DamageableHumanDummy).target_label == label_text:
			return node as DamageableHumanDummy
	return null


func _all_label_text(root: Node) -> Array[String]:
	var result: Array[String] = []
	for node in root.find_children("*", "Label3D", true, false):
		result.append((node as Label3D).text)
	return result


func _owned_group(root: Node, group_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for node in get_tree().get_nodes_in_group(group_name):
		if root.is_ancestor_of(node): result.append(node)
	return result


func _test_scene_path(id: StringName) -> String:
	for entry in DevModeManager.get_test_scene_entries():
		if entry.id == id: return String(entry.scene_path)
	return ""


func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
