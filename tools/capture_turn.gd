extends SceneTree
## Turning sheet: a skater driven round a circle (--radius=6 m, --speed=7 m/s)
## facing his travel, as match.gd does, so the turn lean and crossovers come
## from his own motion. Captures --frames=8 moments over one stride cycle
## from a fixed camera outside the circle and writes <out>-<n>.png
## (--out=, default /tmp/hawkey-turn); prints lean / crossover weight.
## --view=low looks from low, ahead and outside the turn (the crossovers).
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --resolution 640x640 --script tools/capture_turn.gd
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var out := "/tmp/hawkey-turn"
	var radius := 6.0
	var speed := 7.0
	var frames := 8
	var view := "front"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--view="): view = arg.substr(7)
		if arg.begins_with("--out="): out = arg.substr(6)
		if arg.begins_with("--radius="): radius = float(arg.substr(9))
		if arg.begins_with("--speed="): speed = float(arg.substr(8))
		if arg.begins_with("--frames="): frames = int(arg.substr(9))
	var scene = load("res://practice.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	for actor in [scene.player, scene.teammate] + scene.goalkeepers: actor.queue_free()
	scene.puck.visible = false
	scene.selection.visible = false
	scene.hud.get_parent().get_parent().visible = false
	var body := Node3D.new()
	scene.add_child(body)
	var v = load("res://scripts/skater_visual.gd").new()
	v.kit = Color("#185c73")
	v.number = "17"
	body.add_child(v)
	var ang := 0.0
	var dt := 1.0 / 120.0
	var w := speed / radius
	var cam: Camera3D = scene.camera
	var shot := 0
	var steps := 0
	while shot < frames:
		ang += w * dt
		body.position = Vector3(cos(ang) * radius, 0, sin(ang) * radius)
		var dir := Vector3(-sin(ang), 0, cos(ang))   # counter-clockwise travel
		v.rotation.y = atan2(-dir.x, -dir.z)
		v.animate(speed, dt, 0, true)
		steps += 1
		# After settling (2 s), shoot each 1/8 of a stride as he passes the camera.
		if steps > 240 and steps % 9 == 0:
			var p: Vector3 = body.position
			if view == "low":
				# Low, ahead and outside the turn: the skates cross over.
				var outward := Vector3(cos(ang), 0, sin(ang))
				cam.position = p + dir * 2.2 + outward * 1.6 + Vector3(0, 0.45, 0)
				cam.look_at(p + Vector3(0, 0.3, 0))
			else:
				cam.position = p + dir * 3.6 + Vector3(0, 0.9, 0)
				cam.look_at(p + Vector3(0, 0.7, 0))
			cam.fov = 45
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s-%d.png" % [out, shot])
			var mid: Vector3 = (v.feet[0] + v.feet[1]) * 0.5
			var head: Vector3 = v.posed_head
			print("TURN frame %d lean %.2f cross %.2f lat_acc %.1f  body angle %.1f deg (head x %.2f over feet)  feet x %.2f %.2f z %.2f %.2f" % [shot, v.turn_lean, v.cross_w, v.lat_acc, rad_to_deg(atan2(head.x - mid.x, head.y - mid.y)), head.x - mid.x, v.feet[0].x, v.feet[1].x, v.feet[0].z, v.feet[1].z])
			shot += 1
	quit()
