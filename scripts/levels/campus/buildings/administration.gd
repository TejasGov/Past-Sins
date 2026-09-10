extends CampusShellBuilder
class_name Administration

func _build_shell() -> void:
	building_title = "ADMINISTRATION & INTAKE PROCESSING"
	var w := 39.2
	var h := 6.0
	var d := 24.0

	create_shell_with_openings(w, h, d, [
		{"name": "MainIntakeEntrance", "side": "north", "offset": 0.0, "width": 3.4, "height": 3.2, "label": "PRISON INTAKE & PROCESSING"},
		{"name": "PublicFrontEntrance", "side": "south", "offset": 0.0, "width": 3.6, "height": 3.2, "label": "VISITOR RECEPTION & ADMINISTRATION"},
	], 0.45)

	# Front Portico Canopy on South Entrance
	var canopy := _create_box_col("FrontPorticoCanopy", Vector3(0, 4.2, d * 0.5 + 2.5), Vector3(8.0, 0.4, 5.0), SECURITY_DARK)
	var col_l := _create_box_col("CanopyColumnL", Vector3(-3.6, 2.0, d * 0.5 + 4.6), Vector3(0.4, 4.0, 0.4), PAINTED_METAL)
	var col_r := _create_box_col("CanopyColumnR", Vector3(3.6, 2.0, d * 0.5 + 4.6), Vector3(0.4, 4.0, 0.4), PAINTED_METAL)

	create_migration_anchor("IntakeProcessingAnchor", Vector3(-10.0, 0, -4.0))
	create_migration_anchor("VisitationRoomAnchor", Vector3(10.0, 0, 4.0))
	create_migration_anchor("WardenOfficeAnchor", Vector3(0, 0, 4.0))
