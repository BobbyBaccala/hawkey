extends SceneTree
## Faceoff slice 5: the linesman sometimes waves a centre out of the draw (more
## often when the user jumps it); a winger skates in and takes the draw while
## the faceoff phase (and the clock) waits. A draw-timing hint shows at the
## first faceoffs.
const Match = preload("res://scripts/match.gd")
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
	var hud = scene.hud_node
	check(hud.draw_hint.visible, "Draw-timing hint shows at the opening faceoff")
	check(scene.draw_centres.size() == 2, "Two centres take the draw")
	var user: int = scene.user_team()

	# Odds: rare on its own, likely when the user jumps the drop, and a jump
	# only ever gets the user's own centre thrown out.
	var counts := {"none": 0, "jumped": 0, "jumped_user": 0}
	for mode in ["none", "jumped"]:
		scene.violation_rng.seed = 4242
		for i in range(1000):
			scene.draw_press = Match.DRAW_JUMPED if mode == "jumped" else Match.DRAW_NO_PRESS
			var v = scene.pick_violator()
			if v != null:
				counts[mode] += 1
				if mode == "jumped" and scene.body_team(v) == user: counts["jumped_user"] += 1
	print("violations of 1000: ", counts)
	check(counts["none"] > 25 and counts["none"] < 110, "Random violations are occasional (%d / 1000)" % counts["none"])
	check(counts["jumped"] > 520 and counts["jumped"] < 680, "Jumping the drop usually gets waved out (%d / 1000)" % counts["jumped"])
	check(counts["jumped_user"] >= counts["jumped"] - counts["none"] * 2, "A jump throws out the user's centre")
	scene.draw_press = Match.DRAW_NO_PRESS

	# A real violation: the user jumps, and the roll says the linesman saw it.
	var seed_ := 1
	while true:
		var r := RandomNumberGenerator.new()
		r.seed = seed_
		if r.randf() < Match.VIOLATION_JUMP_CHANCE: break
		seed_ += 1
	scene.violation_rng.seed = seed_
	var centre = null
	for c in scene.draw_centres:
		if scene.body_team(c) == user: centre = c
	scene.player = centre
	scene.player_visual = centre.get_child(1)
	scene.match_state.phase_timer = 0.3
	scene.register_draw_press()
	check(scene.draw_press == Match.DRAW_JUMPED, "User jumped the drop")
	var clock: float = scene.match_state.clock
	var frames := 0
	while scene.violation_timer < 0.0 and frames < 60:
		await physics_frame
		frames += 1
	check(scene.violation_timer >= 0.0, "Linesman calls a violation")
	check(scene.violator == centre, "The user's centre is waved out")
	var sub = scene.violation_sub
	check(sub != null and scene.body_team(sub) == user and int(sub.get_meta("slot")) in [1, 2], "A winger of the same team comes in")
	check(scene.match_state.phase == scene.MatchState.Phase.FACEOFF, "Faceoff phase held for the swap")
	check(hud.faceoff_cue.visible and hud.faceoff_cue_title.text == "FACEOFF VIOLATION", "Violation cue shown (%s)" % hud.faceoff_cue_title.text)
	check(hud.faceoff_cue_sub.text.contains("WAVED OUT"), "Cue names who was waved out (%s)" % hud.faceoff_cue_sub.text)
	check(not hud.draw_hint.visible, "Hint hidden during the violation")
	check(scene.draw_press == Match.DRAW_NO_PRESS, "Fresh timing for the new draw")
	var centre_spot: Vector3 = scene.violation_from
	var wing_spot: Vector3 = scene.violation_to
	var linesman = scene.linesman
	var max_wave := 0.0
	var max_step := 0.0
	var prev_c: Vector3 = centre.position
	var prev_s: Vector3 = sub.position
	var turned := false
	frames = 0
	while scene.match_state.phase == scene.MatchState.Phase.FACEOFF and frames < 400:
		await physics_frame
		frames += 1
		max_wave = maxf(max_wave, linesman.wave_out)
		max_step = maxf(max_step, maxf(centre.position.distance_to(prev_c), sub.position.distance_to(prev_s)))
		prev_c = centre.position
		prev_s = sub.position
		var set_yaw := 0.0 if scene.attack_direction(user) < 0 else PI
		if absf(wrapf(centre.get_child(1).rotation.y - set_yaw, -PI, PI)) > 0.8: turned = true
	check(max_wave > 0.9, "Linesman waves him out (%.2f)" % max_wave)
	check(max_step < 0.1, "Players skate the swap, no teleport (max %.3f m/frame)" % max_step)
	check(turned, "Waved-out centre turns to skate away")
	check(centre.position.distance_to(wing_spot) < 0.05, "Waved-out centre ends on the wing")
	check(sub.position.distance_to(centre_spot) < 0.05, "Winger ends on the centre's spot")
	check(sub in scene.draw_centres and not centre in scene.draw_centres, "Winger takes the draw")
	check(sub.get_child(1).faceoff_role == 0 and centre.get_child(1).faceoff_role == 1, "Stances swapped")
	check(scene.player == sub, "User control moves to the new centre")
	check(absf(scene.match_state.clock - clock) < 0.001, "Clock did not run during the violation")
	check(scene.faceoff_violations[user] == 1, "Violation counted")
	check(frames > int(1.5 * 120), "Drop waited for the swap (%d frames)" % frames)
	# The drop follows and the new centre takes it.
	frames = 0
	while not scene.draw_landed and frames < 200:
		await physics_frame
		frames += 1
	check(scene.draw_landed, "Puck dropped after the violation")
	check(scene.faceoff_winner in scene.draw_centres, "Draw decided between the centres now in the circle")
	check(linesman.wave_out == 0.0, "Linesman's arm back down")
	print("test_faceoff_violation: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)
