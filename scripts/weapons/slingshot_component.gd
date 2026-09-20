extends Node3D
class_name SlingshotComponent

signal state_changed(state: StringName)
signal projectile_launched(projectile: SlingshotProjectile, toxin: bool, charge: float)
signal draw_failed(reason: String)

enum State { READY, DRAWING, RELOADING }
var definition: SlingshotDefinition
var state := State.READY
var draw_time := 0.0
var reload_remaining := 0.0
var selected_toxin := false
var visual: ImprovisedSlingshotVisual
var aim_amount := 0.0


func configure(value: SlingshotDefinition) -> bool:
	if value == null or not value.is_valid_slingshot_definition(): return false
	definition = value
	visual = definition.first_person_visual_scene.instantiate() as ImprovisedSlingshotVisual
	if visual == null: return false
	add_child(visual)
	return true


func begin_draw() -> bool:
	if state != State.READY: return false
	if get_selected_ammo_count() <= 0:
		draw_failed.emit("NO %s" % (definition.toxin_ammo.display_name.to_upper() if selected_toxin else definition.normal_ammo.display_name.to_upper()))
		return false
	state = State.DRAWING
	draw_time = 0.0
	state_changed.emit(&"DRAWING")
	return true


func release_draw(camera: Camera3D, source: Node3D) -> SlingshotProjectile:
	if state != State.DRAWING or camera == null: return null
	var ammo := definition.toxin_ammo if selected_toxin else definition.normal_ammo
	if not InventoryManager.remove_item(ammo.item_id, 1):
		cancel_draw()
		return null
	var charge := clampf(draw_time / definition.maximum_draw_time, 0.12, 1.0)
	var speed := lerpf(definition.minimum_velocity, definition.maximum_velocity, charge)
	var spread := lerpf(definition.maximum_spread_degrees, definition.minimum_spread_degrees, charge)
	spread *= lerpf(1.0, definition.aimed_spread_multiplier, aim_amount)
	var direction := -camera.global_basis.z
	# Zero the visible ballistic arc against the center aim ray. This preserves a
	# real, slower projectile while making the crosshair trustworthy at typical
	# room/range distances instead of forcing the player to guess the drop.
	var zero_distance := lerpf(4.0, definition.maximum_zero_distance, charge)
	var gravity_ratio := clampf(definition.projectile_gravity * zero_distance / (speed * speed), 0.0, 0.98)
	var zero_angle := 0.5 * asin(gravity_ratio)
	direction = direction.rotated(camera.global_basis.x, zero_angle)
	if spread > 0.0:
		direction = direction.rotated(camera.global_basis.x, deg_to_rad(randf_range(-spread, spread))).rotated(camera.global_basis.y, deg_to_rad(randf_range(-spread, spread)))
	var projectile := definition.projectile_scene.instantiate() as SlingshotProjectile
	var root := get_tree().current_scene
	var projectile_root := root.get_node_or_null("Projectiles")
	if projectile_root == null:
		projectile_root = Node3D.new()
		projectile_root.name = "Projectiles"
		root.add_child(projectile_root)
	projectile_root.add_child(projectile)
	projectile.global_position = camera.global_position - camera.global_basis.z * 0.38
	projectile.setup(definition, direction.normalized() * speed, selected_toxin, source)
	state = State.RELOADING
	reload_remaining = definition.reload_setup_time
	visual.play_release()
	visual.play_reload(definition.reload_setup_time)
	state_changed.emit(&"RELOADING")
	projectile_launched.emit(projectile, selected_toxin, charge)
	return projectile


func cancel_draw() -> void:
	if state == State.DRAWING:
		state = State.READY
		draw_time = 0.0
		if visual: visual.set_draw_amount(0.0)
		state_changed.emit(&"READY")


func cycle_ammo() -> bool:
	var next_toxin := not selected_toxin
	var next := definition.toxin_ammo if next_toxin else definition.normal_ammo
	if InventoryManager.get_item_count(next.item_id) <= 0: return false
	selected_toxin = next_toxin
	return true


func get_selected_ammo_count() -> int:
	if definition == null: return 0
	var ammo := definition.toxin_ammo if selected_toxin else definition.normal_ammo
	return InventoryManager.get_item_count(ammo.item_id)


func get_charge() -> float:
	return clampf(draw_time / definition.maximum_draw_time, 0.0, 1.0) if definition else 0.0


func set_aim_amount(value: float) -> void:
	aim_amount = clampf(value, 0.0, 1.0)
	if visual: visual.set_aim_amount(aim_amount)


func _physics_process(delta: float) -> void:
	if state == State.DRAWING:
		draw_time = minf(definition.maximum_draw_time, draw_time + delta)
		if visual: visual.set_draw_amount(get_charge())
	elif state == State.RELOADING:
		reload_remaining = maxf(0.0, reload_remaining - delta)
		if reload_remaining <= 0.0:
			state = State.READY
			state_changed.emit(&"READY")
