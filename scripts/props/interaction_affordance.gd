extends RefCounted
## Visual language only. Painted edges identify usable objects; small LED
## materials communicate status. No outlines, new lights, interaction or physics.

const HAZARD := preload("res://materials/props/hazard_yellow.tres")
const PANEL := preload("res://materials/props/security_dark.tres")


static func paint_pickup_trim(root: Node) -> void:
	# Reuse a real supported component of the WORLD visual, never the equipped
	# viewmodel. Future models can mark a small surface `pickup_affordance_trim`.
	# No floating pickup ring, imaginary light source, or extra draw call.
	var pieces := root.find_children("*", "MeshInstance3D", true, false)
	for piece in pieces:
		if piece.has_meta("pickup_affordance_trim"):
			(piece as MeshInstance3D).material_override = HAZARD
			return
	for part_name in ["MagazineBasePlate", "MagazineFloorPlate", "HandleEnd", "GripBand", "MountingCollar", "GripWrap18"]:
		for piece in pieces:
			if String(piece.name) == part_name:
				(piece as MeshInstance3D).material_override = HAZARD
				piece.set_meta("pickup_affordance_trim", true)
				return


static func led_material(color: Color, energy := 1.1) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.4
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.5
	return material


static func add_keypad_face(keypad: MeshInstance3D) -> StandardMaterial3D:
	# The old solid glowing rectangle becomes painted trim, a recessed dark
	# face and ONE tiny status lamp. -Z is the existing locker front.
	keypad.material_override = HAZARD
	var bounds := keypad.mesh.get_aabb()
	var face := MeshInstance3D.new()
	face.name = "KeypadFace"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(bounds.size.x - 0.035, bounds.size.y - 0.035, 0.012)
	face.mesh = mesh
	face.position.z = bounds.position.z - 0.004
	face.material_override = PANEL
	face.layers = keypad.layers
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	keypad.add_child(face)
	var led := MeshInstance3D.new()
	led.name = "StatusLED"
	var led_mesh := BoxMesh.new()
	led_mesh.size = Vector3(0.065, 0.025, 0.012)
	led.mesh = led_mesh
	led.position = Vector3(0, bounds.size.y * 0.32, face.position.z - 0.01)
	var material := led_material(Color("63b9ac"))
	led.material_override = material
	led.layers = keypad.layers
	led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	keypad.add_child(led)
	var numbers := Label3D.new()
	numbers.name = "KeypadNumbers"
	numbers.text = "1 2 3\n4 5 6\n7 8 9"
	numbers.font_size = 20
	numbers.pixel_size = 0.0025
	numbers.position = Vector3(0, -0.03, face.position.z - 0.011)
	numbers.rotation.y = PI
	numbers.modulate = Color("c0bda9")
	numbers.outline_size = 0
	numbers.shaded = true
	numbers.layers = keypad.layers
	keypad.add_child(numbers)
	return material
