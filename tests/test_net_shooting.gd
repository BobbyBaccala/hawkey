extends SceneTree
const Net=preload("res://scripts/net_shooting.gd")
const Puck=preload("res://scripts/puck.gd")
var checks:=0
var failures:=0
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:push_error(why);failures+=1
func _initialize()->void:call_deferred("run")
func run()->void:
	for end_ in [-1.0,1.0]:
		for origin in [Vector3(0,0.02,0),Vector3(-8,0.03,end_*15),Vector3(6,0.03,end_*20)]:
			for placement in [Vector2.ZERO,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
				for slap in [false,true]:
					var target:=Net.target(end_,placement)
					var velocity:=Net.launch(origin,end_,placement,80,slap)
					var time:float=(target.z-origin.z)/velocity.z
					var crossing:Vector3=origin+velocity*time+Vector3.DOWN*4.9*time*time
					check(crossing.distance_to(target)<0.001,"Shot trajectory targets selected net point at either end")
					check(absf(target.x)<0.9 and target.y>0 and target.y<1.22,"Placement remains inside mouth")
	check(Net.launch(Vector3.ZERO,-1,Vector2.ZERO,75,true).length()>Net.launch(Vector3.ZERO,-1,Vector2.ZERO,75,false).length(),"Distinct slap-shot profile")
	check(Net.target(-1,Vector2(1,0)).x>0 and Net.target(1,Vector2(1,0)).x<0,"Right means shooter's right after switching ends")
	check(Net.target(-1,Vector2(0,-1)).y>Net.target(-1,Vector2(0,1)).y,"Up on left stick places high")
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene);await physics_frame
	scene.set_physics_process(false)
	scene.match_state.phase=scene.MatchState.Phase.PLAY
	scene.controller.active=true
	scene.controller.left_stick=Vector2(0.7,-0.8)
	scene.player.position=Vector3(4,0,-10)
	scene.player.get_child(1).rotation.y=PI/2 # Facing away from the goal is irrelevant.
	scene.puck.position=scene.player.position+Vector3(0,0.03,-0.6)
	scene.cooldown=0
	check(scene.take_shot(),"Net shot available when facing sideways")
	var velocity:Vector3=scene.puck.linear_velocity
	var time:float=(-scene.Arena.GOAL_LINE-scene.puck.position.z)/velocity.z
	var at:Vector3=scene.puck.position+velocity*time+Vector3.DOWN*4.9*time*time
	check(at.distance_to(Net.target(-1,scene.controller.left_stick))<0.001,"Controller corners target net rather than facing")
	# Both actual trigger press and mouse click use immediate shots; release never fires.
	scene.cooldown=0;scene.puck.position=scene.player.position+Vector3(0,0.03,-0.6)
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	var before:int=scene.shots
	scene._unhandled_input(click)
	check(scene.shots==before+1,"Mouse press fires immediately")
	scene.cooldown=0;click.pressed=false;scene._unhandled_input(click)
	check(scene.shots==before+1,"Mouse release never fires another shot")
	# Physics integration includes actual air drag, with all defenders removed.
	for actor in scene.skaters:scene.set_actor_active(actor,false)
	for keeper in scene.goalkeepers:scene.set_actor_active(keeper,false)
	scene.puck.freeze=false
	var origin:=Vector3(0,0.03,-10)
	scene.puck.position=origin
	scene.puck.linear_velocity=Net.launch(origin,-1,Vector2(0.6,-0.5),80,false)
	var previous:Vector3=origin
	var crossed:=false
	for frame in range(180):
		await physics_frame
		if previous.z > -scene.Arena.GOAL_LINE and scene.puck.position.z <= -scene.Arena.GOAL_LINE:
			var ratio:float=(-scene.Arena.GOAL_LINE-previous.z)/(scene.puck.position.z-previous.z)
			var point:Vector3=previous.lerp(scene.puck.position,ratio)
			check(absf(point.x)<0.9 and point.y>0 and point.y<1.22,"Actual rigid-body shot reaches goal mouth")
			crossed=true
			break
		previous=scene.puck.position
	check(crossed,"Physical shot crosses goal plane")
	scene.queue_free();await process_frame
	var practice=load("res://practice.tscn").instantiate()
	root.add_child(practice);await physics_frame
	practice.set_physics_process(false)
	practice.puck.position=practice.player.position+Vector3(0,0.03,-0.6)
	practice.cooldown=0
	var e:=InputEventJoypadMotion.new()
	e.device=7;e.axis=JOY_AXIS_LEFT_Y;e.axis_value=-1
	practice._unhandled_input(e)
	e=InputEventJoypadMotion.new();e.device=7;e.axis=JOY_AXIS_TRIGGER_RIGHT;e.axis_value=1
	practice._unhandled_input(e)
	practice._physics_process(1.0/120)
	check(practice.shots==1 and practice.puck.linear_velocity.z < -10,"Practice controller uses same net-targeted quick shot")
	for i in range(10):practice._physics_process(1.0/120)
	check(practice.shots==1 and practice.charge==0,"Practice trigger hold never charges or repeats")
	practice.on_practice_connection(7,false)
	check(practice.paused and not practice.practice_input.trigger_down,"Practice disconnect pauses and clears shot input")
	practice.queue_free();await process_frame
	print("Net shooting: %d checks; %d failures"%[checks,failures])
	quit(failures)
