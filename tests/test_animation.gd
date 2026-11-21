extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var skater = load("res://scripts/skater_visual.gd").new()
	root.add_child(skater)
	await process_frame
	check(skater.skeleton.get_bone_count() == 163,"Human skeleton must import")
	for i in range(360):
		skater.animate(8,1.0/120,0,true,false)
		# The runner (toe and heel) never cuts into the ice and skims low in
		# recovery: the toe may flick and the heel lift, not a running step.
		for skate in skater.skates:
			var toe: float = (skate.transform*Vector3(0,-0.06,0.225)).y
			var heel: float = (skate.transform*Vector3(0,-0.06,-0.085)).y
			check(toe > -0.004 and toe < 0.10,"Skate toe must skim low over the ice (%.3f m)" % toe)
			check(heel > -0.004 and heel < 0.20,"Heel lifts at toe-off but no running step (%.3f m)" % heel)
	check(skater.push_blend > 0.9,"Pushing must activate lateral stride")
	for i in range(180):
		skater.animate(8,1.0/120,0,false,false)
	check(skater.push_blend < 0.01,"Coasting must blend to glide instead of running")
	var phase = skater.phase
	skater.animate(8,0.1,0,false,false)
	check(is_equal_approx(phase,skater.phase),"Gliding must stop the push cycle")
	check(skater.posed_head.y < 1.6,"Hockey stance must lower head from upright rest height")
	check(skater.knees[0].z>skater.feet[0].z,"Ready stance keeps knees flexed forward over blades")
	for input_ in [Vector2.ZERO,Vector2(1,1),Vector2(-1,-1)]:
		skater.desired_stick=input_.limit_length()
		for i in range(30):skater.animate(0,1.0/120)
		# Real heel (the blade runs on from it in the shaft's plane).
		var shaft:Vector3=skater.stick_grip()-skater.stick_heel(skater.stick_grip())
		var lie:float=rad_to_deg(atan2(shaft.y,Vector2(shaft.x,shaft.z).length()))
		check(lie>40 and lie<76,"Stick shaft retains playable lie through stickhandling range (%.0f deg)" % lie)
	check(skater.stick_blade.get_aabb().size.z<0.04,"Blade remains thin with a restrained curve")
	skater.queue_free()
	await process_frame
	print("Animation integration failures: ",failures)
	quit(failures)
