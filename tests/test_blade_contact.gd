extends SceneTree
## Actual rigid-body contact, independently of ownership/control assistance.
const Match=preload("res://scripts/match.gd")
var checks:=0
var failures:=0
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func run()->void:
	load("res://scripts/game_settings.gd").path="res://build/blade-contact-settings.json"
	Match.skip_title=true
	var m=load("res://main.tscn").instantiate();root.add_child(m);await physics_frame
	m.set_physics_process(false);m.set_process(false)
	for actor in m.skaters:m.set_actor_active(actor,false)
	for actor in m.goalkeepers:m.set_actor_active(actor,false)
	m.puck.collision_mask=33 # Isolate blade from nearby skates/torso for this fixture.
	var actor=m.player;m.set_actor_active(actor,true);actor.position=Vector3.ZERO
	var v=actor.get_child(1);v.rotation.y=0
	for hand in ["R","L"]:
		v.set_shoots(hand)
		for f in range(90):v.animate(0,1.0/120,0,false)
		m.sync_skater_contacts(actor);await physics_frame
		var blade:Transform3D=v.stick_blade.global_transform
		var pocket:Vector3=blade.affine_inverse()*v.get_blade_world()
		check(absf(pocket.z)>0.0381+0.0045,"Regulation puck radius fits outside visible blade")
		check(absf(v.get_blade_world().y-0.0127)<0.002,"Carry target rests at ice height")
		for face in [-1.0,1.0]:
			for speed in [5.0,14.0]:
				m.puck.freeze=true
				m.puck.position=blade*Vector3(0,-0.0163,face*0.45)
				m.puck.rotation=Vector3.ZERO;m.puck.angular_velocity=Vector3.ZERO;m.puck.linear_velocity=Vector3.ZERO
				m.sync_skater_contacts(actor);await physics_frame
				m.puck.freeze=false;m.puck.sleeping=false
				m.puck.linear_velocity=-blade.basis.z*face*speed
				var crossed:=false;var nearest:=INF
				for f in range(40):
					m.sync_skater_contacts(actor)
					await physics_frame
					var p:Vector3=blade.affine_inverse()*m.puck.position
					if absf(p.x)<0.10:
						nearest=minf(nearest,p.z*face)
						if p.z*face< -0.025:crossed=true
				print("BLADE_CASE ",hand," ",face," ",speed," nearest ",nearest," layers ",actor.get_node("StickContact").collision_layer)
				check(not crossed,"Free puck cannot pass through blade from either face at 5/14 m/s")
				check(nearest<0.10,"Unassisted puck actually reaches blade")
	print("Blade contact: ",checks," checks; ",failures," failures")
	quit(failures)
