extends Node3D

const PALETTE := preload("res://scripts/visuals/character_material_palette.gd")
const CHARACTER_SCENE := preload("res://scenes/characters/BaseModularCharacter.tscn")
const GUARD_VISUAL_SCENE := preload("res://scenes/npc/GuardVisual.tscn")
const INMATE_VISUAL_SCENE := preload("res://scenes/npc/InmateVisual.tscn")
const GUARD_SCENE := preload("res://scenes/npc/Guard.tscn")
const EXPECTED_ANIMATIONS: Array[StringName] = [&"idle", &"walk", &"run", &"crouch_idle", &"crouch_walk"]

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_validate")


func _validate() -> void:
	# NOTE: as of the Mixamo Auto-Rigger migration, GuardVisual no longer
	# extends ModularCharacter / shares the PSX mesh with inmates -- it uses
	# OperatorCharacter (see scripts/visuals/operator_character.gd). Inmates
	# are still on the PSX pipeline, so those checks remain below; the old
	# guard<->inmate PSX-sharing assertions were retired along with them.
	_validate_source_and_license()
	_validate_material_cache()
	var guard := GUARD_VISUAL_SCENE.instantiate() as GuardVisual
	var inmate := INMATE_VISUAL_SCENE.instantiate() as ModularCharacter
	inmate.auto_skin_tone = false
	inmate.skin_tone = PALETTE.SKIN_TAN
	add_child(guard)
	add_child(inmate)
	_validate_operator_rig(guard)
	_validate_inmate_rig(inmate)
	_validate_animation_states()
	_validate_guard_scene()
	guard.queue_free()
	inmate.queue_free()
	for failure in _failures: push_error(failure)
	print("MODULAR CHARACTER VALIDATION: ", "PASS" if _failures.is_empty() else "FAIL", " — Mixamo operator rig for guards, Characters PSX mesh/UV texture + rest-pose retargeting for inmates")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _validate_source_and_license() -> void:
	_check(FileAccess.file_exists("res://assets/characters/characters_psx/operator_base.fbx"), "Characters PSX base FBX must exist")
	_check(FileAccess.file_exists("res://assets/characters/characters_psx/Character_21_Police.png"), "Original game-authored UV texture must exist")
	_check(FileAccess.file_exists("res://assets/characters/characters_psx/LICENSE.txt"), "Characters PSX CC0 license record must ship beside the source")
	_check(FileAccess.file_exists("res://assets/characters/characters_psx/SOURCE.md"), "Mesh, texture, and animation provenance must be recorded")
	_check(FileAccess.file_exists("res://scenes/characters/MixamoLocomotionRig.tscn"), "Extracted shared Mixamo animation rig must exist")


func _validate_material_cache() -> void:
	PALETTE.clear_cache()
	var texture := load("res://assets/characters/characters_psx/Character_21_Police.png") as Texture2D
	var guard_a := PALETTE.get_character_surface_material(texture, false, PALETTE.SKIN_TAN, PALETTE.GUARD_PRIMARY, PALETTE.GUARD_SECONDARY)
	var guard_b := PALETTE.get_character_surface_material(texture, false, PALETTE.SKIN_TAN, PALETTE.GUARD_PRIMARY, PALETTE.GUARD_SECONDARY)
	var inmate := PALETTE.get_character_surface_material(texture, true, PALETTE.SKIN_TAN, PALETTE.INMATE_ORANGE, PALETTE.INMATE_KHAKI)
	_check(guard_a == guard_b, "Equal faction palettes must reuse one cached material")
	_check(guard_a != inmate, "Guard and inmate palettes must remain visually distinct")
	_check(guard_a.get_shader_parameter(&"source_texture") == inmate.get_shader_parameter(&"source_texture"), "Every faction must share the same authored UV texture")
	_check(PALETTE.SKIN_TONES.size() == 5, "Five cheap skin-tone variants must remain available")


func _validate_operator_rig(guard: GuardVisual) -> void:
	var guard_rig := guard.get_node("OperatorRig") as Node3D
	_check(guard_rig.get_meta("source_pack") == "Mixamo Auto-Rigger (Ch35 operator)", "Guard rig instance must identify the Mixamo operator source")
	var guard_skeleton := guard.get_rig_root() as Skeleton3D
	_check(guard_skeleton != null, "Guard skeleton must build")
	_check(guard_skeleton.get_bone_name(0) == &"mixamorig_Hips", "Guard skeleton must use the Mixamo Auto-Rigger bone names")
	var guard_animation := guard.get_animation_player()
	_check(guard_animation.get_animation_list().size() == EXPECTED_ANIMATIONS.size(), "Only the five requested locomotion clips should ship")
	for clip in EXPECTED_ANIMATIONS:
		_check(guard_animation.has_animation(clip), "Missing Mixamo clip: " + clip)
	_check(guard.get_model_mesh().mesh != null, "Guard mesh must load")
	_check(guard.character_type == OperatorCharacter.CharacterType.GUARD, "Guard scene must keep its role")


func _validate_inmate_rig(inmate: ModularCharacter) -> void:
	var inmate_rig := inmate.get_node("PSXSharedRig") as Node3D
	_check(inmate_rig.get_meta("source_pack") == "Elbolilloduro Characters PSX 1.1", "Inmate instance must identify the Characters PSX source")
	_check(inmate_rig.get_meta("forward_axis") == "+Y source corrected to Godot -Z", "Axis correction must be documented on the inmate rig instance")
	var inmate_skeleton := inmate.get_rig_root() as Skeleton3D
	_check(inmate_skeleton.get_bone_name(0) == &"Hips", "Target skeleton and copied skin binds must use the humanoid profile")
	_check(inmate_skeleton.basis.is_equal_approx(ModularCharacter.SOURCE_TO_GODOT_BASIS), "PSX +X/+Z axes must be corrected to Godot forward/up")
	_check(is_equal_approx(inmate_skeleton.position.y, 0.0076), "Model feet must sit on a zeroed origin")
	var inmate_animation := inmate.get_animation_player()
	_check(inmate_animation.get_animation_list().size() == EXPECTED_ANIMATIONS.size(), "Only the five requested locomotion clips should ship")
	for clip in EXPECTED_ANIMATIONS:
		_check(inmate_animation.has_animation(clip), "Missing Mixamo clip: " + clip)
	_check(inmate_skeleton.get_parent() is RetargetModifier3D, "PSX skeleton must be driven by Godot's rest-pose retargeter")
	var retarget := inmate_skeleton.get_parent() as RetargetModifier3D
	_check(retarget.profile.get_bone_size() >= 25, "Retarget profile must cover the shared Mixamo body bones")
	_check(inmate.character_type == ModularCharacter.CharacterType.INMATE, "Inmate scene must keep its role")
	var inmate_material := inmate.get_model_mesh().material_override as ShaderMaterial
	_check(is_equal_approx(float(inmate_material.get_shader_parameter(&"inmate_mix")), 1.0), "Inmate must use palette-only jumpsuit conversion")
	_check(inmate_material.get_shader_parameter(&"inmate_primary") == PALETTE.INMATE_ORANGE, "Inmate primary color must remain configurable")


func _validate_animation_states() -> void:
	var actor := CharacterBody3D.new()
	actor.name = "AnimationTestGuard"
	var visual := CHARACTER_SCENE.instantiate() as ModularCharacter
	visual.auto_skin_tone = false
	actor.add_child(visual)
	add_child(actor)
	var animation := visual.get_animation_player()
	actor.velocity = Vector3.ZERO
	visual._process(0.2)
	_check(animation.current_animation == "idle", "Stationary state must drive Mixamo idle")
	actor.velocity = Vector3(2.0, 0.0, 0.0)
	visual._process(0.2)
	_check(animation.current_animation == "walk" and is_equal_approx(animation.speed_scale, 1.0), "Patrol velocity must drive Mixamo walk")
	actor.velocity = Vector3(4.8, 0.0, 0.0)
	visual._process(0.2)
	_check(animation.current_animation == "run" and is_equal_approx(animation.speed_scale, 1.0), "Pursuit velocity must drive Mixamo run")
	actor.set_meta("is_crouching", true)
	actor.velocity = Vector3.ZERO
	visual._process(0.2)
	_check(animation.current_animation == "crouch_idle", "Stationary crouch must use the authored Mixamo crouch clip")
	actor.velocity = Vector3(1.2, 0.0, 0.0)
	visual._process(0.2)
	_check(animation.current_animation == "crouch_walk", "Moving crouch must use the authored Mixamo sneak clip")
	for clip in EXPECTED_ANIMATIONS:
		_check(animation.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, String(clip) + " must loop")
	actor.queue_free()


func _validate_guard_scene() -> void:
	var guard := GUARD_SCENE.instantiate() as GuardController
	guard.name = "IntegratedGuardVariant4"
	add_child(guard)
	var visual := guard.get_node("GuardVisual") as GuardVisual
	_check(visual.get_rig_root() != null and visual.get_animation_player() != null, "Guard.tscn must use the Mixamo operator visual")
	guard.velocity = Vector3(guard.patrol_speed, 0.0, 0.0)
	visual._process(0.2)
	_check(visual.get_animation_player().current_animation == "walk", "Existing guard patrol speed must drive walk without AI changes")
	guard.velocity = Vector3(guard.pursuit_speed, 0.0, 0.0)
	visual._process(0.2)
	_check(visual.get_animation_player().current_animation == "run", "Existing guard pursuit speed must drive run without AI changes")
	guard.queue_free()


func _check(ok: bool, message: String) -> void:
	if not ok: _failures.append(message)
