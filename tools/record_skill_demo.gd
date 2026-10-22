extends SceneTree
## Scripted training inputs; production skating, animation and rigid-body puck.
## Never a substitute for an unstaged AI exhibition.
var m
var actor
var frames:=0
var ticks:=0
var started:=false
var samples:Array=[]
var prefix:="/workspace/hawkey/build/skills-demo"
var source_sha:="working-tree"
var shoots:="R"
var hands_camera:=false
var inspection_camera:=false
func _initialize()->void:call_deferred("run")
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source-sha="):source_sha=arg.trim_prefix("--source-sha=")
		if arg.begins_with("--shoots="):shoots=arg.trim_prefix("--shoots=")
		if arg=="--hands-camera":hands_camera=true
		if arg=="--inspection-camera":inspection_camera=true
		if arg.begins_with("--prefix="):prefix=arg.trim_prefix("--prefix=")
	load("res://scripts/game_settings.gd").path="res://build/skills-demo-settings.json"
	load("res://scripts/match.gd").skip_title=true
	root.size=Vector2i(960,600);root.content_scale_size=root.size
	m=load("res://main.tscn").instantiate();root.add_child(m);current_scene=m
	m.set_physics_process(false);m.set_process(false);m.set_process_unhandled_input(false)
	for body in m.skaters:m.set_actor_active(body,false)
	for body in m.goalkeepers:m.set_actor_active(body,false)
	actor=m.player;m.set_actor_active(actor,true);actor.position=Vector3(-3,0,10)
	var v=actor.get_child(1);v.set_shoots(shoots);v.rotation.y=0;v.animate_motion(Vector3.ZERO,1.0/120,0,false)
	m.sync_skater_contacts(actor);m.hud_node.hide()
	m.carrier=actor;m.cooldown=0;m.puck.freeze=true;m.puck.position=v.get_blade_world()
	var caption=Label.new();caption.text="STICKHANDLING LAB  /  scripted inputs · real puck physics";caption.position=Vector2(24,24);caption.add_theme_font_size_override("font_size",19)
	var layer=CanvasLayer.new();m.add_child(layer);layer.add_child(caption)
	process_frame.connect(draw_tick);physics_frame.connect(physics_tick)
func physics_tick()->void:
	if not started:return
	var dt:=1.0/120;ticks+=1
	var v=actor.get_child(1)
	if ticks in [60,300,540]:m.skills_for(actor).request(["cut","toe_drag","sweep"][[60,300,540].find(ticks)],v.shot_side())
	var skills=m.prepare_skills(actor,dt,Vector2.ZERO,m.carrier==actor,ticks>=780 and ticks<900)
	var intent:Vector3=skills.steer(Vector3.FORWARD*0.42,v.global_basis.x) if m.carrier==actor else Vector3.FORWARD*0.42
	actor.velocity=m.Skating.step(actor.velocity,intent,85.0,false,dt)
	actor.move_and_slide();v.animate_motion(actor.velocity,dt,0,true)
	m.sync_skater_contacts(actor);m.update_possession(dt)
	if ticks%60==0:samples.append({"seconds":ticks/120.0,"move":skills.move,"held":m.carrier==actor,"blade_gap_m":m.puck.position.distance_to(v.get_blade_world())})
func draw_tick()->void:
	frames+=1
	if inspection_camera and frames>150:
		var pocket:Vector3=actor.get_child(1).get_blade_world()
		m.camera.position=pocket+Vector3(-0.55,0.38,-0.70);m.camera.look_at(pocket);m.camera.fov=44
	elif hands_camera or inspection_camera:
		var top:Vector3=actor.get_child(1).rig.to_global(actor.get_child(1).stick_grip())
		m.camera.position=top+Vector3(-0.9,0.35,-1.2);m.camera.look_at(top+Vector3(0,-0.15,0));m.camera.fov=42
	else:
		m.camera.position=actor.position+Vector3(-3.2,2.0,-4.0);m.camera.look_at(actor.position+Vector3(0,0.7,0))
	if frames==30:
		started=true;m.puck.freeze=false;m.puck.linear_velocity=Vector3.ZERO
	if frames in [58,118,178,238]:call_deferred("save_preview",frames)
	if frames==270:
		FileAccess.open(prefix+".json",FileAccess.WRITE).store_string(JSON.stringify({"source_sha":source_sha,"engine":Engine.get_version_info().string,"fixture":"Scripted skill inputs, production skating/pose and rigid-body puck. One initial placement; no puck attachment or subsequent reposition. Not natural AI gameplay.","offline_render":true,"shoots":shoots,"hands_camera":hands_camera,"inspection_camera":inspection_camera,"samples":samples},"\t"))
func save_preview(frame:int)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(prefix+"-%03d.jpg"%frame,0.94)
