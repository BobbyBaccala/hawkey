extends SceneTree
## Close-up of one skater's boot/leg join and stick, for equipment review.
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_skater_close.gd
## Writes /tmp/hawkey-skate-side.png, -skate-front.png, -stick.png, -full.png,
## -torso.png, -torso-back.png, -helmet.png, -glove.png, -front.png
## (--out=<prefix> replaces /tmp/hawkey).
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
	var out := "/tmp/hawkey"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--speed="): speed = float(arg.substr(8))
		if arg.begins_with("--phase="): phase = float(arg.substr(8))
		if arg.begins_with("--out="): out = arg.substr(6)
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
	visual.set_nameplate("Larsen")
	visual.position = Vector3(0, 0, 0)
	visual.rotation.y = -PI / 2      # skating toward +x
	for k in range(120): visual.animate(speed, 1.0 / 120, 0, speed > 0.5)
	visual.phase = phase
	visual.animate(speed, 0.0001, 0, speed > 0.5)
	var cam: Camera3D = scene.camera
	await shot(cam, Vector3(0.2, 0.35, 1.6), Vector3(0.0, 0.25, 0), 40, out + "-skate-side.png")
	await shot(cam, Vector3(1.6, 0.4, 0.3), Vector3(0.0, 0.25, 0), 40, out + "-skate-front.png")
	var blade: Vector3 = visual.get_blade_world()
	await shot(cam, blade + Vector3(-0.6, 0.9, 1.6), (blade + Vector3(0, 0.8, 0) + visual.global_position + Vector3(0, 0.8, 0)) * 0.5, 50, out + "-stick.png")
	await shot(cam, Vector3(1.2, 1.0, 2.6), Vector3(0, 0.75, 0), 45, out + "-full.png")
	# Kit geometry close-ups: torso (front three-quarter and back), helmet, glove.
	var chest: Vector3 = visual.to_global(visual.rig.transform * visual.torso_pose.origin)
	var head: Vector3 = visual.helmet.global_position
	await shot(cam, chest + Vector3(0.9, 0.15, 0.75), chest + Vector3(0, -0.12, 0), 42, out + "-torso.png")
	await shot(cam, chest + Vector3(-0.9, 0.35, -0.7), chest + Vector3(0, -0.12, 0), 42, out + "-torso-back.png")
	await shot(cam, head + Vector3(0.45, 0.06, 0.32), head + Vector3(0, -0.05, 0), 35, out + "-helmet.png")
	var glove: Vector3 = visual.skater_gloves[0].global_position
	await shot(cam, glove + Vector3(0.35, 0.18, 0.35), glove, 35, out + "-glove.png")
	await shot(cam, Vector3(2.6, 1.1, 0.2), Vector3(0, 0.8, 0), 40, out + "-front.png")
	# Blade and hosel: forehand side, low, and from above the toe.
	var heel_w: Vector3 = visual.stick_blade.global_transform * Vector3(-visual.stick_blade_length * 0.48, 0, 0)
	var fore: Vector3 = -visual.stick_blade.global_basis.z
	await shot(cam, heel_w + fore * 0.55 + Vector3(0, 0.22, 0) + visual.stick_blade.global_basis.x * 0.12, heel_w + visual.stick_blade.global_basis.x * 0.10 + Vector3(0, 0.05, 0), 38, out + "-blade.png")
	await shot(cam, heel_w + visual.stick_blade.global_basis.x * 0.75 + Vector3(0, 0.30, 0) + fore * 0.25, heel_w + Vector3(0, 0.04, 0), 40, out + "-blade-toe.png")
	quit()
