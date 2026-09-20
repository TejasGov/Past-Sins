extends Node3D
class_name CampusGuardElevatorCore
const WOOD_FURNITURE := preload("res://materials/props/wood_furniture.tres")

const Factory := preload("res://scripts/levels/greybox_factory.gd")
const NORMAL_DOOR_SCENE := preload("res://scenes/interactables/NormalDoor.tscn")

@export_range(1, 3, 1) var floor_number := 1
@export_flags_3d_render var visual_layer_mask := 1

const WIDTH := 5.0
const DEPTH := 5.7
const HEIGHT := 3.55


func _ready() -> void:
	add_to_group("campus_guard_elevator_cores")
	set_meta("campus_floor_number", floor_number)
	# Local western room bounds, excluding the adjacent elevator bay. Consumed
	# by environment zoning and the tier's reused lighting source.
	add_to_group("environment_rooms")
	set_meta("lighting_type", "office")
	set_meta("environment_bounds", AABB(Vector3(-WIDTH * 0.5, 0, -DEPTH * 0.5), Vector3(WIDTH * 0.5 + 0.1, HEIGHT, DEPTH)))
	set_meta("lighting_anchor", Vector3(-1.2, HEIGHT - 0.32, -0.4))
	_build_core()


func _build_core() -> void:
	var g = Factory.new(self, visual_layer_mask)
	var wall_color := Color("424743")
	var security_color := Color("252a28")
	var elevator_color := Color("737b77")
	var floor_color := Color("303431")

	# This compact service core replaces one cell in the same corner on every
	# tier, so the elevator shaft and guard quarters remain vertically aligned.
	g.box("CoreFloor", Vector3(0, -0.06, 0), Vector3(WIDTH, 0.12, DEPTH), floor_color)
	g.box("CoreCeiling", Vector3(0, HEIGHT, 0), Vector3(WIDTH, 0.14, DEPTH), wall_color)
	# Underside of the ceiling is HEIGHT - 0.07. This backplate touches it;
	# the horizontal diffuser is supported directly below, never floating.
	g.box("GuardCeilingLightBackplate", Vector3(-1.2, HEIGHT - 0.10, -0.4), Vector3(1.45, 0.06, 0.24), Color("7b8179"), false)
	var profile := preload("res://scripts/systems/interior_lighting_profiles.gd").get_profile("office")
	var diffuser: MeshInstance3D = g.emissive_box("GuardCeilingLightDiffuser", Vector3(-1.2, HEIGHT - 0.145, -0.4), Vector3(1.32, 0.03, 0.17), profile.color, 0.72)
	diffuser.add_to_group("campus_indoor_light_visuals")
	diffuser.set_meta("automatic_night_light", true)
	diffuser.set_meta("always_on", profile.always_on)
	g.box("RearWall", Vector3(0, HEIGHT * 0.5, -DEPTH * 0.5), Vector3(WIDTH, HEIGHT, 0.2), wall_color)
	g.box("WestWall", Vector3(-WIDTH * 0.5, HEIGHT * 0.5, 0), Vector3(0.2, HEIGHT, DEPTH), wall_color)
	g.box("EastWall", Vector3(WIDTH * 0.5, HEIGHT * 0.5, 0), Vector3(0.2, HEIGHT, DEPTH), wall_color)
	g.box("GuardElevatorDivider", Vector3(0.1, HEIGHT * 0.5, 0), Vector3(0.18, HEIGHT, DEPTH), wall_color)

	# South/front wall contains only the deliberate guard-room door and the
	# sealed elevator opening. No side gap leads into either space.
	g.box("FrontWallLeft", Vector3(-2.18, 1.42, DEPTH * 0.5), Vector3(0.64, 2.84, 0.2), wall_color)
	g.box("FrontWallCenter", Vector3(-0.16, 1.42, DEPTH * 0.5), Vector3(1.18, 2.84, 0.2), wall_color)
	g.box("FrontWallRight", Vector3(2.22, 1.42, DEPTH * 0.5), Vector3(0.56, 2.84, 0.2), wall_color)
	g.box("GuardDoorHeader", Vector3(-1.3, 2.985, DEPTH * 0.5), Vector3(1.12, 1.13, 0.22), wall_color)
	g.box("ElevatorDoorHeader", Vector3(1.2, 3.18, DEPTH * 0.5), Vector3(1.5, 0.74, 0.22), wall_color)

	var guard_door := NORMAL_DOOR_SCENE.instantiate() as NormalDoor
	guard_door.name = "GuardQuarterDoor"
	# Hinge sits beyond the outer wall face, not inside the jamb corner.
	guard_door.position = Vector3(-1.3, 0, DEPTH * 0.5 + 0.31)
	guard_door.display_name = "Floor %d Guard Quarter" % floor_number
	guard_door.persistent_access_id = StringName("cellhouse_a_floor%d_guard_quarter" % floor_number)
	guard_door.starts_locked = false
	guard_door.open_direction = -1.0
	guard_door.open_angle_degrees = 90.0
	guard_door.door_width = 1.08
	guard_door.door_height = 2.42
	add_child(guard_door)
	for x in [-1.88, -0.72]:
		g.box("GuardDoorJambReturn", Vector3(x, 1.21, DEPTH * 0.5 + 0.115), Vector3(0.08, 2.42, 0.23), wall_color)

	# Split the eastern bay into the planned 3.2m shaft and 2.5m waiting
	# lobby. The gallery arch opens onto a real landing; the sealed doors are
	# set back at the shaft boundary rather than sealing the whole corner.
	var shaft_front_z := -DEPTH * 0.5 + 3.2
	g.box("ShaftFrontLeftPier", Vector3(0.275, HEIGHT * 0.5, shaft_front_z), Vector3(0.35, HEIGHT, 0.2), wall_color)
	g.box("ShaftFrontRightPier", Vector3(2.225, HEIGHT * 0.5, shaft_front_z), Vector3(0.55, HEIGHT, 0.2), wall_color)
	g.box("ShaftDoorHeader", Vector3(1.2, 2.985, shaft_front_z), Vector3(1.5, 1.13, 0.2), wall_color)
	# Landing doors stay closed and collision-backed until elevator movement
	# is implemented. No walkable gap opens into the unfinished shaft.
	for side in [-1.0, 1.0]:
		g.box(
			"ElevatorDoorPanelLeft" if side < 0.0 else "ElevatorDoorPanelRight",
			Vector3(1.2 + side * 0.375, 1.21, shaft_front_z),
			Vector3(0.73, 2.42, 0.16),
			elevator_color
		)
	g.box("ElevatorDoorSeam", Vector3(1.2, 1.21, shaft_front_z + 0.085), Vector3(0.035, 2.3, 0.03), security_color, false)
	g.box("ElevatorCallPanel", Vector3(2.11, 1.25, shaft_front_z + 0.13), Vector3(0.18, 0.52, 0.08), security_color, false)
	g.sign("FLOOR %d — LIFT OFFLINE" % floor_number, Vector3(1.2, 2.68, shaft_front_z + 0.12), Vector3.ZERO, Color("d2c98e"), 0.0023)
	var lobby_marker := Marker3D.new()
	lobby_marker.name = "ElevatorLobbyAnchor"
	lobby_marker.position = Vector3(1.2, 0, 1.65)
	add_child(lobby_marker)

	_build_guard_furniture(g, security_color)

	g.sign("GUARD QUARTER — FLOOR %d" % floor_number, Vector3(-1.3, 2.68, DEPTH * 0.5 + 0.03), Vector3.ZERO, Color("c5cec8"), 0.0025)
	g.sign("ELEVATOR — FUTURE SERVICE", Vector3(1.2, 2.68, DEPTH * 0.5 + 0.03), Vector3.ZERO, Color("d2c98e"), 0.0023)


func _build_guard_furniture(g, security_color: Color) -> void:
	var metal := Color("59615d")
	var screen_color := Color("4c8580")
	var paper_color := Color("c0bca7")

	# Four-legged desk with a drawer pedestal, rather than a single block.
	g.box("GuardDeskTop", Vector3(-1.3, 0.76, -1.45), Vector3(1.62, 0.12, 0.68), Color("69716c"), true, WOOD_FURNITURE)
	var desk_leg_index := 0
	for x_offset in [-0.7, 0.7]:
		for z_offset in [-0.25, 0.25]:
			desk_leg_index += 1
			g.cylinder("GuardDeskLeg%d" % desk_leg_index, Vector3(-1.3 + x_offset, 0.36, -1.45 + z_offset), 0.045, 0.72, security_color, false)
	g.box("GuardDeskModestyPanel", Vector3(-1.3, 0.43, -1.72), Vector3(1.38, 0.5, 0.08), metal, false)
	g.box("GuardDrawerPedestal", Vector3(-1.87, 0.39, -1.42), Vector3(0.38, 0.66, 0.5), metal)
	g.box("GuardDrawerPlinth", Vector3(-1.87, 0.04, -1.42), Vector3(0.36, 0.08, 0.48), security_color, false)
	var drawer_heights := [0.2, 0.42, 0.64]
	for index in range(drawer_heights.size()):
		var drawer_y: float = drawer_heights[index]
		g.box("GuardDrawerFront%d" % (index + 1), Vector3(-1.87, drawer_y, -1.15), Vector3(0.32, 0.17, 0.04), metal.lightened(0.08), false)
		g.box("GuardDrawerHandle%d" % (index + 1), Vector3(-1.87, drawer_y, -1.12), Vector3(0.13, 0.025, 0.025), security_color, false)

	# Monitor, articulated-looking base, keyboard and desk radio make the post
	# read as an occupied security workspace.
	g.box("GuardMonitorStand", Vector3(-1.15, 0.92, -1.5), Vector3(0.1, 0.28, 0.1), security_color, false)
	g.box("GuardMonitor", Vector3(-1.15, 1.18, -1.5), Vector3(0.72, 0.46, 0.1), security_color, false)
	g.box("GuardMonitorScreen", Vector3(-1.15, 1.18, -1.44), Vector3(0.62, 0.36, 0.025), screen_color, false)
	g.box("GuardKeyboard", Vector3(-1.12, 0.845, -1.2), Vector3(0.68, 0.05, 0.22), Color("343936"), false)
	g.box("GuardRadio", Vector3(-1.8, 0.91, -1.55), Vector3(0.22, 0.24, 0.18), security_color, false)
	g.cylinder("GuardRadioAntenna", Vector3(-1.86, 1.14, -1.55), 0.018, 0.34, security_color, false)

	# A recognizable four-legged office chair with separated seat and back.
	var chair_center := Vector3(-1.15, 0, -0.48)
	g.box("GuardChairSeat", chair_center + Vector3.UP * 0.5, Vector3(0.62, 0.14, 0.62), Color("3e4542"))
	var chair_leg_index := 0
	for x_offset in [-0.23, 0.23]:
		for z_offset in [-0.23, 0.23]:
			chair_leg_index += 1
			g.cylinder("GuardChairLeg%d" % chair_leg_index, chair_center + Vector3(x_offset, 0.23, z_offset), 0.035, 0.46, security_color, false)
	for index in range(2):
		var x_offset := -0.24 if index == 0 else 0.24
		g.cylinder("GuardChairBackPost%d" % (index + 1), chair_center + Vector3(x_offset, 0.84, 0.26), 0.035, 0.7, security_color, false)
	g.box("GuardChairBack", chair_center + Vector3(0, 0.96, 0.26), Vector3(0.58, 0.5, 0.1), Color("3e4542"), false)

	# Locker detailing includes a separate face, vents, handle and raised feet.
	g.box("GuardLockerBody", Vector3(-2.05, 0.92, 1.35), Vector3(0.66, 1.74, 0.56), metal)
	g.box("GuardLockerDoor", Vector3(-2.05, 0.94, 1.65), Vector3(0.58, 1.62, 0.04), metal.lightened(0.07), false)
	var vent_offsets := [-0.16, 0.0, 0.16]
	for index in range(vent_offsets.size()):
		g.box("GuardLockerVent%d" % (index + 1), Vector3(-2.05 + float(vent_offsets[index]), 1.53, 1.68), Vector3(0.09, 0.025, 0.025), security_color, false)
	g.box("GuardLockerHandle", Vector3(-1.84, 0.96, 1.7), Vector3(0.04, 0.25, 0.03), security_color, false)
	for index in range(2):
		var x_offset := -0.23 if index == 0 else 0.23
		g.box("GuardLockerFoot%d" % (index + 1), Vector3(-2.05 + x_offset, 0.045, 1.35), Vector3(0.08, 0.09, 0.42), security_color, false)

	# Small wall details finish the room without adding any new gameplay logic.
	g.box("GuardNoticeBoard", Vector3(-1.2, 1.95, -2.72), Vector3(1.35, 0.72, 0.06), Color("7a684e"), false)
	var note_offsets := [-0.38, 0.0, 0.38]
	for index in range(note_offsets.size()):
		g.box("GuardNotice%d" % (index + 1), Vector3(-1.2 + float(note_offsets[index]), 1.95, -2.68), Vector3(0.28, 0.42, 0.015), paper_color, false)
	g.cylinder("GuardWallClock", Vector3(-2.39, 2.35, 0.1), 0.24, 0.06, Color("d0d3cc"), false, Vector3(0, 0, PI * 0.5))
