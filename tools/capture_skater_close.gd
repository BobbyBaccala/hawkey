extends SceneTree
## Close-up of one skater's boot/leg join and stick, for equipment review.
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_skater_close.gd
## Writes /tmp/hawkey-skate-side.png, -skate-front.png, -stick.png, -full.png.
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
	var speed := 4.0
	var phase := 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--speed="): speed = float(arg.substr(8))
		if arg.begins_with("--phase="): phase = float(arg.substr(8))
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
	visual.number = "17"
	scene.add_child(visual)
	visual.position = Vector3(0, 0, 0)
	visual.rotation.y = -PI / 2      # skating toward +x
	for k in range(120): visual.animate(speed, 1.0 / 120, 0, speed > 0.5)
	visual.phase = phase
	visual.animate(speed, 0.0001, 0, speed > 0.5)
	var cam: Camera3D = scene.camera
	await shot(cam, Vector3(0.2, 0.35, 1.6), Vector3(0.0, 0.25, 0), 40, "/tmp/hawkey-skate-side.png")
	await shot(cam, Vector3(1.6, 0.4, 0.3), Vector3(0.0, 0.25, 0), 40, "/tmp/hawkey-skate-front.png")
	var blade: Vector3 = visual.get_blade_world()
	await shot(cam, blade + Vector3(-0.6, 0.9, 1.6), (blade + Vector3(0, 0.8, 0) + visual.global_position + Vector3(0, 0.8, 0)) * 0.5, 50, "/tmp/hawkey-stick.png")
	await shot(cam, Vector3(1.2, 1.0, 2.6), Vector3(0, 0.75, 0), 45, "/tmp/hawkey-full.png")
	quit()
