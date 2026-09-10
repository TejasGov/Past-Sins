extends CampusShellBuilder
class_name MedicalWellness

func _build_shell() -> void:
	building_title = "MEDICAL WING & RECREATION WELLNESS"
	var w := 37.2
	var h := 6.0
	var d := 33.2

	create_shell_with_openings(w, h, d, [
		{"name": "MainMedicalEntrance", "side": "north", "offset": 0.0, "width": 3.2, "height": 3.0, "label": "INFIRMARY & RECREATION WELLNESS"},
		{"name": "YardGymEntrance", "side": "east", "offset": -1.0 if campus_blueprints_enabled else 0.0, "width": 2.8, "height": 2.8, "label": "SECURE GYM & SHOWER ACCESS"},
		{"name": "AmbulanceBay", "side": "west", "offset": -1.0 if campus_blueprints_enabled else 0.0, "width": 3.6, "height": 3.4, "label": "EMERGENCY VEHICLE ACCESS"},
	], 0.45)

	create_migration_anchor("InfirmaryAnchor", Vector3(-8.0, 0, -6.0))
	create_migration_anchor("MedicineStorageAnchor", Vector3(-12.0, 0, 6.0))
	create_migration_anchor("GymAreaAnchor", Vector3(8.0, 0, 0.0))
