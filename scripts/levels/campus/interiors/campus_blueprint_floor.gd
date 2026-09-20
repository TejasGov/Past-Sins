extends Node3D
class_name CampusBlueprintFloor

## Room geometry is assembled from one exportable floor-plan resource. Shared
## boundaries are unioned before doors are cut, so neighboring rooms cannot
## accidentally create double walls across each other's entrances.
const Factory := preload("res://scripts/levels/greybox_factory.gd")
const NORMAL_DOOR := preload("res://scenes/interactables/NormalDoor.tscn")
const SECURITY_GATE := preload("res://scenes/levels/campus/modules/CampusTelescopicGate.tscn")
const CELL_LAMP_SCENE := preload("res://scenes/props/prison/CellLamp.tscn")
const LIGHTING := preload("res://scripts/systems/interior_lighting_profiles.gd")
const FLOOR_FINISHES := {
	"gym_rubber": preload("res://materials/props/gym_rubber.tres"),
	"tile_shower": preload("res://materials/props/tile_shower.tres"),
}

@export var plan_id := "food-ground"
@export var furnishings_enabled := true
@export var story_height := 4.0
var plan: Dictionary
var rooms: Dictionary = {}
var door_records: Array[Dictionary] = []
var _g
var _geometry: Node3D
const WALL_THICKNESS := 0.22
const DOOR_HEIGHT := 2.65

func _ready() -> void:
	add_to_group("campus_blueprint_floors")
	if plan.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/campus/floor_plans.json"))
		for candidate in data.plans:
			if candidate.id == plan_id:
				plan = candidate.duplicate(true)
	assert(not plan.is_empty(), "Missing campus plan: " + plan_id)
	_geometry = Node3D.new()
	_geometry.name = "Architecture"
	add_child(_geometry)
	_g = Factory.new(_geometry)
	_prepare_rooms()
	_prepare_thresholds()
	_build_boundaries()
	_build_rooms()
	for record in door_records:
		_build_threshold(record)
	# Only immobile structural meshes are combined; access leaves, collision,
	# independent room roots and furnishing recipes remain separate.
	preload("res://scripts/levels/campus/furnishing/campus_furniture_batcher.gd").consolidate(_geometry)
	set_meta("plan_id", plan_id)

func point(x: float, z: float, y: float = 0.0) -> Vector3:
	return Vector3(x - float(plan.width) * 0.5, y, z - float(plan.depth) * 0.5)

func _prepare_rooms() -> void:
	for data in plan.rooms:
		var room := Node3D.new()
		room.name = String(data.id).to_pascal_case()
		room.position = point(float(data.x) + float(data.w) * 0.5, float(data.y) + float(data.d) * 0.5)
		room.set_meta("room_data", data)
		room.set_meta("plan_id", plan_id)
		room.add_to_group("campus_planned_rooms")
		add_child(room)
		rooms[String(data.id)] = room

func _prepare_thresholds() -> void:
	for source in plan.doors:
		var d: Dictionary = source.duplicate(true)
		var a := rooms.get(String(d.a)) as Node3D
		var b := rooms.get(String(d.b)) as Node3D
		var pos := point(float(d.x), float(d.y))
		var kind := String(d.kind)
		# A stair's own landing ring provides circulation; no arbitrary leaf
		# across normal stair approaches. Restricted lobbies retain their gates.
		if _room_type(a) == "stair" or _room_type(b) == "stair":
			if kind == "door": kind = "open"
		var target := _mount_room(a, b, d)
		var normal := Vector3.BACK if d.axis == "x" else Vector3.RIGHT
		if target != null and (target.position - pos).dot(normal) < 0:
			normal = -normal
		if b == null:
			normal = -normal # exterior equipment mounts on the outside wall face
		var width := float(d.width)
		if kind in ["gate", "glass"] and b != null and target != null:
			var r: Dictionary = target.get_meta("room_data")
			var c := float(d.x) if d.axis == "x" else float(d.y)
			var lo := float(r.x) if d.axis == "x" else float(r.y)
			var hi := lo + (float(r.w) if d.axis == "x" else float(r.d))
			# Four telescoping panels need only a quarter-width side pocket.
			width = minf(width, (minf(c - lo, hi - c) - 0.2) / 0.75)
			assert(width >= 1.1, "Insufficient gate pocket: %s/%s" % [plan_id, d.a])
		d["kind"] = kind
		d["clear_width"] = width
		d["position"] = pos
		d["mount_normal"] = normal
		d["node"] = null
		door_records.append(d)
	if plan_id == "nidra-b2":
		for x in [4.375, 12.125]:
			door_records.append({"a": "observation", "b": "interrogationa" if x < 8 else "interrogationb", "x": x, "y": 26.0, "axis": "x", "width": 3.0, "clear_width": 3.0, "kind": "window", "position": point(x, 26.0), "mount_normal": Vector3.BACK, "node": null})

func _room_type(room: Node3D) -> String:
	return String(room.get_meta("room_data").type) if room else "outside"

func _mount_room(a: Node3D, b: Node3D, d: Dictionary) -> Node3D:
	if b == null: return a
	if a == null: return b
	# Surface-mounted sliding pockets choose the wider side of a junction.
	var best := a
	var space := -1.0
	for room in [a, b]:
		var r: Dictionary = room.get_meta("room_data")
		var center := float(d.x) if d.axis == "x" else float(d.y)
		var low := float(r.x) if d.axis == "x" else float(r.y)
		var high := low + (float(r.w) if d.axis == "x" else float(r.d))
		var candidate := minf(center - low, high - center)
		if _room_type(room) == "stair": candidate = -2.0
		if candidate > space:
			space = candidate
			best = room
	return best

func _build_boundaries() -> void:
	var lines: Dictionary = {}
	for r in plan.rooms:
		for edge in [["x", float(r.y), float(r.x), float(r.x) + float(r.w)], ["x", float(r.y) + float(r.d), float(r.x), float(r.x) + float(r.w)], ["z", float(r.x), float(r.y), float(r.y) + float(r.d)], ["z", float(r.x) + float(r.w), float(r.y), float(r.y) + float(r.d)]]:
			var key := "%s:%.3f" % [edge[0], edge[1]]
			if not lines.has(key): lines[key] = {"axis": edge[0], "fixed": edge[1], "ranges": [], "cuts": []}
			lines[key].ranges.append(Vector2(edge[2], edge[3]))
			lines[key].cuts.append(edge[2])
			lines[key].cuts.append(edge[3])
	for line in lines.values():
		var openings: Array = []
		for d in door_records:
			var fixed := float(d.y) if d.axis == "x" else float(d.x)
			if d.axis != line.axis or absf(fixed - float(line.fixed)) > 0.001: continue
			var c := float(d.x) if d.axis == "x" else float(d.y)
			var w := float(d.clear_width)
			line.cuts.append(c - w * 0.5)
			line.cuts.append(c + w * 0.5)
			openings.append(Vector2(c - w * 0.5, c + w * 0.5))
		line.cuts.sort()
		for i in range(line.cuts.size() - 1):
			var start := float(line.cuts[i])
			var finish := float(line.cuts[i + 1])
			if finish - start < 0.001: continue
			var middle := (start + finish) * 0.5
			var covered := false
			for interval in line.ranges:
				if middle > interval.x - 0.001 and middle < interval.y + 0.001: covered = true
			if not covered: continue
			var opening := false
			for interval in openings:
				if middle > interval.x and middle < interval.y: opening = true
			var low := DOOR_HEIGHT if opening else 0.0
			var height := story_height - low
			var pos := point(middle, line.fixed, low + height * 0.5) if line.axis == "x" else point(line.fixed, middle, low + height * 0.5)
			var size := Vector3(finish - start, height, WALL_THICKNESS) if line.axis == "x" else Vector3(WALL_THICKNESS, height, finish - start)
			var piece: MeshInstance3D = _g.box("Header" if opening else "RoomWall", pos, size, _wall_color())
			if plan_id.begins_with("cellhouse-b"):
				piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			piece.add_to_group("campus_structural_walls")

func _wall_color() -> Color:
	if plan_id.begins_with("food"): return Color("999b85")
	if plan_id.begins_with("medical"): return Color("b6beb6")
	if plan_id.begins_with("nidra"): return Color("abb4b1")
	if plan_id.begins_with("hq"): return Color("626c66")
	return Color("858980")

func _build_rooms() -> void:
	var largest_room_area := 0.0
	var night_light_anchor := Vector3.ZERO
	var primary_room_type := "office"
	for data in plan.rooms:
		var room: Node3D = rooms[String(data.id)]
		var rtype := String(data.type)
		var lighting_type := String(data.get("lighting_type", rtype))
		var center := room.position
		var size := Vector3(float(data.w), 0.2, float(data.d))
		if rtype not in ["stair", "lift", "void"]:
			var floor_mesh: MeshInstance3D = _g.box("Floor_" + String(data.id), center + Vector3(0, -0.1, 0), size, Color("626861"))
			# Finish-only assignment; existing slabs, thresholds and collision stay intact.
			var finish_id := String(data.get("floor_finish", ""))
			if FLOOR_FINISHES.has(finish_id):
				floor_mesh.material_override = FLOOR_FINISHES[finish_id]
			var ceiling_mesh: MeshInstance3D = _g.box("Ceiling_" + String(data.id), center + Vector3(0, story_height - 0.1, 0), size, _wall_color().darkened(0.1))
			if plan_id.begins_with("cellhouse-b"):
				floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				ceiling_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			var mount_y := story_height - 0.24
			room.set_meta("lighting_anchor", Vector3(0, mount_y - 0.35, 0))
			var profile := LIGHTING.get_profile(lighting_type)
			if rtype == "cell":
				# Entrance-side wall position avoids the central tall locker and
				# remains reachable with the normal interaction ray.
				var lamp := CELL_LAMP_SCENE.instantiate() as CellLamp
				lamp.name = "CellTubeLight_" + String(data.id)
				var entrance_side := 1.0 if String(data.id).begins_with("n") else -1.0
				lamp.position = center + Vector3(entrance_side * 1.3, 2.05, -float(data.d) * 0.5 + WALL_THICKNESS * 0.5)
				lamp.local_light_enabled = true
				lamp.breakable = false
				_geometry.add_child(lamp)
			else:
				# Fixture back plate touches the slab underside, never suspended
				# at an arbitrary world height or across a stair void.
				_g.box("LightBackplate", center + Vector3(0, mount_y, 0), Vector3(minf(float(data.w) - 0.4, 1.5), 0.08, 0.24), Color("535c55"), false)
				var diffuser: MeshInstance3D = _g.emissive_box("FluorescentDiffuser", center + Vector3(0, mount_y - 0.05, 0), Vector3(minf(float(data.w) - 0.45, 1.4), 0.025, 0.19), profile.color, 0.8)
				diffuser.add_to_group("campus_indoor_light_visuals")
				diffuser.set_meta("automatic_night_light", true)
				diffuser.set_meta("always_on", profile.always_on)
			var area := float(data.w) * float(data.d)
			if area > largest_room_area:
				largest_room_area = area
				night_light_anchor = center + Vector3(0, mount_y - 0.35, 0)
				primary_room_type = lighting_type
		if furnishings_enabled and rtype not in ["stair", "lift", "void"]:
			var openings: Array = []
			for d in door_records:
				if d.a == data.id or d.b == data.id:
					openings.append({"position": d.position - center, "width": d.clear_width, "axis": d.axis, "kind": d.kind})
			var furnisher = load("res://scripts/levels/campus/furnishing/campus_room_furnisher.gd")
			furnisher.dress(room, plan_id, data, openings)
	# One unshadowed, ceiling-anchored light per storey provides legible indoor
	# night illumination; the many visible room diffusers stay batched together.
	var night_light := OmniLight3D.new()
	night_light.name = "AutomaticInteriorLight"
	night_light.position = night_light_anchor
	LIGHTING.apply_to_light(night_light, primary_room_type)
	night_light.omni_range = maxf(float(plan.width), float(plan.depth)) * 0.62
	night_light.shadow_enabled = false
	night_light.visible = false
	add_child(night_light)
	night_light.add_to_group("campus_indoor_lights")
	night_light.set_meta("automatic_night_light", true)

func _build_threshold(d: Dictionary) -> void:
	var kind := String(d.kind)
	var width := float(d.clear_width)
	var pos: Vector3 = d.position
	var normal: Vector3 = d.mount_normal
	var yaw := atan2(normal.x, normal.z)
	if kind in ["sealed", "window", "hatch"]:
		var fixture := Node3D.new()
		fixture.name = "%s_%s_%s" % [kind, d.a, d.b]
		fixture.position = pos
		fixture.rotation.y = yaw
		add_child(fixture)
		var g = Factory.new(fixture)
		if kind == "sealed":
			g.box("SealedPanel", Vector3(0, DOOR_HEIGHT * 0.5, 0), Vector3(width, DOOR_HEIGHT, 0.2), Color("78877f")).visible = false
			var detail := preload("res://scenes/props/common/InstitutionalDoorVisual.tscn").instantiate()
			detail.set("width", width)
			detail.set("height", DOOR_HEIGHT)
			detail.set("thickness", 0.2)
			detail.set("style", 1 if d.a == "lift" else 2)
			detail.set("caption", "ELEVATOR / OFFLINE" if d.a == "lift" else "FUTURE SERVICE TUNNEL / SEALED")
			detail.set("sealed", true)
			fixture.add_child(detail)
		else:
			g.box("SillWall", Vector3(0, 0.48, 0), Vector3(width, 0.96, 0.22), _wall_color())
			g.box("UpperWall", Vector3(0, 2.37, 0), Vector3(width, 0.56, 0.22), _wall_color())
			if kind == "window":
				var pane: MeshInstance3D = g.box("ObservationPane", Vector3(0, 1.52, 0), Vector3(width, 1.12, 0.08), Color("597473"))
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.25, 0.43, 0.44, 0.22)
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				pane.material_override = mat
			else:
				g.box("TrayShelf", Vector3(0, 0.98, 0), Vector3(width, 0.08, 0.75), Color("929c99"))
				# 0.48 m high service slot cannot become a jump-through shortcut.
				g.box("ServingScreen", Vector3(0, 1.79, 0), Vector3(width, 0.6, 0.12), Color("6e7772"))
		return
	if kind == "open": return
	var gate_mode: bool = kind in ["gate", "glass"] or d.b == "OUTSIDE"
	var access: StringName = _access_for(d)
	var door: Node3D
	if gate_mode:
		var gate := SECURITY_GATE.instantiate() as PrisonSlidingGate
		gate.gate_width = width
		gate.gate_height = DOOR_HEIGHT
		gate.required_key_id = access
		gate.starts_locked = not access.is_empty()
		gate.bulletproof_glass = kind == "glass"
		gate.gate_color = Color("727f75")
		gate.reader_light_enabled = false
		if _room_type(rooms.get(String(d.a))) == "cell": gate.master_key_id = &"cell_master_key"
		door = gate
	else:
		var leaf := NORMAL_DOOR.instantiate() as NormalDoor
		leaf.door_width = width
		leaf.door_height = DOOR_HEIGHT
		leaf.open_direction = -1.0
		leaf.open_angle_degrees = 90.0
		leaf.required_key_id = access
		leaf.starts_locked = not access.is_empty()
		door = leaf
	door.name = "Access_%s_%s" % [d.a, d.b]
	door.set("persistent_access_id", StringName("campus_%s_%s_%s" % [plan_id, d.a, d.b]))
	door.set("display_name", _door_label(d))
	var mount_depth := 0.77 if d.b == "OUTSIDE" else 0.31
	# Keep the sliding panel tracks in front of the reveal return, rather
	# than letting their backs cut the jamb corners while stacking sideways.
	# The full closed blocker still overlaps the return by 2 cm.
	if gate_mode: mount_depth += 0.06
	door.position = pos + normal * mount_depth
	door.rotation.y = yaw
	door.add_to_group("campus_room_access")
	if d.b == "OUTSIDE": door.add_to_group("campus_exterior_gates")
	add_child(door)
	d["node"] = door
	# Side returns close the short reveal between surface-mounted gate and
	# wall opening. No invisible side route around the closed leaf.
	var reveal_length := 0.77 if d.b == "OUTSIDE" else 0.31
	var axis := Vector3.RIGHT if d.axis == "x" else Vector3.BACK
	for side in [-1.0, 1.0]:
		var p: Vector3 = pos + axis * side * (width * 0.5 + 0.04) + normal * reveal_length * 0.5
		var sz := Vector3(0.08, DOOR_HEIGHT, reveal_length) if d.axis == "x" else Vector3(reveal_length, DOOR_HEIGHT, 0.08)
		_g.box("JambReturn", p + Vector3.UP * DOOR_HEIGHT * 0.5, sz, Color("535d55"))
	var sign_root := Node3D.new()
	sign_root.position = pos + normal * (reveal_length + 0.16)
	sign_root.rotation.y = yaw
	add_child(sign_root)
	_label(sign_root, _door_label(d), Vector3(0, 2.97, 0))

func _door_label(d: Dictionary) -> String:
	var room: Node3D = rooms.get(String(d.a))
	if room == null: return "ACCESS"
	var r: Dictionary = room.get_meta("room_data")
	return String(r.label).replace("\n", " / ").to_upper()

func _access_for(d: Dictionary) -> StringName:
	if plan_id.begins_with("cellhouse-b"):
		if _room_type(rooms.get(String(d.a))) == "cell": return StringName("cell_%s_%s" % [plan_id, d.a])
		return &"security_key"
	if plan_id.begins_with("hq"): return &"security_key"
	if plan_id.begins_with("nidra"): return &"lab_key"
	if plan_id.begins_with("maintenance"):
		return &"service_key" if d.kind in ["staff", "gate"] else &""
	if plan_id == "food-ground": return &"service_key" if d.kind == "staff" else &""
	if plan_id == "medical-ground":
		return &"medical_key" if d.kind == "staff" or d.a == "medicine" else &""
	if plan_id == "admin-ground":
		if d.a in ["public", "visitation"] and d.b not in ["OUTSIDE", "secure"]: return &""
		return &"security_key" if d.kind in ["staff", "gate"] else &""
	return &""

func _label(parent: Node3D, text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 30
	label.pixel_size = 0.003
	label.position = at
	label.no_depth_test = false
	parent.add_child(label)

func room_node(id: String) -> Node3D:
	return rooms.get(id) as Node3D
