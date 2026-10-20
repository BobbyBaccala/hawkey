extends SceneTree
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: push_error(message);failures+=1
func _initialize()->void:call_deferred("run")
func count_team(scene,team:int)->int:
	var total:=0
	var ids:=[]
	for actor in scene.skaters:
		if scene.body_team(actor)==team and actor.get_meta("eligible"):
			total+=1
			check(actor.get_meta("roster_id") not in ids,"On-ice roster IDs must be unique")
			ids.append(actor.get_meta("roster_id"))
	return total
func run()->void:
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	check(scene.skaters.size()==10 and scene.goalkeepers.size()==2,"Full 5v5 plus goalkeepers must spawn")
	check(count_team(scene,0)==5 and count_team(scene,1)==5,"Both teams need five eligible skaters")
	scene.match_state.phase_timer=0
	for i in range(4):await physics_frame
	check(scene.match_state.phase==scene.MatchState.Phase.PLAY,"Scene must begin playing")
	scene.paused=true
	var clock=scene.match_state.clock
	for i in range(3):await physics_frame
	check(is_equal_approx(scene.match_state.clock,clock),"Pause must preserve clock")
	scene.paused=false
	scene.assess_penalty(scene.skaters[1],"Tripping")
	check(count_team(scene,0)==4 and count_team(scene,1)==5,"Minor removes an on-ice skater")
	scene.match_state.phase=scene.MatchState.Phase.PLAY
	scene.match_state.penalties[0].remaining=0.01
	for i in range(4):await physics_frame
	check(count_team(scene,0)==5,"Expired minor must restore five skaters")
	scene.match_state.phase=scene.MatchState.Phase.STOPPAGE
	check(scene.request_line(0,1),"Stoppage line change must succeed")
	check(int(scene.skaters[0].get_meta("roster_id"))==3,"New forward line must use new roster")
	check(count_team(scene,0)==5,"Line change must not add skaters")
	scene.match_state.phase=scene.MatchState.Phase.PLAY
	check(scene.request_line(0,2),"On-the-fly line request must succeed")
	for actor in scene.skaters:
		if scene.body_team(actor)==0 and int(actor.get_meta("slot"))<3:
			var slot=int(actor.get_meta("slot"))
			actor.position=Vector3(scene.BENCH_X,0,(slot-1)*1.6-4)
	scene.update_team_ai(1.0/120)
	check(int(scene.skaters[0].get_meta("roster_id"))==6,"Bench arrival must swap identity")
	check(count_team(scene,0)==5,"Bench change must retain five skaters")
	scene.update_camera(1)
	check(absf(scene.camera.rotation.z)<0.0001,"Camera must have no roll")
	check(absf(scene.camera.position.x-scene.camera_target.x)<0.0001,"Camera must have no lateral offset")
	scene.match_state.phase=scene.MatchState.Phase.INTERMISSION
	scene.match_state.phase_timer=0
	var north_keeper=scene.goalkeepers[0].position.z
	for i in range(2):await physics_frame
	check(scene.match_state.period==2,"Intermission must advance period")
	check(scene.goalkeepers[0].position.z*north_keeper<0,"Goalkeepers must switch ends")
	# Every camera: "up" on the stick skates toward the end Toronto attacks,
	# before and after the teams switch ends.
	for period_ in [2,1]:
		scene.match_state.period=period_
		for mode in range(4):
			scene.camera_mode=mode
			scene.update_camera(1)
			# Broadcast (2) is a side view: Toronto attacks to the right.
			var dir:Vector3=scene.screen_to_rink(Vector3(1,0,0) if mode==2 else Vector3(0,0,-1))
			check(dir.z*scene.attack_direction(0)>0.7,"Camera %d, period %d: attack direction on screen" % [mode,period_])
	scene.queue_free()
	await process_frame
	print("Match integration failures: ",failures)
	quit(failures)
