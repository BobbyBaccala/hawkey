extends SceneTree
## Goalie save sheet: ready stance and each save type, posed by the same
## blend the match uses. Writes /tmp/hawkey-goalie-saves-<row>.png.
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://practice.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	for actor in [scene.player,scene.teammate]+scene.goalkeepers:actor.queue_free()
	scene.puck.visible=false
	scene.selection.visible=false
	scene.hud.get_parent().get_parent().visible=false
	var shots:=[["READY","",Vector2(0,0.8)],["BUTTERFLY","butterfly",Vector2(0.1,0.15)],["GLOVE HIGH","glove",Vector2(0.75,1.35)],["BLOCKER","blocker",Vector2(-0.7,0.95)],["PAD LEFT","pad_left",Vector2(0.95,0.1)],["PAD RIGHT","pad_right",Vector2(-0.95,0.1)],["WIDE LOW, GLOVE SIDE","auto",Vector2(1.15,0.1)],["WIDE LOW, BLOCKER SIDE","auto",Vector2(-1.15,0.1)]]
	# --row=0 (ready, butterfly, glove), --row=1 (blocker, pad left, pad right)
	# or --row=2 (low shots past the pad reach; "auto" = the save choose_save picks)
	var row:=0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--row="):row=int(arg.substr(6))
	shots=shots.slice(row*3,row*3+3)
	for i in range(shots.size()):
		var v=load("res://scripts/skater_visual.gd").new()
		v.goalie=true
		v.kit=Color("#b3162c")
		v.accent=Color("#1b2a4a")
		v.number="31"
		scene.add_child(v)
		# The splits spans ~2 m, so that row is spaced wider.
		v.position=Vector3((i-0.5)*2.9,0,0) if row==2 else Vector3((i-1)*2.1,0,0)
		v.rotation.y=PI
		var kind:String=shots[i][1]
		if kind=="auto": kind=v.choose_save(shots[i][2].x,shots[i][2].y)
		for k in range(90):
			v.butterfly=move_toward(v.butterfly,1.0 if kind in ["butterfly","pad_left","pad_right"] else 0.0,6.0/60)
			v.set_save(kind,shots[i][2],1.0/60)
			v.animate(0,1.0/60,0,false)
		var label:=Label3D.new()
		label.text=shots[i][0]
		label.font_size=40
		label.pixel_size=0.003
		label.outline_size=8
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.position=v.position+Vector3(0,1.45,0)
		scene.add_child(label)
	scene.camera.position=Vector3(0,1.5,4.2)
	scene.camera.look_at(Vector3(0,0.6,0))
	scene.camera.fov=55
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("/tmp/hawkey-goalie-saves-%d.png" % row)
	quit()
