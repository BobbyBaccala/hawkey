extends SceneTree
const Skills=preload("res://scripts/puck_skills.gd")
const InputAdapter=preload("res://scripts/controller_input.gd")
const Match=preload("res://scripts/match.gd")
var failures:=0
var checks:=0
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func axis(c,which:int,value:float)->void:
	var e:=InputEventJoypadMotion.new();e.axis=which;e.axis_value=value;c.handle(e)
func button(c,which:int,pressed:bool)->void:
	var e:=InputEventJoypadButton.new();e.button_index=which;e.pressed=pressed;c.handle(e)
func run()->void:
	var c:=InputAdapter.new()
	button(c,JOY_BUTTON_LEFT_SHOULDER,true);axis(c,JOY_AXIS_RIGHT_Y,1)
	check(c.deke_pressed=="toe_drag" and not c.shoot_pressed,"LB down requests toe drag without a shot")
	c.clear_edges();axis(c,JOY_AXIS_RIGHT_Y,-1)
	check(c.deke_pressed=="sweep" and not c.shoot_pressed,"LB up requests sweep without a shot")
	c.clear_edges();axis(c,JOY_AXIS_RIGHT_X,1)
	check(c.deke_pressed=="cut","LB side requests cut")
	button(c,JOY_BUTTON_A,true);check(c.protect_down,"Protection can be held")
	button(c,JOY_BUTTON_A,false);check(not c.protect_down,"Protection releases cleanly")
	button(c,JOY_BUTTON_LEFT_SHOULDER,false);axis(c,JOY_AXIS_RIGHT_Y,0);axis(c,JOY_AXIS_RIGHT_Y,-1)
	check(c.shoot_pressed,"Unmodified upward flick still shoots")
	for kind in ["cut","toe_drag","sweep"]:
		var skill:=Skills.new();check(skill.request(kind),"Skill starts")
		check(not skill.request(kind),"Active skill cannot be spammed")
		for f in range(120):
			skill.advance(1.0/120,true)
			check(skill.stick(Vector2.ZERO,4,true).length()<1.42,"Skill stick command bounded")
		check(skill.move.is_empty(),"Skill completes into ordinary handling")
		skill.advance(1.0,false);check(skill.move.is_empty() and not skill.protecting,"Possession loss cancels action/protection")
	load("res://scripts/game_settings.gd").path="res://build/skills-test/settings.json"
	Match.skip_title=true
	var m=load("res://main.tscn").instantiate();root.add_child(m);await physics_frame
	m.set_physics_process(false);m.set_process(false);m.match_state.phase=m.MatchState.Phase.PLAY
	for actor in m.skaters:m.set_actor_active(actor,false)
	for keeper in m.goalkeepers:m.set_actor_active(keeper,false)
	var actor=m.player;m.set_actor_active(actor,true);actor.position=Vector3(-3,0,4)
	var v=actor.get_child(1);v.rotation.y=0
	v.animate_motion(Vector3.ZERO,1.0/120,0,false);m.sync_skater_contacts(actor);await physics_frame
	m.carrier=actor;m.cooldown=0;m.puck.freeze=false;m.puck.position=v.get_blade_world();m.puck.linear_velocity=Vector3.ZERO
	var last_local:=Vector3.INF;var center_crossings:=0
	var overlap_ticks:=0;var peak_height:=0.0;var max_penetration:=0.0
	var max_error:=0.0;var worst_hand:=0.0;var max_reach:=0.0;var held:=0;var total:=0
	for kind in ["cut","toe_drag","sweep","protection"]:
		if kind!="protection":check(m.request_player_skill(kind),"Human can request skill with real possession")
		for f in range(240):
			var skill=m.prepare_skills(actor,1.0/120,Vector2.ZERO,m.carrier==actor,kind=="protection" and f<120)
			actor.velocity=m.Skating.step(actor.velocity,skill.steer(Vector3.FORWARD*0.35,v.rig.global_basis.x),75,false,1.0/120)
			actor.move_and_slide();v.animate_motion(actor.velocity,1.0/120,0,true)
			m.sync_skater_contacts(actor)
			var before:Vector3=m.puck.position
			m.update_possession(1.0/120)
			check(m.puck.position.distance_to(before)<0.00001,"Deke never teleports puck")
			await physics_frame
			var local_puck:Vector3=v.stick_blade.to_local(m.puck.position)
			if last_local!=Vector3.INF and absf(last_local.x)<0.08 and absf(local_puck.x)<0.08:
				var before_side:=signf(last_local.z+0.023*pow(clampf(last_local.x/0.28+0.5,0,1),2))
				var after_side:=signf(local_puck.z+0.023*pow(clampf(local_puck.x/0.28+0.5,0,1),2))
				if before_side!=after_side:center_crossings+=1
			last_local=local_puck
			var query:=PhysicsShapeQueryParameters3D.new()
			query.shape=m.puck.get_child(1).shape;query.transform=m.puck.global_transform;query.collision_mask=m.puck.BLADE_LAYER
			var hits:Array=m.get_world_3d().direct_space_state.intersect_shape(query)
			if not hits.is_empty():
				overlap_ticks+=1
				var rest:Dictionary=m.get_world_3d().direct_space_state.get_rest_info(query)
				if not rest.is_empty():
					var nd:float=absf(rest.normal.dot(m.puck.global_basis.y))
					var support:float=0.0127*nd+0.0381*sqrt(maxf(0,1-nd*nd))
					max_penetration=maxf(max_penetration,support-rest.normal.dot(m.puck.position-rest.point))
			peak_height=maxf(peak_height,m.puck.position.y)
			total+=1
			if m.carrier==actor:held+=1
			max_error=maxf(max_error,m.puck.position.distance_to(v.get_blade_world()))
			for arm in range(2):max_reach=maxf(max_reach,v.shoulder_of(arm).distance_to(v.posed_wrists[arm]))
			var top:Vector3=v.stick_grip();var shaft:Vector3=(v.stick_heel(top)-top).normalized()
			for glove in v.skater_gloves:
				var hole:Vector3=glove.transform*v.GLOVE_HOLE
				worst_hand=maxf(worst_hand,(hole-top).cross(shaft).length())
	check(m.puck.moving_contacts>0 and m.puck.sweep_contacts>0,"Moving-blade and disk sweeps both exercise real contacts")
	check(center_crossings==0,"Puck never crosses through the central blade face during dekes")
	check(max_penetration<0.005,"Moving puck never penetrates the blade deeper than the 5 mm contact skin")
	check(float(held)/total>0.98 and max_error<0.35,"Moving dekes retain close physical puck control")
	check(max_reach<0.62,"Deke arms remain within anatomical reach")
	check(worst_hand<0.025,"Both hands stay on shaft during moves")
	m.carrier=null;m.pickup_owner=false
	check(not m.request_player_skill("toe_drag"),"No possession means no skill command")
	actor.set_meta("control_age",1.0);m.carrier=actor;m.puck.position=actor.position+Vector3(0,0.03,2)
	m.update_possession(1.0/120)
	check(m.carrier==null,"A deke does not protect against real puck separation")
	# AI uses the same move state when facing pressure and no immediate shot.
	m.ai_vs_ai=true
	for p in m.skaters:
		m.set_actor_active(p,true);p.position=Vector3(-10,0,-15);p.velocity=Vector3.ZERO;p.set_meta("decision",1.0)
	var cpu=m.skaters[1];cpu.position=Vector3.ZERO;cpu.set_meta("decision",0.0)
	m.skaters[5].position=Vector3(2.4,0,0)
	m.carrier=cpu;m.puck.position=cpu.get_child(1).get_blade_world();m.cooldown=0
	m.update_team_ai(1.0/120)
	check(m.skills_for(cpu).moves_started>0,"AI chooses a skill under pressure")
	m.cooldown=0;m.carrier=cpu;m.puck.position=cpu.get_child(1).get_blade_world()
	m.skaters[5].position=m.puck.position+Vector3(0.35,0,0)
	m.update_team_ai(1.0/120)
	check(m.carrier==null and m.cooldown>0,"A defender can physically knock puck off an active deke")
	print("CONTACT_COUNTS moving ",m.puck.moving_contacts," swept ",m.puck.sweep_contacts)
	print("BLADE_OVERLAP_TICKS ",overlap_ticks," peak_height ",peak_height," penetration ",max_penetration," central face crossings ",center_crossings)
	print("Puck skills: ",checks," checks; ",failures," failures; held ",held,"/",total," max error ",max_error," hand gap ",worst_hand," arm reach ",max_reach)
	quit(failures)
