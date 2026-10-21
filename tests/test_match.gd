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
			actor.position=scene.bench_spot(0,slot)   # team 0 bench front (z > 0)
	scene.update_team_ai(1.0/120)
	var changer=scene.skaters[0]
	check(int(changer.get_meta("hop",0))==1,"Bench arrival must start a board hop")
	check(int(changer.get_meta("roster_id"))!=6,"Identity swaps on the bench, not at the boards")
	check(changer.collision_layer==0,"Hopping skater must not collide")
	var furthest:=0.0
	for i in range(240):
		scene.update_team_ai(1.0/120)
		furthest=minf(furthest,changer.get_child(1).global_position.x)
		if int(changer.get_meta("hop",0))==2: break
	check(furthest< -scene.Arena.HALF_WIDTH-0.5,"Tired skater lands on the bench floor behind the boards")
	check(int(changer.get_meta("roster_id"))==6,"Bench arrival must swap identity")
	for i in range(240):
		scene.update_team_ai(1.0/120)
		if int(changer.get_meta("hop",0))==0: break
	check(int(changer.get_meta("hop",0))==0,"Fresh skater must finish hopping back on")
	check(changer.get_child(1).position.length()<0.001,"Fresh skater's visual is back on its body")
	check(changer.collision_layer==2,"Fresh skater collides again")
	check(count_team(scene,0)==5,"Bench change must retain five skaters")
	check_change_nobody_up(scene)
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


## Backlog: bench pass 3 slice 10. When nobody is up to go out as the tired
## player lands (the one who got up sat back down, or nobody was free), a
## bench player gets up then (quickly) while the tired one waits on the bench
## floor in his own number (hop 3); the fresh player then goes out from where
## that player stands and the tired one walks to the seat from his landing.
## Before, the fresh player appeared 0.7 m along and the tired one turned into him.
func check_change_nobody_up(scene) -> void:
	var benches = scene.arena.get_node_or_null("Benches")
	if benches == null:
		check(false, "Benches present for the no-riser change")
		return
	for i in range(400): benches.update_figures(1.0/60)   # earlier risers settle
	scene.match_state.phase=scene.MatchState.Phase.PLAY
	check(scene.request_line(0,0),"Second on-the-fly change")
	var changers:=[]
	for actor in scene.skaters:
		if scene.body_team(actor)==0 and bool(actor.get_meta("changing",false)):
			actor.position=scene.bench_spot(0,int(actor.get_meta("slot")))
			changers.append(actor)
	scene.update_team_ai(1.0/120)
	var changer=changers[0]
	check(int(changer.get_meta("hop",0))==1,"Second change hops onto the bench")
	# The ones who got up sit back down before the tired players land.
	for rig in benches._rigs:
		if rig.team==0: rig.rise_until=-1.0
	for i in range(60): benches.update_figures(1.0/60)
	check(not benches.has_riser(0),"Nobody is up to go out")
	var tired_id:=int(changer.get_meta("roster_id"))
	var v=changer.get_child(1)
	var tired_number:String=v.number
	var landing:=Vector3.ZERO
	var waited:=0
	var steady:=true
	var hop3:=false
	for i in range(600):
		var before:Vector3=v.global_position
		var h:=int(changer.get_meta("hop",0))
		scene.update_team_ai(1.0/120)
		benches.update_figures(1.0/120)
		var now:=int(changer.get_meta("hop",0))
		if now==3:
			if not hop3: landing=v.global_position
			hop3=true
			waited+=1
			if v.global_position.distance_to(before)>0.01: steady=false
			if int(changer.get_meta("roster_id"))!=tired_id or v.number!=tired_number: steady=false
		if h==3 and now==2: break
		if now==2 and not hop3: break
	check(hop3,"With nobody up, the tired player waits on the bench (hop 3)")
	check(steady,"He stays put in his own number while he waits")
	var wait_s:=waited/120.0
	print("no-riser change: waited %.2f s, start x %.2f" % [wait_s, v.global_position.x])
	check(wait_s>0.2 and wait_s<scene.HOP_WAIT_MAX,"A bench player gets up quickly for him (%.2f s)" % wait_s)
	check(int(changer.get_meta("hop",0))==2 and int(changer.get_meta("roster_id"))!=tired_id,"The fresh player then goes out")
	# The tired one is the bench figure walking from his landing in his number.
	var walker=null
	for rig in benches._rigs:
		if rig.team==0 and benches.is_walking(rig) and rig.visual.number==tired_number: walker=rig
	check(walker!=null,"The tired player walks to the seat in his own number")
	if walker!=null:
		var wp:Vector3=walker.visual.global_position
		check(Vector2(wp.x-landing.x,wp.z-landing.z).length()<0.12,"He walks on from where he landed (%.2f m)" % Vector2(wp.x-landing.x,wp.z-landing.z).length())
	# The fresh player starts from the one who got up, not 0.7 m along from the landing.
	var start:Vector3=v.global_position
	check(start.x< -scene.Arena.HALF_WIDTH-0.9,"Fresh player goes out from the bench, behind the landing (x %.2f)" % start.x)
	for i in range(600):
		scene.update_team_ai(1.0/120)
		if int(changer.get_meta("hop",0))==0: break
	check(int(changer.get_meta("hop",0))==0 and changer.collision_layer==2,"Fresh player is back on the ice")
