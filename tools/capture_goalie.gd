extends SceneTree
## Goalie close-ups: ready stance (front, back, glove side, blocker side) and
## butterfly (front), one goalie per shot. Writes <out>-<name>.png
## (default /tmp/hawkey-goalie-<name>.png). Options: --out=<prefix>
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_goalie.gd
func _initialize()->void:call_deferred("run")
func run()->void:
	var out:="/tmp/hawkey-goalie"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.substr(6)
	var scene=load("res://practice.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	for actor in [scene.player,scene.teammate]+scene.goalkeepers:actor.queue_free()
	scene.puck.visible=false
	scene.selection.visible=false
	scene.hud.get_parent().get_parent().visible=false
	var v=load("res://scripts/skater_visual.gd").new()
	v.goalie=true
	v.kit=Color("#b3162c")
	v.accent=Color("#1b2a4a")
	v.number="31"
	v.nameplate_text="HOLT"
	scene.add_child(v)
	v.rotation.y=PI
	# [name, save kind, target, camera position, look-at, fov]
	var shots:=[
		["front","",Vector2(0,0.8),Vector3(0.0,1.15,2.6),Vector3(0,0.85,0),46.0],
		["back","",Vector2(0,0.8),Vector3(0.3,1.35,-2.5),Vector3(0,0.9,0),46.0],
		["glove","",Vector2(0,0.8),Vector3(-2.0,1.1,1.5),Vector3(0,0.85,0),44.0],
		["blocker","",Vector2(0,0.8),Vector3(2.0,1.1,1.5),Vector3(0,0.85,0),44.0],
		["butterfly","butterfly",Vector2(0.1,0.15),Vector3(0.4,1.0,2.6),Vector3(0,0.55,0),46.0],
		["legs-front","",Vector2(0,0.8),Vector3(0.0,0.55,1.9),Vector3(0,0.42,0),44.0],
		["legs-side","",Vector2(0,0.8),Vector3(1.9,0.5,0.25),Vector3(0,0.42,0),44.0],
		["legs-back","",Vector2(0,0.8),Vector3(0.5,0.6,-1.8),Vector3(0,0.42,0),44.0],
		["legs-bfly","butterfly",Vector2(0.1,0.15),Vector3(1.3,0.8,1.6),Vector3(0,0.3,0),44.0],
		["catch","glove",Vector2(0.75,1.35),Vector3(-1.2,1.3,2.3),Vector3(-0.2,0.95,0),46.0],
	]
	var only:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):only=arg.substr(7)
	for s in shots:
		if only!="" and not String(s[0]).begins_with(only):continue
		var kind:String=s[1]
		for k in range(90):
			v.butterfly=move_toward(v.butterfly,1.0 if kind in ["butterfly","pad_left","pad_right"] else 0.0,6.0/60)
			v.set_save(kind,s[2],1.0/60)
			v.animate(0,1.0/60,0,false)
		scene.camera.position=s[3]
		scene.camera.look_at(s[4])
		scene.camera.fov=s[5]
		for k in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("%s-%s.png" % [out,s[0]])
	quit()
