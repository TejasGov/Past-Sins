extends Node

const PROP_SCENES := [
	"res://scenes/props/common/TrashBin.tscn",
	"res://scenes/props/common/WallTrashBin.tscn",
	"res://scenes/props/common/Bench.tscn",
	"res://scenes/props/common/Table.tscn",
	"res://scenes/props/common/Chair.tscn",
	"res://scenes/props/common/MetalShelving.tscn",
	"res://scenes/props/common/StorageRack.tscn",
	"res://scenes/props/common/StorageCrate.tscn",
	"res://scenes/props/common/UtilityCart.tscn",
	"res://scenes/props/common/Locker.tscn",
	"res://scenes/props/common/FilingCabinet.tscn",
	"res://scenes/props/common/WallClock.tscn",
	"res://scenes/props/common/NoticeBoard.tscn",
	"res://scenes/props/common/FireExtinguisherCabinet.tscn",
	"res://scenes/props/cafeteria/CafeteriaTableSet.tscn",
	"res://scenes/props/cafeteria/ServingStall.tscn",
	"res://scenes/props/cafeteria/FoodTray.tscn",
	"res://scenes/props/cafeteria/TrayReturn.tscn",
	"res://scenes/props/cafeteria/WaterDispenser.tscn",
	"res://scenes/props/cafeteria/QueueRailing.tscn",
	"res://scenes/props/cafeteria/CondimentStation.tscn",
	"res://scenes/props/cafeteria/DrinkingFountain.tscn",
	"res://scenes/props/cafeteria/CleaningCart.tscn",
	"res://scenes/props/gym/WeightBench.tscn",
	"res://scenes/props/gym/FlatBenchPress.tscn",
	"res://scenes/props/gym/SquatRack.tscn",
	"res://scenes/props/gym/Barbell.tscn",
	"res://scenes/props/gym/WeightPlateStack.tscn",
	"res://scenes/props/gym/DumbbellRack.tscn",
	"res://scenes/props/gym/PullUpBar.tscn",
	"res://scenes/props/gym/ExerciseMat.tscn",
	"res://scenes/props/gym/ExerciseBike.tscn",
	"res://scenes/props/gym/CableMachine.tscn",
	"res://scenes/props/gym/PunchingBag.tscn",
	"res://scenes/props/gym/Treadmill.tscn",
	"res://scenes/props/gym/RowingMachine.tscn",
	"res://scenes/props/gym/LegPress.tscn",
	"res://scenes/props/gym/LatPulldown.tscn",
	"res://scenes/props/gym/InclineBenchPress.tscn",
	"res://scenes/props/gym/DipStation.tscn",
	"res://scenes/props/medical/ExamTable.tscn",
	"res://scenes/props/kitchen/PrepCounter.tscn",
	"res://scenes/props/kitchen/CookingRange.tscn",
	"res://scenes/props/kitchen/IndustrialOven.tscn",
	"res://scenes/props/kitchen/IndustrialSink.tscn",
	"res://scenes/props/kitchen/Refrigerator.tscn",
	"res://scenes/props/kitchen/Freezer.tscn",
	"res://scenes/props/kitchen/DishwashingStation.tscn",
	"res://scenes/props/kitchen/ExtractorHood.tscn",
	"res://scenes/props/kitchen/CookingVessel.tscn",
	"res://scenes/props/kitchen/ToolRack.tscn",
	"res://scenes/props/kitchen/FoodSackStack.tscn",
	"res://scenes/props/security/SecurityConsole.tscn",
	"res://scenes/props/prison/PrisonBunk.tscn",
	"res://scenes/props/prison/ShowerFloor.tscn",
	"res://scenes/props/prison/ShowerFixture.tscn",
	"res://scenes/props/prison/ShowerHalfWall.tscn",
	"res://scenes/props/prison/FloorDrain.tscn",
	"res://scenes/props/prison/TowelHooks.tscn",
	"res://scenes/props/prison/WashBasin.tscn",
	"res://scenes/props/prison/Mirror.tscn",
	"res://scenes/props/prison/Toilet.tscn",
	"res://scenes/props/prison/Urinal.tscn",
	"res://scenes/props/prison/UrinalDivider.tscn",
	"res://scenes/props/laboratory/LabWorkbench.tscn",
	"res://scenes/props/workshop/WorkshopBench.tscn",
	"res://scenes/props/yard/YardBench.tscn",
	"res://scenes/props/yard/ParallelBars.tscn",
	"res://scenes/props/yard/BasketballHoop.tscn",
	"res://scenes/props/yard/Shrub.tscn",
	"res://scenes/props/yard/SmallTree.tscn",
	"res://scenes/props/yard/CCTVCamera.tscn",
	"res://scenes/props/yard/Searchlight.tscn",
	"res://scenes/props/yard/ObservationPost.tscn",
	"res://scenes/props/yard/FlowerCluster.tscn",
	"res://scenes/props/yard/OfficerGazebo.tscn",
	"res://scenes/props/yard/YardSecurityPost.tscn",
	"res://scenes/props/medical/HospitalBed.tscn",
	"res://scenes/props/medical/BedsideTable.tscn",
	"res://scenes/props/medical/MedicalCart.tscn",
	"res://scenes/props/medical/IVStand.tscn",
	"res://scenes/props/medical/PrivacyDivider.tscn",
	"res://scenes/props/medical/MedicineCabinet.tscn",
	"res://scenes/props/medical/MedicalSink.tscn",
	"res://scenes/props/medical/DoctorDesk.tscn",
	"res://scenes/props/medical/MedicalStool.tscn",
	"res://scenes/props/medical/EquipmentTable.tscn",
	"res://scenes/props/medical/MedicalDisplay.tscn",
	"res://scenes/props/medical/DiagnosticMachine.tscn",
	"res://scenes/props/medical/Wheelchair.tscn",
	"res://scenes/props/medical/BiohazardBin.tscn",
	"res://scenes/props/medical/SecureMedicineStorage.tscn",
	"res://scenes/props/security/SmallWallSafe.tscn",
	"res://scenes/props/security/MediumOfficeSafe.tscn",
	"res://scenes/props/security/LargeEvidenceSafe.tscn",
	"res://scenes/props/security/RecordingCamera.tscn",
	"res://scenes/props/laboratory/LabSink.tscn",
	"res://scenes/props/laboratory/ChemicalCabinet.tscn",
	"res://scenes/props/laboratory/Microscope.tscn",
	"res://scenes/props/laboratory/Centrifuge.tscn",
	"res://scenes/props/laboratory/SampleRack.tscn",
	"res://scenes/props/laboratory/LabGlassware.tscn",
	"res://scenes/props/laboratory/ComputerTerminal.tscn",
	"res://scenes/props/laboratory/LabRefrigerator.tscn",
	"res://scenes/props/laboratory/HazmatCabinet.tscn",
	"res://scenes/props/laboratory/EmergencyShower.tscn",
	"res://scenes/props/laboratory/NidraTerminal.tscn",
	"res://scenes/props/laboratory/LabSign.tscn",
	"res://scenes/props/laboratory/SubjectStorage.tscn",
	"res://scenes/props/laboratory/RestraintChair.tscn",
	"res://scenes/props/laboratory/MetalExamTable.tscn",
	"res://scenes/props/laboratory/ExaminationLight.tscn",
	"res://scenes/props/laboratory/ControlPanel.tscn",
	"res://scenes/props/laboratory/MonitoringEquipment.tscn",
	"res://scenes/props/laboratory/EquipmentTrolley.tscn",
]

const MATERIALS := [
	"res://materials/props/painted_metal.tres",
	"res://materials/props/stainless_steel.tres",
	"res://materials/props/concrete.tres",
	"res://materials/props/institutional_plastic.tres",
	"res://materials/props/dark_rubber.tres",
	"res://materials/props/dirty_off_white.tres",
	"res://materials/props/security_dark.tres",
	"res://materials/props/shower_tile.tres",
	"res://materials/props/yard_green.tres",
	"res://materials/props/court_surface.tres",
	"res://materials/props/medical_blue.tres",
	"res://materials/props/hazard_yellow.tres",
	"res://materials/props/nidra_cyan.tres",
	"res://materials/props/restraint_leather.tres",
	"res://materials/props/cell_bars.tres",
	"res://materials/props/gravel.tres",
	"res://materials/props/asphalt.tres",
	"res://materials/props/chainlink_fence.tres",
]

const DECORATIVE_WALL_PROPS := [
	&"wall_clock", &"notice_board", &"extractor_hood", &"tool_rack",
	&"exercise_mat", &"shower_floor", &"shower_fixture", &"floor_drain",
	&"towel_hooks", &"mirror", &"cctv_camera",
	&"medical_display", &"lab_sign", &"recording_camera",
]


func _ready() -> void:
	for material_path in MATERIALS:
		assert(ResourceLoader.exists(material_path), "Missing prop material: %s" % material_path)
		assert(load(material_path) is StandardMaterial3D, "Invalid prop material: %s" % material_path)

	for scene_path in PROP_SCENES:
		assert(ResourceLoader.exists(scene_path), "Missing prop scene: %s" % scene_path)
		var packed := load(scene_path) as PackedScene
		assert(packed != null, "Invalid prop scene: %s" % scene_path)
		var prop := packed.instantiate() as Node3D
		add_child(prop)
		await get_tree().process_frame
		assert(prop.is_in_group("environmental_props"), "%s is not catalogued" % scene_path)
		var meshes := prop.find_children("*", "MeshInstance3D", true, false)
		var shapes := prop.find_children("*", "CollisionShape3D", true, false)
		assert(meshes.size() >= 2, "%s lacks a recognizable multi-part silhouette" % scene_path)
		var kind := StringName(prop.get_meta("prop_kind", &""))
		if kind not in DECORATIVE_WALL_PROPS:
			assert(not shapes.is_empty(), "%s has no simplified collision" % scene_path)
		for mesh_node in meshes:
			var visual := mesh_node as MeshInstance3D
			assert(visual.material_override != null, "%s contains an unmaterialed part" % scene_path)
		prop.queue_free()
		await get_tree().process_frame

	var world := preload("res://scenes/levels/CellBlockPrototype.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().physics_frame
	var all_environment_props := get_tree().get_nodes_in_group("environmental_props")
	assert(all_environment_props.size() >= 288, "Expected at least 288 environmental props, found %d" % all_environment_props.size())
	var dressing_root := world.get_node("EnvironmentalDressing")
	var placed_props := all_environment_props.filter(func(prop): return prop.get_parent() == dressing_root)
	assert(placed_props.size() >= 226, "Expected at least 226 curated room placements, found %d" % placed_props.size())
	for prop in placed_props:
		assert(prop.has_meta("placement_zone"), "%s was placed without a room assignment" % prop.name)
	print("PROP_LIBRARY_VALIDATION: PASS — %d reusable scenes, 14 materials, %d curated placements / %d total props" % [PROP_SCENES.size(), placed_props.size(), all_environment_props.size()])
	get_tree().quit()
