extends SceneTree
## Stride review: skaters frozen at points through the stride cycle, seen from
## the side (top row) and from behind (bottom row). Optional --speed=<m/s>.
## xvfb-run ... godot --rendering-method gl_compatibility --script tools/capture_stride.gd
## Writes /tmp/hawkey-stride-review.png.
func _initialize()->void:call_deferred("run")
func run()->void:
	var speed:=7.0
	var glide:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--speed="):speed=float(arg.substr(8))
		if arg=="--glide":glide=true
	var scene=load("res://practice.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	for actor in [scene.player,scene.teammate]+scene.goalkeepers:actor.queue_free()
	scene.puck.freeze=true
	scene.puck.visible=false
	scene.selection.visible=false
	scene.hud.get_parent().get_parent().visible=false
	var count:=5
	for row in range(2):
		for i in range(count):
			var visual=load("res://scripts/skater_visual.gd").new()
			visual.kit=Color("#185c73")
			visual.number="17"
			scene.add_child(visual)
			visual.position=Vector3((i-(count-1)*0.5)*1.7,0,row*-3.5)
			# Top row faces right (side view); bottom row skates away from camera.
			visual.rotation.y=-PI/2 if row==0 else PI
			# Settle into the stride, then step to this point of the cycle.
			for k in range(120):visual.animate(speed,1.0/120,0,not glide)
			visual.phase=float(i)/count*TAU
			visual.animate(speed,0.0001,0,not glide)
	scene.camera.position=Vector3(0,2.6,6.5)
	scene.camera.look_at(Vector3(0,0.5,-1.6))
	scene.camera.fov=52
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("/tmp/hawkey-stride-review.png")
	quit()
