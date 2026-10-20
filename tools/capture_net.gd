extends SceneTree
## Goal net review: the north net from a low front-quarter angle, a side
## profile, and the same front view mid-ripple after a puck hit.
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_net.gd
## Writes /tmp/hawkey-net-front.png, /tmp/hawkey-net-side.png, /tmp/hawkey-net-ripple.png.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	for i in range(3): await physics_frame
	scene.set_physics_process(false)
	scene.set_process(false)
	var net = scene.arena.goals[0]
	# Clear the crease so the net is unobstructed.
	for g in scene.goalkeepers: g.visible = false
	scene.puck.visible = false
	var hud = scene.get("hud_node")
	if hud: hud.visible = false
	var cam: Camera3D = scene.camera
	var mouth: Vector3 = net.global_position
	var into: Vector3 = -net.global_basis.z    # toward the back of the net
	var side: Vector3 = net.global_basis.x
	cam.fov = 42
	cam.position = mouth - into * 3.4 + side * 1.7 + Vector3(0, 1.25, 0)
	cam.look_at(mouth + into * 0.45 + Vector3(0, 0.5, 0))
	for i in range(4): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/hawkey-net-front.png")
	cam.position = mouth + into * 0.45 + side * 3.6 + Vector3(0, 0.9, 0)
	cam.look_at(mouth + into * 0.45 + Vector3(0, 0.55, 0))
	for i in range(4): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/hawkey-net-side.png")
	# Puck into the back of the net, top corner side.
	net.set_process(false)
	net.impact(Vector3(0.35, 0.55, -0.9), 24.0)
	net.ripple_age = 0.07
	net._push()
	# Side profile shows the back of the net bellying out.
	for i in range(4): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/hawkey-net-ripple.png")
	print("net capture done")
	quit()
