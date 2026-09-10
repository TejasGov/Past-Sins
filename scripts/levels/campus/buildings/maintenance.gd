extends CampusShellBuilder
class_name Maintenance

func _build_shell() -> void:
	building_title = "MAINTENANCE & UTILITIES"
	var w := 35.2
	var h := 5.5
	var d := 33.2

	create_shell_with_openings(w, h, d, [
		{"name": "MainMaintenanceEntrance", "side": "north", "offset": 0.0, "width": 3.0, "height": 3.0, "label": "FACILITY MAINTENANCE & UTILITIES"},
		{"name": "ServiceYardDoor", "side": "south", "offset": 0.0, "width": 3.8, "height": 3.4, "label": "SERVICE YARD & WASTE MANAGEMENT"},
	], 0.45)

	# External HVAC / Transformer Equipment Enclosure
	_create_box_col("TransformerEnclosure", Vector3(w * 0.5 + 2.0, 1.25, 0), Vector3(3.5, 2.5, 8.0), SECURITY_DARK)

	create_migration_anchor("WorkshopAnchor", Vector3(-8.0, 0, 0))
	create_migration_anchor("LaundryAnchor", Vector3(8.0, 0, -6.0))
	create_migration_anchor("B1TunnelAnchor", Vector3(0, 0, 8.0))
