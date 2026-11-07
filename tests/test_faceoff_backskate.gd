extends SceneTree
## Faceoff slice 6: the linesman's backing glide is real backward skating
## (alternating C-cuts on the ice, hips sat back), and a team's second faceoff
## violation on the same faceoff costs a delay-of-game minor.
const Visual = preload("res://scripts/skater_visual.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func _initialize() -> void: call_deferred("run")

func run() -> void:
	check_c_cut_cycle()
	await check_linesman_cuts()
	await check_delay_of_game()
	print("test_faceoff_backskate: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)

## Pure cycle: each skate cuts a C out to its own side and comes back under the
## hip; never both out at once; stays on the ice; continuous.
func check_c_cut_cycle() -> void:
	var v = Visual.new()
	var max_out := [0.0, 0.0]
	var max_fwd := [0.0, 0.0]
	var both_out := 0
	var max_lift := 0.0
	var max_step := 0.0
	var last := [null, null]
	var out_side_ok := true
	for k in range(241):
		v.back_phase = TAU * float(k) / 240.0
		var outs := [0.0, 0.0]
		for i in range(2):
			var c: Dictionary = v.back_cut_foot(i)
			var a: Vector3 = c.ankle
			var side := 1.0 if i == 0 else -1.0
			if a.x * side < Visual.BACK_BASE.x - 0.001: out_side_ok = false
			outs[i] = a.x * side - Visual.BACK_BASE.x
			max_out[i] = maxf(max_out[i], outs[i])
			max_fwd[i] = maxf(max_fwd[i], a.z)
			max_lift = maxf(max_lift, a.y - Visual.BACK_BASE.y)
			if last[i] != null: max_step = maxf(max_step, (a - (last[i] as Vector3)).length())
			last[i] = a
		if outs[0] > 0.06 and outs[1] > 0.06: both_out += 1
	check(max_out[0] > 0.18 and max_out[1] > 0.18, "Both skates cut out to the side (%.2f, %.2f m)" % max_out)
	check(max_fwd[0] > 0.15 and max_fwd[1] > 0.15, "The C curls round in front (%.2f, %.2f m)" % max_fwd)
	check(out_side_ok, "A skate never crosses under the other")
	check(both_out == 0, "Skates cut in turn, never both out (%d samples)" % both_out)
	check(max_lift <= 0.016, "Skates stay on the ice (lift %.3f m)" % max_lift)
	check(max_step < 0.012, "C-cut path continuous (max %.4f m per 1/240 cycle)" % max_step)
	v.free()

## In the match: after the drop the linesman's skates actually cut (feet move
## sideways in rig space, alternating) while he backs away facing the dot.
func check_linesman_cuts() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	await physics_frame
	scene.match_state.phase_timer = 50.0
	scene.camera_mode = 0
	for i in range(10): await physics_frame
	scene.violation_rng.seed = 1  # no violation at this draw
	scene.violation_checked = true
	var linesman = scene.linesman
	scene.match_state.phase_timer = 0.0
	var frames := 0
	while not scene.draw_landed and frames < 200:
		await physics_frame
		frames += 1
	check(scene.backing_official == linesman, "Linesman backing out")
	var yaw0: float = linesman.rotation.y
	var widest := [0.0, 0.0]
	var ankle_jump := 0.0
	var last := [null, null]
	var lowest_hips := 1.0
	var rest_hips: float = linesman.rig.position.y
	for f in range(int(0.9 * 120)):
		await physics_frame
		if f < 30: continue
		for i in range(2):
			var a: Vector3 = linesman.stride[i].ankle
			widest[i] = maxf(widest[i], absf(a.x))
			if last[i] != null: ankle_jump = maxf(ankle_jump, (a - (last[i] as Vector3)).length())
			last[i] = a
	check(linesman.back_skate > 0.9, "Backward-skating pose blended in (%.2f)" % linesman.back_skate)
	check(widest[0] > 0.28 and widest[1] > 0.28, "Both of his skates push C-cuts (%.2f, %.2f m out)" % widest)
	check(ankle_jump < 0.03, "No foot pops while backing (max %.3f m/frame)" % ankle_jump)
	check(absf(wrapf(linesman.rotation.y - yaw0, -PI, PI)) < 0.01, "Still facing the dot")
	for i in range(240): await physics_frame
	check(scene.backing_official == null and linesman.back_skate < 0.05, "Back to forward skating after the glide (%.2f)" % linesman.back_skate)
	scene.queue_free()
	await physics_frame

## Second violation by the same team on one faceoff: delay of game minor.
func check_delay_of_game() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	await physics_frame
	scene.match_state.phase_timer = 50.0
	scene.camera_mode = 0
	for i in range(10): await physics_frame
	var user: int = scene.user_team()
	var centre = null
	for c in scene.draw_centres:
		if scene.body_team(c) == user: centre = c
	check(scene.start_violation(centre), "First violation waves the centre out")
	check(scene.match_state.phase == 0 and scene.match_state.penalties.is_empty(), "First violation: no penalty, still a faceoff")
	# Let the swap finish: the linesman checks again at the next last tick.
	scene.violation_checked = true
	for i in range(int(2.0 * 120)): await physics_frame
	check(scene.violation_checked == false, "After the swap sets, the next last tick is checked again")
	var sub = scene.violation_sub
	check(scene.draw_centres.has(sub), "Winger now takes the draw")
	var other = null
	for c in scene.draw_centres:
		if scene.body_team(c) != user: other = c
	# The other team's first violation is free.
	scene.draw_violations[1 - user] = 0
	var penalties_before: int = scene.match_state.penalties.size()
	var totals: Array = scene.faceoff_violations.duplicate()
	check(scene.start_violation(sub), "Second violation by the same team")
	check(scene.match_state.penalties.size() == penalties_before + 1, "Second violation assesses a minor")
	var p: Dictionary = scene.match_state.penalties.back() if not scene.match_state.penalties.is_empty() else {}
	check(p.get("reason", "") == scene.DELAY_OF_GAME and int(p.get("team", -1)) == user, "Minor is delay of game on the offending team (%s)" % str(p))
	check(int(p.get("roster_id", -1)) == int(sub.get_meta("roster_id")), "Charged to the player waved out second")
	check(scene.faceoff_violations[user] == totals[user] + 1, "Counted in the team's violations")
	check(scene.match_state.phase == 2, "Play stops for the penalty (phase %d)" % scene.match_state.phase)
	check(scene.hud_node.faceoff_cue.visible and scene.hud_node.faceoff_cue_title.text == "DELAY OF GAME", "DELAY OF GAME cue shown")
	# After the stoppage a new faceoff is set up with the team short-handed.
	for i in range(int(3.0 * 120)): await physics_frame
	check(scene.match_state.count(user) == 4, "Penalised team plays 4 skaters (%d)" % scene.match_state.count(user))
	check(scene.draw_violations == [0, 0], "Violation count resets at the new faceoff")
	check(not bool(sub.get_meta("eligible", true)), "Penalised player off the ice")
	# A first violation for the other team on a fresh faceoff costs nothing.
	var other_centre = null
	for c in scene.draw_centres:
		if scene.body_team(c) != user: other_centre = c
	if other_centre != null:
		var n: int = scene.match_state.penalties.size()
		scene.start_violation(other_centre)
		check(scene.match_state.penalties.size() == n, "A team's first violation is never penalised")
	scene.queue_free()
	await physics_frame
