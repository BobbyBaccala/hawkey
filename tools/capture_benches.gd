extends SceneTree
## Bench and penalty-box review renders:
##  bench  - from the ice, looking at the home bench (west side)
##  benches - wide from centre ice across both benches
##  box    - penalty boxes and officials' booth (east), one road player seated
##  cheer  - home bench standing after a goal, road bench slumped
##  backs  - from behind the home bench (back numbers)
##  goout  - line change: one home player up off the seat, stick raised, to go out
##  walk   - the player who came off walking from his landing spot to the free
##           seat (walk1 just after landing, walk2 turning round at the seat)
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
	benches.set_process(false)
	benches.set_penalty_count(1, 1)
	var cam: Camera3D = scene.camera
	var w := Arena.HALF_WIDTH
	await shot(cam, Vector3(-w + 6.0, 2.0, -11.0), Vector3(-w - 1.5, 0.8, -5.0), 45, "/tmp/hawkey-bench-bench.png")
	await shot(cam, Vector3(2.0, 6.0, 0.0), Vector3(-w - 1.0, 0.6, 0.0), 55, "/tmp/hawkey-bench-benches.png")
	await shot(cam, Vector3(w - 5.5, 2.2, 7.5), Vector3(w + 1.4, 0.8, 1.5), 48, "/tmp/hawkey-bench-box.png")
	# Line change: a home player gets up to go out (arena_benches.gd stand_up()).
	benches.watch_target = Vector3(0, 0, 20)
	benches.stand_up(0, 5.0)
	for i in range(80): benches.update_figures(1.0 / 60.0)
	await shot(cam, Vector3(-w + 5.0, 1.9, 9.5), Vector3(-w - 1.6, 0.9, 4.0), 50, "/tmp/hawkey-bench-goout.png")
	# The player coming off lands at z 5 and walks to the free seat.
	benches.go_out(0, "45", Vector3(-w - 0.85, 0, 5.0), Vector3(-1, 0, 0))
	for i in range(25): benches.update_figures(1.0 / 60.0)
	await shot(cam, Vector3(-w + 4.0, 2.4, 8.5), Vector3(-w - 1.4, 0.8, 4.6), 50, "/tmp/hawkey-bench-walk1.png")
	for i in range(30): benches.update_figures(1.0 / 60.0)
	await shot(cam, Vector3(-w + 4.0, 2.4, 8.5), Vector3(-w - 1.4, 0.8, 4.6), 50, "/tmp/hawkey-bench-walk2.png")
	for i in range(260): benches.update_figures(1.0 / 60.0)
	# Goal reaction: home bench on its feet, arms up; road bench slumped.
	benches.watch_target = Vector3(0, 0, 20)
	for i in range(120): benches.update_figures(1.0 / 60.0)
	benches.celebrate(0)
	for i in range(70): benches.update_figures(1.0 / 60.0)
	await shot(cam, Vector3(-w + 6.5, 2.2, 0.0), Vector3(-w - 1.5, 0.9, 0.0), 62, "/tmp/hawkey-bench-cheer.png")
	await shot(cam, Vector3(-w - 2.55, 2.3, 1.6), Vector3(-w - 1.7, 0.7, 5.0), 60, "/tmp/hawkey-bench-backs.png")
	print("bench capture done")
	quit()
