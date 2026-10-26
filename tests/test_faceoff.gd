extends SceneTree
## Faceoff presentation: players set in a faceoff stance at the dot (centres in
## a deep crouch with the blade on the ice by the dot), the camera cuts in close
## on the dot, and everyone breaks out of the stance when the puck drops.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	await physics_frame
	scene.match_state.phase_timer = 50.0
	scene.camera_mode = 0
	for i in range(10): await physics_frame
	check(scene.match_state.phase == scene.MatchState.Phase.FACEOFF, "Match opens on a faceoff")
	var centres := []
	for actor in scene.skaters:
		var v = actor.get_child(1)
		if not bool(actor.get_meta("eligible")): continue
		check(v.faceoff_blend() > 0.99, "%s is set in the faceoff stance" % actor.name)
		var role := 0 if int(actor.get_meta("slot")) == 0 else (1 if int(actor.get_meta("slot")) < 3 else 2)
		check(v.faceoff_role == role, "%s has faceoff role %d" % [actor.name, role])
		if role == 0: centres.append(actor)
	check(centres.size() == 2, "Two centres take the draw")
	var dot: Vector3 = scene.next_faceoff
	for c in centres:
		var v = c.get_child(1)
		var blade: Vector3 = v.get_blade_world()
		check(Vector2(blade.x - dot.x, blade.z - dot.z).length() < 0.35, "%s blade on the ice by the dot (%.2f m)" % [c.name, Vector2(blade.x - dot.x, blade.z - dot.z).length()])
		check(blade.y < 0.06, "%s blade down on the ice (y %.3f)" % [c.name, blade.y])
		# Deep crouch: hips well below the skating stance, chest bent over.
		check(v.posed_drop.y < -0.27, "%s hips low in the stance (%.2f)" % [c.name, v.posed_drop.y])
		check(v.posed_head.y < 1.42, "%s head down over the dot (%.2f)" % [c.name, v.posed_head.y])
	check(centres[0].position.distance_to(centres[1].position) > 0.7, "Centres do not overlap")
	# Close camera on the dot (Dynamic), much nearer than the play camera.
	var cam_dist: float = scene.camera.global_position.distance_to(dot)
	check(cam_dist < 10.0, "Faceoff camera is close to the dot (%.1f m)" % cam_dist)
	var to_dot: Vector3 = (dot - scene.camera.global_position).normalized()
	check((-scene.camera.global_basis.z).dot(to_dot) > 0.95, "Faceoff camera looks at the dot")
	# Broadcast camera cuts in close too.
	scene.camera_mode = 2
	scene.faceoff_cut = true
	for i in range(3): await physics_frame
	cam_dist = scene.camera.global_position.distance_to(dot)
	check(cam_dist < 11.0, "Broadcast faceoff camera is close to the dot (%.1f m)" % cam_dist)
	scene.camera_mode = 0
	scene.faceoff_cut = true
	await physics_frame
	# Puck drop: stance blends out (no pop) and the camera eases back out.
	scene.match_state.phase_timer = 0.0
	await physics_frame
	await physics_frame
	check(scene.match_state.phase == scene.MatchState.Phase.PLAY, "Puck dropped")
	var v0 = centres[0].get_child(1)
	check(v0.faceoff_blend() > 0.5 and v0.faceoff_blend() < 1.0, "Stance blends out, not snapped (%.2f)" % v0.faceoff_blend())
	var last_cam: Vector3 = scene.camera.global_position
	var biggest := 0.0
	for i in range(60):
		await physics_frame
		biggest = maxf(biggest, scene.camera.global_position.distance_to(last_cam))
		last_cam = scene.camera.global_position
	check(v0.faceoff_blend() == 0.0, "Out of the stance within a second")
	check(biggest < 0.6, "Camera eases back to the play view without a jump (max %.2f m/frame)" % biggest)
	check(scene.camera.global_position.distance_to(dot) > 12.0, "Camera back out to the play framing")
	print("test_faceoff: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)
