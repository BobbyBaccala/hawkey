extends SceneTree
## Intermission / final stats: scripts/game_stats.gd bookkeeping (per-period
## goals, shots, hits, faceoffs, power plays, PIM) and the stats card
## (scripts/stats_screen.gd) shown by match.gd at the period horn and at FINAL.
const GameStats = preload("res://scripts/game_stats.gd")
const MatchState = preload("res://scripts/match_state.gd")
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check_bookkeeping()
	check_rows()
	await check_match_card()
	print("Stats screen checks: ", checks, "  failures: ", failures)
	quit(failures)

func check_bookkeeping() -> void:
	var s := GameStats.new()
	var m := MatchState.new()
	m.phase = MatchState.Phase.PLAY
	var shots := [0, 0]
	var fo := [0, 0]
	s.sync(m, shots, fo)
	check(s.total("goals", 0) == 0 and s.total("shots", 1) == 0, "Fresh stats start at zero")
	# Period 1: two TOR shots, one MTL faceoff win, an even-strength TOR goal.
	shots[0] = 2; fo[1] = 1
	s.sync(m, shots, fo)
	m.goal(0)
	shots[0] = 3
	s.sync(m, shots, fo)
	check(s.in_period("shots", 0, 1) == 3, "Shots booked to the 1st")
	check(s.in_period("faceoffs", 1, 1) == 1, "Faceoff wins booked to the 1st")
	check(s.in_period("goals", 0, 1) == 1, "Goal booked to the 1st")
	check(s.total("pp_goals", 0) == 0, "Even-strength goal is not a power-play goal")
	# A MTL minor: 2 PIM for MTL, a power-play chance for TOR, booked once.
	m.phase = MatchState.Phase.PLAY
	m.minor(1, 3, "Tripping")
	s.sync(m, shots, fo)
	s.sync(m, shots, fo)
	check(s.total("pim", 1) == 2, "Minor books two penalty minutes once (got %d)" % s.total("pim", 1))
	check(s.total("pp_opps", 0) == 1 and s.total("pp_opps", 1) == 0, "Minor gives the other team one power play")
	# TOR scores on the power play.
	m.phase = MatchState.Phase.PLAY
	m.goal(0)
	shots[0] = 4
	s.sync(m, shots, fo)
	check(s.total("pp_goals", 0) == 1, "Goal with the man advantage is a power-play goal")
	check(s.power_play_text(0) == "1/1", "Power play reads 1/1 (got %s)" % s.power_play_text(0))
	# Hits by the user's team.
	s.add_hit(0, m.period)
	s.add_hit(0, m.period)
	check(s.in_period("hits", 0, 1) == 2, "Hits booked to the 1st")
	# Period horn, intermission, then the 2nd: new numbers go to the 2nd.
	m.phase = MatchState.Phase.PLAY
	m.clock = 0.01
	m.advance(1.0)
	check(m.phase == MatchState.Phase.INTERMISSION, "Clock out ends the period")
	check(is_equal_approx(m.phase_timer, MatchState.INTERMISSION_SECONDS), "Intermission long enough to read the card")
	s.sync(m, shots, fo)
	m.advance(MatchState.INTERMISSION_SECONDS + 0.1)
	check(m.period == 2, "Intermission leads into the 2nd")
	m.phase = MatchState.Phase.PLAY
	shots[1] = 5
	fo[0] = 2
	m.goal(1)
	s.sync(m, shots, fo)
	check(s.in_period("shots", 1, 2) == 5 and s.in_period("shots", 1, 1) == 0, "2nd-period shots in the 2nd only")
	check(s.in_period("goals", 1, 2) == 1, "2nd-period goal in the 2nd")
	check(s.total("goals", 0, 1) == 2 and s.total("goals", 0) == 2, "Totals through a period")
	check(s.total("faceoffs", 0) == 2 and s.faceoff_pct(0) == 67, "Faceoff percentage from wins (got %d)" % s.faceoff_pct(0))
	check(GameStats.new().faceoff_pct(1) == 50, "No draws reads 50 percent")

func check_rows() -> void:
	var s := GameStats.new()
	var d: Dictionary = s.fill_demo(2)
	check(d.score == [1, 2], "Demo score through the 2nd (got %s)" % str(d.score))
	var rows: Array = s.rows(2)
	check(rows.size() == 5, "Five stat rows")
	check(rows[0][0] == "SHOTS" and rows[0][1] == "19" and rows[0][2] == "21", "Shots row through the 2nd (got %s)" % str(rows[0]))
	check(rows[3][1] == "1/3" and rows[3][2] == "1/3", "Power-play row (got %s)" % str(rows[3]))
	check(str(rows[2][1]).contains("%"), "Faceoff row shows a percentage")
	check(s.total("shots", 0, 3) == 19, "fill_demo leaves the 3rd empty when through the 2nd")

func check_match_card() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	var hud = scene.hud_node
	check(hud.stats_screen != null and not hud.stats_screen.visible, "Stats card built and hidden during play")
	# A goal and a landed body check in the 1st, then the period horn.
	scene.match_state.phase_timer = 0
	for f in range(10): await physics_frame
	scene.match_state.phase = MatchState.Phase.PLAY
	scene.game_stats.add_hit(0, 1)
	scene.match_state.goal(1)
	scene.team_shots[1] += 1
	scene.match_state.phase = MatchState.Phase.PLAY
	scene.match_state.clock = 0.01
	for f in range(30):
		await physics_frame
		if hud.stats_screen.mode != "": break
	var card = hud.stats_screen
	check(scene.match_state.phase == MatchState.Phase.INTERMISSION, "Period ended")
	check(card.visible and card.mode == "intermission", "Intermission card shows at the period horn")
	check(card.title_label.text == "END OF 1ST", "Card title END OF 1ST (got %s)" % card.title_label.text)
	check(card.team_cells[1].score.text == "1" and card.team_cells[0].score.text == "0", "Card score 0-1")
	check(card.period_cells[1][0].text == "1" and card.period_cells[1][1].text == "–", "Goals by period: 1st filled, 2nd not played")
	check(card.stat_rows[0].right.text == str(scene.team_shots[1]), "Shots row matches the score bug")
	check(card.stat_rows[1].left.text == "1", "Hit shows on the card")
	check(card.stat_rows[0].bar_left.color == hud.team_colors[0] or scene.team_shots[0] == 0, "Bars use team colours")
	check(card.get_global_rect().size.x > 600 and card.get_global_rect().size.y > 300, "Card has a real size (%s)" % str(card.get_global_rect().size))
	var vp: Vector2 = card.get_viewport_rect().size
	var r: Rect2 = card.get_global_rect()
	check(absf(r.get_center().x - vp.x * 0.5) < 4.0, "Card centred horizontally")
	# The 2nd starts: the card goes away.
	scene.match_state.phase_timer = 0.01
	for f in range(60):
		await physics_frame
		if scene.match_state.period == 2 and not card.visible: break
	check(scene.match_state.period == 2, "2nd period started")
	check(card.mode == "", "Card dismissed for the 2nd")
	# Run out the 3rd: FINAL card.
	scene.match_state.period = 3
	scene.match_state.phase = MatchState.Phase.PLAY
	scene.match_state.clock = 0.01
	for f in range(30):
		await physics_frame
		if card.mode != "": break
	check(scene.match_state.phase == MatchState.Phase.FINAL, "Game over after the 3rd")
	check(card.visible and card.mode == "final" and card.title_label.text == "FINAL", "FINAL card shows")
	check(card.period_cells[0][2].text != "–", "Final card fills all three periods")
	scene.queue_free()
	await process_frame
