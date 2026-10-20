extends SceneTree
## Captures the actual title and selected roster match; requires a display.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var match_script = load("res://scripts/match.gd")
	match_script.return_to_title = true
	change_scene_to_file("res://main.tscn")
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build")
	root.get_texture().get_image().save_png("res://build/play-now-title.png")
	current_scene.hud_node.play_requested.emit()
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/play-now-match.png")
	current_scene.match_state.phase = current_scene.MatchState.Phase.PLAY
	current_scene.match_state.period = 3
	current_scene.match_state.clock = 0.01
	current_scene.match_state.advance(0.1)
	current_scene.update_match_hud()
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	print("Results visible: ", current_scene.hud_node.results_panel.is_visible_in_tree(), " rect: ", current_scene.hud_node.results_panel.get_global_rect())
	root.get_texture().get_image().save_png("res://build/play-now-results.png")
	current_scene.queue_free()
	await process_frame
	quit()
