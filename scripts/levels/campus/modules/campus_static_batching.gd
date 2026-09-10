extends RefCounted

## Optional runtime optimization for existing modular greybox assets. Roots,
## colliders, markers and all dynamic children remain independently addressable.
const Batcher := preload("res://scripts/levels/campus/furnishing/campus_furniture_batcher.gd")

static func direct_geometry(root: Node3D) -> void:
	var geometry := Node3D.new()
	geometry.name = "StaticVisualBatch"
	root.add_child(geometry)
	for child in root.get_children():
		if child is MeshInstance3D:
			child.reparent(geometry, false)
	Batcher.consolidate(geometry)

static func cellhouse(root: Node3D) -> void:
	for node in root.get_children():
		if node is CampusPrisonCell or node is CampusGuardElevatorCore:
			direct_geometry(node)
			var gate := node.get_node_or_null("SlidingBarDoor") as PrisonSlidingGate
			if gate:
				# A complete leaf moves as a unit; do NOT merge the gate's reader
				# status material or frame with its moving leaf.
				Batcher.consolidate(gate.visuals)
	direct_geometry(root)
