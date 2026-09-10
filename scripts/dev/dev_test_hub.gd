extends Node3D
class_name DevTestHub

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const Factory := preload("res://scripts/levels/greybox_factory.gd")


func _ready() -> void:
	_build_hub()
	if not DevModeManager.is_enabled():
		return
	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.name = "DevTestPlayer"
	$Actors.add_child(player)
	player.global_transform = $Spawn.global_transform
	_register_point(&"dev_hub_lobby", "Hub Lobby", "Dev Test Hub", $Spawn)
	_register_point(&"weapons_range_staging", "Weapons Range Transfer Bay", "Dev Test Hub", $WeaponsRangeSpawn)
	_register_point(&"character_gallery", "Character Gallery", "Dev Test Hub", $CharacterGallerySpawn)
	_register_point(&"ai_test_area", "AI / Suspicion Test Area", "Dev Test Hub", $AITestSpawn)
	_register_point(&"interaction_test_area", "Interaction Test Area", "Dev Test Hub", $InteractionTestSpawn)


func _build_hub() -> void:
	var g = Factory.new($Geometry)
	var floor_color := Color("495057")
	var wall_color := Color("20272c")
	g.box("HubFloor", Vector3(0, -0.1, 0), Vector3(78, 0.2, 48), floor_color)
	for wall in [
		[Vector3(0, 2.0, -24), Vector3(78, 4, 0.3)],
		[Vector3(0, 2.0, 24), Vector3(78, 4, 0.3)],
		[Vector3(-39, 2.0, 0), Vector3(0.3, 4, 48)],
		[Vector3(39, 2.0, 0), Vector3(0.3, 4, 48)],
	]:
		g.box("PerimeterWall", wall[0], wall[1], wall_color)
	# Low dividers identify future bays without pretending unfinished systems exist.
	for x in [-18.0, 8.0]:
		g.box("ZoneDivider", Vector3(x, 0.6, 7.0), Vector3(0.18, 1.2, 34), Color("606970"))
	g.box("RearDivider", Vector3(20.0, 0.6, 0.0), Vector3(22, 1.2, 0.18), Color("606970"))
	_add_zone_sign(g, "WEAPONS RANGE TRANSFER BAY\nENTER DEDICATED RANGE VIA F8", Vector3(-28, 2.2, -22.8))
	_add_zone_sign(g, "CHARACTER GALLERY\nRESERVED", Vector3(-5, 2.2, -22.8))
	_add_zone_sign(g, "AI / SUSPICION TEST AREA\nRESERVED", Vector3(27, 2.2, -22.8))
	_add_zone_sign(g, "INTERACTION TEST AREA\nRESERVED", Vector3(27, 2.2, 22.8), Vector3(0, 180, 0))
	_add_zone_sign(g, "DEV TEST HUB — OUTSIDE CAMPUS\nF8 DEVELOPER MENU", Vector3(0, 3.0, 23.75), Vector3(0, 180, 0))
	# Simple grounded lane marks; no weapon props are created in this task.
	for z in [-14.0, -7.0, 0.0, 7.0, 14.0]:
		g.box("RangeLaneMark", Vector3(-28, 0.012, z), Vector3(18, 0.015, 0.08), Color("d0b957"), false)


func _add_zone_sign(g, text: String, position: Vector3, rotation := Vector3.ZERO) -> void:
	g.sign(text, position, rotation, Color("f2cf69"), 0.004)


func _register_point(id: StringName, label: String, category: String, marker: Marker3D) -> void:
	DevModeManager.register_teleport_point(id, label, category, marker)
