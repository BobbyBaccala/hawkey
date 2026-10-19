extends SceneTree
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://practice.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	check(scene.puck.continuous_cd, "Puck must use CCD")
	check(scene.arena.goals.size() == 2, "Both nets must exist")
	check(scene.arena.board_count == 68, "Rounded boards must be present")
	check(scene.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Camera must show perspective depth")
	# Isolate the goal-mouth physics test from goalkeeper interference.
	for goalie in scene.goalkeepers:
		goalie.collision_layer = 0
	scene.cooldown = 0
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
	# A centred shot must now meet the active goalkeeper instead of ghosting through.
	scene.paused = false
	scene.puck.freeze = false
	scene.cooldown = 2
	scene.goal_timer = 0
	scene.goals = 0
	for goalie in scene.goalkeepers:
		goalie.collision_layer = 2
	scene.goalkeepers[0].position = Vector3(0,0,-24)
	scene.goalkeepers[0].velocity = Vector3.ZERO
	scene.player.position = Vector3(4,0,-20)
	scene.puck.position = Vector3(0,0.12,-21)
	scene.puck.linear_velocity = Vector3(0,0,-25)
	scene.previous_puck = scene.puck.position
	for i in range(45):
		await physics_frame
	check(scene.saves > 0, "Centred shot must contact goalkeeper")
	check(scene.goals == 0, "Goalkeeper must prevent clean centred shot")
	scene.queue_free()
	await process_frame
	print("Integration failures: ", failures)
	quit(failures)
