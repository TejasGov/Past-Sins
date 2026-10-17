extends Node3D

const GUARD_SCENE := preload("res://scenes/npc/GuardVisual.tscn")
const INMATE_SCENE := preload("res://scenes/npc/InmateVisual.tscn")


func _ready() -> void:
	# Guard now uses the Mixamo operator rig (its own baked-in tactical
	# texture, no palette/skin-tone parameters like the PSX pipeline).
	var guard := GUARD_SCENE.instantiate() as GuardVisual
	guard.name = "GuardOperator"
	guard.position = Vector3(-0.72, 0.0, 0.0)
	add_child(guard)
	var inmate := INMATE_SCENE.instantiate() as ModularCharacter
	inmate.name = "InmateVariant"
	inmate.auto_skin_tone = false
	inmate.skin_tone = CharacterMaterialPalette.SKIN_DARK
	inmate.position = Vector3(0.72, 0.0, 0.0)
	add_child(inmate)
	guard.get_animation_player().play(&"walk")
	inmate.get_animation_player().play(&"crouch_idle")
	await get_tree().create_timer(0.65).timeout
	var result := get_viewport().get_texture().get_image().save_png("/tmp/blacksite-psx-characters.png")
	print("PSX character render: ", error_string(result))
	get_tree().quit(0 if result == OK else 1)
