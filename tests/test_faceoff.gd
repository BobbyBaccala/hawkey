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
	# The linesman holds the puck out over the dot.
	var linesman = scene.linesman
	check(linesman != null, "A linesman takes the faceoff")
	if linesman != null:
		var off := Vector2(linesman.position.x - dot.x, linesman.position.z - dot.z).length()
		check(off > 0.6 and off < 1.3, "Linesman stands just off the dot (%.2f m)" % off)
		check(linesman.drop_hand > 0.99, "Linesman's arm is out with the puck")
	check(scene.puck.position.y > 0.75 and scene.puck.position.y < 1.3, "Puck held up in the linesman's hand (y %.2f)" % scene.puck.position.y)
	check(Vector2(scene.puck.position.x - dot.x, scene.puck.position.z - dot.z).length() < 0.12, "Puck held over the dot (%.2f m off)" % Vector2(scene.puck.position.x - dot.x, scene.puck.position.z - dot.z).length())
	# Puck drop: it falls to the dot while the centres stay down, poised.
	var wins_before: int = scene.faceoff_wins[0] + scene.faceoff_wins[1]
	scene.match_state.phase_timer = 0.0
	await physics_frame
	await physics_frame
	check(scene.match_state.phase == scene.MatchState.Phase.PLAY, "Puck dropped")
	check(scene.puck_in_air_at_drop(), "Puck falling from the linesman's hand")
	var v0 = centres[0].get_child(1)
	check(v0.faceoff_blend() > 0.99, "Centres stay down for the draw")
	var wing = null
	for actor in scene.skaters:
		if int(actor.get_meta("slot")) == 3: wing = actor.get_child(1)
	check(wing.faceoff_blend() < 1.0, "Wingers and D break out of the stance on the drop (no snap: %.2f)" % wing.faceoff_blend())
	var frames := 0
	var lowest := 9.0
	while scene.puck_in_air_at_drop() and frames < 120:
		await physics_frame
		frames += 1
		lowest = minf(lowest, scene.puck.position.y)
		var b: Vector3 = v0.get_blade_world()
		if frames == 20 and scene.puck_in_air_at_drop():
			check(b.y > 0.035, "Blade poised off the ice while the puck falls (y %.3f)" % b.y)
	check(frames > 20 and frames < 60, "Puck takes a believable time to fall (%d frames)" % frames)
	check(scene.faceoff_wins[0] + scene.faceoff_wins[1] == wins_before + 1, "The draw is won by one team")
	var winner = scene.faceoff_winner
	check(winner in centres, "A centre wins the draw")
	var landing: Vector3 = scene.puck.position
	check(Vector2(landing.x - dot.x, landing.z - dot.z).length() < 0.1, "Puck lands on the dot")
	var blade_start: Vector3 = winner.get_child(1).get_blade_world()
	for i in range(18): await physics_frame
	# The winner's blade sweeps back and the puck goes back toward his own end.
	var wv = winner.get_child(1)
	check(wv.draw_result == 1, "Winner's blade pulls the puck back")
	var back_dir := -signf(scene.attack_direction(scene.body_team(winner)))
	var moved: Vector3 = scene.puck.position - landing
	check(moved.z * back_dir > 0.4, "Puck drawn back toward the winner's end (%.2f m)" % (moved.z * back_dir))
	var blade_end: Vector3 = wv.get_blade_world()
	check((blade_end.z - blade_start.z) * back_dir > 0.15, "Winner's blade swept back (%.2f m)" % ((blade_end.z - blade_start.z) * back_dir))
	var last_cam: Vector3 = scene.camera.global_position
	var biggest := 0.0
	for i in range(120):
		await physics_frame
		biggest = maxf(biggest, scene.camera.global_position.distance_to(last_cam))
		last_cam = scene.camera.global_position
	check(v0.faceoff_blend() == 0.0, "Centres out of the stance within a second of the draw")
	check(biggest < 0.6, "Camera eases back to the play view without a jump (max %.2f m/frame)" % biggest)
	# (Measured from the play focus: the puck has gone back toward one end.)
	var from_focus: float = scene.camera.global_position.distance_to(scene.camera_target)
	check(from_focus > 11.0, "Camera back out to the play framing (%.1f m)" % from_focus)
	check(scene.linesman == null or scene.linesman.drop_hand < 0.05, "Linesman's arm back down")
	print("test_faceoff: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)
