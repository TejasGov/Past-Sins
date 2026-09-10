extends Node3D
class_name RoadsAndPaths

@export_flags_3d_render var visual_layer_mask: int = 1

const ASPHALT_ROAD := preload("res://materials/props/security_dark.tres")
const CONCRETE_PATH := preload("res://materials/props/concrete.tres")
const CURB_MAT := preload("res://materials/props/painted_metal.tres")


func _ready() -> void:
	_build_network()


func _build_network() -> void:
	# 1. Compact service ring: still wide enough for emergency/service vehicles.
	_create_road_segment("RingRoadNorth", Vector3(0, 0.01, -88), Vector3(150, 0.02, 6))
	_create_road_segment("RingRoadSouth", Vector3(0, 0.01, 88), Vector3(150, 0.02, 6))
	_create_road_segment("RingRoadWest", Vector3(-72, 0.01, 0), Vector3(6, 0.02, 176))
	_create_road_segment("RingRoadEast", Vector3(72, 0.01, 0), Vector3(6, 0.02, 176))

	# 2. Cross Roads (Width 6m)
	_create_road_segment("NorthCrossRoad", Vector3(0, 0.015, -31), Vector3(140, 0.02, 5))
	_create_road_segment("SouthCrossRoad", Vector3(0, 0.015, 31), Vector3(140, 0.02, 5))

	# 3. Central Avenues
	_create_road_segment("CentralNorthAvenue", Vector3(0, 0.018, -61), Vector3(5, 0.02, 54))
	_create_road_segment("CentralSouthAvenue", Vector3(5, 0.018, 45.5), Vector3(5, 0.02, 27))

	# 4. Pedestrian walkways now bridge short, legible building setbacks.
	# Cellhouse A is a dedicated three-floor cell building: its west service
	# entrance meets the ring road and its east gate aligns with the yard.
	_create_path_segment("PathCellhouseA_Main", Vector3(-70.5, 0.025, 0), Vector3(3.0, 0.03, 3.5))
	_create_path_segment("PathCellhouseA_Yard", Vector3(-27, 0.025, 0), Vector3(2.0, 0.03, 3.5))

	# Bridge the short clearance between the yard fence and Cellhouse B's west
	# entrance. The slight overlap prevents a visible seam at either threshold.
	_create_path_segment("PathCellhouseB_Main", Vector3(29.3, 0.025, 0), Vector3(6.6, 0.03, 3.5))

	# Path from Food Services South entrance (x = -55, z = -58) to North Cross Road (z = -46)
	_create_path_segment("PathFoodServices_Main", Vector3(-48, 0.025, -34.2), Vector3(3.5, 0.03, 1.6))

	# Path from Security HQ South entrance (x = +55, z = -58) to North Cross Road (z = -46)
	_create_path_segment("PathSecurityHQ_Main", Vector3(48, 0.025, -34.2), Vector3(3.5, 0.03, 1.6))

	# Path from Medical North entrance (x = -55, z = +58) to South Cross Road (z = +46)
	_create_path_segment("PathMedical_Main", Vector3(-48, 0.025, 34.2), Vector3(3.5, 0.03, 1.6))

	# Path from Maintenance North entrance (x = +55, z = +58) to South Cross Road (z = +46)
	_create_path_segment("PathMaintenance_Main", Vector3(48, 0.025, 34.2), Vector3(3.5, 0.03, 1.6))

	# Path from Admin North entrance (x = 0, z = +78) to South Cross Road (z = +46)
	_create_path_segment("PathAdmin_Main", Vector3(2.5, 0.025, 59), Vector3(5.0, 0.03, 3.5))

	# Yard gates connect to both cross roads; these were previously unpaved gaps.
	_create_path_segment("PathYardNorth", Vector3(0, 0.025, -27.75), Vector3(4.0, 0.03, 1.6))
	_create_path_segment("PathYardSouth", Vector3(0, 0.025, 27.75), Vector3(4.0, 0.03, 1.5))

	# Dedicated service and perimeter approaches.
	_create_path_segment("PathFoodLoading", Vector3(-67.5, 0.025, -51.5), Vector3(3.0, 0.03, 4.0))
	_create_path_segment("PathMedicalEmergency", Vector3(-67.8, 0.025, 50.5), Vector3(2.4, 0.03, 4.0))
	_create_path_segment("PathMaintenanceService", Vector3(48, 0.025, 76.5), Vector3(4.0, 0.03, 17.0))
	_create_path_segment("PathAdministrationFront", Vector3(0, 0.025, 84), Vector3(4.0, 0.03, 2.0))
	_create_path_segment("PathNorthSallyPort", Vector3(0, 0.025, -87.7), Vector3(6.0, 0.03, 5.4))


func _create_road_segment(road_name: String, center: Vector3, size: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = road_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	instance.mesh = box_mesh
	instance.material_override = ASPHALT_ROAD
	instance.position = center
	instance.layers = visual_layer_mask
	add_child(instance)
	return instance


func _create_path_segment(path_name: String, center: Vector3, size: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = path_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	instance.mesh = box_mesh
	instance.material_override = CONCRETE_PATH
	instance.position = center
	instance.layers = visual_layer_mask
	add_child(instance)
	return instance
