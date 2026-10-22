extends SceneTree
const Stick=preload("res://scripts/puck_control.gd")
const Match=preload("res://scripts/match.gd")
var checks:=0
var failures:=0
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func run()->void:
	var body:=Vector3.ZERO;var blade:=Vector3(0.3,0.03,-1)
	check(Stick.can_receive(blade,Vector3.RIGHT*10,body,Vector3.ZERO,blade),"Reachable flat pass can be controlled")
	check(not Stick.can_receive(Vector3(0,0.03,0.2),Vector3.ZERO,body,Vector3.ZERO,blade),"Puck near boots cannot be vacuumed to distant blade")
	check(not Stick.can_receive(blade+Vector3.UP*0.3,Vector3.ZERO,body,Vector3.ZERO,blade),"Airborne puck cannot be claimed with stick assistance")
	check(not Stick.can_receive(blade,Vector3.RIGHT*24,body,Vector3.ZERO,blade),"Shot-speed puck is not an automatic stick catch")
	check(Stick.can_receive(blade,Vector3.RIGHT*18,body,Vector3.RIGHT*5,blade),"Receiving uses relative speed of moving player")
	for rate in [30.0,60.0,120.0]:
		var old:=Vector3(12,2,0)
		var new:=Stick.control_velocity(blade,old,Vector3.ZERO,blade,1.0/rate)
		check(absf(new.y-old.y)<0.00001,"Stick assistance does not lock vertical flight")
		check((new-old).length()<=Stick.MAX_CONTROL_ACCEL/rate+0.0001,"Cushion acceleration bounded at each tick rate")
	load("res://scripts/game_settings.gd").path="res://build/receiving-test/settings.json"
	Match.skip_title=true
	var m=load("res://main.tscn").instantiate();root.add_child(m);await physics_frame
	m.set_physics_process(false);m.set_process(false)
	m.match_state.phase=m.MatchState.Phase.PLAY
	for actor in m.skaters:m.set_actor_active(actor,false)
	for keeper in m.goalkeepers:m.set_actor_active(keeper,false)
	var receiver=m.skaters[1];m.set_actor_active(receiver,true)
	receiver.position=Vector3(5,0,0);receiver.velocity=Vector3.ZERO
	var v=receiver.get_child(1);v.rotation.y=0
	v.animate_motion(Vector3.ZERO,1.0/120,0,false);m.sync_skater_contacts(receiver)
	await physics_frame
	m.puck.freeze=false;m.carrier=null;m.cooldown=0
	m.puck.position=v.get_blade_world()+Vector3.LEFT*2
	m.puck.linear_velocity=Vector3.RIGHT*10
	var acquired:=false
	var max_dv:=0.0
	for tick in range(180):
		m.prepare_stick(receiver);v.animate_motion(Vector3.ZERO,1.0/120,0,false)
		m.sync_skater_contacts(receiver)
		var pos:Vector3=m.puck.position;var velocity:Vector3=m.puck.linear_velocity
		m.update_possession(1.0/120)
		check(m.puck.position.distance_to(pos)<0.00001,"Receiving never teleports puck to stick")
		if m.carrier==receiver:
			acquired=true
			max_dv=maxf(max_dv,(m.puck.linear_velocity-velocity).length())
		await physics_frame
	check(acquired and m.carrier==receiver,"Actual rigid-body pass is received and held")
	check(m.puck.linear_velocity.length()<0.6,"Incoming pass is absorbed smoothly")
	check(max_dv<=Stick.MAX_CONTROL_ACCEL/120+0.001,"No instantaneous velocity multiplication on receipt")
	check(m.puck.position.distance_to(v.get_blade_world())<0.15,"Controlled puck settles at physical blade")
	# Independent pickup lock: the passer cannot recapture instantly, but an
	# opponent at the physical puck can intercept immediately, even in flight.
	m.puck.freeze=true;m.carrier=null;m.cooldown=0.42
	m.lock_released_puck(receiver);m.puck.position=v.get_blade_world();m.puck.linear_velocity=Vector3.ZERO
	m.update_possession(1.0/120)
	check(m.carrier==null,"Own release has a short re-pickup lock")
	var opponent=m.skaters[5];m.set_actor_active(opponent,true)
	opponent.position=receiver.position;opponent.velocity=Vector3.ZERO
	var ov=opponent.get_child(1);ov.rotation.y=0;ov.animate_motion(Vector3.ZERO,1.0/120,0,false)
	m.puck.position=ov.get_blade_world();m.update_possession(1.0/120)
	check(m.carrier==opponent and m.cooldown==0,"Opponent can intercept during passer lock and act immediately")
	m.set_actor_active(opponent,false);m.carrier=null;m.advance_pickup_lock(0.3)
	m.puck.position=v.get_blade_world();m.update_possession(1.0/120)
	check(m.carrier==receiver,"Self-recovery is possible after release lock expires")
	# Recovering a poke/loose puck does not erase battle cooldown and create
	# immediate every-tick poke/recapture loops.
	m.carrier=null;m.release_in_flight=false;m.cooldown=0.22
	m.puck.position=v.get_blade_world();m.update_possession(1.0/120)
	check(m.carrier==receiver and is_equal_approx(m.cooldown,0.22),"Loose-puck receipt preserves battle cooldown")
	# Receiving and pass preload keep both fists solved onto the same shaft.
	var worst_gap:=0.0;var peak_cushion:=0.0
	v.receive_puck(Vector3.BACK*10)
	for tick in range(120):
		if tick<30:v.offer_receive(v.rig.to_global(Vector3(-0.65,0.03,1.2)))
		v.pass_preparation=1.0 if tick in range(30,60) else 0.0
		v.animate_motion(Vector3.ZERO,1.0/120,0,false)
		peak_cushion=maxf(peak_cushion,v.receive_offset.length())
		var top:Vector3=v.stick_grip();var axis:Vector3=(v.stick_heel(top)-top).normalized()
		for glove in v.skater_gloves:
			var hole:Vector3=glove.transform*v.GLOVE_HOLE
			worst_gap=maxf(worst_gap,(hole-top).cross(axis).length())
	check(peak_cushion>0.08,"Visible receive pose cushions the puck")
	check(worst_gap<0.02,"Both gloves remain on stick during receive and pass preparation")
	check(v.receive_age<0 and v.receive_weight<0.001 and v.pass_load<0.01,"Contact layers recover after action")
	print("Puck receiving: ",checks," checks; ",failures," failures; maximum receive dv ",max_dv)
	quit(failures)
