extends SceneTree

const SOURCE_PATH := "res://assets/characters/characters_psx/mixamo_locomotion_source.dae"
const TARGET_FBX_PATH := "res://assets/characters/characters_psx/operator_base.fbx"
const OUTPUT_PATH := "res://scenes/characters/MixamoLocomotionRig.tscn"

const CLIPS := {
    "Idle": &"idle",
    "Walk": &"walk",
    "Run": &"run",
    "Crouch-Idle": &"crouch_idle",
    "Sneak": &"crouch_walk",
}

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

func _initialize() -> void:
    var dae_packed: PackedScene = load(SOURCE_PATH)
    var fbx_packed: PackedScene = load(TARGET_FBX_PATH)
    var dae_inst := dae_packed.instantiate()
    var fbx_inst := fbx_packed.instantiate()
    
    var dae_skel: Skeleton3D = dae_inst.find_child("Skeleton3D", true, false)
    var dae_player: AnimationPlayer = dae_inst.find_child("AnimationPlayer", true, false)
    var fbx_skel: Skeleton3D = fbx_inst.find_child("Skeleton3D", true, false)
    
    var root := Node3D.new()
    root.name = "MixamoLocomotionRig"
    root.set_meta("animation_source", "Adobe Mixamo locomotion clips")
    root.set_meta("source_project", "aaronsnoswell/3DCharacter")
    
    var source_skel := Skeleton3D.new()
    source_skel.name = "SourceSkeleton"
    
    # Source skeleton is a faithful clone of the Mixamo DAE: exact rest poses
    # (INCLUDING the DAE's non-uniform bone scale, which its clips depend on to
    # pose correctly) with bones renamed to the shared humanoid profile. Because
    # the rest is intact, applying the raw rotation tracks reproduces the DAE's
    # own correct pose. The hierarchy-aware RetargetModifier3D in
    # modular_character.gd then transfers those orientations to the FBX target;
    # it is configured rotation-only, so the DAE's large scale never reaches the
    # target and the target keeps its own bone lengths.
    for b in dae_skel.get_bone_count():
        var raw_name = String(dae_skel.get_bone_name(b))
        source_skel.add_bone(HUMANOID_NAMES.get(raw_name, raw_name))

    for b in dae_skel.get_bone_count():
        source_skel.set_bone_parent(b, dae_skel.get_bone_parent(b))
        source_skel.set_bone_rest(b, dae_skel.get_bone_rest(b))
        source_skel.set_bone_enabled(b, dae_skel.is_bone_enabled(b))
        source_skel.reset_bone_pose(b)

    root.add_child(source_skel)
    source_skel.owner = root

    var player := AnimationPlayer.new()
    player.name = "AnimationPlayer"
    player.root_node = NodePath("..")
    root.add_child(player)
    player.owner = root

    var library := AnimationLibrary.new()

    for clip_source_name in CLIPS:
        var target_clip_name: StringName = CLIPS[clip_source_name]
        var source_anim: Animation = dae_player.get_animation(clip_source_name)
        if source_anim == null:
            push_error("Missing clip: " + clip_source_name)
            quit(1)
            return

        # Copy both POSITION and ROTATION bone tracks verbatim onto the humanoid
        # source skeleton (only the bone names change). The position tracks are
        # required: the DAE's scaled rest means its clips reposition bones every
        # frame, so without them the source pose collapses. The DAE's own world
        # translation ("Root Motion") is dropped to keep the clip in place. The
        # scale stays contained on the source because the runtime retarget in
        # modular_character.gd is rotation-only.
        var target_anim := Animation.new()
        target_anim.length = source_anim.length
        target_anim.loop_mode = Animation.LOOP_LINEAR

        for t in range(source_anim.get_track_count()):
            var ttype = source_anim.track_get_type(t)
            if ttype != Animation.TYPE_ROTATION_3D and ttype != Animation.TYPE_POSITION_3D:
                continue
            var path = source_anim.track_get_path(t)
            if path.get_subname_count() == 0:
                continue
            var old_bname = String(path.get_subname(0))
            if old_bname == "Root Motion" or dae_skel.find_bone(old_bname) < 0:
                continue
            var new_bname = HUMANOID_NAMES.get(old_bname, old_bname)
            var track_idx = target_anim.add_track(ttype)
            target_anim.track_set_path(track_idx, NodePath("SourceSkeleton:" + new_bname))
            for k in range(source_anim.track_get_key_count(t)):
                var time = source_anim.track_get_key_time(t, k)
                var value = source_anim.track_get_key_value(t, k)
                if ttype == Animation.TYPE_ROTATION_3D:
                    target_anim.rotation_track_insert_key(track_idx, time, value)
                else:
                    target_anim.position_track_insert_key(track_idx, time, value)

        library.add_animation(target_clip_name, target_anim)
        
    player.add_animation_library(&"", library)
    
    var packed := PackedScene.new()
    packed.pack(root)
    ResourceSaver.save(packed, OUTPUT_PATH)
    print("Successfully saved ", OUTPUT_PATH)
    
    root.free()
    dae_inst.free()
    fbx_inst.free()
    quit()
