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
		for foot in skater.feet:
			check(foot.y >= 0.11 and foot.y < 0.17,"Skate recovery must stay low over ice")
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
		var shaft:Vector3=skater.stick_grip()-(skater.blade_position+Vector3(-0.1344,0,0))
		var lie:float=rad_to_deg(atan2(shaft.y,Vector2(shaft.x,shaft.z).length()))
		check(lie>42 and lie<76,"Stick shaft retains playable lie through stickhandling range")
	check(skater.stick_blade.get_aabb().size.z<0.04,"Blade remains thin with a restrained curve")
	skater.queue_free()
	await process_frame
	print("Animation integration failures: ",failures)
	quit(failures)
