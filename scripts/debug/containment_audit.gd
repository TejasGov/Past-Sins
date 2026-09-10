extends Node

## Optional editor/development check for the procedural prison shell. It runs
## once, never processes per-frame, and is disabled by default for exports.
@export var enabled := false

const STRUCTURAL_TOKENS := [
	"Wall",
	"Divider",
	"Partition",
	"CellFront",
	"CellHeader",
	"Gate",
	"Jamb",
	"Header",
]
const NON_STRUCTURAL_NAMES := [
	"WallGrime", "MonitorWall", "WallMonitor", "ObservationWindow",
	"ShowerDivider", "CellKeyBoardDivider",
]


func _ready() -> void:
	if enabled and OS.is_debug_build():
		call_deferred("run_audit")


func run_audit() -> PackedStringArray:
	var issues := PackedStringArray()
	var floors := get_node_or_null("../Floors")
	if floors == null:
		issues.append("ContainmentAudit: Floors root was not found")
		return issues

	for floor_root in floors.get_children():
		if floor_root is not Node3D:
			continue
		var collision_root := floor_root.get_node_or_null("Collision") as StaticBody3D
		if collision_root == null:
			issues.append("%s: missing structural Collision body" % floor_root.name)
			continue
		var collision_shapes: Array[CollisionShape3D] = []
		for child in collision_root.get_children():
			if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
				collision_shapes.append(child as CollisionShape3D)
		for child in floor_root.get_children():
			if child is not MeshInstance3D:
				continue
			var visual := child as MeshInstance3D
			if visual.mesh is not BoxMesh or not _is_structural_visual(visual.name):
				continue
			if not _has_matching_collision(visual, collision_shapes):
				issues.append("%s/%s: visible structural box has no matching collision" % [floor_root.name, visual.name])

	var interactables := get_node_or_null("../Interactables")
	if interactables:
		for item in interactables.get_children():
			if item is NormalDoor and (item as NormalDoor).door_width > 2.1:
				issues.append("%s: normal doorway is wider than the audit limit" % item.name)
			elif item is PrisonSlidingGate and (item as PrisonSlidingGate).gate_width > 2.4 and item.name != "YardSecurityGate":
				issues.append("%s: security opening is wider than the audit limit" % item.name)

	if issues.is_empty():
		print("CONTAINMENT_AUDIT: PASS — structural visuals match collision")
	else:
		for issue in issues:
			push_warning(issue)
	return issues


func _is_structural_visual(piece_name: String) -> bool:
	for excluded in NON_STRUCTURAL_NAMES:
		if piece_name.contains(excluded):
			return false
	for token in STRUCTURAL_TOKENS:
		if piece_name.contains(token):
			return true
	return false


func _has_matching_collision(visual: MeshInstance3D, shapes: Array[CollisionShape3D]) -> bool:
	var visual_box := visual.mesh as BoxMesh
	for shape_node in shapes:
		var collision_box := shape_node.shape as BoxShape3D
		if not visual_box.size.is_equal_approx(collision_box.size):
			continue
		if not visual.transform.origin.is_equal_approx(shape_node.transform.origin):
			continue
		if _basis_matches(visual.transform.basis, shape_node.transform.basis):
			return true
	return false


func _basis_matches(a: Basis, b: Basis) -> bool:
	return a.x.is_equal_approx(b.x) and a.y.is_equal_approx(b.y) and a.z.is_equal_approx(b.z)
