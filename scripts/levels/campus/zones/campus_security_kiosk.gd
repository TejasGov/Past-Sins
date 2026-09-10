extends Node3D

## Independently placeable, supported kiosk with a real side entry and mounted
## worktop. All heights are measured from finished ground, without scale hacks.
const FACTORY := preload("res://scripts/levels/greybox_factory.gd")
const CHAIR := preload("res://scenes/props/common/Chair.tscn")
const CAMERA := preload("res://scenes/props/yard/CCTVCamera.tscn")
const DOOR := preload("res://scenes/interactables/NormalDoor.tscn")
@export_flags_3d_render var visual_layer_mask := 1


func _ready() -> void:
	add_to_group("environmental_props")
	set_meta("prop_kind", "campus_security_kiosk")
	var g = FACTORY.new(self, visual_layer_mask)
	var metal := Color("414c48")
	var white := Color("c3c7be")
	g.box("Foundation", Vector3(0, 0.04, 0), Vector3(3.6, 0.08, 3.0), Color("969a90"))
	g.box("RearWall", Vector3(0, 1.5, -1.4), Vector3(3.4, 2.9, 0.15), metal)
	g.box("WestWall", Vector3(-1.65, 1.5, 0), Vector3(0.15, 2.9, 2.8), metal)
	g.partition_with_door("EastEntry", Vector3(1.65, 0.08, 0), 2.8, false, 0.1, 1.2, metal, 2.85, 2.3, 0.15)
	g.box("FrontSill", Vector3(0, 0.62, 1.4), Vector3(3.4, 1.08, 0.15), metal)
	g.box("FrontHeader", Vector3(0, 2.73, 1.4), Vector3(3.4, 0.5, 0.15), metal)
	for x in [-1.61, 0.0, 1.61]:
		g.box("WindowMullion", Vector3(x, 1.81, 1.4), Vector3(0.11, 1.3, 0.15), metal)
	g.box("Roof", Vector3(0, 3.02, 0), Vector3(3.8, 0.16, 3.25), metal)
	# Worktop ties into the west/rear walls through visible steel supports.
	g.box("Worktop", Vector3(-0.5, 0.84, -0.97), Vector3(2.1, 0.09, 0.64), white)
	for x in [-1.35, 0.35]:
		g.box("DeskLeg", Vector3(x, 0.44, -0.76), Vector3(0.07, 0.72, 0.07), metal)
		g.box("DeskWallBracket", Vector3(x, 0.74, -1.09), Vector3(0.07, 0.08, 0.6), metal, false)
	g.box("MonitorBase", Vector3(-0.55, 0.905, -0.97), Vector3(0.36, 0.04, 0.22), metal, false)
	g.box("MonitorStand", Vector3(-0.55, 1.02, -1.04), Vector3(0.06, 0.21, 0.06), metal, false)
	g.box("MonitorBody", Vector3(-0.55, 1.2, -1.04), Vector3(0.56, 0.32, 0.06), metal, false)
	g.emissive_box("MonitorScreen", Vector3(-0.55, 1.2, -1.004), Vector3(0.5, 0.26, 0.012), Color("69847a"), 0.2)
	g.box("Keyboard", Vector3(-0.55, 0.9, -0.74), Vector3(0.44, 0.03, 0.16), metal, false)
	var chair := CHAIR.instantiate() as Node3D
	chair.name = "DutyChair"
	chair.position = Vector3(-0.55, 0.08, -0.2)
	chair.set("visual_layer_mask", visual_layer_mask)
	add_child(chair)
	var door := DOOR.instantiate() as Node3D
	door.name = "KioskDoor"
	door.position = Vector3(1.96, 0.08, 0.1)
	door.rotation_degrees.y = 90
	door.set("starts_locked", false)
	door.set("door_width", 1.16)
	door.set("open_direction", -1.0)
	door.set("open_angle_degrees", 90.0)
	door.set("door_height", 2.3)
	door.set("display_name", "Security Post")
	add_child(door)
	for z in [-0.52, 0.72]:
		g.box("DoorJambReturn", Vector3(1.765, 1.23, z), Vector3(0.23, 2.3, 0.08), metal)
	var camera := CAMERA.instantiate() as Node3D
	camera.name = "MountedCCTV"
	camera.position = Vector3(0.85, 0, 1.4)
	camera.set("visual_layer_mask", visual_layer_mask)
	add_child(camera)
	g.sign("RECREATION SECURITY", Vector3(0, 2.74, 1.49), Vector3.ZERO, Color("ede0b2"), 0.0025)
