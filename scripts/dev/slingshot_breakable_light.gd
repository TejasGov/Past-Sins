extends StaticBody3D
class_name SlingshotBreakableLight

var broken := false


func _ready() -> void:
	add_to_group("slingshot_breakable_lights")
	set_meta("surface_type", &"LIGHT")


func on_slingshot_projectile_impact(_projectile: SlingshotProjectile, _position: Vector3) -> void:
	if broken: return
	broken = true
	$Light.visible = false
	$Bulb.material_override = $BrokenMaterial.material_override
	$Label.text = "BREAKABLE LIGHT\nBROKEN"


func reset_light() -> void:
	broken = false
	$Light.visible = true
	$Bulb.material_override = $LitMaterial.material_override
	$Label.text = "BREAKABLE LIGHT"
