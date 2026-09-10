extends Node3D
class_name DamageableHumanDummy

const HIT_ZONE_SCENE := preload("res://scenes/components/BodyHitZone.tscn")

@export var target_label := "UNARMORED"
@export var armor_type: ArmorTypes.Type = ArmorTypes.Type.NONE

@onready var health: HealthComponent = $HealthComponent
@onready var body: Node3D = $Body
@onready var status_label: Label3D = $StatusLabel

var _zones: Array[BodyHitZone] = []


func _ready() -> void:
	add_to_group("weapon_range_damage_dummies")
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_build_segmented_body()
	health.base_health = 100.0
	health.set_armor_type(armor_type)
	reset_target()


func apply_test_damage(amount: float, hit_zone: StringName) -> float:
	return health.apply_damage(amount, hit_zone)


func reset_target() -> void:
	health.set_armor_type(armor_type)
	body.visible = true
	for zone in _zones:
		zone.set_dead_visual(false)
	_update_status_label()


func get_total_health() -> float:
	return health.get_total_health()


func get_current_health() -> float:
	return health.current_health


func is_dead() -> bool:
	return health.is_dead()


func get_hit_zones() -> Array[BodyHitZone]:
	return _zones.duplicate()


func _build_segmented_body() -> void:
	var lower := _new_zone(BodyHitZone.Type.LOWER_BODY)
	lower.add_box_segment("Pelvis", Vector3(0, 1.15, 0), Vector3(0.82, 0.34, 0.42), Color("66757b"))
	lower.add_box_segment("LeftLeg", Vector3(-0.22, 0.58, 0), Vector3(0.28, 0.9, 0.34), Color("536168"))
	lower.add_box_segment("RightLeg", Vector3(0.22, 0.58, 0), Vector3(0.28, 0.9, 0.34), Color("536168"))

	var torso := _new_zone(BodyHitZone.Type.TORSO)
	torso.add_box_segment("Chest", Vector3(0, 1.78, 0), Vector3(0.92, 0.9, 0.48), Color("69787e"))
	torso.add_box_segment("LeftArm", Vector3(-0.61, 1.72, 0), Vector3(0.24, 0.82, 0.3), Color("5c6a70"))
	torso.add_box_segment("RightArm", Vector3(0.61, 1.72, 0), Vector3(0.24, 0.82, 0.3), Color("5c6a70"))
	if armor_type != ArmorTypes.Type.NONE:
		var vest_color := Color("34434a") if armor_type == ArmorTypes.Type.STANDARD_VEST else Color("263940")
		torso.add_box_segment("Vest", Vector3(0, 1.82, -0.27), Vector3(0.84, 0.68, 0.12), vest_color)

	var head := _new_zone(BodyHitZone.Type.HEAD)
	head.add_box_segment("Neck", Vector3(0, 2.31, 0), Vector3(0.24, 0.24, 0.25), Color("8b8479"))
	head.add_cylinder_segment("Head", Vector3(0, 2.64, 0), 0.3, 0.52, Color("979086"))
	for zone in _zones:
		zone.remember_alive_colors()


func _new_zone(type: BodyHitZone.Type) -> BodyHitZone:
	var zone := HIT_ZONE_SCENE.instantiate() as BodyHitZone
	zone.configure(type, health, self)
	body.add_child(zone)
	_zones.append(zone)
	return zone


func _on_health_changed(_current: float, _total: float) -> void:
	_update_status_label()


func _on_died(_hit_zone: StringName) -> void:
	for zone in _zones:
		zone.set_dead_visual(true)
	_update_status_label()


func _update_status_label() -> void:
	if not is_node_ready():
		return
	var total := health.get_total_health()
	if health.is_dead():
		status_label.text = "%s\nDEAD — RESET REQUIRED" % target_label
	elif is_equal_approx(health.current_health, total):
		status_label.text = "%s\n%d HP" % [target_label, int(total)]
	else:
		status_label.text = "%s\n%d / %d HP" % [target_label, int(health.current_health), int(total)]
