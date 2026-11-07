extends SceneTree
## Crowd reaction review: renders the end/side stands seated (in-play fidget),
## then on its feet after a goal (two moments of the bounce), and a broadcast
## view of the goal moment.
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_crowd.gd
## Writes /tmp/hawkey-crowd-seated.png, -cheer-a.png, -cheer-b.png, -broadcast.png.
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
	var d = scene.arena.get_node("Dressing")
	d.set_process(false)
	scene.celebration.set_process(false)
	var cam: Camera3D = scene.camera
	# From the ice near the east boards, looking into the east stands.
	cam.fov = 42
	cam.position = Vector3(Arena.HALF_WIDTH - 6.0, 2.2, 14.0)
	cam.look_at(Vector3(Arena.HALF_WIDTH + 6.0, 4.6, 22.0))
	d.advance_crowd(3.0)
	await shot("/tmp/hawkey-crowd-seated.png")
	scene.celebration.celebrate(1.0, hud.team_colors[0], hud.team_names[0])
	scene.celebration.advance(0.6)
	d.advance_crowd(0.6)
	await shot("/tmp/hawkey-crowd-cheer-a.png")
	d.advance_crowd(0.13)
	await shot("/tmp/hawkey-crowd-cheer-b.png")
	# Broadcast-height view across the rink to the far (west) stands.
	cam.fov = 50
	cam.position = Vector3(Arena.HALF_WIDTH + 3.0, 9.0, 4.0)
	cam.look_at(Vector3(0, 1.0, 16.0))
	d.advance_crowd(0.1)
	await shot("/tmp/hawkey-crowd-broadcast.png")
	quit(0)
