extends SceneTree
## Neutral side, arm assignment, actual roster integration and real moving puck.
const Match=preload("res://scripts/match.gd")
var failures:=0
var checks:=0
var held:=0
var total:=0
var worst_gap:=0.0
var worst_contact:=0.0
var min_thumb:=1.0
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func inspect(v)->void:
	var top:Vector3=v.stick_grip();var down:Vector3=(v.stick_heel(top)-top).normalized()
	for i in range(2):
		var glove:Node3D=v.skater_gloves[i]
		var hole:Vector3=glove.transform*v.GLOVE_HOLE
		var thumb:Vector3=glove.basis.x*(1.0 if i==0 else -1.0)
		var expected:Vector3=down if i==v.top_hand_index() else -down
		min_thumb=minf(min_thumb,thumb.dot(expected))
		worst_contact=maxf(worst_contact,(hole-top).cross(down).length())
		check(thumb.dot(expected)>0.40,"Handed thumb direction stays correct through moves")
		check(v.shoulder_of(i).distance_to(v.posed_wrists[i])<0.62,"Both handed arm chains remain reachable")
func run()->void:
	load("res://scripts/game_settings.gd").path="res://build/strong-side-test/settings.json"
	Match.skip_title=true
	var m=load("res://main.tscn").instantiate();root.add_child(m);await physics_frame
	m.set_physics_process(false);m.set_process(false);m.match_state.phase=m.MatchState.Phase.PLAY
	var left_count:=0;var right_count:=0
	for actor in m.skaters:
		var hand:String=str(m.roster(actor).get("shoots","R"))
		check(actor.get_child(1).shoots_right==(hand=="R"),"Initial lineup uses actual roster handedness")
		if hand=="L":left_count+=1
		else:right_count+=1
	check(left_count>0 and right_count>0,"Production lineup includes both handednesses")
	for hand in ["L","R"]:
		var id_:int=m.rosters[0].find_custom(func(p):return p.get("shoots","R")==hand)
		check(id_>=0,"Roster contains a player with requested handedness")
		m.change_identity(m.player,id_)
		check(m.player.get_child(1).shoots_right==(hand=="R"),"Line-change identity updates grip handedness")
	for actor in m.skaters:m.set_actor_active(actor,false)
	for actor in m.goalkeepers:m.set_actor_active(actor,false)
	var actor=m.player;m.set_actor_active(actor,true)
	var v=actor.get_child(1)
	for hand in ["R","L"]:
		var side:=1.0 if hand=="R" else -1.0
		v.set_shoots(hand);v.rotation.y=0;v.phase=0;v.desired_stick=Vector2.ZERO;v.stick_intent=Vector2.ZERO;v.skill_lean=0
		actor.position=Vector3(-3,0,7);actor.velocity=Vector3.ZERO
		for f in range(90):v.animate_motion(Vector3.ZERO,1.0/120,0,false)
		check(v.blade_position.x*side < -0.65 and absf(v.blade_position.x)>v.blade_position.z,"Neutral blade lies beside shooting side, not centered forward")
		var top:Vector3=v.stick_grip();var lower:Vector3=v.bottom_grip(v.shoulder_of(1-v.top_hand_index()))
		check(top.x*side < -0.02 and lower.x*side < top.x*side-0.18,"Hands follow strong-side diagonal")
		check(v.top_hand_index()==(0 if hand=="R" else 1),"Left shot swaps actual top and lower arms")
		check(v.rig.scale.x>0 and v.rig.basis.determinant()>0,"No negative-scale mesh/jersey mirror")
		for raw in [Vector2.ZERO,Vector2(0.7,0.3),Vector2(-0.8,-0.2)]:
			var r:Vector3=v.stick_home(raw,true);var l:Vector3=v.stick_home(Vector2(-raw.x,raw.y),false)
			check(r.distance_to(Vector3(-l.x,l.y,l.z))<0.0001,"Left/right stick trajectories mirror exactly")
		m.sync_skater_contacts(actor);await physics_frame
		m.carrier=actor;m.cooldown=0;m.puck.freeze=false;m.puck.position=v.get_blade_world();m.puck.linear_velocity=Vector3.ZERO
		m.skills_for(actor).move="";m.skills_for(actor).cooldown=0
		for tick in range(720):
			if tick%240==0:check(m.skills_for(actor).request(["cut","toe_drag","sweep"][tick/240],side),"Each handed skill can start")
			var skill=m.prepare_skills(actor,1.0/120,Vector2.ZERO,m.carrier==actor,false)
			actor.velocity=m.Skating.step(actor.velocity,skill.steer(Vector3.FORWARD*0.35,v.rig.global_basis.x),75,false,1.0/120)
			actor.move_and_slide();v.animate_motion(actor.velocity,1.0/120,0,true);m.sync_skater_contacts(actor)
			var before:Vector3=m.puck.position;m.update_possession(1.0/120)
			check(m.puck.position.distance_to(before)<0.00001,"Handed carrying never repositions puck")
			inspect(v);await physics_frame
			total+=1
			if m.carrier==actor:held+=1
			worst_gap=maxf(worst_gap,m.puck.position.distance_to(v.get_blade_world()))
		for kind in ["pass","shot","slap"]:
			v.play_release(kind,Vector3.FORWARD)
			for f in range(120):v.animate(4,1.0/120,0,true);inspect(v)
	check(float(held)/total>0.98 and worst_gap<0.35,"Both handed moving dekes retain close physical control")
	check(worst_contact<0.025,"Both handed fists remain seated on shaft")
	print("Strong side: ",checks," checks; ",failures," failures; held ",held,"/",total," gap ",worst_gap," contact ",worst_contact," thumb dot ",min_thumb)
	quit(failures)
