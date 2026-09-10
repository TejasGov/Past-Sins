extends Node3D
class_name WeaponRange

## Permanent dev-only environment. The pistol is the sole functional weapon;
## every other equipment/melee/firearm display remains a data-only placeholder.
const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const RETURN_TERMINAL_SCENE := preload("res://scenes/dev/DevReturnTerminal.tscn")
const RESET_CONTROL_SCENE := preload("res://scenes/dev/DevRangeResetControl.tscn")
const DAMAGE_DUMMY_SCENE := preload("res://scenes/dev/DamageableHumanDummy.tscn")
const INVENTORY_PICKUP_SCENE := preload("res://scenes/dev/DevInventoryPickup.tscn")
const FIREARM_PICKUP_SCENE := preload("res://scenes/weapons/FirearmPickup.tscn")
const FIREARM_CONTROL_SCENE := preload("res://scenes/dev/DevRangeFirearmControl.tscn")
const PISTOL_DEFINITION: FirearmDefinition = preload("res://resources/weapons/pistol.tres")
const Factory := preload("res://scripts/levels/greybox_factory.gd")

const FLOOR_COLOR := Color("646b6e")
const WALL_COLOR := Color("30383d")
const STRUCTURE_COLOR := Color("3c454a")
const STEEL_COLOR := Color("727d82")
const SAFETY_COLOR := Color("d5ad42")
const DISABLED_COLOR := Color("8b4545")
const LABEL_COLOR := Color("e9d17d")
const FIRING_LINE_Z := 29.0
const INVENTORY_TEST_ITEMS: Array[ItemDefinition] = [
	preload("res://resources/items/dev/test_firearm_a.tres"),
	preload("res://resources/items/dev/test_firearm_b.tres"),
	preload("res://resources/items/dev/test_firearm_c.tres"),
	preload("res://resources/items/dev/test_melee_a.tres"),
	preload("res://resources/items/dev/test_melee_b.tres"),
	preload("res://resources/items/dev/test_equipment.tres"),
	preload("res://resources/items/dev/test_stackable_equipment.tres"),
]


func _ready() -> void:
	add_to_group("dev_only_scene")
	set_meta("dev_only", true)
	_build_range()
	if not DevModeManager.is_enabled():
		return
	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.name = "WeaponRangePlayer"
	$Actors.add_child(player)
	player.global_transform = $Spawn.global_transform
	_register_point(&"weapon_range_lobby", "Range Lobby", $Spawn)
	_register_point(&"weapon_range_equipment", "Equipment Displays", $EquipmentSpawn)
	_register_point(&"weapon_range_firing", "Firing Line", $FiringSpawn)
	_register_point(&"weapon_range_damage", "Damage Dummy Stations", $DamageSpawn)
	_register_point(&"weapon_range_stealth", "Stealth Test Room", $StealthSpawn)


func _build_range() -> void:
	var g = Factory.new($Geometry)
	g.box("ConcreteFloor", Vector3(0, -0.12, 0), Vector3(50, 0.24, 94), FLOOR_COLOR)
	g.box("ConcreteCeiling", Vector3(0, 4.9, 0), Vector3(50, 0.24, 94), WALL_COLOR)
	g.outer_walls(50, 94, 5.0, WALL_COLOR)
	_build_zone_boundaries(g)
	_build_equipment_display(g)
	_build_inventory_test_pickups()
	_build_pistol_pickup()
	_build_firing_range(g)
	_build_damage_area(g)
	_build_stealth_area(g)
	_build_control_wall(g)
	_build_lighting(g)
	_build_return_terminal()


func _build_zone_boundaries(g) -> void:
	# Full-height ballistic partition keeps the firing lane isolated. Its front
	# opening is deliberately wide enough for ordinary player movement.
	g.wall_segment("BallisticPartition", Vector3(-0.7, 0, -5.5), 73.0, false, WALL_COLOR, 4.75, 0.3)
	g.partition_with_door("FiringEntry", Vector3(11.8, 0, 33.0), 25.0, true, -10.0, 2.4, WALL_COLOR, 4.75, 2.5, 0.3)
	g.partition_with_door("StealthThreshold", Vector3(-12.85, 0, 3.2), 24.3, true, 8.1, 2.0, WALL_COLOR, 4.75, 2.5, 0.3)
	# Floor bands make the open equipment/damage threshold readable without
	# blocking its shared circulation aisle.
	g.box("EquipmentZoneBand", Vector3(-12.8, 0.012, 25.0), Vector3(23.5, 0.018, 0.16), SAFETY_COLOR, false)
	g.box("DamageZoneBand", Vector3(-12.8, 0.012, 4.2), Vector3(23.5, 0.018, 0.16), SAFETY_COLOR, false)


func _build_equipment_display(g) -> void:
	var section := Node3D.new()
	section.name = "EquipmentDisplayArea"
	section.add_to_group("weapon_range_station")
	section.set_meta("station_id", "equipment")
	$Stations.add_child(section)
	g.sign("EQUIPMENT DISPLAY AREA // EMPTY PLACEHOLDERS", Vector3(-12.8, 3.35, 45.7), Vector3(0, 180, 0), LABEL_COLOR, 0.004)

	_add_display_table(g, "FirearmsDisplay", Vector3(-12.8, 0, 39.5), "FIREARMS", ["PISTOL", "SMG", "CARBINE AR", "SNIPER"])
	_add_display_table(g, "MeleeDisplay", Vector3(-12.8, 0, 34.2), "MELEE", ["KNIFE", "HAMMER"])
	_add_display_table(g, "EquipmentDisplay", Vector3(-12.8, 0, 28.9), "EQUIPMENT", ["MONOCULAR", "WIRE NOOSE", "TRANQUILIZER\nINJECTOR", "MAKESHIFT\nSUPPRESSOR", "PROPER\nSUPPRESSOR"])


func _add_display_table(g, piece_name: String, center: Vector3, heading: String, labels: Array[String]) -> void:
	g.supported_surface(piece_name, center, Vector2(20.0, 1.15), 0.9, 0.14, STEEL_COLOR, STRUCTURE_COLOR)
	g.sign(heading, center + Vector3(0, 1.78, -0.48), Vector3.ZERO, LABEL_COLOR, 0.0037)
	var usable_width := 18.0
	for index in range(labels.size()):
		var x := center.x if labels.size() == 1 else center.x - usable_width * 0.5 + usable_width * float(index) / float(labels.size() - 1)
		if piece_name == "FirearmsDisplay" and index == 0:
			# The real data-driven pistol pickup replaces this former empty rack card.
			continue
		g.box("%sEmptySlot%02d" % [piece_name, index], Vector3(x, 0.99, center.z), Vector3(1.35, 0.05, 0.72), Color("30383c"), false)
		g.box("%sSlotPlaque%02d" % [piece_name, index], Vector3(x, 1.27, center.z + 0.075), Vector3(1.75, 0.46, 0.045), Color("20282c"), false)
		g.sign(labels[index], Vector3(x, 1.28, center.z + 0.12), Vector3.ZERO, Color("c7d6d8"), 0.00235)


func _build_inventory_test_pickups() -> void:
	# These colored data tokens validate carry rules only; they are intentionally
	# not weapon models and expose no use/attack behavior.
	var positions := [
		Vector3(-15.8, 0.9, 39.5), Vector3(-9.8, 0.9, 39.5), Vector3(-3.8, 0.9, 39.5),
		Vector3(-16.4, 0.9, 34.2), Vector3(-9.2, 0.9, 34.2),
		Vector3(-16.4, 0.9, 28.9), Vector3(-9.2, 0.9, 28.9),
	]
	for index in range(INVENTORY_TEST_ITEMS.size()):
		var pickup := INVENTORY_PICKUP_SCENE.instantiate() as DevInventoryPickup
		pickup.name = INVENTORY_TEST_ITEMS[index].display_name.to_pascal_case().validate_node_name()
		pickup.item_definition = INVENTORY_TEST_ITEMS[index]
		pickup.position = positions[index]
		$Interactables.add_child(pickup)


func _build_pistol_pickup() -> void:
	var pickup := FIREARM_PICKUP_SCENE.instantiate() as FirearmPickup
	pickup.name = "PistolPickup"
	pickup.definition = PISTOL_DEFINITION
	# Slightly toward the aisle so the real model is visible in front of the old
	# empty-slot plaque while remaining fully supported by the tabletop.
	pickup.position = Vector3(-21.8, 0.9, 39.95)
	pickup.add_to_group("weapon_range_pistol_pickups")
	$Interactables.add_child(pickup)


func _build_firing_range(g) -> void:
	var station := Node3D.new()
	station.name = "FiringRange"
	station.add_to_group("weapon_range_station")
	station.set_meta("station_id", "firing")
	$Stations.add_child(station)
	g.sign("FIRING RANGE // FUTURE BALLISTICS TESTING", Vector3(11.8, 3.4, 45.7), Vector3(0, 180, 0), LABEL_COLOR, 0.004)
	g.box("FiringLine", Vector3(11.8, 0.018, FIRING_LINE_Z), Vector3(23.5, 0.025, 0.18), Color("efc94c"), false)
	g.sign("FIRING LINE", Vector3(11.8, 0.035, FIRING_LINE_Z + 0.35), Vector3(-90, 0, 0), Color("f1d568"), 0.0028)

	var distances: Array[float] = [5.0, 15.0, 30.0, 60.0]
	var lane_x: Array[float] = [2.4, 8.6, 14.8, 21.0]
	for index in range(distances.size()):
		var x := lane_x[index]
		var target_z := FIRING_LINE_Z - distances[index]
		_add_shooting_station(g, index + 1, x)
		_add_target_stand(g, index + 1, Vector3(x, 0, target_z), distances[index])
		g.box("LaneCenter%02d" % index, Vector3(x, 0.012, -3.0), Vector3(0.055, 0.015, 63.0), Color("9b8f58"), false)
	# Thick layered backstop is unmistakable and prevents passage behind targets.
	g.box("BackstopConcrete", Vector3(11.8, 2.25, -39.3), Vector3(24.0, 4.5, 2.4), Color("171c1f"))
	g.box("BackstopRubber", Vector3(11.8, 2.1, -37.95), Vector3(23.6, 4.2, 0.32), Color("282d2f"))
	g.sign("SAFE BACKSTOP // NO ACCESS", Vector3(11.8, 3.65, -37.75), Vector3.ZERO, Color("e17362"), 0.0036)


func _add_shooting_station(g, lane_number: int, x: float) -> void:
	g.box("LaneShelf%02d" % lane_number, Vector3(x, 1.0, 30.4), Vector3(4.8, 0.13, 0.7), STEEL_COLOR)
	for side in [-1.0, 1.0]:
		g.box("LaneDivider%02d" % lane_number, Vector3(x + side * 2.35, 1.35, 30.2), Vector3(0.12, 2.7, 2.2), STRUCTURE_COLOR)
		g.box("LaneSupport%02d" % lane_number, Vector3(x + side * 1.8, 0.48, 30.4), Vector3(0.12, 0.96, 0.58), STRUCTURE_COLOR)
	g.sign("LANE %02d" % lane_number, Vector3(x, 2.9, 30.1), Vector3.ZERO, Color("b8d3d4"), 0.003)


func _add_target_stand(g, lane_number: int, center: Vector3, distance_m: float) -> void:
	var marker := Marker3D.new()
	marker.name = "Target%02d_%dm" % [lane_number, int(distance_m)]
	marker.position = center
	marker.add_to_group("weapon_range_targets")
	marker.set_meta("distance_m", distance_m)
	marker.set_meta("firing_line_z", FIRING_LINE_Z)
	$Stations.add_child(marker)
	g.box("TargetBase%02d" % lane_number, center + Vector3(0, 0.08, 0), Vector3(1.5, 0.16, 0.8), STRUCTURE_COLOR)
	for side in [-1.0, 1.0]:
		g.box("TargetPost%02d" % lane_number, center + Vector3(side * 0.48, 1.15, 0), Vector3(0.09, 2.2, 0.09), STEEL_COLOR)
	g.box("TargetBoard%02d" % lane_number, center + Vector3(0, 1.65, 0), Vector3(1.35, 1.55, 0.09), Color("d8d2bd"), false)
	g.box("TargetCenter%02d" % lane_number, center + Vector3(0, 1.65, 0.052), Vector3(0.32, 0.32, 0.025), Color("9b4747"), false)
	g.sign("%d m" % int(distance_m), center + Vector3(0, 2.72, 0.02), Vector3.ZERO, LABEL_COLOR, 0.0032)


func _build_damage_area(g) -> void:
	var station := Node3D.new()
	station.name = "DamageTestArea"
	station.add_to_group("weapon_range_station")
	station.set_meta("station_id", "damage")
	$Stations.add_child(station)
	g.sign("DAMAGE TEST AREA // BODY HEALTH PROBE", Vector3(-12.8, 3.35, 23.9), Vector3.ZERO, LABEL_COLOR, 0.0035)
	var dummy_data := [
		["UNARMORED", ArmorTypes.Type.NONE, -20.0],
		["STANDARD VEST", ArmorTypes.Type.STANDARD_VEST, -12.8],
		["ADVANCED VEST", ArmorTypes.Type.ADVANCED_VEST, -5.6],
	]
	for entry in dummy_data:
		_add_damage_dummy(String(entry[0]), int(entry[1]), Vector3(float(entry[2]), 0, 11.5))


func _add_damage_dummy(label_text: String, vest_type: ArmorTypes.Type, center: Vector3) -> void:
	var dummy := DAMAGE_DUMMY_SCENE.instantiate() as DamageableHumanDummy
	dummy.name = label_text.to_pascal_case().validate_node_name()
	dummy.target_label = label_text
	dummy.armor_type = vest_type
	dummy.position = center
	$Stations.add_child(dummy)


func _build_stealth_area(g) -> void:
	var station := Node3D.new()
	station.name = "StealthTestArea"
	station.add_to_group("weapon_range_station")
	station.set_meta("station_id", "stealth")
	$Stations.add_child(station)
	g.sign("STEALTH TEST AREA // PLACEHOLDERS ONLY", Vector3(-12.8, 3.35, 2.95), Vector3.ZERO, LABEL_COLOR, 0.0036)
	var placements := [
		["UNAWARE INMATE", Vector3(-19.5, 0, -6.5), 35.0, Color("777b75")],
		["UNAWARE GUARD", Vector3(-11.8, 0, -6.5), -30.0, Color("3f4a50")],
		["GUARD FACING PLAYER", Vector3(-5.0, 0, -6.5), 180.0, Color("3f4a50")],
		["GUARD FACING AWAY", Vector3(-18.0, 0, -23.0), 0.0, Color("3f4a50")],
		["WITNESS NPC", Vector3(-7.0, 0, -23.0), 70.0, Color("6d6963")],
	]
	for entry in placements:
		_add_placeholder_person(String(entry[0]), entry[1] as Vector3, float(entry[2]), entry[3] as Color)


func _add_placeholder_person(label_text: String, center: Vector3, yaw: float, color: Color) -> void:
	var placeholder := Node3D.new()
	placeholder.name = label_text.to_pascal_case().validate_node_name()
	placeholder.position = center
	placeholder.rotation_degrees.y = yaw
	placeholder.add_to_group("weapon_range_stealth_placeholders")
	placeholder.set_meta("placeholder_role", label_text)
	$Stations.add_child(placeholder)
	var pg = Factory.new(placeholder)
	pg.box("FootBase", Vector3(0, 0.06, 0), Vector3(1.0, 0.12, 0.8), STRUCTURE_COLOR)
	pg.box("Legs", Vector3(0, 0.7, 0), Vector3(0.62, 1.3, 0.38), color.darkened(0.12), false)
	pg.box("Torso", Vector3(0, 1.65, 0), Vector3(0.92, 0.9, 0.46), color, false)
	pg.cylinder("Head", Vector3(0, 2.38, 0), 0.29, 0.5, Color("8d8478"), false)
	# A short nose/heading bar makes facing tests unambiguous before models exist.
	pg.box("FacingMarker", Vector3(0, 2.18, -0.38), Vector3(0.12, 0.12, 0.55), SAFETY_COLOR, false)
	pg.sign(label_text, Vector3(0, 3.05, 0), Vector3(0, -yaw, 0), Color("cbd7d8"), 0.0024)


func _build_control_wall(g) -> void:
	var station := Node3D.new()
	station.name = "TestControls"
	station.add_to_group("weapon_range_station")
	station.set_meta("station_id", "controls")
	$Stations.add_child(station)
	g.box("ControlConsoleBody", Vector3(11.2, 1.35, 46.62), Vector3(15.8, 2.45, 0.38), Color("11191d"), false)
	g.sign("DEV TEST CONTROLS", Vector3(11.2, 2.82, 46.38), Vector3(0, 180, 0), LABEL_COLOR, 0.0033)
	var controls := [
		["RESET TARGETS", "[E] AVAILABLE"],
		["REFILL AMMO", "[E] AVAILABLE"],
		["CLEAR LOADOUT", "AVAILABLE IN F8"],
		["GIVE ALL TEST ITEMS", "AVAILABLE IN F8"],
		["RESET SUSPICION", "AVAILABLE IN F8"],
		["RESET PLAYER HEALTH", "AVAILABLE IN F8"],
	]
	for index in range(controls.size()):
		var column := index % 3
		var row := index / 3
		var x := 5.3 + float(column) * 5.9
		var y := 2.08 - float(row) * 0.92
		var available := String(controls[index][1]) != "UNAVAILABLE"
		g.box("DisabledControl%02d" % index, Vector3(x - 1.9, y, 46.36), Vector3(0.22, 0.22, 0.07), Color("4c8a65") if available else DISABLED_COLOR, false)
		g.sign("%s\n%s" % [controls[index][0], controls[index][1]], Vector3(x, y, 46.33), Vector3(0, 180, 0), Color("bad0d2") if available else Color("a78c8c"), 0.00185)
	var reset_control := RESET_CONTROL_SCENE.instantiate() as DevRangeResetControl
	reset_control.name = "ResetTargetsControl"
	reset_control.position = Vector3(5.3, 2.08, 46.25)
	$Interactables.add_child(reset_control)
	var firearm_control := FIREARM_CONTROL_SCENE.instantiate() as DevRangeFirearmControl
	firearm_control.name = "RefillPistolAmmoControl"
	firearm_control.position = Vector3(11.2, 2.08, 46.25)
	$Interactables.add_child(firearm_control)


func _build_lighting(g) -> void:
	var fixture_positions := [
		Vector3(-13, 4.76, 35), Vector3(-13, 4.76, 15), Vector3(-13, 4.76, -14), Vector3(-13, 4.76, -33),
		Vector3(11.5, 4.76, 35), Vector3(11.5, 4.76, 12), Vector3(11.5, 4.76, -12), Vector3(11.5, 4.76, -33),
	]
	for index in range(fixture_positions.size()):
		var position: Vector3 = fixture_positions[index]
		g.emissive_box("CeilingFixture%02d" % index, position, Vector3(3.2, 0.12, 0.42), Color("dce8df"), 0.8)
		if index % 2 == 0:
			var light := OmniLight3D.new()
			light.name = "RangeLight%02d" % index
			light.position = position + Vector3.DOWN * 0.25
			light.light_color = Color("dce8df")
			light.light_energy = 1.05
			light.omni_range = 18.0
			light.omni_attenuation = 1.8
			light.shadow_enabled = false
			$Lighting.add_child(light)


func _build_return_terminal() -> void:
	var terminal := RETURN_TERMINAL_SCENE.instantiate() as DevReturnTerminal
	terminal.name = "ReturnToDevHub"
	terminal.position = Vector3(22.8, 0.95, 46.68)
	terminal.rotation_degrees.y = 180.0
	$Interactables.add_child(terminal)


func _register_point(id: StringName, label: String, marker: Marker3D) -> void:
	DevModeManager.register_teleport_point(id, label, "Weapons Test Range", marker)
