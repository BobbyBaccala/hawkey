extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	for i in range(120):
		await physics_frame
	check(scene.player.position.z < -3, "Actual W input must skate forward")
	check(scene.velocity.length() > 5, "Skater must accelerate")
	key.pressed = false
	Input.parse_input_event(key)
	var brake := InputEventKey.new()
	brake.physical_keycode = KEY_CTRL
	brake.pressed = true
	Input.parse_input_event(brake)
	for i in range(70):
		await physics_frame
	check(scene.velocity.length() < 0.1, "Ctrl stop must brake")
	brake.pressed = false
	Input.parse_input_event(brake)
	# Stick assistance should remain bounded, with no spring explosion.
	scene.reset_puck()
	scene.cooldown = 0
	for i in range(180):
		await physics_frame
	check(scene.player.position.distance_to(scene.puck.position) < 1.9,"Stationary stick control must stay in reach")
	check(scene.puck.linear_velocity.length() < 2,"Settled puck must not oscillate violently")
	scene.queue_free()
	await process_frame
	print("Control integration failures: ",failures)
	quit(failures)
