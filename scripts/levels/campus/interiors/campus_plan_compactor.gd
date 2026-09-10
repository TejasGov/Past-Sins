extends RefCounted
class_name CampusPlanCompactor

## Removes only deliberately oversized circulation strips. Endpoints outside a
## strip translate together, so furnished rooms retain their authored size and
## adjacency while corridors become more believable. Door widths never shrink.
const STRIPS := {
	"food-ground": {"z": [[14.0, 18.0, 3.2]]},
	"medical-ground": {"x": [[17.0, 21.0, 3.2]], "z": [[14.0, 18.0, 3.2]]},
	"cellhouse-b-0": {"x": [[16.0, 20.0, 3.2]], "z": [[20.0, 26.0, 4.8]]},
	"cellhouse-b-1": {"x": [[16.0, 20.0, 3.2]], "z": [[20.0, 26.0, 4.8]]},
	"hq-0": {"x": [[16.0, 20.0, 3.2]], "z": [[14.0, 18.0, 3.2]]},
	"hq-1": {"x": [[16.0, 20.0, 3.2]], "z": [[14.0, 18.0, 3.2]]},
	"maintenance-ground": {"x": [[16.0, 20.0, 3.2]], "z": [[14.0, 18.0, 3.2]]},
	"maintenance-b1": {"x": [[16.0, 20.0, 3.2]], "z": [[14.0, 18.0, 3.2]]},
	"nidra-b2": {"x": [[16.0, 20.0, 3.2]], "z": [[14.0, 18.0, 3.2]]},
	"admin-ground": {"x": [[18.0, 22.0, 3.2]]},
}

static func compact(source: Dictionary) -> Dictionary:
	var result: Dictionary = source.duplicate(true)
	var strips: Dictionary = STRIPS.get(String(result.id), {})
	if strips.is_empty(): return result
	for room in result.rooms:
		var old_x := float(room.x)
		var old_z := float(room.y)
		room.x = _map(old_x, strips.get("x", []))
		room.y = _map(old_z, strips.get("z", []))
		room.w = _map(old_x + float(room.w), strips.get("x", [])) - float(room.x)
		room.d = _map(old_z + float(room.d), strips.get("z", [])) - float(room.y)
	for door in result.doors:
		door.x = _map(float(door.x), strips.get("x", []))
		door.y = _map(float(door.y), strips.get("z", []))
	result.width = _map(float(result.width), strips.get("x", []))
	result.depth = _map(float(result.depth), strips.get("z", []))
	result["compacted"] = true
	return result

static func compact_size(plan_id: String, size: Vector2) -> Vector2:
	var strips: Dictionary = STRIPS.get(plan_id, {})
	return Vector2(_map(size.x, strips.get("x", [])), _map(size.y, strips.get("z", [])))

static func _map(value: float, strips: Array) -> float:
	var result := value
	for strip in strips:
		var start := float(strip[0])
		var finish := float(strip[1])
		var target := float(strip[2])
		var removed := finish - start - target
		if value >= finish:
			result -= removed
		elif value > start:
			result -= (value - start) * removed / (finish - start)
	return result
