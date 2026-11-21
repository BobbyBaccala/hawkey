extends SceneTree
## CPU body checks (skater_ai.gd wants_hit(), match.gd ai_defend() /
## land_body_check()): a CPU on top of the carrier and skating into him
## finishes his check, the hit is booked for his team, a cooldown stops him
## hitting again at once, the victim staggers and recovers, the glass rattles
## along the boards, and nobody hits on a dead puck.
const SkaterAI = preload("res://scripts/skater_ai.gd")
const Arena = preload("res://scripts/arena.gd")
const MatchState = preload("res://scripts/match_state.gd")
var failures := 0
var checks := 0
var scene

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		print("FAIL: ", message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check_reads()
	await check_match()
	print("CPU check checks: ", checks, "  failures: ", failures)
	quit(failures)

## The pure decision: range, closing speed, facing, charging, from behind.
func check_reads() -> void:
	var wall_x := Arena.HALF_WIDTH - 1.0
	var c := Vector3(wall_x, 0, 3)
	check(SkaterAI.wants_hit(c + Vector3(-1.1, 0, 0.4), Vector3(4.5, 0, -1.5), c, Vector3(0, 0, 3.0)), "Along the wall: closing fast and on him -> hit")
	check(not SkaterAI.wants_hit(c + Vector3(-2.5, 0, 0), Vector3(5, 0, 0), c, Vector3.ZERO), "Out of range: no hit")
	check(not SkaterAI.wants_hit(c + Vector3(-1.1, 0, 0), Vector3(1.0, 0, 0), c, Vector3.ZERO), "Drifting in slowly: no hit")
	check(not SkaterAI.wants_hit(c + Vector3(-1.1, 0, 0), Vector3(0.5, 0, 6.0), c, Vector3(0, 0, 1.0)), "Skating past, not into him: no hit")
	check(not SkaterAI.wants_hit(c + Vector3(-1.1, 0, 0), Vector3(10.5, 0, 0), c, Vector3.ZERO), "A run from distance would be charging: no hit")
	# Carrier a stride off the wall skating into it, checker right behind him.
	var near := Vector3(Arena.HALF_WIDTH - 1.2, 0, 0)
	check(not SkaterAI.wants_hit(near + Vector3(-1.1, 0, 0), Vector3(6.5, 0, 0), near, Vector3(2.5, 0, 0)), "From behind into the boards: no hit")
	var mid := Vector3(0, 0, 5)
	check(not SkaterAI.wants_hit(mid + Vector3(0, 0, -1.1), Vector3(0, 0, 3.6), mid, Vector3.ZERO), "Open ice needs a real run (3.6 m/s is not enough)")
	check(SkaterAI.wants_hit(mid + Vector3(0, 0, -1.1), Vector3(0, 0, 6.0), mid, Vector3.ZERO), "Open ice at speed -> hit")
	check(is_equal_approx(SkaterAI.boards_distance(Vector3(Arena.HALF_WIDTH - 2.0, 0, 0)), 2.0), "boards_distance reads the side wall")

func stage(defender: CharacterBody3D, victim: CharacterBody3D, at: Vector3) -> void:
	victim.position = at
	victim.velocity = Vector3(0, 0, 2.5)
	defender.position = at + Vector3(-1.1, 0, 0.3)
	defender.velocity = Vector3(4.6, 0, -1.2)
	scene.puck.position = at + Vector3(0, 0.03, 0.5)
	scene.puck.linear_velocity = Vector3.ZERO
	scene.carrier = victim
	scene.cooldown = 0.0
	defender.set_meta("poke", 0.0)

func check_match() -> void:
	var Match = load("res://scripts/match.gd")
	Match.play_spectate = true
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	scene.match_state.phase = MatchState.Phase.PLAY
	var defender: CharacterBody3D
	var victim: CharacterBody3D
	for s in scene.skaters:
		if scene.body_team(s) == 1 and defender == null: defender = s
		if scene.body_team(s) == 0 and victim == null: victim = s
	var at := Vector3(Arena.HALF_WIDTH - 1.0, 0, 4.0)
	var period: int = scene.match_state.period
	var hits_before: int = scene.game_stats.total("hits", 1, period)
	var other_before: int = scene.game_stats.total("hits", 0, period)

	# (d) Dead puck first: same set-up, whistle blown -> never a hit.
	scene.match_state.phase = MatchState.Phase.FACEOFF
	for i in range(40):
		stage(defender, victim, at)
		defender.set_meta("hit_cd", 0.0)
		scene.ai_defend(defender, 1, 1.0 / 60.0)
	check(scene.game_stats.total("hits", 1, period) == hits_before, "No hit during a dead puck")
	check(scene.carrier == victim, "Dead puck: the carrier keeps the puck")
	scene.match_state.phase = MatchState.Phase.PLAY

	# (a) In range, closing: he throws the check (skill is a roll: a few tries).
	var tries := 0
	while tries < 40 and scene.game_stats.total("hits", 1, period) == hits_before:
		stage(defender, victim, at)
		defender.set_meta("hit_cd", 0.0)
		scene.ai_defend(defender, 1, 1.0 / 60.0)
		tries += 1
	check(scene.game_stats.total("hits", 1, period) == hits_before + 1, "CPU defender in range throws a check; hit booked for his team (tries %d)" % tries)
	check(scene.game_stats.total("hits", 0, period) == other_before, "No hit booked for the victim's team")
	check(scene.carrier == null, "The carrier loses the puck")
	check(float(defender.get_meta("hit_cd")) > SkaterAI.HIT_COOLDOWN - 0.1, "Hit cooldown started")

	# (c) Victim staggers...
	var visual = victim.get_child(1)
	check(float(victim.get_meta("stun")) > 0.3, "Victim is stunned")
	check(visual.hit_stagger > 0.9, "Victim's stagger started")
	check(victim.velocity.x > 2.0, "Victim knocked along the hit")
	check(scene.last_rattle != null and int(scene.last_rattle.get_meta("rattles", 0)) >= 1, "Glass rattles on a hit along the boards")

	# (b) Cooldown: the same chance again and again -> no second hit.
	for i in range(60):
		stage(defender, victim, at)
		scene.ai_defend(defender, 1, 1.0 / 60.0)
	check(scene.game_stats.total("hits", 1, period) == hits_before + 1, "Cooldown: no second hit within the window")
	# ...and once it has run out he can hit again.
	defender.set_meta("hit_cd", 0.0)
	tries = 0
	while tries < 40 and scene.game_stats.total("hits", 1, period) == hits_before + 1:
		stage(defender, victim, at)
		if tries > 0: defender.set_meta("hit_cd", 0.0)
		scene.ai_defend(defender, 1, 1.0 / 60.0)
		tries += 1
	check(scene.game_stats.total("hits", 1, period) == hits_before + 2, "After the cooldown he can hit again")

	# (c) ...and recovers: stagger pose mid-way, then back to normal in live play.
	visual.take_hit(Vector3(1, 0, 0), SkaterAI.HIT_STAGGER)
	visual.animate(2.0, SkaterAI.HIT_STAGGER * 0.25, 0, false)
	check(visual.hit_amount() > 0.6, "Mid-stagger the lean is strong (%.2f)" % visual.hit_amount())
	check(absf(visual.hit_bend().get_euler().z) > 0.2, "Stagger leans the torso sideways for a side hit")
	victim.set_meta("stun", SkaterAI.HIT_STUN)
	scene.carrier = null
	scene.set_physics_process(true)
	for frame in range(90):
		await physics_frame
	check(float(victim.get_meta("stun")) == 0.0, "Stun wears off")
	check(visual.hit_stagger == 0.0 and visual.hit_amount() == 0.0, "Stagger wears off")
	check(is_equal_approx(scene.last_rattle.position.z, float(scene.last_rattle.get_meta("rest_z"))), "Glass pane settles back")

	# Goalies are never hit: the decision only ever targets the carrier, and a
	# goalie can't be the carrier.
	for g in scene.goalkeepers: check(not scene.skaters.has(g), "Goalies are not checkable skaters")
	Match.play_spectate = false
	scene.queue_free()
	await process_frame
