extends Area3D
class_name MemoryShard

@export var memory_id: StringName = &"memory_001"
@export var memory_title := "A Familiar Voice"
@export_multiline var transcript := "Darkness.\nTwo boys laughing.\nA hand grabs Parth's shoulder.\n\nRAMAN:\n\"Again. You always forget the pattern.\"\n\nA sequence flashes:\n\n2 - 7 - 1 - 8\n\nPARTH:\n\"Raman...?\"\n\nThe memory ends abruptly."
@export var practical_clue := "2718"

var collected := false


func _ready() -> void:
	collision_layer = 1 << 2
	collision_mask = 0
	collected = MemoryManager.has_memory(memory_id)
	visible = not collected
	monitorable = not collected
	if collected:
		collision_layer = 0
	if not collected:
		_start_float_animation()


func get_interaction_prompt(_player: Node) -> String:
	return "" if collected else "[E] Collect memory shard"


func interact(player: Node) -> void:
	if collected:
		return
	collected = true
	set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	if not MemoryManager.collect_memory(memory_id, memory_title, transcript, practical_clue):
		queue_free()
		return
	var data := {
		"id": memory_id,
		"title": memory_title,
		"transcript": transcript,
		"clue": practical_clue,
	}
	player.call("set_control_enabled", false)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("play_memory_sequence"):
		var finish_callback := _finish_collection.bind(player)
		if not hud.is_connected("memory_sequence_finished", finish_callback):
			hud.connect("memory_sequence_finished", finish_callback, CONNECT_ONE_SHOT)
		hud.call("play_memory_sequence", data)
	else:
		_finish_collection(player)


func _finish_collection(player: Node) -> void:
	if is_instance_valid(player):
		player.call("set_control_enabled", true)
	queue_free()


func _start_float_animation() -> void:
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($ShardVisual, "position:y", 0.22, 1.2)
	tween.tween_property($ShardVisual, "position:y", -0.08, 1.2)
