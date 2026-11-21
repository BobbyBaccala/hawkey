extends SceneTree
## Renders captured-motion poses (needs the Mixamo clips in assets/mixamo/):
## goalie idle, goalie mid-shuffle, skater celebration at two moments.
## xvfb-run godot --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_mocap.gd
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://practice.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	for actor in [scene.player, scene.teammate] + scene.goalkeepers:
		actor.queue_free()
	scene.puck.visible = false
	scene.selection.visible = false
	scene.hud.get_parent().get_parent().visible = false
	var Visual = load("res://scripts/skater_visual.gd")
	var labels := ["GOALIE • CAPTURED IDLE", "GOALIE • SHUFFLE", "SKATER • CELEBRATION 0.8s", "SKATER • CELEBRATION 1.6s"]
	var visuals := []
	for i in range(4):
		var v = Visual.new()
		v.goalie = i < 2
		v.kit = Color("#185c73")
		v.number = "31" if i < 2 else "17"
		scene.add_child(v)
		v.position = Vector3(-2.7 + i * 1.8, 0, 0)
		v.rotation.y = PI
		visuals.append(v)
		var label := Label3D.new()
		label.text = labels[i]
		label.font_size = 32
		label.pixel_size = 0.002
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(-2.7 + i * 1.8, 0.02, 1)
		scene.add_child(label)
	await process_frame
	visuals[2].play_mocap("Standing_Cheering", false, ["spine", "arms", "stick_up"])
	visuals[3].play_mocap("Standing_Cheering", false, ["spine", "arms", "stick_up"])
	for f in range(96):
		var dt := 1.0 / 60
		visuals[0].animate(0, dt)
		# Slide the second goalie sideways and back to the same spot.
		visuals[1].position.x += (2.2 if f < 48 else -2.2) * dt
		visuals[1].animate(0, dt)
		if f < 48:
			visuals[2].animate(0, dt)
		visuals[3].animate(0, dt)
	scene.camera.position = Vector3(0, 2.0, 6.4)
	scene.camera.look_at(Vector3(0, 0.85, 0))
	scene.camera.fov = 42
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("/tmp/hawkey-mocap-review.png")
	quit()
