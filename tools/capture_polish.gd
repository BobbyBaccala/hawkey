extends SceneTree
## Genuine engine captures. OT/SO clocks are advanced for UI inspection.
func _initialize()->void:call_deferred("run")
func capture(name_:String)->void:
	if "--shootout-only" in OS.get_cmdline_user_args() and name_ not in ["shootout","results"]:
		for i in range(2):await process_frame
		return
	for i in range(10):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/polish-"+name_+".png")
func run()->void:
	DirAccess.make_dir_recursive_absolute("res://build")
	load("res://scripts/match.gd").return_to_title=true
	change_scene_to_file("res://main.tscn")
	await capture("title")
	current_scene.hud_node.play_requested.emit()
	await capture("match")
	var s=current_scene.match_state
	s.period=3;s.phase=s.Phase.PLAY;s.score.assign([2,2]);s.clock=0.01
	s.advance(0.1);s.advance(6)
	await capture("overtime")
	s.phase=s.Phase.PLAY;s.clock=0.01;s.advance(0.1)
	for i in range(4):await process_frame
	s.advance(3)
	current_scene.controller.active=true
	current_scene.controller.left_stick=Vector2(0.6,-0.8)
	await capture("shootout")
	print("Shooter visible: ",current_scene.shootout_actor.visible," screen: ",current_scene.camera.unproject_position(current_scene.shootout_actor.position))
	for scored in [true,false,true,false]:
		if s.phase==s.Phase.SHOOTOUT_READY:s.advance(3)
		s.record_attempt(scored,"fictional:capture-fixture")
	current_scene.update_match_hud()
	await capture("results")
	current_scene.queue_free();await process_frame
	quit()
