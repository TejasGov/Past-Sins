extends SceneTree

## Render any character/rig scene to a real PNG so a pose/material fix can be
## confirmed visually, not just by bone statistics. Run WITHOUT --headless:
##   Godot --path . --script res://tools/screenshot_rig.gd -- <out.png> [anim] [scene_path]

const DEFAULT_CHARACTER_SCENE := "res://scenes/characters/BaseModularCharacter.tscn"

var _frames := 0
var _out := "/tmp/rig_preview.png"
var _anim := "idle"
var _scene_path := DEFAULT_CHARACTER_SCENE
var _character: Node3D

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1: _out = args[0]
	if args.size() >= 2: _anim = args[1]
	if args.size() >= 3: _scene_path = args[2]

	var root := get_root()
	root.size = Vector2i(720, 900)

	# Neutral studio lighting: if the character still looks green here, the tint
	# is in its material; if not, it comes from the level environment.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.5, 0.52)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 25, 0)
	key.light_energy = 1.2
	root.add_child(key)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.3)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	cam.current = true
	root.add_child(cam)

	_character = (load(_scene_path) as PackedScene).instantiate()
	root.add_child(_character)

func _process(_delta: float) -> bool:
	_frames += 1
	# Give the rig a few frames to build and the requested clip to settle.
	if _frames == 10:
		var ap := _character.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.has_animation(_anim):
			ap.play(_anim)
	if _frames < 30:
		return false
	var img := get_root().get_texture().get_image()
	img.save_png(_out)
	print("SAVED ", _out)
	return true
