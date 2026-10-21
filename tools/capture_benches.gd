extends SceneTree
## Bench and penalty-box review renders:
##  bench  - from the ice, looking at the home bench (west side)
##  benches - wide from centre ice across both benches
##  box    - penalty boxes and officials' booth (east), one road player seated
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_benches.gd
## Writes /tmp/hawkey-bench-<name>.png.
const Arena = preload("res://scripts/arena.gd")
func _initialize() -> void: call_deferred("run")

func shot(cam: Camera3D, pos: Vector3, look: Vector3, fov: float, path: String) -> void:
	cam.fov = fov
	cam.position = pos
	cam.look_at(look)
	cam.cull_mask = preload("res://scripts/arena_lighting.gd").camera_cull_mask(pos)
	for i in range(4): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	for i in range(3): await physics_frame
	scene.set_physics_process(false)
	scene.set_process(false)
	for s in scene.skaters: s.visible = false
	for g in scene.goalkeepers: g.visible = false
	scene.puck.visible = false
	var hud = scene.get("hud_node")
	if hud: hud.visible = false
	var benches = scene.arena.get_node("Benches")
	benches.set_penalty_count(1, 1)
	var cam: Camera3D = scene.camera
	var w := Arena.HALF_WIDTH
	await shot(cam, Vector3(-w + 6.0, 2.0, -11.0), Vector3(-w - 1.5, 0.8, -5.0), 45, "/tmp/hawkey-bench-bench.png")
	await shot(cam, Vector3(2.0, 6.0, 0.0), Vector3(-w - 1.0, 0.6, 0.0), 55, "/tmp/hawkey-bench-benches.png")
	await shot(cam, Vector3(w - 5.5, 2.2, 7.5), Vector3(w + 1.4, 0.8, 1.5), 48, "/tmp/hawkey-bench-box.png")
	print("bench capture done")
	quit()
