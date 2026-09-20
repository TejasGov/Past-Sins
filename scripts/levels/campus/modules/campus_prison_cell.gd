extends Node3D
class_name CampusPrisonCell

const Factory := preload("res://scripts/levels/greybox_factory.gd")
const GATE_SCENE := preload("res://scenes/interactables/PrisonSlidingGate.tscn")
const CELL_LAMP_SCENE := preload("res://scenes/props/prison/CellLamp.tscn")
const WOOD_FURNITURE := preload("res://materials/props/wood_furniture.tres")
const CELL_MASTER_KEY_ID: StringName = &"cell_master_key"

@export var cell_access_id: StringName = &"cellhouse_a_cell"
@export var cell_display_name := "Cell"
@export var cell_number_label := "A-1-N01"
@export var front_direction := 1.0
@export var is_parth_cell := false
@export var upper_tier := false
@export_flags_3d_render var visual_layer_mask := 1

const CELL_WIDTH := 5.7
const CELL_DEPTH := 5.0
const CELL_HEIGHT := 3.55
const GATE_WIDTH := 1.35


func _ready() -> void:
	add_to_group("campus_cells")
	add_to_group("campus_upper_cells" if upper_tier else "campus_lower_cells")
	set_meta("cell_access_id", cell_access_id)
	set_meta("is_parth_cell", is_parth_cell)
	_build_cell()


func _build_cell() -> void:
	var g = Factory.new(self, visual_layer_mask)
	var wall_color := Color("444743")
	var floor_color := Color("303330")
	var front_color := Color("292d2b")
	var rear_x := -front_direction * CELL_WIDTH * 0.5
	var front_x := front_direction * CELL_WIDTH * 0.5

	# Each module is structurally complete on every side except its deliberate
	# barred-door opening. The 5m module depth matches the placement grid so
	# neighboring walls and ceilings meet without light-leaking seams.
	# A module's origin is its finished floor, shared with the gallery. This
	# removes both the doorway collision lip and furniture buried in the slab.
	g.box("CellFloor", Vector3(0, -0.06, 0), Vector3(CELL_WIDTH, 0.12, CELL_DEPTH), floor_color)
	g.box("CellCeiling", Vector3(0, CELL_HEIGHT, 0), Vector3(CELL_WIDTH, 0.14, CELL_DEPTH), wall_color)
	g.box("RearWall", Vector3(rear_x, CELL_HEIGHT * 0.5, 0), Vector3(0.2, CELL_HEIGHT, CELL_DEPTH), wall_color)
	g.box("NorthPartition", Vector3(0, CELL_HEIGHT * 0.5, -CELL_DEPTH * 0.5), Vector3(CELL_WIDTH, CELL_HEIGHT, 0.18), wall_color)
	g.box("SouthPartition", Vector3(0, CELL_HEIGHT * 0.5, CELL_DEPTH * 0.5), Vector3(CELL_WIDTH, CELL_HEIGHT, 0.18), wall_color)

	var side_length := (CELL_DEPTH - GATE_WIDTH) * 0.5
	var side_offset := GATE_WIDTH * 0.5 + side_length * 0.5
	for sign_value in [-1.0, 1.0]:
		g.box(
			"CellFrontSide",
			Vector3(front_x, 1.42, sign_value * side_offset),
			Vector3(0.18, 2.84, side_length),
			front_color
		)
	g.box("CellFrontHeader", Vector3(front_x, 3.18, 0), Vector3(0.2, 0.74, GATE_WIDTH), front_color)
	# The gate travels along the gallery face of this wall, not through its
	# concrete. Short reveal returns close the sides of the surface mount.
	for side in [-1.0, 1.0]:
		g.box("CellGateJambReturn", Vector3(front_x + front_direction * 0.085, 1.4, side * (GATE_WIDTH * 0.5 + 0.05)), Vector3(0.17, 2.8, 0.1), front_color)

	var marker := Marker3D.new()
	marker.name = "DoorMarker"
	marker.position = Vector3(front_x, 0, 0)
	marker.rotation_degrees.y = 90.0
	marker.add_to_group("campus_cell_door_markers")
	marker.set_meta("cell_access_id", cell_access_id)
	marker.set_meta("cell_display_name", cell_display_name)
	marker.set_meta("is_parth_cell", is_parth_cell)
	add_child(marker)
	_build_sliding_bar_door(marker)
	# Cell walls must occlude the lamp, including after static mesh batching.
	for piece in get_children():
		if piece is MeshInstance3D:
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	_build_wall_bed(g, rear_x)
	_build_sanitary_corner(g, rear_x)
	_build_cupboard(g)
	_build_wooden_chair(g)
	_build_personal_items(g)
	_build_cell_light()
	g.sign(cell_number_label, Vector3(front_x + front_direction * 0.12, 2.5, -1.28), Vector3(0, -90.0 * front_direction, 0), Color("d4cfad"), 0.0024)

	if is_parth_cell:
		var spawn := Marker3D.new()
		spawn.name = "ParthPlayableSpawn"
		spawn.position = Vector3(-front_direction * 0.25, 0.95, 0.55)
		spawn.rotation_degrees.y = -90.0 if front_direction > 0.0 else 90.0
		add_child(spawn)


func _build_cell_light() -> void:
	# A reachable wall fixture beside the entrance, visible from the cell floor.
	var lamp := CELL_LAMP_SCENE.instantiate() as CellLamp
	lamp.name = "CellTubeLight"
	lamp.position = Vector3(front_direction * 1.20, 2.05, -CELL_DEPTH * 0.5 + 0.09)
	lamp.local_light_enabled = true
	lamp.breakable = false
	lamp.visual_layer_mask = visual_layer_mask
	add_child(lamp)


func _build_wall_bed(g, rear_x: float) -> void:
	var frame_color := Color("292d2b")
	var bed_x := rear_x + front_direction * 0.62
	g.box("PrisonBunkFrame", Vector3(bed_x, 0.43, -1.0), Vector3(1.05, 0.12, 2.0), frame_color)
	g.box("PrisonBunkMattress", Vector3(bed_x + front_direction * 0.03, 0.57, -1.0), Vector3(0.95, 0.18, 1.88), Color("5c625e"), false)
	g.box("PrisonBunkPillow", Vector3(bed_x, 0.7, -1.72), Vector3(0.78, 0.12, 0.34), Color("777d77"), false)
	var bracket_positions := [-1.72, -0.28]
	for index in range(bracket_positions.size()):
		var z_position: float = bracket_positions[index]
		g.box("PrisonBunkWallBracket%d" % (index + 1), Vector3(rear_x + front_direction * 0.3, 0.31, z_position), Vector3(0.5, 0.12, 0.12), frame_color, false)
		g.box("PrisonBunkWallPlate%d" % (index + 1), Vector3(rear_x + front_direction * 0.12, 0.48, z_position), Vector3(0.12, 0.5, 0.18), frame_color, false)


func _build_sanitary_corner(g, rear_x: float) -> void:
	var steel := Color("929a96")
	var dark := Color("303532")
	# A chest-high privacy wall separates the toilet and basin from the bed.
	g.box("SanitaryPrivacyWall", Vector3(rear_x + front_direction * 0.88, 0.8, 0.48), Vector3(1.72, 1.6, 0.14), Color("4b4f4b"))
	var toilet_x := rear_x + front_direction * 0.55
	g.cylinder("ToiletPedestal", Vector3(toilet_x, 0.22, 1.72), 0.22, 0.44, Color("7f8783"))
	g.cylinder("ToiletBowl", Vector3(toilet_x + front_direction * 0.16, 0.48, 1.72), 0.3, 0.18, steel, false)
	g.box("ToiletTank", Vector3(toilet_x - front_direction * 0.1, 0.72, 2.08), Vector3(0.48, 0.5, 0.22), Color("7d8582"), false)
	g.cylinder("ToiletSeat", Vector3(toilet_x + front_direction * 0.16, 0.59, 1.72), 0.24, 0.05, dark, false)

	var basin_x := rear_x + front_direction * 1.42
	g.cylinder("WashBasinPedestal", Vector3(basin_x, 0.36, 1.72), 0.13, 0.72, Color("777f7b"))
	g.box("WashBasin", Vector3(basin_x, 0.78, 1.72), Vector3(0.62, 0.16, 0.48), steel, false)
	g.box("WashBasinBacksplash", Vector3(basin_x, 1.0, 1.94), Vector3(0.62, 0.42, 0.08), Color("858d89"), false)
	g.cylinder("WashBasinFaucet", Vector3(basin_x, 1.06, 1.67), 0.035, 0.26, dark, false)
	g.box("WashBasinSpout", Vector3(basin_x, 1.16, 1.58), Vector3(0.07, 0.07, 0.2), dark, false)


func _build_cupboard(g) -> void:
	var wood := Color("6b5845")
	g.box("CellCupboardBody", Vector3(0.1, 0.68, -2.16), Vector3(0.82, 1.36, 0.52), wood, true, WOOD_FURNITURE)
	g.box("CellCupboardDoorLeft", Vector3(-0.105, 0.7, -1.89), Vector3(0.38, 1.22, 0.04), wood.lightened(0.08), false, WOOD_FURNITURE)
	g.box("CellCupboardDoorRight", Vector3(0.305, 0.7, -1.89), Vector3(0.38, 1.22, 0.04), wood.lightened(0.05), false, WOOD_FURNITURE)
	g.cylinder("CellCupboardHandleLeft", Vector3(0.02, 0.7, -1.85), 0.025, 0.16, Color("2f302d"), false)
	g.cylinder("CellCupboardHandleRight", Vector3(0.18, 0.7, -1.85), 0.025, 0.16, Color("2f302d"), false)


func _build_wooden_chair(g) -> void:
	var wood := Color("765d43")
	var center := Vector3(0.25, 0, 1.45)
	g.box("WoodenChairSeat", center + Vector3.UP * 0.48, Vector3(0.58, 0.12, 0.56), wood, true, WOOD_FURNITURE)
	var leg_index := 0
	for x_offset in [-0.22, 0.22]:
		for z_offset in [-0.2, 0.2]:
			leg_index += 1
			g.cylinder("WoodenChairLeg%d" % leg_index, center + Vector3(x_offset, 0.22, z_offset), 0.035, 0.44, wood.darkened(0.16), false, Vector3.ZERO, WOOD_FURNITURE)
	for index in range(2):
		var x_offset := -0.23 if index == 0 else 0.23
		g.cylinder("WoodenChairBackPost%d" % (index + 1), center + Vector3(x_offset, 0.82, -0.23), 0.035, 0.72, wood.darkened(0.12), false, Vector3.ZERO, WOOD_FURNITURE)
	for index in range(2):
		var back_y := 0.72 if index == 0 else 0.94
		g.box("WoodenChairBackSlat%d" % (index + 1), center + Vector3(0, back_y, -0.23), Vector3(0.5, 0.09, 0.07), wood, false, WOOD_FURNITURE)


func _build_personal_items(g) -> void:
	# Stable variation from the access ID gives cells an inhabited character
	# without random placement, runtime churn or identical copy/paste clutter.
	var variant := absi(int(cell_access_id.hash())) % 6
	set_meta("personal_detail_variant", variant)
	var paper := Color("c5c0a9")
	var cloth := Color("555e61")
	var book_colors := [Color("65523d"), Color("405869"), Color("6b443c")]
	if variant in [0, 2, 5] or is_parth_cell:
		for index in range(2 + int(variant == 5)):
			g.box("PersonalBook%d" % index, Vector3(0.08 + index * 0.015, 1.405 + index * 0.055, -2.14), Vector3(0.38 - index * 0.02, 0.05, 0.24), book_colors[index % book_colors.size()], false)
	if variant in [1, 3, 5]:
		for index in range(2):
			g.box("FoldedClothing%d" % index, Vector3(-front_direction * 2.05, 0.70 + index * 0.055, -0.62), Vector3(0.42, 0.05, 0.32), cloth.lightened(index * 0.06), false)
	if variant in [0, 3, 4]:
		g.cylinder("PersonalCup", Vector3(-front_direction * 1.42, 0.95, 1.7), 0.065, 0.16, Color("9ca29c"), false)
	if variant in [2, 4] or is_parth_cell:
		for index in range(3):
			g.box("PersonalPaper%d" % index, Vector3(0.25 + index * 0.008, 0.555 + index * 0.008, 1.44), Vector3(0.36, 0.008, 0.25), paper, false)


func _build_sliding_bar_door(marker: Marker3D) -> void:
	# The reusable cell owns its door. A cell therefore cannot exist in the
	# campus without its visible/collision-backed sliding barred leaf.
	var gate := GATE_SCENE.instantiate() as PrisonSlidingGate
	gate.name = "SlidingBarDoor"
	gate.position = marker.position + Vector3(front_direction * 0.26, 0, 0)
	gate.rotation = marker.rotation
	gate.display_name = cell_display_name
	gate.required_key_id = &"" if is_parth_cell else StringName("%s_key" % cell_access_id)
	gate.master_key_id = CELL_MASTER_KEY_ID
	gate.persistent_access_id = cell_access_id
	gate.starts_locked = not is_parth_cell
	gate.gate_width = GATE_WIDTH
	gate.gate_height = 2.8
	gate.slide_distance = 1.55
	gate.open_direction = 1.0
	gate.reader_light_enabled = false
	gate.gate_color = Color("9aa49d")
	gate.add_to_group("campus_cell_doors")
	gate.set_meta("cell_access_id", cell_access_id)
	add_child(gate)
