extends Node3D

const Factory := preload("res://scripts/levels/greybox_factory.gd")


func _ready() -> void:
	var g = Factory.new(self, 256)
	var roof_color := Color("383936")
	var metal_color := Color("555853")
	var dark_color := Color("292b29")

	g.floor_with_stairwell(34, 42, roof_color)
	# Low visible parapets replace invisible roof boundaries.
	g.outer_walls(34, 42, 1.25, metal_color)

	# Ventilation and mechanical placeholders.
	for x in [-10, -5, 0, 5, 10]:
		g.box("VentilationUnit", Vector3(x, 0.75, -8), Vector3(2.4, 1.5, 4.0), dark_color)
		g.box("VentCap", Vector3(x, 1.6, -8), Vector3(2.7, 0.2, 4.3), metal_color)
	for z in [2, 8]:
		g.box("Duct", Vector3(-6, 0.55, z), Vector3(12, 1.1, 1.4), dark_color)

	# Non-emitting searchlight placeholders for future systems.
	for x in [-14, 14]:
		for z in [-18, 18]:
			g.box("SearchlightPost", Vector3(x, 1.2, z), Vector3(0.35, 2.4, 0.35), metal_color)
			g.box("SearchlightHead", Vector3(x, 2.3, z - 0.25), Vector3(1.0, 0.65, 1.3), Color("626660"), false)

	# The upper flight finishes on a real landing instead of colliding with a
	# decorative locked door at the final tread.
	g.box("RoofStairLanding", Vector3(13.5, -0.08, 19.7), Vector3(3.5, 0.16, 2.0), roof_color)
	g.railing(Vector3(12.0, 0, 12.0), Vector3(12.0, 0, 18.7), metal_color)
	g.railing(Vector3(15.0, 0, 12.0), Vector3(15.0, 0, 18.7), metal_color)
	g.railing(Vector3(12.0, 0, 12.0), Vector3(15.0, 0, 12.0), metal_color)
	g.sign("ROOF ACCESS", Vector3(13.5, 0.95, 20.65), Vector3(0, 180, 0), Color("d09b55"), 0.0045)
