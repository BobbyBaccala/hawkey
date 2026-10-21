extends SceneTree
const Session=preload("res://scripts/event_session.gd")
const Settings=preload("res://scripts/game_settings.gd")
func _initialize() -> void: call_deferred("run")
func shot(name_: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	var result:=root.get_texture().get_image().save_jpg("res://build/modes-"+name_+".jpg",0.96)
	print("MODE_CAPTURE ",name_," result ",result)
func run() -> void:
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900)
	Settings.path="res://build/event-capture/settings.json";Session.slot_path="res://build/event-capture/cup.json"
	DirAccess.make_dir_recursive_absolute("res://build/event-capture")
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(Session.slot_path+suffix): DirAccess.remove_absolute(Session.slot_path+suffix)
	Session.ensure_database()
	var clubs: Array=Session.database.teams.filter(func(t): return t.league_id=="hl")
	Session.create(clubs[0].id,27)
	change_scene_to_file("res://events.tscn")
	for i in range(3): await process_frame
	await shot("cup-opening")
	for i in range(4): Session.simulate_next()
	current_scene.rebuild();await shot("cup-semifinals")
	for i in range(3): Session.simulate_next()
	current_scene.rebuild();await shot("cup-champions")
	current_scene.start_shootout()
	for i in range(4): await process_frame
	current_scene.set_physics_process(false)
	current_scene.setup_shootout_attempt()
	current_scene.update_camera(0.0)
	current_scene.update_match_hud()
	await shot("shootout-ready")
	var metadata:={"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"source":"Actual native events.tscn and main.tscn; isolated demo cup, all shown cup scores simulated; shootout frozen at setup; viewport JPEGs"}
	FileAccess.open("res://build/modes-capture.json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"\t"))
	quit()
