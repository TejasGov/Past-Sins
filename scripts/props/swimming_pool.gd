extends Node3D
class_name SwimmingPool

## Recessed basin, not a collision plane over the water. Hosts must excavate
## terrain beneath its footprint. Local Y=0 is deck, surface is 12 cm below it.
const Factory := preload("res://scripts/levels/greybox_factory.gd")
@export var pool_size := Vector2(20, 10)
@export var depth := 2.4
@export var surface_y := -0.12
@export_flags_3d_render var visual_layer_mask := 1

func _ready() -> void:
	add_to_group("swimming_water")
	var g = Factory.new(self, visual_layer_mask)
	var half := pool_size * 0.5
	var tile := Color("bccdca")
	g.box("BasinFloor", Vector3(0, -depth - 0.12, 0), Vector3(pool_size.x + 0.4, 0.24, pool_size.y + 0.4), tile)
	for sign_value in [-1.0, 1.0]:
		g.box("BasinLongWall", Vector3(0, -depth * 0.5, sign_value * (half.y + 0.1)), Vector3(pool_size.x + 0.4, depth, 0.2), tile)
		g.box("BasinEndWall", Vector3(sign_value * (half.x + 0.1), -depth * 0.5, 0), Vector3(0.2, depth, pool_size.y), tile)
		g.box("LongCoping", Vector3(0, 0.025, sign_value * (half.y + 0.16)), Vector3(pool_size.x + 0.6, 0.05, 0.32), Color("e0dcca"))
		for end in [-1.0, 1.0]:
			g.box("EndCoping", Vector3(sign_value * (half.x + 0.16), 0.025, end * (half.y + 1.3) * 0.5), Vector3(0.32, 0.05, half.y - 1.3), Color("e0dcca"))
		_build_steps(g, sign_value)
	for z in [-pool_size.y * 0.3, 0.0, pool_size.y * 0.3]:
		g.box("UnderwaterLane", Vector3(0, -depth + 0.006, z), Vector3(pool_size.x - 0.2, 0.008, 0.07), Color("28565d"), false)
	# One transparent surface, no refraction, reflections or extra rendering camera.
	var water := MeshInstance3D.new()
	water.name = "WaterSurface"
	var plane := PlaneMesh.new()
	plane.size = pool_size
	water.mesh = plane
	water.position.y = surface_y
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/pool_water.gdshader")
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	var sign_root := Node3D.new()
	sign_root.position = Vector3(0, 0, -half.y - 1.05)
	add_child(sign_root)
	var board = Factory.new(sign_root, visual_layer_mask)
	for x in [-1.35, 1.35]:
		board.box("SignPost", Vector3(x, 1.15, 0), Vector3(0.08, 2.3, 0.08), Color("63776c"))
	board.box("PoolRulesBoard", Vector3(0, 1.9, 0), Vector3(3, 0.85, 0.08), Color("42665f"), false)
	board.sign("COMMUNITY POOL — 2.4 m\nWASD SWIM   SPACE RISE   C DIVE\nSTEPS AT BOTH ENDS — NO DIVING", Vector3(0, 1.9, 0.05), Vector3.ZERO, Color("edf2df"), 0.0027)
	board.sign("COMMUNITY POOL\nOPEN DECK / STEPS AT BOTH ENDS", Vector3(0, 1.9, -0.05), Vector3(0, 180, 0), Color("edf2df"), 0.0027)

func contains_horizontal(world_point: Vector3) -> bool:
	var p := to_local(world_point)
	return absf(p.x) < pool_size.x * 0.5 and absf(p.z) < pool_size.y * 0.5

func surface_height() -> float:
	return global_position.y + surface_y

func _build_steps(g, side: float) -> void:
	# Solid supported steps with smooth, exact ramp collision; 20 cm risers.
	var run := minf(6.0, pool_size.x * 0.30)
	var root := Node3D.new()
	root.name = "WestExitSteps" if side < 0 else "EastExitSteps"
	root.position = Vector3(side * (pool_size.x * 0.5 - run), -depth, 0)
	root.rotation.y = side * PI * 0.5
	add_child(root)
	var steps = Factory.new(root, visual_layer_mask)
	var count := ceili(depth / 0.2)
	var incline_run := run - 0.6
	for index in range(count):
		var h := depth * float(index + 1) / float(count)
		steps.box("SupportedStep", Vector3(0, h * 0.5 - 0.02, (index + 0.5) * incline_run / count), Vector3(2.4, h - 0.04, incline_run / count + 0.01), Color("aabfb9"), false)
	# Reach finished deck level BEFORE the capsule touches the basin lip.
	steps.box("LevelExitLanding", Vector3(0, depth * 0.5, run - 0.3), Vector3(2.4, depth, 0.6), Color("aabfb9"), false)
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for x in [-1.2, 1.2]:
		points.append(Vector3(x, -0.1, 0))
		points.append(Vector3(x, 0, 0))
		points.append(Vector3(x, depth, incline_run))
		points.append(Vector3(x, depth, run + 0.1))
		points.append(Vector3(x, -0.1, run + 0.1))
	shape.points = points
	collider.shape = shape
	body.add_child(collider)
	root.add_child(body)
	for sign_value in [-1.0, 1.0]:
		var x: float = sign_value * 1.12
		for end in [0.0, 1.0]:
			steps.cylinder("HandrailPost", Vector3(x, depth * end + 0.45, run * end), 0.035, 0.9, Color("a4bab4"), false)
		steps.bar_between("PoolHandrail", Vector3(x, 0.9, 0), Vector3(x, depth + 0.9, run), Color("a4bab4"), 0.055)
