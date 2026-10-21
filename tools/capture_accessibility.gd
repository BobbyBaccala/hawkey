extends SceneTree
## Genuine Godot JPEG capture. Isolated preferences; never edits user settings.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	load("res://scripts/game_settings.gd").path="res://build/accessibility-capture-settings.json"
	change_scene_to_file("res://settings.tscn")
	for i in range(5): await process_frame
	if "--enabled" in OS.get_cmdline_user_args():
		current_scene.motion.button_pressed=true;current_scene.puck_cue.button_pressed=true;current_scene.save_preferences()
		for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var stage:="before" if "--before" in OS.get_cmdline_user_args() else "after"
	root.get_texture().get_image().save_jpg("res://build/accessibility-"+stage+".jpg",0.94)
	quit()
