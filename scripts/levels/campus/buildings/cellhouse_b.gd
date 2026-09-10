extends CampusShellBuilder
class_name CellhouseB

func _build_shell() -> void:
	building_title = "CELLHOUSE B — HIGH SECURITY FACILITY"
	var w := 35.2
	var h := 9.0
	var d := 44.8

	create_shell_with_openings(w, h, d, [
		{"name": "MainEntranceWest", "side": "west", "offset": 0.0, "width": 3.0, "height": 3.2, "label": "HIGH SECURITY — AUTHORIZED ONLY"},
		{"name": "NorthSallyPort", "side": "north", "offset": 0.0, "width": 3.6, "height": 3.4, "label": "SECURE TRANSPORT SALLY PORT"},
	], 0.5, SECURITY_DARK, SECURITY_DARK)

	# Dedicated Security Fence Barrier around Cellhouse B compound
	var fence_w := w + 8.0
	var fence_d := d + 8.0
	var fence_h := 3.6
	# North fence is split around the transport port; west is split around the
	# yard-facing entrance. This keeps the sector contained without burying its
	# deliberate approaches in fence collision.
	var north_segment := (fence_w - 7.2) * 0.5
	var north_center := 3.6 + north_segment * 0.5
	_create_box_col("SecurityPerimeterFenceNorthWest", Vector3(-north_center, fence_h * 0.5, -fence_d * 0.5), Vector3(north_segment, fence_h, 0.15), PAINTED_METAL)
	_create_box_col("SecurityPerimeterFenceNorthEast", Vector3(north_center, fence_h * 0.5, -fence_d * 0.5), Vector3(north_segment, fence_h, 0.15), PAINTED_METAL)
	_create_box_col("SecurityPerimeterNorthGate", Vector3(0, fence_h * 0.5, -fence_d * 0.5), Vector3(7.2, fence_h, 0.18), SECURITY_DARK).set_meta("temporary_placeholder", true)
	_create_box_col("SecurityPerimeterFenceS", Vector3(0, fence_h * 0.5, fence_d * 0.5), Vector3(fence_w, fence_h, 0.15), PAINTED_METAL)
	_create_box_col("SecurityPerimeterFenceE", Vector3(fence_w * 0.5, fence_h * 0.5, 0), Vector3(0.15, fence_h, fence_d), PAINTED_METAL)
	var west_segment := (fence_d - 3.0) * 0.5
	var west_center := 1.5 + west_segment * 0.5
	_create_box_col("SecurityPerimeterFenceWestNorth", Vector3(-fence_w * 0.5, fence_h * 0.5, -west_center), Vector3(0.15, fence_h, west_segment), PAINTED_METAL)
	_create_box_col("SecurityPerimeterFenceWestSouth", Vector3(-fence_w * 0.5, fence_h * 0.5, west_center), Vector3(0.15, fence_h, west_segment), PAINTED_METAL)
	_create_box_col("SecurityPerimeterWestGate", Vector3(-fence_w * 0.5, fence_h * 0.5, 0), Vector3(0.18, fence_h, 3.0), SECURITY_DARK).set_meta("temporary_placeholder", true)

	create_migration_anchor("HighSecurityVaultAnchor", Vector3(0, 1.0, 0))
