extends SceneTree
## Goal celebration: a real goal in the match turns on the red goal light
## behind the scored-on net (lamp spinning, omni + beam lights on), pulses the
## arena light pools, and puts an animated GOAL then the team name on the
## jumbotron; everything returns to normal afterwards and the board shows the
## updated score.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	await physics_frame
	var c = scene.get_node_or_null("GoalCelebration")
	check(c != null, "GoalCelebration node exists under the match")
	if c == null:
		finish(scene)
		return
	check(c.lamps.size() == 2, "One goal light per net")
	var Arena = preload("res://scripts/arena.gd")
	for end_sign in [-1.0, 1.0]:
		var lamp = c.lamps[end_sign]
		var p: Vector3 = lamp.root.global_position
		check(signf(p.z) == end_sign and absf(p.z) > Arena.HALF_LENGTH, "Lamp %d sits behind the end glass (z %.2f)" % [end_sign, p.z])
		check(absf(p.x) < 0.5 and p.y > 2.5 and p.y < 3.2, "Lamp %d is centred over the net at glass height" % end_sign)
		check(not lamp.glow.visible and not lamp.beam.visible, "Lamp %d is off before a goal" % end_sign)
	check(not c.is_active(), "Nothing celebrating at puck drop")
	check(c.lighting != null and c.dressing != null, "Celebration found the arena lighting and jumbotron")
	var dressing = c.dressing
	var base_pool: float = c.lighting.pools[0].light_energy
	# Wait for play, then put the puck across the goal line of one net.
	scene.match_state.phase_timer = 0.05
	for i in range(240):
		await physics_frame
		if scene.match_state.phase == scene.MatchState.Phase.PLAY: break
	check(scene.match_state.phase == scene.MatchState.Phase.PLAY, "Match reached play")
	var end_sign := 1.0
	var scoring_team: int = 0 if scene.attack_direction(0) == end_sign else 1
	var before: int = scene.match_state.score[scoring_team]
	scene.previous_puck = Vector3(0.1, 0.02, end_sign * (Arena.GOAL_LINE - 0.25))
	scene.puck.position = Vector3(0.1, 0.02, end_sign * (Arena.GOAL_LINE + 0.4))
	await physics_frame
	await physics_frame
	check(scene.match_state.score[scoring_team] == before + 1, "Goal counted (score %s)" % [scene.match_state.score])
	var lamp = c.lamps[end_sign]
	var other = c.lamps[-end_sign]
	check(c.lamp_on(end_sign) and lamp.glow.visible and lamp.beam.visible, "Scored-on net's goal light is on")
	check(not c.lamp_on(-end_sign) and not other.glow.visible, "Other net's goal light stays off")
	# Step the effects directly so the test is frame-rate independent.
	c.set_process(false)
	var spin0: float = lamp.spinner.rotation.y
	c.advance(0.3)
	check(absf(wrapf(lamp.spinner.rotation.y - spin0, -PI, PI)) > 0.5, "Goal light reflector spins")
	check(lamp.glow.light_energy > 0.5 and lamp.glow.light_energy < 4.0, "Lamp glow is on at a plausible level (%.2f)" % lamp.glow.light_energy)
	check(lamp.dome.emission_energy_multiplier > 0.5, "Red dome glows")
	check(lamp.glow.light_color.r > 0.9 and lamp.glow.light_color.g < 0.3, "Goal light is red")
	var max_pool := 0.0
	for spot in c.lighting.pools: max_pool = maxf(max_pool, spot.light_energy)
	check(max_pool > base_pool * 1.1 and max_pool < base_pool * 1.6, "Arena pools pulse brighter, restrained (%.2f vs %.2f)" % [max_pool, base_pool])
	var main: Label3D = dressing.jumbotron_labels[0]
	check(main.text == "GOAL", "Jumbotron shows GOAL (got '%s')" % main.text)
	check(main.scale.x > 1.2, "GOAL text is scaled up (%.2f)" % main.scale.x)
	var scale_a: float = main.scale.x
	c.advance(0.2)
	check(absf(main.scale.x - scale_a) > 0.01 or main.modulate != Color.WHITE, "GOAL text animates")
	c.advance(2.0)   # t = 2.5 s: team name
	check(main.text == scene.hud_node.team_names[scoring_team], "Jumbotron shows the scoring team's name (got '%s')" % main.text)
	check(c.flash_left > 0.0 and c.flash_left < 1.0, "Arena flash decaying")
	c.advance(2.0)   # t = 4.5 s: all done
	check(not c.is_active(), "Celebration finished")
	check(not lamp.glow.visible and not lamp.beam.visible and lamp.dome.emission_energy_multiplier == 0.0, "Goal light off again")
	for i in range(c.lighting.pools.size()):
		check(is_equal_approx(c.lighting.pools[i].light_energy, c._pool_base[i][0]), "Pool %d back to its base energy" % i)
	check(not dressing.scoreboard_hold, "Jumbotron handed back to the score")
	var score_text := "%d" % scene.match_state.score[scoring_team]
	check(main.text.contains(score_text) and main.text.begins_with("TOR"), "Jumbotron shows the updated score ('%s')" % main.text)
	check(main.scale.is_equal_approx(Vector3.ONE), "Score text back to normal size")
	finish(scene)

func finish(scene) -> void:
	scene.queue_free()
	await process_frame
	print("Goal celebration failures: ", failures)
	quit(failures)
