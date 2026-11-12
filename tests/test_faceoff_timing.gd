extends SceneTree
## Faceoff timing (EA-style draw mini-game): shoot/pass pressed while the puck
## falls tips the draw toward the user's centre (best just before it lands),
## jumping the drop costs odds, and a FACEOFF WON / LOST cue shows on landing.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var Match = load("res://scripts/match.gd")
	# Grading.
	check(Match.draw_timing_quality(Match.DRAW_NO_PRESS, 0.3) == 0.0, "No press: no effect")
	check(Match.draw_timing_quality(Match.DRAW_JUMPED, 0.3) < 0.0, "Jumping the drop is penalised")
	check(is_equal_approx(Match.draw_timing_quality(0.0, 0.3), 0.5), "Press as the puck leaves the hand: half bonus")
	check(is_equal_approx(Match.draw_timing_quality(0.3, 0.3), 1.0), "Press at the landing: full bonus")
	check(Match.draw_timing_quality(0.28, 0.3) > Match.draw_timing_quality(0.1, 0.3), "Later in the fall is better")
	check(Match.draw_timing_grade(0.95) == "PERFECT", "Grade PERFECT")
	check(Match.draw_timing_grade(0.75) == "GOOD", "Grade GOOD")
	check(Match.draw_timing_grade(0.55) == "EARLY", "Grade EARLY")
	check(Match.draw_timing_grade(-1.0) == "JUMPED", "Grade JUMPED")
	check(Match.draw_timing_grade(0.0) == "", "No grade without a press")

	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	await physics_frame
	scene.match_state.phase_timer = 50.0
	for i in range(5): await physics_frame
	check(scene.match_state.phase == scene.MatchState.Phase.FACEOFF, "Match opens on a faceoff")
	var user: int = scene.user_team()
	# A press long before the drop is ignored; one in the last moments jumps it.
	scene.register_draw_press()
	check(scene.draw_press == Match.DRAW_NO_PRESS, "Press long before the drop is ignored")
	scene.match_state.phase_timer = 0.3
	scene.register_draw_press()
	check(scene.draw_press == Match.DRAW_JUMPED, "Press just before the drop jumps it")
	scene.draw_press = Match.DRAW_NO_PRESS

	# Odds: the same seeded draws, with and without perfect timing / jumping.
	var wins := {}
	for mode in ["none", "perfect", "jumped"]:
		scene.faceoff_rng.seed = 777
		var count := 0
		for i in range(600):
			scene.drop_timer = 0.3
			scene.draw_press = {"none": Match.DRAW_NO_PRESS, "perfect": 0.3, "jumped": Match.DRAW_JUMPED}[mode]
			if scene.body_team(scene.pick_faceoff_winner()) == user: count += 1
		wins[mode] = count
	print("user draw wins of 600: ", wins)
	check(wins["perfect"] > wins["none"] + 90, "Perfect timing wins clearly more draws (%d vs %d)" % [wins["perfect"], wins["none"]])
	check(wins["jumped"] < wins["none"] - 40, "Jumping the drop loses more draws (%d vs %d)" % [wins["jumped"], wins["none"]])
	scene.drop_timer = -1.0
	scene.draw_press = Match.DRAW_NO_PRESS
	scene.draw_timing = ""

	# A real drop: the press while the puck falls is recorded and graded, and
	# the cue appears when it lands.
	scene.match_state.phase_timer = 0.0
	await physics_frame
	await physics_frame
	check(scene.puck_in_air_at_drop(), "Puck falling")
	var frames := 0
	while scene.puck_in_air_at_drop() and frames < 120:
		if scene.puck.position.y < 0.2 and scene.draw_press == Match.DRAW_NO_PRESS:
			scene.register_draw_press()
		await physics_frame
		frames += 1
	check(scene.draw_press > 0.0, "Press during the fall recorded (%.3f s)" % scene.draw_press)
	check(scene.draw_timing in ["PERFECT", "GOOD"], "Late press graded well (%s)" % scene.draw_timing)
	var hud = scene.hud_node
	await physics_frame
	check(hud.faceoff_cue.visible, "Faceoff cue shown on the landing")
	var won: bool = scene.body_team(scene.faceoff_winner) == user
	check(hud.faceoff_cue_title.text == ("FACEOFF WON" if won else "FACEOFF LOST"), "Cue names the result (%s)" % hud.faceoff_cue_title.text)
	check(hud.faceoff_cue_sub.text.begins_with(scene.draw_timing), "Cue shows the timing grade (%s)" % hud.faceoff_cue_sub.text)
	# A press after the landing does nothing to the decided draw.
	var before: float = scene.draw_press
	scene.register_draw_press()
	check(scene.draw_press == before, "Press after the landing ignored")
	print("test_faceoff_timing: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)
