extends SceneTree
## Genuine native-engine UI capture; simulated days are staged, not human play.
const Session=preload("res://scripts/gm_session.gd")
const Settings=preload("res://scripts/game_settings.gd")
func _initialize() -> void: call_deferred("run")
func capture(name_: String) -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/gm-"+name_+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	Session.slot_path="res://build/capture-gm.json";Settings.path="res://build/capture-preferences.json"
	for path in [Session.slot_path,Settings.path]:
		for suffix in ["",".bak",".tmp",".bak.tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	change_scene_to_file("res://gm.tscn");await capture("setup")
	for i in range(current_scene.teams.size()):
		if current_scene.teams[i].id=="har": current_scene.choice.select(i)
	current_scene.create_season();await capture("opening")
	for day in range(13): Session.season.simulate_day()
	Session.save();Session.notice="Day 13 complete. Your season and full roster snapshot are saved."
	current_scene.rebuild();await capture("standings")
	change_scene_to_file("res://settings.tscn");await capture("preferences")
	current_scene.queue_free();await process_frame
	Session.season=null
	quit()
