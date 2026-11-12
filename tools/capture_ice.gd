extends SceneTree
## Skate-cut review: plays the live match with rendering paused (fast) so cuts
## build up, then renders a close and a broadcast-height view of the ice.
## xvfb-run ... godot --rendering-method gl_compatibility --script tools/capture_ice.gd -- --seconds=40
## Writes /tmp/hawkey-ice-close.png and /tmp/hawkey-ice-wide.png.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var seconds := 40.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="): seconds = float(arg.substr(10))
	var packed: PackedScene = load("res://main.tscn")
	var scene = packed.instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	await physics_frame
	scene.match_state.phase_timer = 0.3
	RenderingServer.render_loop_enabled = false
	var frames := int(seconds * 120)
	for i in range(frames):
		await physics_frame
		if i % 2 == 0: await process_frame
	RenderingServer.render_loop_enabled = true
	scene.ice_marks.flush()
	scene.set_physics_process(false)
	scene.set_process(false)
	var cam: Camera3D = scene.camera
	var focus := Vector3(0, 0, 0)
	# Close: about what a low broadcast/zoomed camera sees around centre ice.
	cam.position = focus + Vector3(0, 4.5, 6.5)
	cam.look_at(focus + Vector3(0, 0, -1.5))
	cam.fov = 55
	for i in range(3): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/hawkey-ice-close.png")
	cam.position = Vector3(0, 16, 22)
	cam.look_at(Vector3(0, 0, -2))
	cam.fov = 50
	for i in range(3): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/hawkey-ice-wide.png")
	print("ice capture: ", scene.ice_marks.cut_texels, " cut texels")
	quit()
