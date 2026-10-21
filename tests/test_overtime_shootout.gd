extends SceneTree
const State = preload("res://scripts/match_state.gd")
var checks := 0
var failures := 0
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: push_error(why); failures+=1
func tied() -> RefCounted:
	var s := State.new()
	s.period=3
	s.phase=State.Phase.PLAY
	s.clock=0.01
	s.score.assign([2,2])
	s.advance(0.1)
	return s
func attempt(s, scored: bool) -> void:
	s.advance(3)
	check(s.phase==State.Phase.SHOOTOUT_ATTEMPT,"Attempt begins after ready countdown")
	check(s.record_attempt(scored,"fictional:test"),"Attempt accepted once")
	check(not s.record_attempt(scored),"Duplicate attempt rejected")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var s=tied()
	check(s.phase==State.Phase.INTERMISSION and s.winner==-1,"Tied regulation must not end in draw")
	s.advance(6)
	check(s.period==4 and s.clock==300 and s.count(0)==3 and s.count(1)==3,"Five-minute three-on-three overtime")
	s.advance(3)
	check(s.phase==State.Phase.PLAY,"Overtime faceoff starts live play")
	s.minor(0,0,"Tripping")
	check(s.count(0)==3 and s.count(1)==4,"OT penalty adds opponent skater")
	s.phase=State.Phase.PLAY
	s.minor(0,1,"Tripping")
	check(s.count(0)==3 and s.count(1)==5,"OT two minors gives five-on-three")
	s.phase=State.Phase.PLAY
	s.goal(1)
	check(s.phase==State.Phase.FINAL and s.winner==1 and s.decision=="OT" and s.score==[2,3],"Overtime goal wins immediately")
	s.goal(1)
	s.advance(1000)
	check(s.score==[2,3],"Final result remains immutable")
	s=tied();s.advance(6);s.advance(3);s.clock=0.01;s.advance(0.1)
	check(s.phase==State.Phase.SHOOTOUT_READY and s.penalties.is_empty(),"Tied OT starts shootout")
	attempt(s,true);attempt(s,false);attempt(s,true);attempt(s,false)
	check(s.phase==State.Phase.FINAL and s.winner==0,"Two-goal early clinch after two rounds")
	check(s.score==[3,2] and s.shootout_score==[2,0],"One deciding goal only in match score")
	s=State.new();s.start_shootout()
	for i in range(6): attempt(s,false)
	check(s.phase==State.Phase.SHOOTOUT_READY and s.winner==-1,"Tied three rounds continues")
	attempt(s,true)
	check(s.phase!=State.Phase.FINAL,"Sudden death gives opponent equal attempt")
	attempt(s,true)
	check(s.phase!=State.Phase.FINAL,"Equal conversions continue another pair")
	attempt(s,false);attempt(s,true)
	check(s.phase==State.Phase.FINAL and s.winner==1 and s.shootout_attempts.size()==10,"Sudden-death pair decides winner")
	s=State.new();s.start_shootout();s.advance(3);s.shootout_player_id="fictional:timeout";s.advance(21)
	check(s.shootout_attempts.size()==1 and not s.shootout_attempts[0].scored and s.shootout_attempts[0].player_id=="fictional:timeout","Attempt timeout records miss and stable ID")
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	scene.match_state=tied();scene.match_state.advance(6);scene.match_state.advance(3)
	scene.sync_strength()
	for team in range(2):
		var actors: Array=scene.skaters.filter(func(a):return scene.body_team(a)==team and a.get_meta("eligible"))
		check(actors.size()==3,"Scene spawns three eligible OT skaters")
		check(actors.any(func(a):return int(a.get_meta("slot"))>=3),"Overtime includes a defender")
	scene.match_state.clock=0.01;scene.match_state.advance(0.1)
	scene.setup_shootout_attempt()
	check(scene.skaters.filter(func(a):return a.visible).size()==1 and scene.goalkeepers.filter(func(g):return g.visible).size()==1,"One shooter and one opposing goalie visible")
	check(scene.goalkeeper_at_end(scene.attack_direction(0)).get_meta("team")==1,"Goalie belongs to defending club")
	scene.update_camera(1)
	var view:Rect2=scene.get_viewport().get_visible_rect().grow(-48)
	check(view.has_point(scene.camera.unproject_position(scene.shootout_actor.position+Vector3.UP*0.05)),"Shootout camera keeps home shooter visible immediately")
	check(view.has_point(scene.camera.unproject_position(Vector3(0,0.6,scene.attack_direction(0)*scene.Arena.GOAL_LINE))),"Shootout camera also frames goal")
	var stats=scene.team_shots.duplicate()
	scene.match_state.advance(3)
	check(scene.take_shot(),"Home shootout attempt uses real shot path")
	check(not scene.take_shot(),"No second shot in an attempt")
	check(scene.team_shots==stats and scene.shots==0,"Shootout attempts do not inflate match shots")
	# Drive an actual puck crossing through the same goal detector used in play.
	var end_: float=scene.attack_direction(0)
	scene.previous_puck=Vector3(0,0.3,end_*(scene.Arena.GOAL_LINE-0.1))
	scene.puck.position=Vector3(0,0.3,end_*(scene.Arena.GOAL_LINE+0.1))
	scene.process_shootout(0)
	check(scene.match_state.shootout_score[0]==1 and scene.match_state.shootout_attempts[0].player_id==scene.roster(scene.shootout_actor).id,"Physical crossing records stable shooter exactly once")
	scene.setup_shootout_attempt();scene.match_state.advance(3)
	check(scene.match_state.shootout_team==1 and not scene.take_shot(),"Away attempts cannot be shot by hidden home player")
	scene.update_camera(1)
	check(view.has_point(scene.camera.unproject_position(scene.shootout_actor.position+Vector3.UP*0.05)),"Shootout camera keeps away shooter visible immediately")
	# A live pair with real skating, rigid-body flight, goalkeeper collisions and AI.
	scene.match_state=State.new()
	scene.shootout_prepared=-1
	scene.match_state.start_shootout()
	scene.team_shots.assign([0,0])
	var ai_fired:=false
	for frame in range(6500):
		scene.cooldown=maxf(0,scene.cooldown-1.0/120)
		scene.goalie_contact_timer=maxf(0,scene.goalie_contact_timer-1.0/120)
		scene.match_state.advance(1.0/120)
		scene.process_shootout(1.0/120)
		if scene.match_state.phase==State.Phase.SHOOTOUT_ATTEMPT:
			if scene.match_state.shootout_team==0 and not scene.shootout_shot:
				scene.controller.active=true
				scene.controller.left_stick=Vector2(0.7,-0.8)
				scene.take_shot()
			if scene.match_state.shootout_team==1 and scene.shootout_shot:ai_fired=true
		await physics_frame
		if scene.match_state.shootout_attempts.size()>=2:break
	check(scene.match_state.shootout_attempts.size()>=2 and ai_fired,"Live home and AI attempts complete through physical play")
	check(scene.match_state.shootout_attempts.all(func(a):return not a.player_id.is_empty()),"Live attempt ledger retains identities")
	check(scene.team_shots==[0,0],"Real goalie contacts during shootout do not inflate match shots")
	scene.set_paused(true)
	var remaining:float=scene.match_state.shootout_remaining
	scene._physics_process(1)
	check(scene.match_state.shootout_remaining==remaining,"Pause freezes shootout clock")
	scene.set_paused(false)
	scene.queue_free();await process_frame
	print("Overtime/shootout: %d checks; %d failures"%[checks,failures])
	quit(failures)
