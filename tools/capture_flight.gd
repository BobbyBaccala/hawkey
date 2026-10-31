extends SceneTree
## Reproducible in-engine shot fixture. This is a scripted review, not a live-match capture.
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	scene.match_state.phase=scene.MatchState.Phase.PLAY
	scene.controller.active=true
	for i in range(scene.skaters.size()):
		var actor=scene.skaters[i]
		actor.position=Vector3(-8+(i%5)*4,0,-7+(i/5)*5)
		actor.velocity=Vector3.ZERO
		actor.get_child(1).animate(0,1)
	scene.player.position=Vector3(0,0,-17)
	scene.player_visual.rotation.y=0
	scene.player_visual.desired_stick=Vector2(0.5,0)
	for i in range(30):scene.player_visual.animate(0,1.0/120)
	scene.player.get_node("PuckContact").rotation.y=0
	scene.camera.position=Vector3(0,3.1,-12)
	scene.camera.look_at(Vector3(0,0.7,-21))
	scene.camera.fov=58
	scene.puck.freeze=false
	scene.puck.position=scene.player_visual.get_blade_world()+Vector3(0,0.02,0)
	scene.release_puck(scene.player,Vector3.FORWARD,20,0.24)
	for i in range(27):
		await physics_frame
		scene.update_goalkeepers(1.0/120)
		scene.player_visual.animate(0,1.0/120)
	scene.puck.freeze=true
	scene.puck_shadow.position=Vector3(scene.puck.position.x,0.003,scene.puck.position.z)
	scene.update_match_hud()
	scene.status.text="SCRIPTED SHOT REVIEW  •  Actual engine render  •  Puck height %.2f m"%scene.puck.position.y
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("/tmp/hawkey-flight-review.png")	
	quit()
