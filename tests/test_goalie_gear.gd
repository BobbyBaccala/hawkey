extends SceneTree
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok:push_error(message);failures+=1
func _initialize()->void:call_deferred("run")
func bottom(transform_:Transform3D,size:Vector3)->float:
	return transform_.origin.y-(absf(transform_.basis.x.y)*size.x+absf(transform_.basis.y.y)*size.y+absf(transform_.basis.z.y)*size.z)/2
func run()->void:
	var scene=load("res://practice.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	for actor in [scene.player,scene.teammate]+scene.goalkeepers:scene.set_puck_contacts_enabled(actor,false)
	var keeper=scene.goalkeepers[0]
	keeper.position=Vector3.ZERO
	keeper.rotation=Vector3.ZERO
	var visual=keeper.get_child(1)
	visual.rotation=Vector3.ZERO
	visual.butterfly=0
	visual.animate(0,1)
	scene.sync_goalie_contacts(keeper)
	scene.set_puck_contacts_enabled(keeper,true)
	check(keeper.get_node("PuckContact").get_child_count()==0,"No invisible broad pad wall")
	check(visual.posed_head.y<1.4,"Goalie must start in a compact active stance")
	for skate in visual.skates:
		check(absf(skate.position.y-0.0625)<0.002,"Skate blade rests at ice level")
	var ready_pad:Transform3D=keeper.get_node("PadLeft").transform
	visual.butterfly=1
	visual.animate(0,1)
	scene.sync_goalie_contacts(keeper)
	check(ready_pad.basis.y.angle_to(keeper.get_node("PadLeft").basis.y)>0.4,"Butterfly rotates individual pad collision with visible shin")
	for name_ in visual.get_goalie_gear():
		var spec:Dictionary=visual.get_goalie_gear()[name_]
		var body=keeper.get_node(name_)
		check(body.transform.is_equal_approx(spec.transform),"Visible and physical gear share transform: "+name_)
		if name_ in ["PadLeft","PadRight"]:
			check(bottom(body.transform,spec.size)>-0.002,"Pad does not penetrate ice")
			check(absf(body.basis.z.y)<0.1,"Butterfly pad face remains upright toward the shooter")
	check(keeper.get_node("Blocker").physics_material_override.bounce>keeper.get_node("Catcher").physics_material_override.bounce,"Blocker and catcher have distinct rebound materials")
	# Send real pucks at each pad and at the blocker; record the actual collision body.
	var touched:Array[String]=[]
	scene.puck.body_entered.connect(func(body):touched.append(str(body.name)))
	for name_ in ["PadLeft","PadRight","Blocker"]:
		var body=keeper.get_node(name_)
		var target:Vector3=body.position
		scene.puck.position=target+Vector3(0,0.05,-0.85)
		scene.puck.rotation=Vector3.ZERO
		scene.puck.angular_velocity=Vector3.ZERO
		scene.puck.linear_velocity=Vector3(0,0,8)
		scene.puck.sleeping=false
		touched.clear()
		for i in range(25):await physics_frame
		check(name_ in touched,"Lifted shot makes physical "+name_+" contact")
	# A puck outside the visible pads must not be blocked by the discarded wall.
	scene.puck.position=Vector3(1.3,0.06,-1)
	scene.puck.linear_velocity=Vector3(0,0,8)
	scene.puck.angular_velocity=Vector3.ZERO
	touched.clear()
	for i in range(25):await physics_frame
	check(not ("PadLeft" in touched or "PadRight" in touched),"Shot outside pad silhouette remains unblocked")
	scene.queue_free()
	await process_frame
	var match_=load("res://main.tscn").instantiate()
	root.add_child(match_)
	await physics_frame
	match_.set_physics_process(false)
	var catcher=match_.goalkeepers[0].get_node("Catcher")
	var front:Vector3=catcher.global_basis.z
	match_.puck.global_position=catcher.global_position+front*0.06
	match_.last_puck_velocity=-front*12
	match_.goalie_contact_timer=0
	match_.match_state.phase=match_.MatchState.Phase.PLAY
	match_._on_puck_contact(catcher)
	check(match_.match_state.phase==match_.MatchState.Phase.STOPPAGE,"Front pocket catch whistles play dead")
	match_.match_state.phase=match_.MatchState.Phase.PLAY
	match_.last_puck_velocity=front*12
	match_.goalie_contact_timer=0
	match_._on_puck_contact(catcher)
	check(match_.match_state.phase==match_.MatchState.Phase.PLAY,"Rear glove hit is not an automatic catch")
	match_.queue_free()
	await process_frame
	print("Goalie gear failures: ",failures)
	quit(failures)
