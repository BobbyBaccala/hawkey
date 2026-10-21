extends SceneTree
const Match=preload("res://scripts/match.gd")
const T=preload("res://scripts/team_tactics.gd")
const Settings=preload("res://scripts/game_settings.gd")
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Settings.path="res://build/tactics-test/settings.json"
	Match.skip_title=true
	change_scene_to_file("res://main.tscn")
	for i in range(4): await process_frame
	var m=current_scene
	m.set_physics_process(false);m.set_process(false)
	m.in_menu=false;m.cooldown=10
	var controlled=m.player
	m.carrier=m.skaters[1]
	for actor in m.skaters:
		actor.set_meta("changing",false);actor.set_meta("hop",0);actor.set_meta("eligible",true)
		actor.position=Vector3(float(actor.get_meta("slot"))*2-4,0,18*m.attack_direction(0) if m.body_team(actor)==0 else 10*m.attack_direction(1))
		actor.velocity=Vector3.ZERO
	m.puck.position=m.carrier.position
	var original: Vector3=controlled.position
	m.update_team_ai(1.0/60)
	check(controlled.position==original,"Planner never moves human-controlled skater")
	var wing=m.skaters[2]
	var old: Vector3=wing.get_meta("tactical_target")
	T.set_choice(0,"offense",2);m.update_team_ai(1.0/60)
	check(not old.is_equal_approx(wing.get_meta("tactical_target")),"Coaching option changes actual match target")
	check(wing.velocity.length()>0,"Tactical movement uses skating physics")
	m.hud_node.coaching_team.select(1);m.hud_node.refresh_coaching()
	m.hud_node.coaching_choices.breakout.item_selected.emit(2)
	check(T.choices[1].breakout==2 and T.choices[0].breakout==0,"UI edits selected team independently")
	m.hud_node.coaching_team.select(0);m.hud_node.refresh_coaching()
	check(m.hud_node.coaching_choices.offense.selected==2,"UI refresh retains selection")
	# Bench/changing and penalized actors are absent from the planner population.
	var bench=m.skaters[4];bench.set_meta("changing",true);bench.set_meta("pending_id",13)
	bench.position=Vector3(4,0,0)
	var penalized=m.skaters[9];penalized.set_meta("eligible",false)
	m.update_team_ai(1.0/60)
	check(not m.tactical_plans[0].has(bench.get_instance_id()),"Changing player excluded")
	check(not m.tactical_plans[1].has(penalized.get_instance_id()),"Penalized player excluded")
	bench.set_meta("changing",false)
	m.update_team_ai(1.0/60)
	check(m.tactical_plans[0][wing.get_instance_id()].phase!="Power play","Roster absence does not invent a penalty advantage")
	m.match_state.minor(1,int(penalized.get_meta("roster_id")),"Tactical test")
	m.update_team_ai(1.0/60)
	check(m.tactical_plans[0][wing.get_instance_id()].phase=="Power play","Real penalty enables PP")
	check(m.tactical_plans[1][m.skaters[5].get_instance_id()].phase=="Penalty kill","Same penalty enables opposing PK")
	m.match_state.penalties.clear()
	m.update_team_ai(1.0/60)
	check(m.tactical_plans[0][wing.get_instance_id()].phase!="Power play","Penalty expiry restores even-strength tactics")
	# Lane obstruction and bench exclusion use the physical opponent positions.
	for actor in m.skaters:
		actor.position=Vector3(10,0,-20)
		actor.set_meta("eligible",true);actor.set_meta("changing",false)
	m.skaters[5].position=Vector3(0,0,0)
	check(not m.lane_clear(Vector3(0,0,-5),Vector3(0,0,5),0),"Opponent blocks passing lane")
	m.skaters[5].set_meta("eligible",false)
	check(m.lane_clear(Vector3(0,0,-5),Vector3(0,0,5),0),"Penalized opponent cannot block lane")
	# Exercise actual puck decisions, not only desired station geometry.
	var cpu=m.skaters[1]
	var attack: float=m.attack_direction(0)
	for actor in m.skaters:
		actor.set_meta("eligible",true);actor.set_meta("changing",false)
		actor.position=Vector3(-10,0,20*attack);actor.velocity=Vector3.ZERO
	cpu.position=Vector3(0,0,-18*attack)
	m.skaters[2].position=Vector3(8,0,-10*attack)
	m.carrier=cpu;m.puck.position=cpu.position;m.cooldown=0;cpu.set_meta("decision",0.0)
	m.update_team_ai(1.0/60)
	check(m.carrier==null and m.puck.linear_velocity.x>1,"AI breakout carrier releases physical pass to forward outlet")
	m.match_state.minor(0,int(m.skaters[4].get_meta("roster_id")),"Clear test")
	for actor in m.skaters: actor.position=Vector3(-10,0,20*attack)
	cpu.position=Vector3(0,0,-18*attack)
	m.carrier=cpu;m.puck.position=cpu.position;m.cooldown=0;cpu.set_meta("decision",0.0)
	m.update_team_ai(1.0/60)
	check(m.carrier==null and m.puck.linear_velocity.z*attack>12 and m.puck.linear_velocity.y>3,"PK carrier clears up ice when no safe outlet exists")
	m.match_state.penalties.clear()
	T.choices=[T.defaults(),T.defaults()]
	change_scene_to_file("res://events.tscn");await process_frame
	print("Tactics match: %d checks; %d failures"%[checks,failures]);quit(failures)
