extends SceneTree
## Backward-skating review (linesman C-cuts, skater_visual.gd back_skate):
## officials frozen at five points through the C-cut cycle, seen from behind
## (near row) and from the front, as the dot sees him backing away (far row).
## Optional --speed=<m/s>.
## xvfb-run ... godot --rendering-method gl_compatibility --script tools/capture_backskate.gd
## Writes /tmp/hawkey-backskate-review.png.
func _initialize()->void:call_deferred("run")
func run()->void:
	var speed:=2.4
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--speed="):speed=float(arg.substr(8))
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
			visual.referee=true
			visual.kit=Color("#11171e")
			visual.number=""
			scene.add_child(visual)
			visual.position=Vector3((i-(count-1)*0.5)*1.7,0,row*-3.5)
			# Near row faces away from the camera; far row faces it.
			visual.rotation.y=0.0 if row==0 else PI
			visual.back_skate_target=1.0
			for k in range(120):visual.animate(speed,1.0/120,0,false)
			visual.back_phase=float(i)/count*TAU
			visual.animate(speed,0.0001,0,false)
	scene.camera.position=Vector3(0,3.4,6.0)
	scene.camera.look_at(Vector3(0,0.3,-1.6))
	scene.camera.fov=52
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("/tmp/hawkey-backskate-review.png")
	quit()
