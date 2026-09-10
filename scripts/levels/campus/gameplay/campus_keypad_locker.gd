extends KeypadLocker

const Factory := preload("res://scripts/levels/greybox_factory.gd")

func _ready() -> void:
	super._ready()
	# The old generic prop's opaque box is replaced per instance with a hollow
	# supported cabinet, preserving all original interaction nodes and IDs.
	$Interior.mesh = null
	var g = Factory.new(self)
	var steel := Color("646e67")
	for x in [-0.565, 0.565]:
		g.box("CabinetSide", Vector3(x, 0, 0), Vector3(0.07, 2.2, 0.75), steel)
	for y in [-1.065, 1.065]:
		g.box("CabinetPanel", Vector3(0, y, 0), Vector3(1.2, 0.07, 0.75), steel)
	g.box("CabinetBack", Vector3(0, 0, 0.34), Vector3(1.06, 2.06, 0.07), steel)
	g.box("CabinetShelf", Vector3(0, -0.18, -0.015), Vector3(1.06, 0.08, 0.65), steel)
	g.box("MaintenanceCard", Vector3(0, -0.12, -0.06), Vector3(0.32, 0.04, 0.2), Color("b69b49"), false)
	access_card.position = Vector3(0, 0.32, 0.285)
	access_card.rotation.y = PI
	access_card.pixel_size = 0.003

func interact(_player: Node) -> void:
	if is_open:
		return
	if not MemoryManager.knows_clue(correct_code):
		_flash_keypad(Color(0.9, 0.12, 0.08))
		return
	is_open = true
	_flash_keypad(Color(0.15, 1.0, 0.45))
	blocker.set_deferred("disabled", true)
	access_card.visible = true
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Positive rotation opens this -Z facing leaf outward into its clear landing.
	tween.tween_property($DoorPivot, "rotation:y", deg_to_rad(105.0), 0.75)
