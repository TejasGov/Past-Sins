extends Node3D

const RANGE := preload("res://scenes/dev/WeaponRange.tscn")
const SLINGSHOT: SlingshotDefinition = preload("res://resources/weapons/improvised_slingshot.tres")
const KNIFE: MeleeDefinition = preload("res://resources/weapons/kitchen_knife.tres")
var failures: Array[String] = []
var range_scene: WeaponRange


func _ready() -> void: call_deferred("_validate")


func _validate() -> void:
	DevModeManager.set_enabled(true)
	range_scene = RANGE.instantiate() as WeaponRange
	add_child(range_scene)
	for frame in range(5): await get_tree().process_frame
	await get_tree().physics_frame
	_check(SLINGSHOT.is_valid_slingshot_definition(), "Slingshot definition must be valid")
	_check(SLINGSHOT.damage_for_zone(&"LOWER_BODY") == 25 and SLINGSHOT.damage_for_zone(&"TORSO") == 45 and SLINGSHOT.damage_for_zone(&"HEAD") == 120, "Slingshot damage must be 25/45/120")
	_check(SLINGSHOT.minimum_velocity == 9.0 and SLINGSHOT.maximum_velocity == 25.0 and SLINGSHOT.aimed_spread_multiplier <= 0.25, "Slingshot must use the slower, aimed-readable projectile tuning")
	_check(SLINGSHOT.weapon_visibility_class == &"IMPROVISED_WEAPON", "Slingshot must expose IMPROVISED_WEAPON")
	var fp := SLINGSHOT.first_person_visual_scene.instantiate() as ImprovisedSlingshotVisual
	add_child(fp); await get_tree().process_frame
	for part in ["LeftProng", "CenterProng", "RightProng", "GripCore", "LeftElastic", "RightElastic", "Pouch"]: _check(fp.find_child(part, true, false) != null, "Slingshot is missing %s" % part)
	fp.free()

	InventoryManager.clear_all_inventory(false)
	var player := DevModeManager.get_player()
	var range_pickup: SlingshotPickup
	for node in get_tree().get_nodes_in_group("melee_pickups"):
		if node is SlingshotPickup and range_scene.is_ancestor_of(node): range_pickup = node as SlingshotPickup
	_check(range_pickup != null, "Range must contain the dedicated slingshot pickup")
	if range_pickup: range_pickup.interact(player)
	_check(InventoryManager.has_item(SLINGSHOT.item_id), "Slingshot pickup must fill improvised/melee slot")
	_check(InventoryManager.get_item_count(&"slingshot_nail") == 12, "Slingshot pickup must grant 12 starter nails so it works immediately")
	_check(not InventoryManager.add_item(KNIFE) and InventoryManager.get_last_feedback() == InventoryComponent.MELEE_SLOT_FULL, "Knife and slingshot cannot coexist in one slot")
	InventoryManager.add_item(SLINGSHOT.toxin_ammo, 4)
	var controller := player.get_node("MeleeController") as PlayerMeleeController
	_check(controller.equip_melee_slot() and controller.current_slingshot != null, "Player must equip functional slingshot through slot 3")
	var count_before := InventoryManager.get_item_count(&"slingshot_nail")
	var visual := controller.current_slingshot.visual
	var idle_pouch_z := visual.pouch.position.z
	Input.action_press("fire_weapon")
	await get_tree().process_frame
	_check(controller.current_slingshot.state == SlingshotComponent.State.DRAWING, "Real hold-fire input must begin drawing")
	for frame in range(50): await get_tree().physics_frame
	var charge := controller.current_slingshot.get_charge()
	_check(visual.pouch.position.z > idle_pouch_z + 0.35 and visual.pouch.position.y < 0.02 and visual.find_child("RearHand", true, false) != null, "Full draw must visibly pull pouch, elastic and rear hand backward")
	var launched := {"projectile": null}
	controller.current_slingshot.projectile_launched.connect(func(value: SlingshotProjectile, _toxin: bool, _charge: float): launched.projectile = value, CONNECT_ONE_SHOT)
	Input.action_release("fire_weapon")
	var release_event := InputEventAction.new()
	release_event.action = &"fire_weapon"
	release_event.pressed = false
	controller._unhandled_input(release_event)
	await get_tree().process_frame
	var projectile := launched.projectile as SlingshotProjectile
	_check(projectile != null and charge > 0.9, "Release fire must launch a charged real projectile")
	_check(InventoryManager.get_item_count(&"slingshot_nail") == count_before - 1, "One shot must consume exactly one nail")
	if projectile:
		var start := projectile.global_position
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(is_instance_valid(projectile) and projectile.global_position.distance_to(start) > 0.05 and projectile.velocity.length() <= SLINGSHOT.maximum_velocity + 0.25, "Projectile must have slower visible travel and remain within configured launch speed")
	DevModeManager.reset_slingshot_projectiles()
	await get_tree().process_frame

	for data in [["UNARMORED", &"LOWER_BODY", 25.0], ["STANDARD VEST", &"TORSO", 45.0], ["ADVANCED VEST", &"HEAD", 120.0]]:
		var dummy := _dummy(String(data[0])); dummy.reset_target()
		var zone := dummy.get_node("Body/%s" % String(data[1]).to_pascal_case()) as BodyHitZone
		var before := dummy.get_current_health()
		var nail := _projectile(false); nail._resolve_hit({"collider": zone, "position": zone.global_position, "normal": Vector3.BACK})
		_check(dummy.get_current_health() == maxf(0.0, before - float(data[2])), "%s damage must use normal HealthComponent flow" % data[1])
		await get_tree().process_frame

	var noises: Array[Dictionary] = []
	WorldNoiseSystem.noise_emitted.connect(func(_p: Vector3, intensity: float, surface: StringName, _s: Node): noises.append({"intensity": intensity, "surface": surface}), CONNECT_ONE_SHOT)
	var concrete := range_scene.get_node("Stations/ConcreteImpactSurface")
	var normal_nail := _projectile(false); normal_nail.recovery_chance_override = 1.0
	var pickups_before := get_tree().get_nodes_in_group("slingshot_ammo_pickups").size()
	normal_nail._resolve_hit({"collider": concrete, "position": concrete.global_position, "normal": Vector3.BACK})
	await get_tree().process_frame
	_check(not noises.is_empty() and noises[0].surface == &"CONCRETE", "Concrete impact must emit reusable world noise")
	_check(get_tree().get_nodes_in_group("slingshot_ammo_pickups").size() == pickups_before + 1, "Normal environment miss can create recoverable ammo")
	var metal := range_scene.get_node("Stations/MetalImpactSurface")
	var metal_noise := {"value": 0.0}
	WorldNoiseSystem.noise_emitted.connect(func(_p: Vector3, intensity: float, _surface: StringName, _s: Node): metal_noise.value = intensity, CONNECT_ONE_SHOT)
	var toxin_miss := _projectile(true); toxin_miss.recovery_chance_override = 1.0
	pickups_before = get_tree().get_nodes_in_group("slingshot_ammo_pickups").size()
	toxin_miss._resolve_hit({"collider": metal, "position": metal.global_position, "normal": Vector3.BACK})
	await get_tree().process_frame
	_check(float(metal_noise.value) > float(noises[0].intensity), "Metal impact disturbance must be stronger than concrete")
	_check(get_tree().get_nodes_in_group("slingshot_ammo_pickups").size() == pickups_before, "Toxin nails must never recover")

	var light := range_scene.get_node("Stations/SlingshotBreakableLight") as SlingshotBreakableLight
	var light_nail := _projectile(false); light_nail.recovery_chance_override = 0.0
	light_nail._resolve_hit({"collider": light, "position": light.global_position, "normal": Vector3.BACK})
	await get_tree().process_frame
	_check(light.broken and not light.get_node("Light").visible, "DEV breakable light must visibly turn off")
	DevModeManager.reset_slingshot_breakable_lights(); _check(not light.broken, "Breakable light reset must restore it")

	var inmate := _dummy("INMATE TOXIN TARGET"); inmate.reset_target()
	_projectile(true)._resolve_hit({"collider": inmate.get_node("Body/Torso"), "position": inmate.global_position, "normal": Vector3.BACK})
	for frame in range(35): await get_tree().physics_frame
	_check(inmate.is_dead() and inmate.toxin_status.incapacitated, "Inmate toxin target must transition rapidly")
	var guard := _dummy("GUARD TOXIN TARGET"); guard.reset_target()
	_projectile(true)._resolve_hit({"collider": guard.get_node("Body/LowerBody"), "position": guard.global_position, "normal": Vector3.BACK})
	_check(guard.toxin_status.active and not guard.toxin_status.can_use_security_actions(), "Guard must immediately lose alarm/radio/panel capability during toxin transition")
	for frame in range(120): await get_tree().physics_frame
	_check(not guard.is_dead(), "Guard toxin transition must last longer than two seconds")
	for frame in range(70): await get_tree().physics_frame
	_check(guard.is_dead() and guard.toxin_status.incapacitated, "Guard must incapacitate after the configured three-second transition")

	range_scene.free(); DevModeManager.set_enabled(false)
	if failures.is_empty(): print("SLINGSHOT VALIDATION: PASS — slot, draw/release, projectile/drop, damage, noise, recovery, toxin, breakable light and obsolete-item removal")
	else:
		for failure in failures: push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _projectile(toxin: bool) -> SlingshotProjectile:
	var node := SLINGSHOT.projectile_scene.instantiate() as SlingshotProjectile
	range_scene.add_child(node)
	node.setup(SLINGSHOT, Vector3.FORWARD * 20.0, toxin, DevModeManager.get_player())
	return node


func _dummy(label: String) -> DamageableHumanDummy:
	for node in get_tree().get_nodes_in_group("weapon_range_damage_dummies"):
		if range_scene.is_ancestor_of(node) and (node as DamageableHumanDummy).target_label == label: return node
	return null


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
