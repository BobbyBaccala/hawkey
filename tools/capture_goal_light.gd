extends SceneTree
## Goal celebration review: triggers a goal on the south net and renders the
## goal light behind the net (lit and unlit), the jumbotron mid-"GOAL" and
## showing the team name, and a broadcast-angle view of the arena flash.
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_goal_light.gd
## Writes /tmp/hawkey-goal-light-off.png, -on.png, -close.png, /tmp/hawkey-goal-jumbotron.png,
## /tmp/hawkey-goal-jumbotron-name.png and /tmp/hawkey-goal-wide.png.
const Arena = preload("res://scripts/arena.gd")

func _initialize() -> void: call_deferred("run")

func shot(path: String) -> void:
	for i in range(4): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	for i in range(3): await physics_frame
	scene.set_physics_process(false)
	scene.set_process(false)
	var hud = scene.get("hud_node")
	if hud: hud.visible = false
	var c = scene.celebration
	c.set_process(false)
	var cam: Camera3D = scene.camera
	var end_sign := 1.0
	var net_z := end_sign * Arena.GOAL_LINE
	# Low slot view of the net with the goal light on the glass behind it.
	cam.fov = 44
	cam.position = Vector3(2.6, 1.55, net_z - end_sign * 8.5)
	cam.look_at(Vector3(0, 1.55, end_sign * Arena.HALF_LENGTH))
	await shot("/tmp/hawkey-goal-light-off.png")
	c.celebrate(end_sign, hud.team_colors[0], hud.team_names[0])
	c.advance(0.62)
	await shot("/tmp/hawkey-goal-light-on.png")
	# Close-up of the lamp through the glass, from just in front of the net.
	cam.fov = 40
	cam.position = Vector3(-1.6, 2.2, end_sign * (Arena.HALF_LENGTH - 3.2))
	cam.look_at(Vector3(0, 2.75, end_sign * (Arena.HALF_LENGTH + 0.38)))
	await shot("/tmp/hawkey-goal-light-close.png")
	# Jumbotron mid-GOAL, from the lower bowl.
	cam.fov = 30
	cam.position = Vector3(0, 9.0, 24.0)
	cam.look_at(Vector3(0, 12.6, 0))
	c.advance(0.2)
	await shot("/tmp/hawkey-goal-jumbotron.png")
	# Broadcast-height wide view of the end zone: pools pulsing, red beam.
	cam.fov = 55
	cam.position = Vector3(-15, 9.5, 14)
	cam.look_at(Vector3(0, 1.0, end_sign * 22))
	await shot("/tmp/hawkey-goal-wide.png")
	# Team name on the board after the GOAL burst.
	cam.fov = 30
	cam.position = Vector3(0, 9.0, 24.0)
	cam.look_at(Vector3(0, 12.6, 0))
	c.advance(1.8)
	await shot("/tmp/hawkey-goal-jumbotron-name.png")
	print("goal light capture done")
	quit()
