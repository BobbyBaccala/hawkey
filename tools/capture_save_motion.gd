extends SceneTree
## Save motion: one save from the ready stance and back, sampled from the
## live per-frame update at 60 fps (no settling). Writes <out>-strip.png (a
## frame every STEP updates, left to right) and prints, per frame, the save
## weight and the speed of the moving hand/foot so the shape of the motion
## (snap in, settle, ease back) can be compared run to run.
## Options: --out=<prefix> --save=<kind> --x=<crossing x> --y=<height>
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_save_motion.gd -- --save=glove
const STEP := 3
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var out := "/tmp/hawkey-save-motion"
	var kind := "glove"
	var target := Vector2(0.75, 1.35)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.substr(6)
		if arg.begins_with("--save="): kind = arg.substr(7)
		if arg.begins_with("--x="): target.x = float(arg.substr(4))
		if arg.begins_with("--y="): target.y = float(arg.substr(4))
	var scene = load("res://practice.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	for actor in [scene.player, scene.teammate] + scene.goalkeepers: actor.queue_free()
	scene.puck.visible = false
	scene.selection.visible = false
	scene.hud.get_parent().get_parent().visible = false
	var v = load("res://scripts/skater_visual.gd").new()
	v.goalie = true
	v.kit = Color("#b3162c")
	v.accent = Color("#1b2a4a")
	v.number = "31"
	scene.add_child(v)
	v.rotation.y = PI
	for k in range(60):
		v.set_save("", Vector2(0, 0.8), 1.0 / 60)
		v.animate(0, 1.0 / 60, 0, false)
	scene.camera.position = Vector3(0.2, 1.1, 3.0)
	scene.camera.look_at(Vector3(0, 0.75, 0))
	scene.camera.fov = 52
	var down: bool = kind in ["butterfly", "pad_left", "pad_right"]
	var tiles: Array[Image] = []
	var last := Vector3.INF
	var peak := 0.0
	# 30 frames into the save, then 40 frames of recovery.
	for f in range(70):
		var active := f < 30
		v.butterfly = move_toward(v.butterfly, 1.0 if active and down else 0.0, (6.0 if active else 2.0) / 60)
		v.set_save(kind if active else "", target if active else v.save_target, 1.0 / 60)
		v.animate(0, 1.0 / 60, 0, false)
		var hand: Vector3 = v.goalie_gloves[0].global_position if kind != "blocker" else v.goalie_gloves[1].global_position
		if kind.begins_with("pad") or kind.begins_with("splits") or kind.begins_with("stack"):
			hand = v.skates[0 if kind.ends_with("left") else 1].global_position
		var speed := 0.0 if last == Vector3.INF else hand.distance_to(last) * 60.0
		last = hand
		peak = maxf(peak, speed)
		var w: float = v.save_weights[kind] if v.save_weights.has(kind) else v.butterfly
		print("F %02d w=%.3f speed=%.2f m/s" % [f, w, speed])
		if f % STEP == 0 and f < 45:
			await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.resize(img.get_width() / 3, img.get_height() / 3)
			tiles.append(img)
	print("PEAK_SPEED %.2f m/s" % peak)
	var tw := tiles[0].get_width()
	var th := tiles[0].get_height()
	var cols := 5
	var sheet := Image.create(tw * cols, th * ((tiles.size() + cols - 1) / cols), false, tiles[0].get_format())
	for i in range(tiles.size()):
		sheet.blit_rect(tiles[i], Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
	sheet.save_png(out + "-strip.png")
	quit()
