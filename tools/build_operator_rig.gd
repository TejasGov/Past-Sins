extends SceneTree

## Merges the Mixamo Ch35 operator's separate clip downloads onto ONE
## AnimationPlayer. Unlike the old PSX pipeline, every file here comes from
## the same Auto-Rigger character, so the skeletons are identical (same bone
## names, same rest pose) -- tracks are copied verbatim, renamed only by
## semantic clip name. No cross-skeleton retargeting.

const BASE_FBX := "res://assets/characters/models_mixamo/Ch35_nonPBR.fbx"
const OUTPUT_PATH := "res://scenes/characters/OperatorLocomotionRig.tscn"

# clip source file -> semantic animation name used by the game state machine
const CLIPS := {
	"Idle": &"idle",
	"Walking": &"walk",
	"Run Forward": &"run",
	"Idle Crouching": &"crouch_idle",
	"Crouch Walking": &"crouch_walk",
}

func _clear_owner_recursive(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_clear_owner_recursive(child)


func _initialize() -> void:
	var base_inst := (load(BASE_FBX) as PackedScene).instantiate()
	var base_skel: Skeleton3D = base_inst.find_child("Skeleton3D", true, false)
	var base_mesh: MeshInstance3D = base_inst.find_child("Ch35", true, false)
	if base_skel == null or base_mesh == null:
		push_error("Base FBX missing Skeleton3D or Ch35 mesh")
		quit(1)
		return

	var root := Node3D.new()
	root.name = "OperatorLocomotionRig"
	root.set_meta("source_pack", "Mixamo Auto-Rigger (Ch35 operator)")
	root.set_meta("source_path", BASE_FBX)

	# Re-parent (not duplicate) the skeleton and mesh out of the transient base
	# instance so the saved scene owns a single clean copy. Clear the old owner
	# first, otherwise re-adding under the new root leaves a stale owner
	# reference that can make packing silently drop nodes.
	_clear_owner_recursive(base_skel)
	base_skel.get_parent().remove_child(base_skel)
	root.add_child(base_skel)
	base_skel.owner = root
	base_skel.name = "Skeleton3D"
	base_mesh.owner = root

	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.root_node = NodePath("..")
	root.add_child(player)
	player.owner = root

	var library := AnimationLibrary.new()

	for clip_file in CLIPS:
		var target_name: StringName = CLIPS[clip_file]
		var clip_path := "res://assets/characters/models_mixamo/%s.fbx" % clip_file
		var clip_inst := (load(clip_path) as PackedScene).instantiate()
		var clip_player: AnimationPlayer = clip_inst.find_child("AnimationPlayer", true, false)
		var source_anim: Animation = clip_player.get_animation("mixamo_com") if clip_player else null
		if source_anim == null:
			push_error("Missing mixamo_com animation in " + clip_path)
			quit(1)
			return

		# Same skeleton, so this is a straight duplicate + rename; no track
		# remapping or rest-pose reconciliation needed.
		var target_anim := source_anim.duplicate() as Animation
		target_anim.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(target_name, target_anim)
		clip_inst.free()

	player.add_animation_library(&"", library)

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, OUTPUT_PATH)
	if err != OK:
		push_error("Failed to save %s: %s" % [OUTPUT_PATH, err])
		quit(1)
		return
	print("Successfully saved ", OUTPUT_PATH)

	root.free()
	base_inst.free()
	quit()
