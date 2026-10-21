extends SceneTree
## Actual native preferences capture; isolated settings path, no user-save mutation.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	load("res://scripts/game_settings.gd").path="res://build/nonexistent-capture-audio-settings.json"
	change_scene_to_file("res://settings.tscn")
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/realism-preferences.png")
	quit()
