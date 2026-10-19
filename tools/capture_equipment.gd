extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://practice.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	for actor in [scene.player,scene.teammate]+scene.goalkeepers:actor.queue_free()
	scene.puck.freeze=true
	scene.puck.visible=false
	scene.selection.visible=false
	scene.hud.get_parent().get_parent().visible=false
	var closeup:bool="--goalie-closeup" in OS.get_cmdline_user_args()
	var skater_closeup:bool="--skater-closeup" in OS.get_cmdline_user_args()
	var positions:=[-2.7,-0.9,0.9,2.7]
	var labels:=["SKATER • READY","SKATER • SIDE","GOALIE • READY","GOALIE • BUTTERFLY"]
	for i in range(4):
		if closeup and i<2:continue
		if skater_closeup and i>=2:continue
		if closeup:positions[i]= -0.95 if i==2 else 0.95
		if skater_closeup:positions[i]= -0.75 if i==0 else 0.75
		var visual=load("res://scripts/skater_visual.gd").new()
		visual.goalie=i>=2
		visual.kit=Color("#185c73")
		visual.number="31" if i>=2 else "17"
		scene.add_child(visual)
		visual.position=Vector3(positions[i],0,0)
		visual.rotation.y=PI if i!=1 else -PI/2
		visual.butterfly=1 if i==3 else 0
		visual.animate(0,1)
		var label:=Label3D.new()
		label.text=labels[i]
		label.font_size=32
		label.pixel_size=0.002
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.position=Vector3(positions[i],0.02,1)
		scene.add_child(label)
	scene.camera.position=Vector3(0,1.7,3.7) if closeup or skater_closeup else Vector3(0,2.7,7.8)
	scene.camera.look_at(Vector3(0,0.65,0))
	scene.camera.fov=42
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("/tmp/hawkey-goalie-closeup.png" if closeup else ("/tmp/hawkey-skater-closeup.png" if skater_closeup else "/tmp/hawkey-gear-review.png"))
	quit()
