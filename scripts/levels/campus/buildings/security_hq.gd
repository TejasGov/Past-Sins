extends CampusShellBuilder
class_name SecurityHQ

func _build_shell() -> void:
	building_title = "SECURITY HEADQUARTERS & COMMAND"
	var w := 35.2
	var h := 8.6 if campus_blueprints_enabled else 7.0
	var d := 33.2

	create_shell_with_openings(w, h, d, [
		{"name": "MainSecurityEntrance", "side": "south", "offset": 0.0, "width": 3.0, "height": 3.2, "label": "SECURITY HQ — COMMAND & SURVEILLANCE"},
		{"name": "StaffSideEntrance", "side": "west", "offset": -1.0 if campus_blueprints_enabled else 0.0, "width": 2.4, "height": 2.8, "label": "STAFF ACCESS ONLY"},
	], 0.45, SECURITY_DARK, SECURITY_DARK)

	# Second-Floor Command Windows Accent
	var window_mat := StandardMaterial3D.new()
	window_mat.albedo_color = Color("142830")
	window_mat.metallic = 0.95
	window_mat.roughness = 0.05
	var win_strip := _create_box_col("CommandWindowStrip", Vector3(0, h * 0.75, d * 0.5 + 0.02), Vector3(w - 6.0, 1.4, 0.1), window_mat)

	create_migration_anchor("SurveillanceRoomAnchor", Vector3(0, 3.5, 0))
	create_migration_anchor("SecureEquipmentStorageAnchor", Vector3(10.0, 0, -8.0))
	create_migration_anchor("ChiefOfficeAnchor", Vector3(-10.0, 3.5, 8.0))
	create_migration_anchor("B2ElevatorAnchor", Vector3(10.0, 0, 8.0))
