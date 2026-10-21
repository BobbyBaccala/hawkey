extends SceneTree
const Match=preload("res://scripts/match.gd")
const Settings=preload("res://scripts/game_settings.gd")
const Net=preload("res://scripts/net_shooting.gd")
var failures:=0
var checks:=0
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func run()->void:
	Settings.path="res://build/video-corrections/settings.json"
	Match.skip_title=true
	var m=load("res://main.tscn").instantiate();root.add_child(m)
	await process_frame
	m.set_physics_process(false);m.set_process(false)
	m.puck.freeze=true
	for actor in m.skaters:m.set_actor_active(actor,false)
	# Track the puck around a complete circle, at both ends, across +/-PI.
	for keeper in m.goalkeepers:
		var end_:float=signf(keeper.position.z)
		var center:=Vector3(0,0,end_*m.Arena.GOAL_LINE)
		for step in range(17):
			var angle:=TAU*step/16
			m.puck.position=center+Vector3(sin(angle)*3,0.03,cos(angle)*3)
			for i in range(30):m.update_goalkeepers(1.0/60)
			var visual=keeper.get_child(1)
			var forward:Vector3=-visual.global_basis.z
			var desired:Vector3=(m.puck.position-center);desired.y=0;desired=desired.normalized()
			check(forward.dot(desired)>0.999,"Goalie tracks full circle including directly behind net")
			check(keeper.position.z*end_<=m.Arena.GOAL_LINE-1.12,"Tracking keeps gear ahead of net")
			for gear in visual.get_goalie_gear().values():
				var box:=AABB(-gear.size*0.5,gear.size)
				for c in range(8):
					var world:Vector3=keeper.global_transform*gear.transform*box.get_endpoint(c)
					check(world.z*end_<m.Arena.GOAL_LINE,"Rotating equipment never intersects goal mouth plane")
		# Actual CharacterBody motion into closed guard; goal mouth not a goalie exit.
		keeper.position=center-Vector3(0,0,end_*1.5)
		for i in range(120):
			keeper.velocity=Vector3(0,0,end_*4)
			keeper.move_and_slide()
		check(keeper.position.z*end_<m.Arena.GOAL_LINE-0.25,"Goalie physical body cannot enter net cavity through mouth")
	for goal in m.arena.goals:
		var guard=goal.get_node("GoalieNetGuard")
		check(guard.collision_layer==32 and m.puck.collision_mask&32==0,"Guard does not block puck scoring")
	# Release variants move blade and torso, retain hand/shaft reach, then recover.
	var v=m.player.get_child(1)
	m.set_actor_active(m.player,true)
	v.animate(0,1.0/60,0,false)
	var rest:Vector3=v.blade_position
	var heights:={}
	var worst_hand_gap:=0.0
	for kind in ["pass","shot","slap"]:
		v.play_release(kind,Vector3.FORWARD)
		var max_height:=0.0
		for frame in range(110):
			v.animate(3,1.0/120)
			max_height=maxf(max_height,v.blade_position.y)
			var grip:Vector3=v.stick_grip()
			var shaft:Vector3=(v.stick_heel(grip)-grip).normalized()
			for glove in v.skater_gloves:
				var hole:Vector3=glove.transform*v.GLOVE_HOLE
				worst_hand_gap=maxf(worst_hand_gap,(hole-grip).cross(shaft).length())
			check(v.blade_position.is_finite() and v.posed_wrists[0].is_finite() and v.posed_wrists[1].is_finite(),"Release geometry is finite")
		check(v.blade_position.distance_to(rest)<0.001 and v.release_kind.is_empty(),"Release settles back into normal skating pose")
		heights[kind]=max_height
	check(worst_hand_gap<0.02,"Both gloves stay closed on shaft throughout every release")
	check(heights.pass>0.08 and heights.pass<0.12,"Passing has low sweeping follow-through")
	check(heights.shot>0.39 and heights.shot<0.44,"Wrist shot lifts blade clearly")
	check(heights.slap>0.66 and heights.slap>heights.shot,"Slap follow-through is distinct")
	# Both AI and human use these same actual release functions.
	m.puck.position=m.player.position+Vector3(0,0.03,-0.5)
	m.release_puck(m.player,Vector3.FORWARD,17)
	check(v.release_kind=="pass" and m.puck.linear_velocity.length()<14,"Match pass is visibly animated and moderated")
	m.emit_net_shot(m.player,Vector2.ZERO)
	check(v.release_kind=="shot" and m.puck.linear_velocity.length()<25,"Match shot uses visible follow-through and slower profile")
	m.emit_net_shot(m.player,Vector2.ZERO,true)
	check(v.release_kind=="slap","Slap release uses its own animation")
	m.queue_free();await process_frame
	var p=load("res://practice.tscn").instantiate();root.add_child(p);await process_frame
	p.set_physics_process(false);p.set_process(false);p.paused=false
	p.puck.position=Vector3(0,0.03,-p.Arena.GOAL_LINE-2)
	for i in range(60):p.update_goalkeepers(1.0/60)
	check((-p.goalie_visuals[0].global_basis.z).dot(Vector3.FORWARD)>0.999,"Practice goalie also tracks directly behind net")
	p.player.position=Vector3.ZERO;p.velocity=Vector3.ZERO
	p.puck.position=Vector3(0,0.03,-0.5);p.cooldown=0
	var accepted:bool=p.strike(Vector3.FORWARD,17,true)
	check(accepted and p.player_visual.release_kind=="pass" and p.puck.linear_velocity.length()<14,"Practice shares pass animation and speed tuning")
	print("Video corrections: ",checks," checks; ",failures," failures")
	quit(failures)
