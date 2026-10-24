extends SceneTree
## Goal net review renders of the north net:
##  front  - low front-quarter close-up, crease cleared
##  side   - side profile
##  ripple - side profile mid-ripple after a puck hit
##  goalie - from the slot at broadcast height with the goalie set in the crease
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_net.gd
## Writes /tmp/hawkey-net-<name>.png.
func _initialize() -> void: call_deferred("run")

func shot(cam: Camera3D, pos: Vector3, look: Vector3, fov: float, path: String) -> void:
	cam.fov = fov
	cam.position = pos
	cam.look_at(look)
	for i in range(4): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	for i in range(3): await physics_frame
	scene.set_physics_process(false)
	scene.set_process(false)
	var net = scene.arena.goals[0]
	net.set_process(false)
	for g in scene.goalkeepers: g.visible = false
	scene.puck.visible = false
	var hud = scene.get("hud_node")
	if hud: hud.visible = false
	var cam: Camera3D = scene.camera
	var mouth: Vector3 = net.global_position
	var into: Vector3 = -net.global_basis.z    # toward the back of the net
	var side: Vector3 = net.global_basis.x
	var centre := mouth + into * 0.45 + Vector3(0, 0.5, 0)
	await shot(cam, mouth - into * 2.6 + side * 1.6 + Vector3(0, 1.1, 0), centre, 40, "/tmp/hawkey-net-front.png")
	await shot(cam, mouth + into * 0.45 + side * 3.4 + Vector3(0, 0.9, 0), mouth + into * 0.45 + Vector3(0, 0.55, 0), 42, "/tmp/hawkey-net-side.png")
	net.impact(Vector3(0.35, 0.55, -0.9), 24.0)
	net.ripple_age = 0.07
	net._push()
	await shot(cam, mouth + into * 0.45 + side * 3.4 + Vector3(0, 0.9, 0), mouth + into * 0.45 + Vector3(0, 0.55, 0), 42, "/tmp/hawkey-net-ripple.png")
	net.ripple_age = 99.0
	net._push()
	# Goalie in front, seen from the high slot like a broadcast replay.
	var goalie = scene.goalkeepers[0]
	goalie.visible = true
	goalie.global_position = mouth - into * 0.55
	await shot(cam, mouth - into * 7.0 - side * 1.2 + Vector3(0, 2.6, 0), mouth + into * 0.2 + Vector3(0, 0.6, 0), 30, "/tmp/hawkey-net-goalie.png")
	print("net capture done")
	quit()
