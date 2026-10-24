extends SceneTree
## Hockey-stop review: a skater cruises at speed across a low broadcast-style
## camera, brakes hard, and is captured at several moments of the stop (snow
## spray, skid pose, recovery). Run with a fixed frame rate so particles and
## the pose advance together:
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1728x1080 --fixed-fps 60 --script tools/capture_stop.gd
## Writes /tmp/hawkey-stop-<ms>.png for each capture moment.
const DT := 1.0 / 60
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var speed := 8.5
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--speed="): speed = float(arg.substr(8))
	var scene = load("res://practice.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	for actor in [scene.player, scene.teammate] + scene.goalkeepers: actor.queue_free()
	scene.puck.freeze = true
	scene.puck.visible = false
	scene.selection.visible = false
	scene.hud.get_parent().get_parent().visible = false
	var visual = load("res://scripts/skater_visual.gd").new()
	visual.kit = Color("#185c73")
	visual.number = "17"
	scene.add_child(visual)
	# Skates toward +x (camera right), facing the travel.
	visual.rotation.y = -PI / 2
	var start := Vector3(-14.0, 0, -2.0)
	visual.position = start
	var cam: Camera3D = scene.camera
	cam.fov = 38
	# Software GL is slow: simulate with rendering off, draw only the captures.
	RenderingServer.render_loop_enabled = false
	# Cruise in.
	for f in range(150):
		visual.position.x += speed * DT
		visual.animate(speed, DT, 0, true, false)
		await process_frame
	# Brake (Ctrl: 22 m/s^2) and capture moments through the stop.
	var shots := [0.15, 0.22, 0.30, 0.40, 0.55, 1.4]
	var t := 0.0
	var v := speed
	var stop_at: Vector3 = visual.position + Vector3(v * v / 44.0, 0, 0)
	# Low broadcast-ish angle, a little ahead of the stop so the spray comes
	# toward the camera.
	cam.position = stop_at + Vector3(2.6, 1.05, 4.2)
	cam.look_at(stop_at + Vector3(-0.2, 0.5, 0))
	while not shots.is_empty():
		v = maxf(0.0, v - 22.0 * DT)
		visual.position.x += v * DT
		visual.animate(v, DT, 0, true, v > 0.0)
		t += DT
		await process_frame
		if t >= shots[0] - 0.001:
			RenderingServer.render_loop_enabled = true
			await RenderingServer.frame_post_draw
			RenderingServer.render_loop_enabled = false
			var path := "/tmp/hawkey-stop-%03d.png" % int(round(shots[0] * 100))
			root.get_texture().get_image().save_png(path)
			print("stop capture ", path, " speed %.1f weight %.2f spraying %s" % [v, visual.stop_weight, visual.sprays[0].is_spraying() or visual.sprays[1].is_spraying()])
			shots.pop_front()
	quit()
