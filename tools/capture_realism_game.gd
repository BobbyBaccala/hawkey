extends SceneTree
## Actual combined arena/UI capture. Close-up is an explicitly frozen review view.
func _initialize() -> void: call_deferred("run")
func capture(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var result:=root.get_texture().get_image().save_jpg("res://build/realism-"+name_+".jpg",0.96)
	print("ARENA_CAPTURE ",name_," result ",result)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	load("res://scripts/game_settings.gd").path="res://build/realism-capture-preferences.json"
	load("res://scripts/match.gd").return_to_title=true
	change_scene_to_file("res://main.tscn")
	for i in range(3): await process_frame
	await capture("arena-title")
	current_scene.hud_node.play_requested.emit()
	for i in range(3): await process_frame
	await capture("arena-match")
	var scene=current_scene
	scene.set_physics_process(false);scene.set_process(false)
	var player=scene.player
	var facing: Vector3=-player.get_child(1).global_basis.z.normalized()
	var side: Vector3=player.get_child(1).global_basis.x.normalized()
	scene.camera.position=player.global_position+facing*2.8+side*1.2+Vector3.UP*1.3
	scene.camera.look_at(player.global_position+Vector3.UP*0.8);scene.camera.fov=38
	scene.hud_node.visible=false
	await capture("arena-player-review")
	var visual=player.get_child(1)
	var head: Vector3=visual.helmet.global_position
	scene.camera.position=head+facing*0.8+side*0.3+Vector3.UP*0.03
	scene.camera.look_at(head+Vector3(0,-0.05,0));scene.camera.fov=32
	await capture("face-lit-review")
	if "--diagnose-face" in OS.get_cmdline_user_args():
		visual.helmet.get_node("Visor").visible=false
		await capture("diagnostic-face-no-visor")
		for light in scene.find_children("*","DirectionalLight3D",true,false): light.shadow_enabled=false
		await capture("diagnostic-face-no-shadows")
	var metadata: Dictionary={"source":"Actual combined main.tscn, real title and match; final camera is a frozen in-arena model inspection, not normal gameplay","engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name()}
	var file:=FileAccess.open("res://build/realism-arena-capture.json",FileAccess.WRITE);file.store_string(JSON.stringify(metadata,"\t"));file.close()
	scene.queue_free();await process_frame;quit()
