extends SceneTree
## Native close-up inspection of production contact layers; controlled poses,
## not a replacement for actual gameplay footage.
var m
var captures:Array=[]
var source_sha:=""
func _initialize()->void:call_deferred("run")
func shot(label:String)->void:
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	var path:="res://docs/screenshots/receiving-"+label+"-20261022.jpg"
	var error:=root.get_texture().get_image().save_jpg(path,0.95)
	captures.append({"path":path,"error":error});print("RECEIVING_CAPTURE ",label," ",error)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source-sha="):source_sha=arg.trim_prefix("--source-sha=")
	root.size=Vector2i(960,600);root.content_scale_size=Vector2i(960,600)
	root.msaa_3d=Viewport.MSAA_DISABLED;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_DISABLED
	load("res://scripts/game_settings.gd").path="res://build/receiving-capture-settings.json"
	load("res://scripts/match.gd").skip_title=true
	m=load("res://main.tscn").instantiate();root.add_child(m);current_scene=m
	m.set_physics_process(false);m.set_process(false);m.puck.freeze=true
	m.hud_node.visible=false;m.selection.visible=false
	for actor in m.skaters:
		if actor!=m.player:m.set_actor_active(actor,false)
	var actor=m.player;var v=actor.get_child(1)
	actor.position=Vector3.ZERO;v.rotation.y=0;actor.velocity=Vector3.ZERO
	for i in range(120):v.animate_motion(Vector3.ZERO,1.0/120,0,false)
	m.camera.position=Vector3(-2.6,1.8,-3.7)
	m.camera.look_at(Vector3(0,0.8,-0.1));m.camera.fov=36
	m.puck.position=v.get_blade_world()
	await shot("ready")
	var incoming:Vector3=v.rig.to_global(Vector3(-0.62,0.03,1.2))
	m.puck.position=incoming
	for i in range(30):
		v.offer_receive(incoming);v.animate_motion(Vector3.ZERO,1.0/120,0,false)
	await shot("reach")
	v.receive_puck(Vector3.BACK*10)
	for i in range(16):v.animate_motion(Vector3.ZERO,1.0/120,0,false)
	m.puck.position=v.get_blade_world()
	await shot("cushion")
	for i in range(120):v.animate_motion(Vector3.ZERO,1.0/120,0,false)
	m.carrier=actor;m.controller.active=true;m.controller.trigger_down=true
	m.controller.pass_held=0.8;m.controller_pass_actor=actor
	for i in range(30):m.control_player(1.0/120)
	m.puck.position=v.get_blade_world()
	await shot("pass-preparation")
	m.release_puck(actor,Vector3.FORWARD,17)
	for i in range(15):v.animate_motion(Vector3.ZERO,1.0/120,0,false)
	await shot("pass-follow-through")
	FileAccess.open("res://build/receiving-capture.json",FileAccess.WRITE).store_string(JSON.stringify({"source_sha":source_sha,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"source":"Production main.tscn inspection camera with hidden HUD. Receiving target/contact command sampled directly; held-pass preparation through real control_player path; release through release_puck. Puck placed for inspection; these JPEGs are controlled poses, not live gameplay.","captures":captures},"\t"))
	quit()
