extends Node3D

## Curated environmental dressing, deliberately separate from level generation.
## Coordinates are grouped by room so additions remain reviewable and never use
## random scattering. Each PackedScene is also independently placeable.

const TRASH_BIN := preload("res://scenes/props/common/TrashBin.tscn")
const WALL_TRASH_BIN := preload("res://scenes/props/common/WallTrashBin.tscn")
const BENCH := preload("res://scenes/props/common/Bench.tscn")
const LOCKER := preload("res://scenes/props/common/Locker.tscn")
const FILING_CABINET := preload("res://scenes/props/common/FilingCabinet.tscn")
const STORAGE_RACK := preload("res://scenes/props/common/StorageRack.tscn")
const STORAGE_CRATE := preload("res://scenes/props/common/StorageCrate.tscn")
const UTILITY_CART := preload("res://scenes/props/common/UtilityCart.tscn")
const WALL_CLOCK := preload("res://scenes/props/common/WallClock.tscn")
const NOTICE_BOARD := preload("res://scenes/props/common/NoticeBoard.tscn")
const FIRE_CABINET := preload("res://scenes/props/common/FireExtinguisherCabinet.tscn")
const WEIGHT_BENCH := preload("res://scenes/props/gym/WeightBench.tscn")
const EXAM_TABLE := preload("res://scenes/props/medical/ExamTable.tscn")
const SECURITY_CONSOLE := preload("res://scenes/props/security/SecurityConsole.tscn")
const LAB_WORKBENCH := preload("res://scenes/props/laboratory/LabWorkbench.tscn")
const CAFETERIA_TABLE := preload("res://scenes/props/cafeteria/CafeteriaTableSet.tscn")
const SERVING_STALL := preload("res://scenes/props/cafeteria/ServingStall.tscn")
const FOOD_TRAY := preload("res://scenes/props/cafeteria/FoodTray.tscn")
const TRAY_RETURN := preload("res://scenes/props/cafeteria/TrayReturn.tscn")
const WATER_DISPENSER := preload("res://scenes/props/cafeteria/WaterDispenser.tscn")
const QUEUE_RAILING := preload("res://scenes/props/cafeteria/QueueRailing.tscn")
const CONDIMENT_STATION := preload("res://scenes/props/cafeteria/CondimentStation.tscn")
const DRINKING_FOUNTAIN := preload("res://scenes/props/cafeteria/DrinkingFountain.tscn")
const CLEANING_CART := preload("res://scenes/props/cafeteria/CleaningCart.tscn")
const PREP_COUNTER := preload("res://scenes/props/kitchen/PrepCounter.tscn")
const COOKING_RANGE := preload("res://scenes/props/kitchen/CookingRange.tscn")
const INDUSTRIAL_OVEN := preload("res://scenes/props/kitchen/IndustrialOven.tscn")
const INDUSTRIAL_SINK := preload("res://scenes/props/kitchen/IndustrialSink.tscn")
const REFRIGERATOR := preload("res://scenes/props/kitchen/Refrigerator.tscn")
const FREEZER := preload("res://scenes/props/kitchen/Freezer.tscn")
const DISHWASHING_STATION := preload("res://scenes/props/kitchen/DishwashingStation.tscn")
const EXTRACTOR_HOOD := preload("res://scenes/props/kitchen/ExtractorHood.tscn")
const COOKING_VESSEL := preload("res://scenes/props/kitchen/CookingVessel.tscn")
const TOOL_RACK := preload("res://scenes/props/kitchen/ToolRack.tscn")
const FOOD_SACK_STACK := preload("res://scenes/props/kitchen/FoodSackStack.tscn")
const METAL_SHELVING := preload("res://scenes/props/common/MetalShelving.tscn")
const FLAT_BENCH_PRESS := preload("res://scenes/props/gym/FlatBenchPress.tscn")
const SQUAT_RACK := preload("res://scenes/props/gym/SquatRack.tscn")
const BARBELL := preload("res://scenes/props/gym/Barbell.tscn")
const WEIGHT_PLATES := preload("res://scenes/props/gym/WeightPlateStack.tscn")
const DUMBBELL_RACK := preload("res://scenes/props/gym/DumbbellRack.tscn")
const PULL_UP_BAR := preload("res://scenes/props/gym/PullUpBar.tscn")
const EXERCISE_MAT := preload("res://scenes/props/gym/ExerciseMat.tscn")
const EXERCISE_BIKE := preload("res://scenes/props/gym/ExerciseBike.tscn")
const CABLE_MACHINE := preload("res://scenes/props/gym/CableMachine.tscn")
const PUNCHING_BAG := preload("res://scenes/props/gym/PunchingBag.tscn")
const SHOWER_FLOOR := preload("res://scenes/props/prison/ShowerFloor.tscn")
const SHOWER_FIXTURE := preload("res://scenes/props/prison/ShowerFixture.tscn")
const SHOWER_HALF_WALL := preload("res://scenes/props/prison/ShowerHalfWall.tscn")
const FLOOR_DRAIN := preload("res://scenes/props/prison/FloorDrain.tscn")
const TOWEL_HOOKS := preload("res://scenes/props/prison/TowelHooks.tscn")
const WASH_BASIN := preload("res://scenes/props/prison/WashBasin.tscn")
const MIRROR := preload("res://scenes/props/prison/Mirror.tscn")
const TOILET := preload("res://scenes/props/prison/Toilet.tscn")
const URINAL := preload("res://scenes/props/prison/Urinal.tscn")
const URINAL_DIVIDER := preload("res://scenes/props/prison/UrinalDivider.tscn")
const HOSPITAL_BED := preload("res://scenes/props/medical/HospitalBed.tscn")
const BEDSIDE_TABLE := preload("res://scenes/props/medical/BedsideTable.tscn")
const MEDICAL_CART := preload("res://scenes/props/medical/MedicalCart.tscn")
const IV_STAND := preload("res://scenes/props/medical/IVStand.tscn")
const PRIVACY_DIVIDER := preload("res://scenes/props/medical/PrivacyDivider.tscn")
const MEDICINE_CABINET := preload("res://scenes/props/medical/MedicineCabinet.tscn")
const MEDICAL_SINK := preload("res://scenes/props/medical/MedicalSink.tscn")
const DOCTOR_DESK := preload("res://scenes/props/medical/DoctorDesk.tscn")
const MEDICAL_STOOL := preload("res://scenes/props/medical/MedicalStool.tscn")
const EQUIPMENT_TABLE := preload("res://scenes/props/medical/EquipmentTable.tscn")
const MEDICAL_DISPLAY := preload("res://scenes/props/medical/MedicalDisplay.tscn")
const DIAGNOSTIC_MACHINE := preload("res://scenes/props/medical/DiagnosticMachine.tscn")
const WHEELCHAIR := preload("res://scenes/props/medical/Wheelchair.tscn")
const BIOHAZARD_BIN := preload("res://scenes/props/medical/BiohazardBin.tscn")
const SECURE_MEDICINE_STORAGE := preload("res://scenes/props/medical/SecureMedicineStorage.tscn")
const SMALL_WALL_SAFE := preload("res://scenes/props/security/SmallWallSafe.tscn")
const MEDIUM_SAFE := preload("res://scenes/props/security/MediumOfficeSafe.tscn")
const LARGE_SAFE := preload("res://scenes/props/security/LargeEvidenceSafe.tscn")
const LAB_SINK := preload("res://scenes/props/laboratory/LabSink.tscn")
const CHEMICAL_CABINET := preload("res://scenes/props/laboratory/ChemicalCabinet.tscn")
const MICROSCOPE := preload("res://scenes/props/laboratory/Microscope.tscn")
const CENTRIFUGE := preload("res://scenes/props/laboratory/Centrifuge.tscn")
const SAMPLE_RACK := preload("res://scenes/props/laboratory/SampleRack.tscn")
const LAB_GLASSWARE := preload("res://scenes/props/laboratory/LabGlassware.tscn")
const COMPUTER_TERMINAL := preload("res://scenes/props/laboratory/ComputerTerminal.tscn")
const LAB_REFRIGERATOR := preload("res://scenes/props/laboratory/LabRefrigerator.tscn")
const HAZMAT_CABINET := preload("res://scenes/props/laboratory/HazmatCabinet.tscn")
const EMERGENCY_SHOWER := preload("res://scenes/props/laboratory/EmergencyShower.tscn")
const NIDRA_TERMINAL := preload("res://scenes/props/laboratory/NidraTerminal.tscn")
const LAB_SIGN := preload("res://scenes/props/laboratory/LabSign.tscn")
const SUBJECT_STORAGE := preload("res://scenes/props/laboratory/SubjectStorage.tscn")
const RESTRAINT_CHAIR := preload("res://scenes/props/laboratory/RestraintChair.tscn")
const METAL_EXAM_TABLE := preload("res://scenes/props/laboratory/MetalExamTable.tscn")
const RECORDING_CAMERA := preload("res://scenes/props/security/RecordingCamera.tscn")
const EXAMINATION_LIGHT := preload("res://scenes/props/laboratory/ExaminationLight.tscn")
const CONTROL_PANEL := preload("res://scenes/props/laboratory/ControlPanel.tscn")
const MONITORING_EQUIPMENT := preload("res://scenes/props/laboratory/MonitoringEquipment.tscn")
const EQUIPMENT_TROLLEY := preload("res://scenes/props/laboratory/EquipmentTrolley.tscn")


func _ready() -> void:
	_build_b2_dressing()
	_build_b1_dressing()
	_build_ground_dressing()
	_build_floor_1_dressing()
	_build_cell_block_dressing(4.0, 32, "Floor2")
	_build_cell_block_dressing(8.0, 64, "Floor3")
	_build_floor_4_dressing()


func _place(scene: PackedScene, node_name: String, position: Vector3, yaw_degrees: float, visual_layer: int, zone: String, label := "") -> Node3D:
	var prop := scene.instantiate() as Node3D
	prop.name = node_name
	prop.position = position
	prop.rotation_degrees.y = yaw_degrees
	prop.set("visual_layer_mask", visual_layer)
	if not label.is_empty():
		prop.set("display_label", label)
	prop.set_meta("placement_zone", zone)
	add_child(prop)
	return prop


func _build_b2_dressing() -> void:
	_place(LAB_WORKBENCH, "B2LabWorkbench", Vector3(-13.4, -12, -15.4), 0, 2, "B2 Laboratory")
	_place(UTILITY_CART, "B2LabUtilityCart", Vector3(-5.5, -12, -14.5), 90, 2, "B2 Laboratory")
	_place(STORAGE_RACK, "B2ChemicalRack", Vector3(-15.6, -12, 15.5), 90, 2, "B2 Chemical Storage")
	_place(STORAGE_CRATE, "B2ChemicalCrate", Vector3(-13.7, -12, 17.2), 0, 2, "B2 Chemical Storage")
	_place(FILING_CABINET, "B2ObservationFiles", Vector3(15.7, -12, -13.5), -90, 2, "B2 Observation")
	_place(TRASH_BIN, "B2InterrogationBin", Vector3(15.6, -12, 15.5), 0, 2, "B2 Interrogation")
	_place(NOTICE_BOARD, "B2LabNoticeBoard", Vector3(-16.8, -12, -7.5), 90, 2, "B2 Laboratory")
	_place(LAB_SINK, "B2LabSink", Vector3(-16.55, -12, -17.6), 90, 2, "B2 Laboratory")
	_place(LAB_REFRIGERATOR, "B2SampleRefrigerator", Vector3(-15.8, -12, -3.0), 90, 2, "B2 Laboratory")
	_place(EMERGENCY_SHOWER, "B2EmergencyShower", Vector3(-2.55, -12, -16.0), -90, 2, "B2 Laboratory")
	for index in range(3):
		_place(MEDICAL_STOOL, "B2LabStool%02d" % index, Vector3(-12.0 + index * 1.6, -12, -8.5), 0, 2, "B2 Laboratory")
	_place(MICROSCOPE, "B2Microscope", Vector3(-11.5, -10.73, -10.0), 0, 2, "B2 Laboratory")
	_place(CENTRIFUGE, "B2Centrifuge", Vector3(-9.8, -10.73, -10.0), 0, 2, "B2 Laboratory")
	_place(SAMPLE_RACK, "B2SampleRack", Vector3(-10.8, -10.73, -5.5), 0, 2, "B2 Laboratory")
	_place(LAB_GLASSWARE, "B2Glassware", Vector3(-9.3, -10.73, -5.5), 0, 2, "B2 Laboratory")
	_place(COMPUTER_TERMINAL, "B2LabComputer", Vector3(-11.9, -10.73, -5.5), 0, 2, "B2 Laboratory")
	_place(NIDRA_TERMINAL, "B2NidraTerminal", Vector3(-5.0, -12, -7.0), -90, 2, "B2 Laboratory")
	_place(EQUIPMENT_TABLE, "B2InstrumentTable", Vector3(-5.0, -12, -11.5), 90, 2, "B2 Laboratory")
	_place(SUBJECT_STORAGE, "B2SubjectStorageA", Vector3(-12.5, -12, -19.4), 0, 2, "B2 Laboratory")
	_place(SUBJECT_STORAGE, "B2SubjectStorageB", Vector3(-10.8, -12, -19.4), 0, 2, "B2 Laboratory")
	_place(LAB_SIGN, "B2NeuralResponseSign", Vector3(-16.8, -12, -12.0), 90, 2, "B2 Laboratory", "NEURAL RESPONSE")
	_place(LAB_SIGN, "B2AuthorizedSign", Vector3(-2.38, -12, -15.0), -90, 2, "B2 Laboratory", "AUTHORIZED PERSONNEL")
	_place(HAZMAT_CABINET, "B2HazmatCabinet", Vector3(-15.8, -12, 3.5), 90, 2, "B2 Chemical Storage")
	_place(CHEMICAL_CABINET, "B2ChemicalCabinet", Vector3(-15.8, -12, 6.0), 90, 2, "B2 Chemical Storage")
	_place(LARGE_SAFE, "B2LargeEvidenceSafe", Vector3(-5.2, -12, 17.5), -90, 2, "B2 Chemical Storage")
	_place(MEDIUM_SAFE, "B2ObservationSafe", Vector3(14.2, -12, -19.8), 0, 2, "B2 Observation")
	_place(COMPUTER_TERMINAL, "B2ObservationTerminal", Vector3(9.0, -10.73, -10.0), 0, 2, "B2 Observation")
	_place(MONITORING_EQUIPMENT, "B2ObservationMonitorRack", Vector3(14.8, -12, -8.0), -90, 2, "B2 Observation")
	_place(RESTRAINT_CHAIR, "B2RestraintChair", Vector3(10.0, -12, 9.0), 180, 2, "B2 Interrogation")
	_place(METAL_EXAM_TABLE, "B2MetalExamTable", Vector3(10.0, -12, 6.5), 0, 2, "B2 Interrogation")
	_place(EQUIPMENT_TROLLEY, "B2InterrogationTrolley", Vector3(6.0, -12, 6.5), 90, 2, "B2 Interrogation")
	_place(RECORDING_CAMERA, "B2RecordingCamera", Vector3(16.78, -12, 6.0), -90, 2, "B2 Interrogation")
	_place(EXAMINATION_LIGHT, "B2ExaminationLight", Vector3(8.3, -12, 6.5), 0, 2, "B2 Interrogation")
	_place(FLOOR_DRAIN, "B2InterrogationDrain", Vector3(10.0, -12, 10.5), 0, 2, "B2 Interrogation")
	_place(CONTROL_PANEL, "B2InterrogationControl", Vector3(16.68, -12, 10.0), -90, 2, "B2 Interrogation")
	_place(MONITORING_EQUIPMENT, "B2InterrogationMonitor", Vector3(14.8, -12, 13.0), -90, 2, "B2 Interrogation")
	_place(CHEMICAL_CABINET, "B2InterrogationStorage", Vector3(15.8, -12, 17.0), -90, 2, "B2 Interrogation")


func _build_b1_dressing() -> void:
	_place(MEDICAL_CART, "B1MedicalCart", Vector3(-5.0, -8, -15.5), 0, 4, "B1 Medical")
	_place(WALL_TRASH_BIN, "B1MedicalWallBin", Vector3(-16.8, -8, -5.0), 90, 4, "B1 Medical")
	_place(STORAGE_CRATE, "B1DryStorageCrateA", Vector3(8.2, -8, 4.0), 0, 4, "B1 Storage")
	_place(STORAGE_CRATE, "B1DryStorageCrateB", Vector3(10.0, -8, 4.0), 0, 4, "B1 Storage")
	_place(FIRE_CABINET, "B1KitchenFireCabinet", Vector3(16.8, -8, -8.0), -90, 4, "B1 Kitchen")
	_place(NOTICE_BOARD, "B1ServiceNoticeBoard", Vector3(-16.8, -8, 17.8), 90, 4, "B1 Maintenance")
	_place(SECURE_MEDICINE_STORAGE, "B1SecureMedicineStorage", Vector3(-14.3, -8, -0.5), 0, 4, "B1 Medical Secure Storage")
	for index in range(3):
		var bed_z := -16.0 + index * 5.0
		_place(HOSPITAL_BED, "B1HospitalBed%02d" % index, Vector3(-15.0, -8, bed_z), 0, 4, "B1 Medical")
		_place(BEDSIDE_TABLE, "B1BedsideTable%02d" % index, Vector3(-13.8, -8, bed_z), 0, 4, "B1 Medical")
		_place(IV_STAND, "B1IVStand%02d" % index, Vector3(-13.0, -8, bed_z - 0.5), 0, 4, "B1 Medical")
		_place(EXAM_TABLE, "B1ExamTable%02d" % index, Vector3(-10.3, -8, [-14.5, -9.5, -4.5][index]), 0, 4, "B1 Medical")
		_place(PRIVACY_DIVIDER, "B1PrivacyDivider%02d" % index, Vector3(-11.8, -8, [-12.1, -7.1, -2.8][index]), 90, 4, "B1 Medical")
		_place(MEDICAL_STOOL, "B1MedicalStool%02d" % index, Vector3(-9.0, -8, [-14.5, -9.5, -4.5][index]), 0, 4, "B1 Medical")
	_place(MEDICINE_CABINET, "B1MedicineCabinetA", Vector3(-15.2, -8, 1.15), 180, 4, "B1 Medical Secure Storage")
	_place(MEDICINE_CABINET, "B1MedicineCabinetB", Vector3(-13.4, -8, 1.15), 180, 4, "B1 Medical Secure Storage")
	# Mount the safe above the cabinet line so each fixture remains readable and
	# its collision does not overlap the medicine cabinets below it.
	_place(SMALL_WALL_SAFE, "B1MedicineWallSafe", Vector3(-14.3, -6.8, 1.12), 180, 4, "B1 Medical Secure Storage")
	_place(MEDICAL_SINK, "B1MedicalSink", Vector3(-2.68, -8, -18.0), -90, 4, "B1 Medical")
	_place(DOCTOR_DESK, "B1DoctorDesk", Vector3(-6.2, -8, -18.0), 180, 4, "B1 Medical")
	_place(EQUIPMENT_TABLE, "B1EquipmentTable", Vector3(-6.0, -8, -8.0), 90, 4, "B1 Medical")
	_place(DIAGNOSTIC_MACHINE, "B1DiagnosticMachine", Vector3(-5.0, -8, -12.5), -90, 4, "B1 Medical")
	_place(WHEELCHAIR, "B1Wheelchair", Vector3(-5.0, -8, -4.0), -90, 4, "B1 Medical")
	_place(BIOHAZARD_BIN, "B1BiohazardBin", Vector3(-8.8, -8, -4.5), 0, 4, "B1 Medical")
	_place(MEDICAL_DISPLAY, "B1MedicalDisplayA", Vector3(-2.68, -8, -14.0), -90, 4, "B1 Medical")
	_place(MEDICAL_DISPLAY, "B1MedicalDisplayB", Vector3(-16.8, -8, -11.0), 90, 4, "B1 Medical")
	_place(METAL_SHELVING, "B1MedicalStorageShelf", Vector3(-5.0, -8, -2.5), 0, 4, "B1 Medical")
	for index in range(3):
		_place(PREP_COUNTER, "B1KitchenPrepCounter%02d" % index, Vector3(9.0, -8, [-15.0, -11.0, -7.0][index]), 0, 4, "B1 Kitchen")
	_place(COOKING_RANGE, "B1CookingRange", Vector3(15.7, -8, -16.0), -90, 4, "B1 Kitchen")
	_place(EXTRACTOR_HOOD, "B1ExtractorHood", Vector3(16.6, -8, -16.0), -90, 4, "B1 Kitchen")
	_place(INDUSTRIAL_OVEN, "B1IndustrialOven", Vector3(15.7, -8, -13.0), -90, 4, "B1 Kitchen")
	_place(REFRIGERATOR, "B1Refrigerator", Vector3(15.7, -8, -9.0), -90, 4, "B1 Kitchen", "REFRIGERATOR")
	_place(FREEZER, "B1Freezer", Vector3(15.7, -8, -6.5), -90, 4, "B1 Kitchen", "FREEZER")
	_place(INDUSTRIAL_SINK, "B1IndustrialSink", Vector3(3.0, -8, -16.0), 90, 4, "B1 Kitchen")
	_place(DISHWASHING_STATION, "B1DishwashingStation", Vector3(3.0, -8, -19.0), 90, 4, "B1 Kitchen")
	_place(TOOL_RACK, "B1KitchenToolRack", Vector3(10.5, -8, -20.8), 0, 4, "B1 Kitchen")
	_place(TRASH_BIN, "B1KitchenRubbishBin", Vector3(14.5, -8, -3.0), 0, 4, "B1 Kitchen")
	_place(UTILITY_CART, "B1KitchenUtilityCart", Vector3(4.5, -8, -5.0), 0, 4, "B1 Kitchen")
	_place(FOOD_SACK_STACK, "B1FoodSackStack", Vector3(10.0, -8, 10.0), 0, 4, "B1 Food Storage")
	_place(COOKING_VESSEL, "B1StockPotA", Vector3(15.25, -6.94, -16.45), 0, 4, "B1 Kitchen")
	_place(COOKING_VESSEL, "B1StockPotB", Vector3(15.25, -6.94, -15.55), 0, 4, "B1 Kitchen")
	_place(FOOD_TRAY, "B1PrepTray", Vector3(9.0, -6.98, -15.0), 0, 4, "B1 Kitchen")


func _build_ground_dressing() -> void:
	var table_index := 0
	for x in [-11.0, -6.0, -1.0]:
		for z in [-7.0, -1.0, 5.0, 10.0]:
			_place(CAFETERIA_TABLE, "CafeteriaTableSet%02d" % table_index, Vector3(x, -4, z), 0, 8, "Ground Cafeteria")
			table_index += 1
	_place(SERVING_STALL, "ServingStall1", Vector3(7.35, -4, -10.0), -90, 8, "Ground Serving Area", "SERVING 1")
	_place(SERVING_STALL, "ServingStall2", Vector3(7.35, -4, -5.3), -90, 8, "Ground Serving Area", "SERVING 2")
	_place(SERVING_STALL, "ServingStallDietary", Vector3(7.35, -4, 1.0), -90, 8, "Ground Serving Area", "DIETARY / MEDICAL")
	for index in range(3):
		_place(QUEUE_RAILING, "ServingQueueRail%02d" % index, Vector3(3.6, -4, -8.0 + index * 5.0), 90, 8, "Ground Serving Queue")
	_place(TRAY_RETURN, "CafeteriaTrayReturn", Vector3(5.8, -4, 6.3), -90, 8, "Ground Cafeteria", "TRAY RETURN")
	_place(WATER_DISPENSER, "CafeteriaWaterDispenser", Vector3(-15.7, -4, 10.0), 90, 8, "Ground Cafeteria")
	_place(CONDIMENT_STATION, "CafeteriaCondimentStation", Vector3(3.2, -4, 8.0), 0, 8, "Ground Cafeteria")
	_place(DRINKING_FOUNTAIN, "CafeteriaDrinkingFountain", Vector3(-16.8, -4, 2.0), 90, 8, "Ground Cafeteria")
	_place(CLEANING_CART, "CafeteriaCleaningCart", Vector3(5.8, -4, 10.8), 0, 8, "Ground Cafeteria")
	_place(WALL_CLOCK, "CafeteriaWestClock", Vector3(-16.8, -4, -8.0), 90, 8, "Ground Cafeteria")
	var tray_positions := [Vector3(-11, -3.14, -7), Vector3(-6, -3.14, -1), Vector3(-1, -3.14, 5), Vector3(-11, -3.14, 10), Vector3(-6, -3.14, 5), Vector3(-1, -3.14, -7)]
	for index in range(tray_positions.size()):
		_place(FOOD_TRAY, "CafeteriaTray%02d" % index, tray_positions[index], 8.0 * index, 8, "Ground Cafeteria")
	_place(TRASH_BIN, "CafeteriaBinNorth", Vector3(-15.4, -4, -15.5), 0, 8, "Ground Cafeteria")
	_place(TRASH_BIN, "CafeteriaBinSouth", Vector3(6.5, -4, 9.8), 0, 8, "Ground Cafeteria")
	_place(BENCH, "CommonAreaBenchA", Vector3(-11.5, -4, 16.0), 0, 8, "Ground Common Area")
	_place(BENCH, "CommonAreaBenchB", Vector3(-7.5, -4, 16.0), 0, 8, "Ground Common Area")
	_place(WALL_CLOCK, "CafeteriaClock", Vector3(0, -4, -20.8), 0, 8, "Ground Cafeteria")
	_place(NOTICE_BOARD, "CommonAreaNoticeBoard", Vector3(-16.8, -4, 7.0), 90, 8, "Ground Common Area")
	_place(FIRE_CABINET, "FoodServiceFireCabinet", Vector3(7.85, -4, 3.0), -90, 8, "Ground Food Service")


func _build_floor_1_dressing() -> void:
	_place(WEIGHT_BENCH, "GymWeightBenchWest", Vector3(-4.2, 0, 0.0), 0, 16, "Floor 1 Gym")
	_place(WEIGHT_BENCH, "GymWeightBenchEast", Vector3(4.2, 0, 0.0), 0, 16, "Floor 1 Gym")
	_place(FLAT_BENCH_PRESS, "GymFlatBenchPress", Vector3(-11.5, 0, -7.0), 0, 16, "Floor 1 Gym")
	_place(SQUAT_RACK, "GymSquatRack", Vector3(-11.5, 0, -2.0), 0, 16, "Floor 1 Gym")
	_place(DUMBBELL_RACK, "GymDumbbellRack", Vector3(-11.5, 0, 3.5), 0, 16, "Floor 1 Gym")
	_place(WEIGHT_PLATES, "GymWeightPlateStack", Vector3(-14.3, 0, 4.0), 0, 16, "Floor 1 Gym")
	_place(BARBELL, "GymSpareBarbell", Vector3(-14.0, 0, 7.0), 0, 16, "Floor 1 Gym")
	_place(PULL_UP_BAR, "GymPullUpBar", Vector3(-11.5, 0, 8.5), 0, 16, "Floor 1 Gym")
	_place(EXERCISE_BIKE, "GymExerciseBike", Vector3(11.5, 0, 7.0), 0, 16, "Floor 1 Gym")
	_place(CABLE_MACHINE, "GymCableMachine", Vector3(11.5, 0, 2.5), 0, 16, "Floor 1 Gym")
	_place(PUNCHING_BAG, "GymPunchingBag", Vector3(11.5, 0, -5.5), 0, 16, "Floor 1 Gym")
	_place(EXERCISE_MAT, "GymExerciseMatWest", Vector3(-3.5, 0, 4.0), 0, 16, "Floor 1 Gym")
	_place(EXERCISE_MAT, "GymExerciseMatEast", Vector3(3.5, 0, 4.0), 0, 16, "Floor 1 Gym")
	_place(DRINKING_FOUNTAIN, "GymWaterFountain", Vector3(-16.8, 0, 0.0), 90, 16, "Floor 1 Gym")
	_place(BENCH, "GymRestBench", Vector3(-14.0, 0, 10.0), 0, 16, "Floor 1 Gym")
	_place(METAL_SHELVING, "GymTowelShelf", Vector3(15.7, 0, 8.0), -90, 16, "Floor 1 Gym")
	_place(SHOWER_FLOOR, "ShowerTileFloor", Vector3(6.5, 0, -16.5), 0, 16, "Floor 1 Showers")
	for index in range(8):
		var fixture_x := -2.5 + float(index) * 2.1
		_place(SHOWER_FIXTURE, "ShowerFixture%02d" % index, Vector3(fixture_x, 0, -20.78), 0, 16, "Floor 1 Showers")
		_place(FLOOR_DRAIN, "ShowerDrain%02d" % index, Vector3(fixture_x, 0, -18.55), 0, 16, "Floor 1 Showers")
	for index in range(7):
		_place(SHOWER_HALF_WALL, "ShowerHalfWall%02d" % index, Vector3(-1.45 + index * 2.1, 0, -19.25), 0, 16, "Floor 1 Showers")
	for index in range(2):
		var basin_z := -19.0 + index * 3.0
		_place(WASH_BASIN, "ShowerBasin%02d" % index, Vector3(-3.82, 0, basin_z), 90, 16, "Floor 1 Washroom")
		_place(MIRROR, "ShowerMirror%02d" % index, Vector3(-3.78, 0, basin_z), 90, 16, "Floor 1 Washroom")
	_place(TOWEL_HOOKS, "ShowerTowelHooks", Vector3(-3.78, 0, -13.5), 90, 16, "Floor 1 Showers")
	for index in range(8):
		var toilet_z := -20.0 + float(index)
		_place(TOILET, "ShowerToilet%02d" % index, Vector3(16.35, 0, toilet_z), -90, 16, "Floor 1 Toilets")
	for index in range(7):
		_place(SHOWER_HALF_WALL, "ToiletPrivacyWall%02d" % index, Vector3(15.25, 0, -19.5 + float(index)), 90, 16, "Floor 1 Toilets")
	var urinal_positions := [-2.5, -0.8, 0.9, 2.2, 5.3, 7.0, 8.7, 10.4]
	for index in range(urinal_positions.size()):
		_place(URINAL, "ShowerUrinal%02d" % index, Vector3(urinal_positions[index], 0, -12.22), 180, 16, "Floor 1 Urinals")
	var urinal_dividers := [-1.65, 0.05, 1.55, 6.15, 7.85, 9.55]
	for index in range(urinal_dividers.size()):
		_place(URINAL_DIVIDER, "UrinalDivider%02d" % index, Vector3(urinal_dividers[index], 0, -12.25), 180, 16, "Floor 1 Urinals")
	for index in range(3):
		_place(LOCKER, "ChangingLocker%02d" % index, Vector3(-13.0 + index * 2.1, 0, -20.55), 0, 16, "Floor 1 Changing")
	_place(LOCKER, "ChangingLocker03", Vector3(-6.7, 0, -20.55), 0, 16, "Floor 1 Changing")
	_place(TRASH_BIN, "ChangingRoomBin", Vector3(-15.6, 0, -13.3), 0, 16, "Floor 1 Changing")
	_place(WALL_CLOCK, "RecreationClock", Vector3(0, 0, 20.8), 180, 16, "Floor 1 Recreation")
	_place(FIRE_CABINET, "GymFireCabinet", Vector3(-16.8, 0, 6.0), 90, 16, "Floor 1 Gym")


func _build_cell_block_dressing(floor_y: float, visual_layer: int, prefix: String) -> void:
	_place(WALL_TRASH_BIN, "%sWestWallBin" % prefix, Vector3(-16.8, floor_y, 0), 90, visual_layer, "%s Cell Block" % prefix)
	_place(WALL_TRASH_BIN, "%sEastWallBin" % prefix, Vector3(16.8, floor_y, 0), -90, visual_layer, "%s Cell Block" % prefix)
	_place(NOTICE_BOARD, "%sNorthNoticeBoard" % prefix, Vector3(0, floor_y, -20.8), 0, visual_layer, "%s Cell Block" % prefix)
	# Kept against the perimeter, outside the dedicated guard's z=19 patrol line.
	_place(TRASH_BIN, "%sSouthWingBin" % prefix, Vector3(5.8, floor_y, 20.35), 0, visual_layer, "%s South Wing" % prefix)


func _build_floor_4_dressing() -> void:
	_place(SECURITY_CONSOLE, "Floor4StaffConsole", Vector3(-1.0, 12, 8.0), 180, 128, "Floor 4 Security Office")
	_place(FILING_CABINET, "Floor4OfficeFilesA", Vector3(-15.7, 12, 8.0), 90, 128, "Floor 4 Security Office")
	_place(FILING_CABINET, "Floor4OfficeFilesB", Vector3(-15.7, 12, 10.0), 90, 128, "Floor 4 Security Office")
	# Keep movable-looking storage clear of the roof-stair landing and approach.
	_place(STORAGE_CRATE, "Floor4EvidenceCrateA", Vector3(7.2, 12, 13.5), 0, 128, "Floor 4 Evidence")
	_place(STORAGE_CRATE, "Floor4EvidenceCrateB", Vector3(7.2, 12, 19.0), 0, 128, "Floor 4 Evidence")
	_place(WALL_CLOCK, "Floor4ControlClock", Vector3(0, 12, -20.8), 0, 128, "Floor 4 Control")
	_place(TRASH_BIN, "Floor4OfficeBin", Vector3(-6.5, 12, 18.5), 0, 128, "Floor 4 Security Office")
