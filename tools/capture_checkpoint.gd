extends SceneTree
## Actual in-progress data checkpoint and completed dashboard, in JPEG.
const Session=preload("res://scripts/gm_session.gd")
const Season=preload("res://scripts/gm_season.gd")
func _initialize() -> void: call_deferred("run")
func capture(name_: String) -> void:
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("res://build/"+name_+".jpg",0.94)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	Session.slot_path="res://build/checkpoint-capture.json"
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(Session.slot_path+suffix): DirAccess.remove_absolute(Session.slot_path+suffix)
	Session.season=Season.new()
	if not Session.season.new_season(FileAccess.get_file_as_string(Season.Database.DEFAULT_PATH),"har"): quit(1);return
	change_scene_to_file("res://gm.tscn")
	for i in range(4): await process_frame
	current_scene.advance_day()
	await capture("checkpoint-saving")
	while current_scene.checkpoint_job!=null: await process_frame
	await capture("checkpoint-complete")
	current_scene.queue_free();await process_frame;Session.season=null
	quit()
