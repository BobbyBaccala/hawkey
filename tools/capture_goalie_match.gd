extends SceneTree
## Frozen in-arena inspection of actual goalie gear and save poses.
func _initialize() -> void: call_deferred("run")
func shot(name_: String) -> void:
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	print("GOALIE_ARENA ",name_," ",root.get_texture().get_image().save_jpg("res://build/goalie-arena-"+name_+".jpg",0.96))
func run() -> void:
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900)
	load("res://scripts/game_settings.gd").path="res://build/goalie-capture-settings.json"
	load("res://scripts/match.gd").skip_title=true
	change_scene_to_file("res://main.tscn")
	for i in range(4): await process_frame
	var m=current_scene;m.set_physics_process(false);m.set_process(false)
	m.hud_node.visible=false;m.selection.visible=false
	var keeper=m.goalkeepers[0];var v=keeper.get_child(1)
	var forward: Vector3=v.rig.global_basis.z.normalized()
	var side: Vector3=v.rig.global_basis.x.normalized()
	m.camera.position=keeper.global_position+forward*3.4+side*1.0+Vector3.UP*1.2
	m.camera.look_at(keeper.global_position+Vector3.UP*0.72);m.camera.fov=38
	await shot("ready")
	for i in range(60):
		v.butterfly=move_toward(v.butterfly,1.0,0.1)
		v.set_save("butterfly",Vector2(0.1,0.15),1.0/60)
		v.animate(0,1.0/60,0,false)
	m.sync_goalie_contacts(keeper)
	await shot("butterfly")
	FileAccess.open("res://build/goalie-arena-capture.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"source":"Actual main.tscn; frozen goalie inspection camera, HUD hidden, posed with production save functions. Direct viewport JPEGs, not normal gameplay footage."},"\t"))
	quit()
