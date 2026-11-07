extends SceneTree
const Puck=preload("res://scripts/puck.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok:push_error(message);failures+=1
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://practice.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	for actor in [scene.player,scene.teammate]+scene.goalkeepers:
		scene.set_puck_contacts_enabled(actor,false)
	var puck=scene.puck
	check(puck.gravity_scale==1 and not puck.axis_lock_linear_y,"Puck must have gravity and free vertical motion")
	puck.position=Vector3(5,0.06,0)
	puck.linear_velocity=Puck.launch(Vector3.FORWARD,20,0.32)
	var peak:=0.0
	for i in range(180):
		await physics_frame
		peak=maxf(peak,puck.position.y)
	check(peak>1.7 and peak<2.4,"Lifted shot follows free ballistic arc")
	check(puck.position.y>0 and puck.position.y<0.1,"Puck lands on ice without height clamp")
	puck.position=Vector3(5,0.03,0)
	puck.rotation=Vector3.ZERO
	puck.angular_velocity=Vector3.ZERO
	puck.linear_velocity=Vector3.ZERO
	for i in range(60):await physics_frame
	puck.sleeping=false
	puck.linear_velocity=Vector3(5,0,0)
	for i in range(120):await physics_frame
	check(puck.grounded,"Ice contact must be recognized")
	check(puck.linear_velocity.x<4.9 and puck.linear_velocity.x>3.8,"Grounded drag slows puck without pinning it")
	# Shot targeted to upper net, sampled at the goal line without a goalkeeper.
	puck.position=Vector3(0,0.05,-15)
	puck.linear_velocity=Puck.launch(Vector3.FORWARD,29,Puck.solve_elevation(10,29,0.85,0.05))
	var crossing_height:=0.0
	for i in range(80):
		await physics_frame
		if puck.position.z<= -25:
			crossing_height=puck.position.y
			break
	check(crossing_height>0.65 and crossing_height<1.05,"Elevated shot reaches upper goal mouth")
	# A slow ground shot hitting the player's flat skate must stay low.
	scene.player.position=Vector3(0,0,0)
	scene.player.get_node("PuckContact").rotation.y=0
	scene.set_puck_contacts_enabled(scene.player,true)
	puck.position=Vector3(0.18,0.04,-1)
	puck.rotation=Vector3.ZERO
	puck.angular_velocity=Vector3.ZERO
	puck.linear_velocity=Vector3(0,0,6)
	peak=0
	for i in range(35):
		await physics_frame
		peak=maxf(peak,puck.position.y)
	check(peak<0.18,"Flat skate contact must not create capsule launch")
	# A lifted puck must meet the torso rather than pass through the skater.
	puck.position=Vector3(0,1.1,-1)
	puck.rotation=Vector3.ZERO
	puck.angular_velocity=Vector3.ZERO
	puck.linear_velocity=Vector3(0,0,8)
	for i in range(20):await physics_frame
	check(puck.linear_velocity.z<2,"Lifted puck must collide with torso")
	scene.queue_free()
	await process_frame
	print("Puck flight failures: ",failures)
	quit(failures)
