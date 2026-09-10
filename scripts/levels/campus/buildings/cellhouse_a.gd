extends CampusShellBuilder
class_name CellhouseA

const INTERIOR_SCENE := preload("res://scenes/levels/campus/interiors/CellhouseAInterior.tscn")

@export var phase_two_interior_enabled := true

func _build_shell() -> void:
	building_title = "CELLHOUSE A — GENERAL POPULATION"
	var w := 44.0
	var h := 13.0
	var d := 34.0

	create_shell_with_openings(w, h, d, [
		{"name": "MainEntranceWest", "side": "west", "offset": 0.0, "width": 3.0, "height": 3.2, "label": "CELLHOUSE A — MAIN ENTRANCE"},
		{"name": "YardExitEast", "side": "east", "offset": 0.0, "width": 3.0, "height": 3.2, "label": "YARD ACCESS"},
	], 0.45)

	# Migration Anchor for future player start
	create_migration_anchor("ParthSpawnAnchor", Vector3(-8.05, 8.95, -14.1))
	create_migration_anchor("GuardStationAnchor", Vector3(10.0, 1.0, 0.0))

	if phase_two_interior_enabled:
		var interior := INTERIOR_SCENE.instantiate() as Node3D
		interior.name = "Interior"
		add_child(interior)
