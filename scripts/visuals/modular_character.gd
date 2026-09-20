extends Node3D
class_name ModularCharacter

## Shared Characters PSX visual controller.
##
## One Elbolilloduro mesh/UV texture is instanced for every humanoid. A single
## extracted Mixamo animation library drives a lightweight source skeleton;
## Godot's RetargetModifier3D transfers that pose to the PSX bind skeleton.
## Factions only change shader palette parameters, never mesh/skeleton data.

enum CharacterType { GUARD, INMATE, CIVILIAN }
enum LocomotionState { IDLE, WALK, RUN, CROUCH_IDLE, CROUCH_WALK }

const RIG_SCENE: PackedScene = preload("res://assets/characters/characters_psx/operator_base.fbx")
const MOTION_SCENE: PackedScene = preload("res://scenes/characters/MixamoLocomotionRig.tscn")
const SOURCE_TEXTURE: Texture2D = preload("res://assets/characters/characters_psx/Character_21_Police.png")
const RIG_SOURCE_PATH := "res://assets/characters/characters_psx/operator_base.fbx"
const PALETTE := preload("res://scripts/visuals/character_material_palette.gd")
const STATE_ANIMATIONS := {
	LocomotionState.IDLE: &"idle",
	LocomotionState.WALK: &"walk",
	LocomotionState.RUN: &"run",
	LocomotionState.CROUCH_IDLE: &"crouch_idle",
	LocomotionState.CROUCH_WALK: &"crouch_walk",
}
const LOOPED_ANIMATIONS: Array[StringName] = [&"idle", &"walk", &"run", &"crouch_idle", &"crouch_walk"]
const SOURCE_TO_GODOT_BASIS := Basis.IDENTITY
const HUMANOID_NAMES := {
	"Hips": "Hips", "Spine": "Spine", "Spine1": "Chest", "Spine2": "UpperChest",
	"Neck": "Neck", "Head": "Head", "LeftShoulder": "LeftShoulder", "LeftArm": "LeftUpperArm",
	"LeftForeArm": "LeftLowerArm", "LeftHand": "LeftHand", "LeftHandIndex1": "LeftIndexProximal",
	"LeftHandIndex2": "LeftIndexIntermediate", "LeftHandIndex3": "LeftIndexDistal",
	"RightShoulder": "RightShoulder", "RightArm": "RightUpperArm", "RightForeArm": "RightLowerArm",
	"RightHand": "RightHand", "RightHandIndex1": "RightIndexProximal",
	"RightHandIndex2": "RightIndexIntermediate", "RightHandIndex3": "RightIndexDistal",
	"LeftUpLeg": "LeftUpperLeg", "LeftLeg": "LeftLowerLeg", "LeftFoot": "LeftFoot", "LeftToeBase": "LeftToes",
	"RightUpLeg": "RightUpperLeg", "RightLeg": "RightLowerLeg", "RightFoot": "RightFoot", "RightToeBase": "RightToes",
}

@export var character_type: CharacterType = CharacterType.GUARD:
	set(value):
		character_type = value
		_apply_type_defaults()
		if is_node_ready(): _apply_materials()

@export_group("Faction Palette")
@export var auto_skin_tone := true
@export_range(-1, 4, 1) var appearance_variant := -1
@export var skin_tone: Color = PALETTE.SKIN_MEDIUM:
	set(value):
		skin_tone = value
		if is_node_ready(): _apply_materials()
@export var uniform_primary: Color = PALETTE.GUARD_PRIMARY:
	set(value):
		uniform_primary = value
		if is_node_ready(): _apply_materials()
@export var uniform_secondary: Color = PALETTE.GUARD_SECONDARY:
	set(value):
		uniform_secondary = value
		if is_node_ready(): _apply_materials()
@export var vest_color: Color = PALETTE.GUARD_VEST
@export var leather_color: Color = PALETTE.GUARD_LEATHER
@export var badge_color: Color = PALETTE.GUARD_BADGE
@export var hair_color: Color = PALETTE.HAIR_BLACK

@export_group("Compatibility Flags")
@export var show_cap := true
@export var show_vest := true
@export var show_belt := true

@export_group("Animation Parameters")
@export_range(0.8, 1.25, 0.01) var model_scale := 1.08
@export_range(0.01, 1.0, 0.01) var movement_threshold := 0.08
@export_range(1.0, 10.0, 0.1) var run_threshold := 3.2
@export_range(0.05, 0.5, 0.01) var blend_time := 0.18
@export var is_crouching := false

var _rig_instance: Node3D
var _motion_instance: Node3D
var _source_skeleton: Skeleton3D
var _target_skeleton: Skeleton3D
var _model_mesh: MeshInstance3D
var _animation_player: AnimationPlayer
var _current_state: LocomotionState = LocomotionState.IDLE


func _enter_tree() -> void:
	_build_character_rig()


func _ready() -> void:
	_build_character_rig()
	_apply_type_defaults()
	if auto_skin_tone:
		var resolved_variant := appearance_variant
		if resolved_variant < 0:
			resolved_variant = absi(String(get_parent().name if get_parent() else name).hash()) % PALETTE.SKIN_TONES.size()
		skin_tone = PALETTE.SKIN_TONES[clampi(resolved_variant, 0, PALETTE.SKIN_TONES.size() - 1)]
	_apply_materials()
	_configure_shared_animations()
	_play_state_animation(LocomotionState.IDLE, true)


func _process(_delta: float) -> void:
	var horizontal_speed := 0.0
	var actor := get_parent() as CharacterBody3D
	var crouching := is_crouching
	if actor:
		horizontal_speed = Vector2(actor.velocity.x, actor.velocity.z).length()
		var actor_crouch = actor.get("is_crouching")
		if actor_crouch != null:
			crouching = bool(actor_crouch)
		elif actor.has_meta("is_crouching"):
			crouching = bool(actor.get_meta("is_crouching"))
	var target_state := LocomotionState.IDLE
	if crouching:
		target_state = LocomotionState.CROUCH_WALK if horizontal_speed > movement_threshold else LocomotionState.CROUCH_IDLE
	elif horizontal_speed > run_threshold:
		target_state = LocomotionState.RUN
	elif horizontal_speed > movement_threshold:
		target_state = LocomotionState.WALK
	if target_state != _current_state or not _animation_player.is_playing():
		_play_state_animation(target_state)
	_update_animation_speed(horizontal_speed)


func _build_character_rig() -> void:
	if is_instance_valid(_rig_instance): return
	_rig_instance = Node3D.new()
	_rig_instance.name = "PSXSharedRig"
	_rig_instance.scale = Vector3.ONE * model_scale
	_rig_instance.set_meta("source_pack", "Elbolilloduro Characters PSX 1.1")
	_rig_instance.set_meta("source_path", RIG_SOURCE_PATH)
	_rig_instance.set_meta("forward_axis", "+Y source corrected to Godot -Z")
	add_child(_rig_instance)

	_motion_instance = MOTION_SCENE.instantiate() as Node3D
	_motion_instance.name = "SharedMixamoMotion"
	_rig_instance.add_child(_motion_instance)
	_source_skeleton = _motion_instance.find_child("SourceSkeleton", true, false) as Skeleton3D
	_animation_player = _motion_instance.find_child("AnimationPlayer", true, false) as AnimationPlayer

	var imported_rig := RIG_SCENE.instantiate() as Node3D
	imported_rig.name = "ImportedPSXCharacter"
	_rig_instance.add_child(imported_rig)
	_target_skeleton = imported_rig.find_child("Skeleton3D", true, false) as Skeleton3D
	_model_mesh = imported_rig.find_child("Character_21_Police", true, false) as MeshInstance3D
	if _source_skeleton == null or _animation_player == null or _target_skeleton == null or _model_mesh == null:
		push_error("Characters PSX shared rig is incomplete")
		return
	_rename_target_skeleton_and_skin()
	var retarget := RetargetModifier3D.new()
	retarget.name = "HumanoidRetarget"
	retarget.profile = SkeletonProfileHumanoid.new()
	retarget.use_global_pose = true
	# Rotation-only transfer: the Mixamo source skeleton keeps the DAE's native
	# (large, non-uniform) bone scale, which its clips need to pose correctly.
	# Transferring position/scale would drag that scale onto the FBX target and
	# blow out its proportions, so we take orientations only and let the target
	# retain its own bone lengths (this is also what keeps the feet grounded).
	retarget.set_position_enabled(false)
	retarget.set_rotation_enabled(true)
	retarget.set_scale_enabled(false)
	_source_skeleton.add_child(retarget)
	_target_skeleton.reparent(retarget, false)
	_target_skeleton.name = "TargetSkeleton"
	_target_skeleton.basis = SOURCE_TO_GODOT_BASIS
	_target_skeleton.position = Vector3(0.0, 0.0076, 0.0)
	imported_rig.queue_free()


func _rename_target_skeleton_and_skin() -> void:
	# FBX skins use named binds, so canonicalization must update the per-instance
	# Skin copy and Skeleton3D together. The imported shared resources remain
	# untouched and every mesh continues to use the same ArrayMesh.
	var skin := _model_mesh.skin.duplicate(true) as Skin
	for bind_index in skin.get_bind_count():
		var raw_bind_name := String(skin.get_bind_name(bind_index)).trim_prefix("mixamorig_")
		skin.set_bind_name(bind_index, HUMANOID_NAMES.get(raw_bind_name, raw_bind_name))
	_model_mesh.skin = skin
	for bone_index in _target_skeleton.get_bone_count():
		var raw_name := String(_target_skeleton.get_bone_name(bone_index)).trim_prefix("mixamorig_")
		_target_skeleton.set_bone_name(bone_index, HUMANOID_NAMES.get(raw_name, raw_name))


func _configure_shared_animations() -> void:
	for animation_name in LOOPED_ANIMATIONS:
		var animation := _animation_player.get_animation(animation_name)
		if animation: animation.loop_mode = Animation.LOOP_LINEAR


func _apply_type_defaults() -> void:
	match character_type:
		CharacterType.GUARD:
			uniform_primary = PALETTE.GUARD_PRIMARY
			uniform_secondary = PALETTE.GUARD_SECONDARY
			vest_color = PALETTE.GUARD_VEST
			leather_color = PALETTE.GUARD_LEATHER
			show_cap = true
			show_vest = true
			show_belt = true
		CharacterType.INMATE:
			uniform_primary = PALETTE.INMATE_ORANGE
			uniform_secondary = PALETTE.INMATE_KHAKI
			leather_color = PALETTE.INMATE_SHOES
			show_cap = false
			show_vest = false
			show_belt = false
		CharacterType.CIVILIAN:
			uniform_primary = Color("3c4d5c")
			uniform_secondary = Color("28323c")
			leather_color = Color("1e1714")
			show_cap = false
			show_vest = false
			show_belt = false


func _apply_materials() -> void:
	if not is_instance_valid(_model_mesh): return
	_model_mesh.material_override = PALETTE.get_character_surface_material(
		SOURCE_TEXTURE,
		character_type == CharacterType.INMATE,
		skin_tone,
		uniform_primary,
		uniform_secondary
	)


func _play_state_animation(state: LocomotionState, immediate := false) -> void:
	if not is_instance_valid(_animation_player): return
	_current_state = state
	var animation_name: StringName = STATE_ANIMATIONS[state]
	if _animation_player.has_animation(animation_name):
		_animation_player.play(animation_name, 0.0 if immediate else blend_time)


func _update_animation_speed(horizontal_speed: float) -> void:
	if not is_instance_valid(_animation_player): return
	match _current_state:
		LocomotionState.WALK:
			_animation_player.speed_scale = clampf(horizontal_speed / 2.0, 0.6, 1.8)
		LocomotionState.RUN:
			_animation_player.speed_scale = clampf(horizontal_speed / 4.8, 0.7, 2.0)
		LocomotionState.CROUCH_WALK:
			_animation_player.speed_scale = clampf(horizontal_speed / 1.2, 0.6, 1.8)
		_:
			_animation_player.speed_scale = 1.0


func get_rig_root() -> Node3D:
	_build_character_rig()
	return _target_skeleton


func get_animation_player() -> AnimationPlayer:
	_build_character_rig()
	return _animation_player


func get_current_locomotion_state() -> LocomotionState:
	return _current_state


func get_state_animation(state: LocomotionState) -> StringName:
	return STATE_ANIMATIONS[state]


func get_model_mesh() -> MeshInstance3D:
	_build_character_rig()
	return _model_mesh


func configure_variant(type: CharacterType, skin: Color = Color.BLACK, uniform: Color = Color.BLACK) -> void:
	character_type = type
	_apply_type_defaults()
	if skin != Color.BLACK:
		auto_skin_tone = false
		skin_tone = skin
	if uniform != Color.BLACK: uniform_primary = uniform
	_apply_materials()
