extends SceneTree
## PLAY NOW: the seat model (control_slots.gd: CPUs hold every position until
## a human takes it) and the CPU hockey brain (skater_ai.gd), plus a full
## CPU-vs-CPU stretch of a real match to check the AI actually plays hockey:
## both teams carry, pass and shoot, nobody skates around with it forever.
const ControlSlots = preload("res://scripts/control_slots.gd")
const SkaterAI = preload("res://scripts/skater_ai.gd")
const Arena = preload("res://scripts/arena.gd")
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
	check_seats()
	check_shot_quality()
	check_passing()
	check_decisions()
	check_defence_reads()
	await check_cpu_match()
	await check_human_seat()
	print("Play Now / AI checks: ", checks, "  failures: ", failures)
	quit(failures)

func check_seats() -> void:
	var s := ControlSlots.new()
	check(ControlSlots.MODES == ["play_now"], "Play Now is the only mode")
	check(s.cpu_count() == 12 and s.human_count() == 0, "Every seat starts with a CPU")
	check(s.join("p1", 0) == 0, "First human on a team takes centre")
	check(s.join("p2", 0) == 1, "Next human takes the next open seat")
	check(s.cpu_count(0) == 4 and s.cpu_count(1) == 6, "CPUs fill the rest")
	check(not s.claim("p3", 0, 0), "A human can't bump another human")
	check(s.claim("p3", 1, 5), "A human can take the goalie seat")
	check(s.move("p1", 2) and s.owner(0, 0) == ControlSlots.CPU and s.owner(0, 2) == "p1", "Team-style switching moves the seat; CPU takes the old one")
	check(not s.move("p1", 1), "Can't switch onto another human")
	s.release("p2")
	check(s.is_cpu(0, 1) and s.human_count(0) == 1, "Leaving gives the seat back to a CPU")
	var copy := ControlSlots.new()
	copy.from_dict(s.to_dict())
	check(copy.owner(0, 2) == "p1" and copy.owner(1, 5) == "p3" and copy.cpu_count() == s.cpu_count(), "Seat state survives a network snapshot")
	check(s.summary(0, "p1").begins_with("YOU RW"), "HUD summary names the local human's position (%s)" % s.summary(0, "p1"))

func check_shot_quality() -> void:
	var attack := 1.0
	var goalie := Vector3(0, 0, Arena.GOAL_LINE - 0.6)
	var slot := SkaterAI.shot_quality(Vector3(0, 0, Arena.GOAL_LINE - 7.0), attack, goalie, [])
	var point := SkaterAI.shot_quality(Vector3(-6, 0, Arena.BLUE_LINE + 1.0), attack, goalie, [])
	var sharp := SkaterAI.shot_quality(Vector3(9, 0, Arena.GOAL_LINE - 1.0), attack, goalie, [])
	var behind := SkaterAI.shot_quality(Vector3(1, 0, Arena.GOAL_LINE + 1.5), attack, goalie, [])
	check(slot > point and point > sharp, "Slot > point > sharp angle (%.2f %.2f %.2f)" % [slot, point, sharp])
	check(behind == 0.0, "No shots from behind the net")
	var blocked := SkaterAI.shot_quality(Vector3(0, 0, Arena.GOAL_LINE - 7.0), attack, goalie, [Vector3(0, 0, Arena.GOAL_LINE - 4.0)])
	check(blocked < slot * 0.6, "A body in the lane spoils the shot")
	var open_net := SkaterAI.shot_quality(Vector3(-3, 0, Arena.GOAL_LINE - 4.0), attack, Vector3(1.4, 0, Arena.GOAL_LINE - 0.8), [])
	var covered := SkaterAI.shot_quality(Vector3(-3, 0, Arena.GOAL_LINE - 4.0), attack, Vector3(-0.4, 0, Arena.GOAL_LINE - 0.9), [])
	check(open_net > covered, "Goalie off his angle opens the net (%.2f > %.2f)" % [open_net, covered])

func check_passing() -> void:
	var a := Vector3(0, 0, 0)
	var b := Vector3(0, 0, 10)
	check(SkaterAI.pass_safety(a, b, [Vector3(8, 0, 5)]) > 0.9, "Open lane is safe")
	check(SkaterAI.pass_safety(a, b, [Vector3(0.4, 0, 5)]) < 0.2, "Defender on the lane picks it off")
	check(SkaterAI.pass_safety(a, b, [Vector3(2.5, 0, 9)]) < SkaterAI.pass_safety(a, b, [Vector3(2.5, 0, 1)]), "A defender near the end of a long lane has time to close")
	var lead := SkaterAI.lead_point(a, Vector3(5, 0, 10), Vector3(0, 0, 6))
	check(lead.z > 10.0, "Passes lead a moving receiver")

func ctx(pos: Vector3, opponents: Array, teammates: Array, is_d := false) -> Dictionary:
	return {"pos": pos, "vel": Vector3.ZERO, "attack": 1.0, "is_d": is_d, "goalie": Vector3(0, 0, Arena.GOAL_LINE - 0.6),
		"opponents": opponents, "teammates": teammates, "skill": SkaterAI.skill("SUPERSTAR"), "roll": 0.5}

func check_decisions() -> void:
	# Alone in the slot: shoot.
	var d := SkaterAI.carrier_decision(ctx(Vector3(0.5, 0, Arena.GOAL_LINE - 6.0), [Vector3(-8, 0, 0)], []))
	check(d.kind == "shoot", "Alone in the slot he shoots (got %s)" % d.kind)
	# Wide and blocked, open teammate in the slot: pass.
	var mate := {"pos": Vector3(0.5, 0, Arena.GOAL_LINE - 6.0), "vel": Vector3.ZERO, "index": 3}
	d = SkaterAI.carrier_decision(ctx(Vector3(-8.5, 0, Arena.GOAL_LINE - 2.0), [Vector3(-7.0, 0, Arena.GOAL_LINE - 0.8), Vector3(6, 0, Arena.GOAL_LINE - 9.0)], [mate]))
	check(d.kind == "pass" and d.receiver == 3, "Sharp angle with a man open in the slot: pass (got %s)" % d.kind)
	# Neutral zone with open ice: carry it up.
	d = SkaterAI.carrier_decision(ctx(Vector3(0, 0, -2.0), [Vector3(-10, 0, -14), Vector3(10, 0, -14)], []))
	check(d.kind == "carry" and d.target.z > -2.0, "Open ice ahead: carry it up (got %s)" % d.kind)
	# Stuck at the red line, checkers in front, nobody open: dump it in.
	d = SkaterAI.carrier_decision(ctx(Vector3(3, 0, 1.0), [Vector3(3, 0, 3.0), Vector3(1, 0, 4.0), Vector3(5.5, 0, 3.0)], []))
	check(d.kind == "dump" or d.kind == "protect", "Stuck in the neutral zone: dump or protect (got %s)" % d.kind)
	# One-timers: a feed into a prime spot is shot first time, a so-so one isn't.
	var bar: float = SkaterAI.skill("ALL-STAR").shot_bar
	var prime := SkaterAI.shot_quality(Vector3(-1.0, 0, Arena.GOAL_LINE - 5.0), 1.0, Vector3(1.0, 0, Arena.GOAL_LINE - 0.7), [])
	var wide := SkaterAI.shot_quality(Vector3(-9.0, 0, Arena.GOAL_LINE - 3.0), 1.0, Vector3(-0.5, 0, Arena.GOAL_LINE - 0.7), [])
	check(SkaterAI.one_timer(prime, bar), "Cross-crease feed in the slot is one-timed (%.2f)" % prime)
	check(not SkaterAI.one_timer(wide, bar), "Wide feed at a bad angle is settled first (%.2f)" % wide)
	# The pass never goes through a defender.
	var blocked_mate := {"pos": Vector3(0, 0, 12.0), "vel": Vector3.ZERO, "index": 1}
	d = SkaterAI.carrier_decision(ctx(Vector3(0, 0, 0.0), [Vector3(0.3, 0, 6.0)], [blocked_mate]))
	check(d.kind != "pass", "No pass through a defender (got %s)" % d.kind)

func check_defence_reads() -> void:
	# Pursuit angle is goal-side (own net at -z when attacking +z).
	var p := SkaterAI.pursue_target(Vector3(5, 0, 0), Vector3(0, 0, -5), 1.0, Vector3(5, 0, -8))
	check(p.z < 0.0 and absf(p.x) < 5.0, "Pursuit takes the inside, goal-side")
	var m := SkaterAI.mark_target(Vector3(3, 0, -20), 1.0)
	check(m.z < -20.0 + 0.01 or absf(m.x) < 3.0, "Marking is goal-side of the man")
	var pairs := SkaterAI.assign_coverage([Vector3(0, 0, -18), Vector3(5, 0, -15), Vector3(-5, 0, -15)],
		[Vector3(1, 0, -22), Vector3(6, 0, -17), Vector3(-6, 0, -17)], 1.0)
	var targets := {}
	for k in pairs: targets[pairs[k]] = true
	check(pairs.size() == 3 and targets.size() == 3, "Coverage: one man each")
	check(SkaterAI.intercept_point(Vector3(0, 0, 0), Vector3(0, 0, 15), Vector3(1, 0, 6)) != Vector3.INF, "Can step into a nearby passing lane")
	check(SkaterAI.intercept_point(Vector3(0, 0, 0), Vector3(0, 0, 25), Vector3(14, 0, -10), 8.5, 0.6) == Vector3.INF, "Doesn't chase what he can't reach")

## CPU vs CPU (spectate): a minute and a half of real match play.
func check_cpu_match() -> void:
	var Match = load("res://scripts/match.gd")
	Match.play_spectate = true
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	check(scene.slots.human_count() == 0 and scene.slots.cpu_count() == 12, "Spectate: all twelve seats CPU")
	scene.match_state.phase_timer = 0
	var possession_frames := [0, 0]
	var longest_carry := 0
	var carry_run := 0
	var last_carrier = null
	var zone_entries := [0, 0]
	var last_zone := [false, false]
	for frame in range(60 * 90):
		await physics_frame
		var c = scene.carrier
		if c != null:
			var team: int = scene.body_team(c)
			possession_frames[team] += 1
			carry_run = carry_run + 1 if c == last_carrier else 1
			longest_carry = maxi(longest_carry, carry_run)
			var in_zone: bool = c.position.z * scene.attack_direction(team) > Arena.BLUE_LINE
			if in_zone and not last_zone[team]: zone_entries[team] += 1
			last_zone[team] = in_zone
		else:
			carry_run = 0
		last_carrier = c
	var shots: int = scene.team_shots[0] + scene.team_shots[1]
	var cpu_shots := 0
	for team in range(2):
		for r in scene.rosters[team]: cpu_shots += int(r.shots)
	var passes: int = scene.passes_by_team[0] + scene.passes_by_team[1]
	print("CPU 90 s: shots on goal ", scene.team_shots, " attempts ", cpu_shots, " passes ", scene.passes_by_team, " possession ", possession_frames, " zone entries ", zone_entries, " longest carry ", longest_carry / 60.0, " s  score ", scene.match_state.score)
	check(cpu_shots >= 2, "CPUs take shots (%d)" % cpu_shots)
	check(passes >= 8, "CPUs pass the puck (%d)" % passes)
	check(int(scene.ai_log.get("pass_done", 0)) >= 3, "Passes get received (%s)" % str(scene.ai_log))
	check(scene.passes_by_team[0] > 0 and scene.passes_by_team[1] > 0, "Both teams pass")
	check(possession_frames[0] > 120 and possession_frames[1] > 120, "Both teams have the puck")
	check(zone_entries[0] + zone_entries[1] >= 2, "Teams get into the offensive zone")
	check(longest_carry < 60 * 12, "Nobody skates around with it for 12 s")
	Match.play_spectate = false
	scene.queue_free()
	await process_frame

## A human on the away team playing one position stays on that position.
func check_human_seat() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.apply_play_now({"team": 1, "style": "position", "position": 3, "difficulty": "PRO"})
	check(scene.user_team() == 1, "Human plays for the chosen team")
	check(scene.body_team(scene.player) == 1 and int(scene.player.get_meta("slot")) == 3, "Position lock: the human is the left D")
	scene.switch_player()
	check(int(scene.player.get_meta("slot")) == 3, "No switching off a locked position")
	check(scene.slots.cpu_count() == 11, "The other eleven seats are CPU")
	scene.apply_play_now({"team": 0, "style": "team", "position": 0, "difficulty": "ROOKIE"})
	check(scene.user_team() == 0 and scene.ai_skill(1).react > 0.5, "Whole-team control on TOR vs rookie CPUs")
	scene.queue_free()
	await process_frame
