extends SceneTree
## Genuine engine inspection images; controlled scenarios, not live gameplay.
var m
var captures:Array=[]
var source_sha:=""
func _initialize()->void:call_deferred("run")
func shot(label:String)->void:
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	var path:="res://docs/screenshots/exhibition-polish-"+label+"-20261022.jpg"
	var error:=root.get_texture().get_image().save_jpg(path,0.95)
	captures.append({"path":path,"error":error})
	print("EXHIBITION_CAPTURE ",label," ",error)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source-sha="):source_sha=arg.trim_prefix("--source-sha=")
	root.size=Vector2i(960,600);root.content_scale_size=Vector2i(960,600)
	root.msaa_3d=Viewport.MSAA_DISABLED;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_DISABLED
	load("res://scripts/game_settings.gd").path="res://build/solo-polish-capture-settings.json"
	load("res://scripts/match.gd").skip_title=true
	m=load("res://main.tscn").instantiate();root.add_child(m);current_scene=m
	m.set_physics_process(false);m.set_process(false);m.puck.freeze=true;m.ai_vs_ai=true
	m.camera_mode=2;m.update_camera(1.0);m.update_match_hud()
	await shot("broadcast")
	m.hud_node.visible=false;m.selection.visible=false
	for actor in m.skaters:m.set_actor_active(actor,false)
	for keeper in m.goalkeepers:m.set_actor_active(keeper,false)
	var models:Array=[]
	for i in range(3):
		var v=load("res://scripts/skater_visual.gd").new()
		m.add_child(v);v.position=Vector3((i-1)*1.8,0,0);v.rotation.y=PI
		v.kit=Color("#17638f");v.set_nameplate(["FORWARD","BACKWARD","LATERAL"][i]);models.append(v)
		var motion:Vector3=[Vector3.BACK*5,Vector3.FORWARD*5,Vector3.RIGHT*5][i]
		for f in range(180):v.animate_motion(motion,1.0/120)
		v.phase=TAU*0.40;v.animate_motion(motion,0.0001)
	m.get_node("IceReflection").retag()
	m.camera.position=Vector3(1.1,2.1,7)
	m.camera.look_at(Vector3(0,0.8,0));m.camera.fov=42
	await shot("directional-footwork")
	# Same camera, geometry and lighting with reflections off/on: an A/B
	# for the imported reflection layer only, not a fabricated older build.
	for i in range(3):models[i].visible=i==1
	m.camera.position=Vector3(1.8,1.9,4.6)
	m.camera.look_at(Vector3(0,0.75,0));m.camera.fov=38
	var reflection=m.get_node("IceReflection")
	m.arena.set_reflection(reflection.viewport.get_texture(),0.0,reflection.BLUR)
	await shot("reflection-off")
	m.arena.set_reflection(reflection.viewport.get_texture(),reflection.strength(),reflection.BLUR)
	await shot("reflection-on")
	FileAccess.open("res://build/exhibition-polish-capture.json",FileAccess.WRITE).store_string(JSON.stringify({"source_sha":source_sha,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"source":"Actual production match and materials. Broadcast starts at opening faceoff. Footwork figures are controlled production visual instances sampled at the same stride phase. Reflection A/B toggles only reflection strength in this build; not an older-build comparison. Inspection stills, not gameplay footage.","captures":captures},"\t"))
	quit()
