extends SceneTree
## Inspection scenarios in the real match. These are labeled posed previews,
## not a new gameplay recording. No generated or retouched imagery.
var m
var samples:Array=[]
func _initialize()->void:call_deferred("run")
func capture(label:String)->void:
	for i in range(3):await process_frame
	await RenderingServer.frame_post_draw
	var path:="res://docs/screenshots/video-fix-"+label+"-20261021.jpg"
	var result:=root.get_texture().get_image().save_jpg(path,0.95)
	samples.append({"image":path,"result":result})
	print("VIDEO_FIX_CAPTURE ",label," ",result)
func run()->void:
	root.size=Vector2i(960,600);root.content_scale_size=Vector2i(960,600)
	root.msaa_3d=Viewport.MSAA_DISABLED
	load("res://scripts/game_settings.gd").path="res://build/video-fix-capture-settings.json"
	load("res://scripts/match.gd").skip_title=true
	m=load("res://main.tscn").instantiate();root.add_child(m);current_scene=m
	m.set_physics_process(false);m.set_process(false)
	m.hud_node.visible=false;m.selection.visible=false;m.puck.freeze=true
	var keeper=m.goalkeepers[0]
	m.puck.position=Vector3(0,0.03,-m.Arena.GOAL_LINE-2)
	for i in range(60):m.update_goalkeepers(1.0/60)
	m.camera.position=Vector3(3.2,2.6,-29.5)
	m.camera.look_at(keeper.position+Vector3.UP*0.75);m.camera.fov=48
	await capture("behind-net")
	var actor=m.player;var v=actor.get_child(1)
	for other in m.skaters:
		if other!=actor:m.set_actor_active(other,false)
	actor.position=Vector3.ZERO;v.rotation.y=0
	m.camera.position=Vector3(-3.1,1.8,-3.8)
	m.camera.look_at(Vector3(0,0.95,0.2));m.camera.fov=34
	v.animate(0,1.0/60,0,false)
	await capture("ready")
	for kind in ["pass","shot","slap"]:
		m.puck.position=v.get_blade_world()
		if kind=="pass":m.release_puck(actor,Vector3.FORWARD,17)
		else:m.emit_net_shot(actor,Vector2.ZERO,kind=="slap")
		for i in range(24):v.animate(0,v.release_duration*0.28/24,0,false)
		await capture(kind)
		for i in range(120):v.animate(0,1.0/120,0,false)
	FileAccess.open("res://build/video-fix-capture.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"source":"Production main.tscn inspection scenarios: puck placed behind goal; normal pass/shot release functions sampled at follow-through peak. Frozen camera, HUD hidden; not continuous gameplay.","captures":samples},"\t"))
	quit()
