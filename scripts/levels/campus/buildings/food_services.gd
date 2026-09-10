extends CampusShellBuilder
class_name FoodServices

func _build_shell() -> void:
	building_title = "FOOD SERVICES & CATERING"
	var w := 38.0
	var h := 5.5
	var d := 33.2

	create_shell_with_openings(w, h, d, [
		{"name": "MainDiningEntrance", "side": "south", "offset": 0.0, "width": 3.2, "height": 3.0, "label": "CAFETERIA & DINING HALL"},
		{"name": "ServiceLoadingDock", "side": "west", "offset": -1.0 if campus_blueprints_enabled else 0.0, "width": 3.6, "height": 3.4, "label": "KITCHEN SERVICE & RECEIVING"},
	], 0.45)

	# Flush loading apron: visibly defines the receiving bay without creating a
	# 1.2 m collision step across the service doorway.
	_create_box_col("LoadingPlatform", Vector3(-w * 0.5 - 2.0, -0.04, 0), Vector3(4.0, 0.08, 8.0), CONCRETE_WALL)

	create_migration_anchor("KitchenPrepAnchor", Vector3(-8.0, 0, 0))
	create_migration_anchor("ColdStorageAnchor", Vector3(-12.0, 0, -8.0))
