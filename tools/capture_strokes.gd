extends SceneTree
## Frame sheets of the skater stick strokes (stroke_anim.gd): each stroke is
## played from the skating stance and captured at evenly spaced moments
## (--frames=N, default 6) from a front three-quarter camera on the forehand
## side, plus one side view at the release. Writes
## <out>-<kind>-<n>.png (--out=<prefix>, default /tmp/hawkey-stroke);
## --only=<kind> limits it to one stroke. Assemble with tools/stroke_sheet.py.
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --resolution 640x640 --script tools/capture_strokes.gd
const StrokeAnim = preload("res://scripts/stroke_anim.gd")
func _initialize() -> void: call_deferred("run")

func snap(cam: Camera3D, pos: Vector3, at: Vector3, path: String) -> void:
	cam.position = pos
	cam.look_at(at)
	cam.fov = 42
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var out := "/tmp/hawkey-stroke"
	var frames := 6
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.substr(6)
		if arg.begins_with("--frames="): frames = int(arg.substr(9))
		if arg.begins_with("--only="): only = arg.substr(7)
	var scene = load("res://practice.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	for actor in [scene.player, scene.teammate] + scene.goalkeepers: actor.queue_free()
	scene.selection.visible = false
	scene.hud.get_parent().get_parent().visible = false
	var visual = load("res://scripts/skater_visual.gd").new()
	visual.kit = Color("#185c73")
	visual.number = "17"
	scene.add_child(visual)
	visual.position = Vector3.ZERO
	visual.rotation.y = -PI / 2      # facing +x
	var cam: Camera3D = scene.camera
	var puck: Node3D = scene.puck
	puck.freeze = true
	for kind in StrokeAnim.library().keys():
		if only != "" and kind != only: continue
		for k in range(60): visual.animate(0.0, 1.0 / 60, 0, false)
		visual.play_stroke(kind)
		var dur := StrokeAnim.duration(kind)
		var t := 0.0
		for n in range(frames):
			var want := dur * n / float(frames - 1) * 0.92
			while t < want - 0.0001:
				var step := minf(1.0 / 120.0, want - t)
				visual.animate(0.0, step, 0, false)
				t += step
			puck.global_position = visual.get_puck_world() + Vector3(0, 0.0254, 0)
			if StrokeAnim.release_at(kind) >= 0.0 and t > StrokeAnim.release_at(kind): puck.global_position = Vector3(0, -5, 0)
			await snap(cam, Vector3(2.0, 1.15, 1.45), Vector3(0.35, 0.7, 0.0), "%s-%s-%d.png" % [out, kind, n])
	print("STROKES written ", out)
	quit()
