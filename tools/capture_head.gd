extends SceneTree
## Head / helmet / neck close-ups of one figure, four angles in one sheet.
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_head.gd -- [--no-helmet] [--goalie|--referee] [--number=17] [--out=/tmp/hawkey-head]
## Writes <out>-0.png .. -3.png (three-quarter, side, back, front).
func _initialize() -> void: call_deferred("run")

func shot(cam: Camera3D, pos: Vector3, at: Vector3, fov: float, path: String) -> void:
	cam.position = pos
	cam.look_at(at)
	cam.fov = fov
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var out := "/tmp/hawkey-head"
	var args := OS.get_cmdline_user_args()
	var number := "17"
	for arg in args:
		if arg.begins_with("--out="): out = arg.substr(6)
		if arg.begins_with("--number="): number = arg.substr(9)
	var scene = load("res://practice.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	for actor in [scene.player, scene.teammate] + scene.goalkeepers: actor.queue_free()
	scene.puck.visible = false
	scene.selection.visible = false
	scene.hud.get_parent().get_parent().visible = false
	var visual = load("res://scripts/skater_visual.gd").new()
	visual.kit = Color("#185c73")
	visual.number = number
	visual.goalie = "--goalie" in args
	visual.referee = "--referee" in args
	scene.add_child(visual)
	visual.rotation.y = -PI / 2      # facing +x
	for k in range(120): visual.animate(4.0, 1.0 / 120, 0, true)
	visual.animate(4.0, 0.0001, 0, true)
	if "--no-helmet" in args: visual.helmet.visible = false
	if "--no-guard" in args and visual.neck_guard: visual.neck_guard.visible = false
	if "--no-jersey" in args: visual.jersey.visible = false
	if "--no-head" in args:
		for n in visual.head_nodes: n.visible = false
	var cam: Camera3D = scene.camera
	var head: Vector3 = visual.helmet.global_position + Vector3(0, -0.06, 0)
	await shot(cam, head + Vector3(0.45, 0.06, 0.32), head, 35, out + "-0.png")
	await shot(cam, head + Vector3(0.02, 0.05, 0.55), head, 35, out + "-1.png")
	await shot(cam, head + Vector3(-0.5, 0.22, -0.2), head, 35, out + "-2.png")
	await shot(cam, head + Vector3(0.55, 0.02, -0.03), head, 35, out + "-3.png")
	quit()
