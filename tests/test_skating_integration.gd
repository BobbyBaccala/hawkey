extends SceneTree
const Match=preload("res://scripts/match.gd")
var failures:=0
func check(ok:bool,why:String)->void:
	if not ok:failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func run()->void:
	load("res://scripts/game_settings.gd").path="res://build/skating-integration/settings.json"
	Match.skip_title=true
	var m=load("res://main.tscn").instantiate();root.add_child(m);await process_frame
	m.set_physics_process(false);m.set_process(false);m.ai_vs_ai=true;m.puck.freeze=true;m.cooldown=100
	for actor in m.skaters:
		actor.position=Vector3((int(actor.get_meta("slot"))-2)*3,0,8 if m.body_team(actor)==0 else -8)
		actor.velocity=Vector3.ZERO
		m.carrier=actor;m.puck.position=actor.position+Vector3(4,0.03,2)
		check(m.body_facing(actor).dot(m.net_facing(actor))>0.999,"Carrier faces attacked net at both ends")
		m.carrier=null
		var d:Vector3=(m.puck.position-actor.position);d.y=0;d=d.normalized()
		check(m.body_facing(actor).dot(d)>0.999,"Other skaters stay square to puck")
	var enemy=m.skaters[5];enemy.position=Vector3(4,0,17);m.carrier=enemy;m.puck.position=Vector3(4,0.03,17)
	m.skaters[3].position=Vector3(4,0,18) # Strong-side pressure covers the carrier.
	var defender=m.skaters[4];defender.position=Vector3(3,0,19) # Remaining defender retreats into coverage.
	var peak_backtracking:=0.0
	for f in range(150):
		m.update_team_ai(1.0/120)
		var current=defender.get_child(1)
		if defender.velocity.dot(-current.global_basis.z)< -0.2:
			peak_backtracking=maxf(peak_backtracking,current.backward_weight)
	var v=defender.get_child(1)
	var toward:Vector3=m.puck.position-defender.position;toward.y=0;toward=toward.normalized()
	var forward:Vector3=-v.global_basis.z
	check(forward.dot(toward)>0.98,"AI defender watches puck while repositioning")
	print("Defensive skating sample: velocity ",defender.velocity," backward weight ",v.backward_weight," role ",defender.get_meta("tactical_role",""))
	check(peak_backtracking>0.5,"Live tactical repositioning drives backward C-cuts while actually moving backward")
	# Spectator flag and ordinary user mode retain their existing input ownership.
	check(m.ai_vs_ai and defender.has_meta("tactical_target"),"Spectator uses real tactical assignment")
	m.ai_vs_ai=false;m.player=defender;m.player_visual=v
	m.controller.active=true;m.controller.left_stick=Vector2.ZERO;m.carrier=defender
	for i in range(90):m.control_player(1.0/120)
	check((-v.global_basis.z).dot(m.net_facing(defender))>0.98,"Human carrier uses same facing rule")
	print("Skating integration failures: ",failures)
	quit(failures)
