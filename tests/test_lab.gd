extends SceneTree
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	check(scene.puck.continuous_cd, "Puck must use CCD")
	scene.player.position = Vector3(0, 0, -23.8)
	scene.puck.position = Vector3(0, 0.15, -24.6)
	scene.previous_puck = scene.puck.position
	scene.strike(Vector3.FORWARD, 34)
	for i in range(30):
		await physics_frame
	check(scene.goals == 1, "Front shot must score exactly once")
	scene.player.position = Vector3(0, 0, 3)
	scene.reset_puck()
	for i in range(8):
		await physics_frame
	check(scene.puck.position.distance_to(scene.player.position) < 2, "Reset must return puck")
	scene.puck.position = Vector3(13.5, 0.15, 0)
	scene.puck.linear_velocity = Vector3(34, 0, 0)
	scene.cooldown = 2.0
	for i in range(20):
		await physics_frame
	check(scene.puck.position.x < 15.0 and scene.puck.linear_velocity.x < 0, "Fast puck must rebound from side boards")
	scene.paused = true
	await physics_frame
	await physics_frame
	check(scene.puck.freeze, "Pause freezes physical puck")
	scene.queue_free()
	await process_frame
	print("Integration failures: ", failures)
	quit(failures)
