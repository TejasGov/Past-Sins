extends Node3D
class_name PrisonCampusPrototype

const WATCHTOWER_SCENE := preload("res://scenes/props/security/Watchtower.tscn")
const PERIMETER_SCENE := preload("res://scenes/levels/campus/infrastructure/CampusPerimeter.tscn")
const ROADS_SCENE := preload("res://scenes/levels/campus/infrastructure/RoadsAndPaths.tscn")
const CENTRAL_YARD_SCENE := preload("res://scenes/levels/campus/infrastructure/CentralYardGrounds.tscn")
const PHASE_TWO_GAMEPLAY_SCENE := preload("res://scenes/levels/campus/gameplay/CampusPhaseTwoGameplay.tscn")
const INTERIOR_ASSEMBLY := preload("res://scenes/levels/campus/interiors/CampusInteriorAssembly.tscn")
const SESSION_CONTENT := preload("res://scenes/levels/campus/gameplay/CampusSessionContent.tscn")

const CELLHOUSE_A_SCENE := preload("res://scenes/levels/campus/buildings/CellhouseA.tscn")
const CELLHOUSE_B_SCENE := preload("res://scenes/levels/campus/buildings/CellhouseB.tscn")
const FOOD_SERVICES_SCENE := preload("res://scenes/levels/campus/buildings/FoodServices.tscn")
const MEDICAL_WELLNESS_SCENE := preload("res://scenes/levels/campus/buildings/MedicalWellness.tscn")
const SECURITY_HQ_SCENE := preload("res://scenes/levels/campus/buildings/SecurityHQ.tscn")
const MAINTENANCE_SCENE := preload("res://scenes/levels/campus/buildings/Maintenance.tscn")
const ADMINISTRATION_SCENE := preload("res://scenes/levels/campus/buildings/Administration.tscn")

@export var phase_two_enabled := true
## False retains the original isolated Cellhouse A migration validation slice.
@export var campus_interiors_enabled := true
@export var furnishings_enabled := true
@export var gameplay_enabled := true

@onready var campus_shell: Node3D = $CampusShell
@onready var buildings: Node3D = $Buildings
@onready var underground: Node3D = $Underground
@onready var actors: Node3D = $Actors
@onready var interactables: Node3D = $Interactables
@onready var patrol_routes: Node3D = $PatrolRoutes
@onready var environmental_props: Node3D = $EnvironmentalProps
@onready var navigation_root: Node3D = $Navigation


func _ready() -> void:
	_assemble_campus()
	$PreviewCamera.look_at(Vector3(0, 0, 0), Vector3.UP)


func _assemble_campus() -> void:
	# 1. Environment and Ground Base
	_create_ground_base()

	# 2. Campus Infrastructure
	_spawn_infrastructure()

	# 3. Eight Strategic Watchtowers
	_spawn_watchtowers()

	# 4. Seven Sealed Building Shells
	_spawn_buildings()
	if phase_two_enabled and campus_interiors_enabled:
		var assembly := INTERIOR_ASSEMBLY.instantiate()
		assembly.name = "CampusInteriors"
		assembly.set("furnishings_enabled", furnishings_enabled)
		add_child(assembly)
		var content := SESSION_CONTENT.instantiate()
		content.name = "CampusSessionContent"
		add_child(content)

	# 5. Underground System Anchors
	_setup_underground_anchors()

	# 6. Navigation Walkable Anchors
	_setup_navigation_anchors()

	# 7. First playable migration slice: Cellhouse A only.
	if phase_two_enabled and gameplay_enabled:
		_spawn_phase_two_gameplay()


func _create_ground_base() -> void:
	if phase_two_enabled and campus_interiors_enabled:
		_create_excavated_ground()
		return
	# Compact 156m x 188m campus; keeps a service ring without dead acreage.
	var ground_body := StaticBody3D.new()
	ground_body.name = "CampusGroundTerrain"

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "GroundVisual"
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(156, 0.4, 188)
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = preload("res://materials/props/yard_green.tres")
	ground_body.add_child(mesh_inst)

	var shape_inst := CollisionShape3D.new()
	shape_inst.name = "GroundCollision"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(156, 0.4, 188)
	shape_inst.shape = box_shape
	ground_body.add_child(shape_inst)

	ground_body.position = Vector3(0, -0.2, 0)
	campus_shell.add_child(ground_body)


func _spawn_infrastructure() -> void:
	var perimeter := PERIMETER_SCENE.instantiate()
	perimeter.name = "Perimeter"
	campus_shell.add_child(perimeter)

	var roads := ROADS_SCENE.instantiate()
	roads.name = "RoadsAndPaths"
	campus_shell.add_child(roads)

	var yard := CENTRAL_YARD_SCENE.instantiate()
	yard.name = "CentralYard"
	campus_shell.add_child(yard)


func _spawn_watchtowers() -> void:
	var watchtowers_group := Node3D.new()
	watchtowers_group.name = "Watchtowers"
	campus_shell.add_child(watchtowers_group)

	# 8 Strategic Watchtower Placements (all ladders facing safely into compound)
	var tower_configs := [
		{"name": "NorthWestPerimeterTower", "pos": Vector3(-66, 0, -80), "ladder_rot": 39.0, "light": true, "beam_rot": 39.0, "beam_pitch": 45.0},
		{"name": "NorthEastPerimeterTower", "pos": Vector3(66, 0, -80), "ladder_rot": -39.0, "light": false, "beam_rot": -39.0},
		{"name": "SouthWestPerimeterTower", "pos": Vector3(-66, 0, 80), "ladder_rot": 141.0, "light": false, "beam_rot": 141.0},
		{"name": "SouthEastPerimeterTower", "pos": Vector3(66, 0, 80), "ladder_rot": -141.0, "light": true, "beam_rot": -141.0, "beam_pitch": 45.0},
		{"name": "CentralYardNorthTower", "pos": Vector3(25, 0, -36.5), "ladder_rot": -35.0, "light": true, "beam_rot": -35.0, "beam_pitch": 32.0},
		{"name": "CentralYardSouthTower", "pos": Vector3(-25, 0, 36.5), "ladder_rot": 145.0, "light": false, "beam_rot": 145.0},
		{"name": "ServiceLoadingTower", "pos": Vector3(-66, 0, -72), "ladder_rot": 49.0, "light": false, "beam_rot": 49.0},
		{"name": "CellhouseBSecurityTower", "pos": Vector3(66, 0, -38), "ladder_rot": -66.0, "light": false, "beam_rot": -66.0}
	]

	for cfg in tower_configs:
		var tower: Node3D = WATCHTOWER_SCENE.instantiate()
		tower.name = cfg["name"]
		tower.position = cfg["pos"]
		tower.set("ladder_rotation_y", cfg["ladder_rot"])
		tower.set("light_enabled", cfg["light"])
		tower.set("searchlight_yaw_degrees", cfg["beam_rot"])
		# Steeper service-road pools stop before the neighboring shells. The
		# yard fixture reaches beyond its fence to illuminate the exercise pad.
		tower.set("searchlight_depression_degrees", cfg.get("beam_pitch", 32.0))
		watchtowers_group.add_child(tower)


func _spawn_buildings() -> void:
	var building_list := [
		{"name": "CellhouseA", "scene": CELLHOUSE_A_SCENE, "pos": Vector3(-50, 0, 0)},
		{"name": "CellhouseB", "scene": CELLHOUSE_B_SCENE, "pos": Vector3(50, 0, 0)},
		{"name": "FoodServices", "scene": FOOD_SERVICES_SCENE, "pos": Vector3(-48, 0, -51.5)},
		{"name": "MedicalWellness", "scene": MEDICAL_WELLNESS_SCENE, "pos": Vector3(-48, 0, 51.5)},
		{"name": "SecurityHQ", "scene": SECURITY_HQ_SCENE, "pos": Vector3(48, 0, -51.5)},
		{"name": "Maintenance", "scene": MAINTENANCE_SCENE, "pos": Vector3(48, 0, 51.5)},
		{"name": "Administration", "scene": ADMINISTRATION_SCENE, "pos": Vector3(0, 0, 71)}
	]

	for b in building_list:
		var inst := (b["scene"] as PackedScene).instantiate() as Node3D
		inst.name = b["name"]
		inst.position = b["pos"]
		if b["name"] == "CellhouseA":
			inst.set("phase_two_interior_enabled", phase_two_enabled)
		inst.set("campus_blueprints_enabled", phase_two_enabled and campus_interiors_enabled)
		buildings.add_child(inst)


func _create_excavated_ground() -> void:
	# Excavate the stair shafts and, when present, the reusable pool's basin.
	var regions: Array[Rect2] = [Rect2(-78, -94, 156, 188)]
	var holes: Array[Rect2] = [Rect2(40.4, 52.1, 6, 9), Rect2(40.4, -67.6, 6, 9)]
	if furnishings_enabled: holes.append(Rect2(-24, 37.5, 20, 10))
	for hole in holes:
		var next: Array[Rect2] = []
		for region in regions:
			if not region.intersects(hole):
				next.append(region)
				continue
			var overlap := region.intersection(hole)
			for part in [Rect2(region.position, Vector2(region.size.x, overlap.position.y - region.position.y)), Rect2(Vector2(region.position.x, overlap.end.y), Vector2(region.size.x, region.end.y - overlap.end.y)), Rect2(Vector2(region.position.x, overlap.position.y), Vector2(overlap.position.x - region.position.x, overlap.size.y)), Rect2(Vector2(overlap.end.x, overlap.position.y), Vector2(region.end.x - overlap.end.x, overlap.size.y))]:
				if part.size.x > 0.001 and part.size.y > 0.001: next.append(part)
		regions = next
	var root := Node3D.new()
	root.name = "CampusGroundTerrain"
	campus_shell.add_child(root)
	var factory = preload("res://scripts/levels/greybox_factory.gd").new(root)
	for region in regions:
		var center := region.get_center()
		factory.box("UnderfloorStructure", Vector3(center.x, -0.2, center.y), Vector3(region.size.x, 0.4, region.size.y), Color("757b70")).visible = false
	# The ground still supports lower stair bays, but it must not render at
	# exactly the same plane as finished room floors (coplanar flicker/triangles).
	# Remove its visual surface only where the building's own floor is visible.
	var visual_regions: Array[Rect2] = regions.duplicate()
	for finished_floor in [Rect2(-71.6, -16.6, 43.2, 33.2), Rect2(32.9, -22.0, 34.2, 44.0), Rect2(-66.5, -67.6, 37, 32.2), Rect2(-66.1, 35.4, 36.2, 32.2), Rect2(30.9, -67.6, 34.2, 32.2), Rect2(30.9, 35.4, 34.2, 32.2), Rect2(-19.1, 59.5, 38.2, 23), Rect2(-71, -55.5, 4, 8)]:
		visual_regions = _subtract_visual_rect(visual_regions, finished_floor)
	var grass_mat := preload("res://materials/props/yard_green.tres")
	for region in visual_regions:
		var center := region.get_center()
		var visual: MeshInstance3D = factory.box("ExposedGround", Vector3(center.x, -0.2, center.y), Vector3(region.size.x, 0.4, region.size.y), Color("757b70"), false)
		visual.material_override = grass_mat


func _subtract_visual_rect(regions: Array[Rect2], hole: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for region in regions:
		if not region.intersects(hole):
			result.append(region)
			continue
		var overlap := region.intersection(hole)
		for piece in [Rect2(region.position, Vector2(region.size.x, overlap.position.y - region.position.y)), Rect2(Vector2(region.position.x, overlap.end.y), Vector2(region.size.x, region.end.y - overlap.end.y)), Rect2(Vector2(region.position.x, overlap.position.y), Vector2(overlap.position.x - region.position.x, overlap.size.y)), Rect2(Vector2(overlap.end.x, overlap.position.y), Vector2(region.end.x - overlap.end.x, overlap.size.y))]:
			if piece.size.x > 0.001 and piece.size.y > 0.001: result.append(piece)
	return result


func _spawn_phase_two_gameplay() -> void:
	var gameplay := PHASE_TWO_GAMEPLAY_SCENE.instantiate()
	gameplay.name = "PhaseTwoGameplay"
	add_child(gameplay)


func _setup_underground_anchors() -> void:
	var b1_anchor := Marker3D.new()
	b1_anchor.name = "B1ServiceTunnelsAnchor"
	b1_anchor.position = Vector3(48, -4.0, 51.5)
	underground.add_child(b1_anchor)

	var b2_anchor := Marker3D.new()
	b2_anchor.name = "B2NidraFacilityAnchor"
	b2_anchor.position = Vector3(48, -8.0, -51.5)
	underground.add_child(b2_anchor)


func _setup_navigation_anchors() -> void:
	# Navigation waypoint anchors along primary walkable routes
	var route_points := [
		Vector3(-72, 0.1, 0),    # Cellhouse A west service entrance
		Vector3(-28, 0.1, 0),    # Cellhouse A east yard exit
		Vector3(-26, 0.1, 0),    # Central Yard West gate
		Vector3(0, 0.1, 0),      # Central Yard Core
		Vector3(26, 0.1, 0),     # Central Yard East gate
		Vector3(32.4, 0.1, 0),   # Cellhouse B West gate
		Vector3(0, 0.1, -31),    # North Cross Road center
		Vector3(0, 0.1, 31),     # South Cross Road center
		Vector3(-48, 0.1, -34.5),
		Vector3(48, 0.1, -34.5),
		Vector3(-48, 0.1, 34.5),
		Vector3(48, 0.1, 34.5),
		Vector3(0, 0.1, 59)
	]
	for idx in range(route_points.size()):
		var nav_marker := Marker3D.new()
		nav_marker.name = "NavAnchor_%02d" % idx
		nav_marker.position = route_points[idx]
		navigation_root.add_child(nav_marker)
