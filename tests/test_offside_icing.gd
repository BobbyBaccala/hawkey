extends SceneTree
## Offside and icing (scripts/rules_offside_icing.gd): every rule branch as
## pure logic, then one offside and one icing in the match scene (whistle,
## banner, faceoff spot), and the off switch.
const Rules = preload("res://scripts/rules_offside_icing.gd")
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
	check_offside()
	check_icing()
	await check_match()
	print("Offside/icing checks: ", checks, "  failures: ", failures)
	quit(failures)

const ATTACK := [1.0, -1.0]  # team 0 attacks +z in the pure cases

func sk(team: int, x: float, z: float) -> Dictionary:
	return {"team": team, "pos": Vector3(x, 0, z)}

func tick(r, puck: Vector3, carrier: int, skaters: Array, short := [false, false]) -> Dictionary:
	return r.step({"puck": puck, "carrier": carrier, "skaters": skaters, "attack": ATTACK, "shorthanded": short})

func check_offside() -> void:
	# Carried in with a team-mate already inside: whistle at once.
	var r = Rules.new()
	var men := [sk(0, 2, 7.0), sk(0, -3, 9.5), sk(1, 0, 15)]
	check(tick(r, Vector3(2, 0, 7.3), 0, men).call == Rules.NONE, "Puck still outside: nothing")
	var v := tick(r, Vector3(2, 0, 7.9), 0, men)
	check(v.call == Rules.OFFSIDE and int(v.team) == 0, "Carried in with a mate inside -> offside")
	check(is_equal_approx(v.spot.z, r.neutral_dot_z) and is_equal_approx(v.spot.x, r.dot_x), "Offside faceoff: neutral dot outside that line, puck's side")
	# Onside entry: nobody ahead of the puck.
	r = Rules.new()
	men = [sk(0, 2, 7.0), sk(0, -3, 6.0), sk(1, 0, 15)]
	tick(r, Vector3(2, 0, 7.3), 0, men)
	check(tick(r, Vector3(2, 0, 7.9), 0, men).call == Rules.NONE and not r.delayed_offside(0), "Clean entry: no call")
	# A skater straddling the line (not fully across) is onside.
	r = Rules.new()
	men = [sk(0, 2, 7.0), sk(0, -3, 7.8), sk(1, 0, 15)]
	tick(r, Vector3(2, 0, 7.3), 0, men)
	check(tick(r, Vector3(2, 0, 7.9), 0, men).call == Rules.NONE, "Mate on the line is onside")
	# Shot in with a mate inside: delayed, cleared by a tag-up.
	r = Rules.new()
	men = [sk(0, -2, 5.0), sk(0, -3, 9.5), sk(1, 0, 15)]
	tick(r, Vector3(-2, 0, 5.2), 0, men)
	tick(r, Vector3(-2, 0, 6.5), -1, men)
	check(tick(r, Vector3(-2, 0, 8.5), -1, men).call == Rules.NONE and r.delayed_offside(0), "Shot in past a mate: delayed offside, no whistle")
	check(not r.delayed_offside(1), "The other team is not flagged")
	men[1] = sk(0, -3, 7.5)
	check(tick(r, Vector3(-2, 0, 12), -1, men).call == Rules.NONE and not r.delayed_offside(0), "Everyone tagged up: delayed offside cleared")
	# Delayed, then an attacker plays the puck: whistle.
	r = Rules.new()
	men = [sk(0, -2, 5.0), sk(0, -3, 9.5), sk(1, 0, 15)]
	tick(r, Vector3(-2, 0, 5.2), 0, men)
	tick(r, Vector3(-2, 0, 6.5), -1, men)
	tick(r, Vector3(-2, 0, 9.0), -1, men)
	v = tick(r, Vector3(-3, 0, 9.5), 1, men)
	check(v.call == Rules.OFFSIDE and int(v.team) == 0, "Attacker plays the puck during a delayed offside -> whistle")
	check(is_equal_approx(v.spot.x, -r.dot_x) and is_equal_approx(v.spot.z, r.neutral_dot_z), "Faceoff on the side the puck went in")
	check(int(r.calls[Rules.OFFSIDE]) == 1, "Call counted")
	# Delayed, then the puck comes back out: cleared.
	r = Rules.new()
	tick(r, Vector3(-2, 0, 5.2), 0, men)
	tick(r, Vector3(-2, 0, 6.5), -1, men)
	tick(r, Vector3(-2, 0, 9.0), -1, men)
	check(r.delayed_offside(0), "Flag up")
	check(tick(r, Vector3(-2, 0, 7.0), -1, men).call == Rules.NONE and not r.delayed_offside(0), "Puck leaves the zone: cleared")
	# A defender carrying it out through a delayed offside is fine.
	r = Rules.new()
	tick(r, Vector3(-2, 0, 5.2), 0, men)
	tick(r, Vector3(-2, 0, 6.5), -1, men)
	tick(r, Vector3(-2, 0, 9.0), -1, men)
	check(tick(r, Vector3(0, 0, 15), 2, men).call == Rules.NONE, "Defender picks it up: play on")
	# The defending team putting it into its own zone is never offside.
	r = Rules.new()
	men = [sk(1, 0, 5.0), sk(0, -3, 9.5)]
	tick(r, Vector3(0, 0, 5.2), 0, men)
	check(tick(r, Vector3(0, 0, 8.0), 0, men).call == Rules.NONE and not r.delayed_offside(0), "Defender carries it back in: no offside")
	# Switched off.
	r = Rules.new()
	r.enabled = false
	men = [sk(0, 2, 7.0), sk(0, -3, 9.5)]
	tick(r, Vector3(2, 0, 7.3), 0, men)
	check(tick(r, Vector3(2, 0, 7.9), 0, men).call == Rules.NONE, "Rules off: no call")

## Team 0 releases from `from_z`, the puck runs down to the far goal line at x.
func ice(r, from_z: float, x: float, men: Array, short := [false, false]) -> Dictionary:
	tick(r, Vector3(x, 0, from_z), 0, men, short)
	tick(r, Vector3(x, 0, from_z + 1.0), -1, men, short)
	tick(r, Vector3(x, 0, 10), -1, men, short)
	tick(r, Vector3(x, 0, r.end_dot_z + 0.3), -1, men, short)
	return tick(r, Vector3(x, 0, r.goal_line + 0.3), -1, men, short)

func check_icing() -> void:
	# Shooter (team 0) in his own half; nearest defender well off the puck but
	# nearer than any attacker.
	var men := [sk(0, 4, -3), sk(0, 0, 2), sk(1, -6, 22)]
	var r = Rules.new()
	var v := ice(r, -3, 5, men)
	check(v.call == Rules.ICING and int(v.team) == 0, "Shot from his own half over the far goal line -> icing")
	check(is_equal_approx(v.spot.z, -r.end_dot_z) and is_equal_approx(v.spot.x, r.dot_x), "Icing faceoff: offender's end dot, side it was shot from")
	r = Rules.new()
	v = ice(r, -3, -5, [sk(0, -4, -3), sk(1, 6, 22)])
	check(v.call == Rules.ICING and is_equal_approx(v.spot.x, -r.dot_x), "Shot from the left: left dot")
	r = Rules.new()
	check(ice(r, 0.5, 5, [sk(0, 4, 0.5), sk(1, -6, 22)]).call == Rules.NONE, "Released past the red line: no icing")
	r = Rules.new()
	check(ice(r, -3, 0.6, men).call == Rules.NONE, "On net: no icing")
	r = Rules.new()
	check(ice(r, -3, 5, men, [true, false]).call == Rules.NONE, "Shorthanded team may ice it")
	r = Rules.new()
	check(ice(r, -3, 5, [sk(0, 4, -3), sk(0, 5, 19), sk(1, -6, 12)]).call == Rules.NONE and r.waved_icings == 1, "Attacker wins the race: waved off")
	r = Rules.new()
	check(ice(r, -3, 5, [sk(0, 4, -3), sk(1, 5.5, 21.5)]).call == Rules.NONE and r.waved_icings == 1, "Defender could have played it: waved off")
	# Touched by an opponent on the way down.
	r = Rules.new()
	tick(r, Vector3(5, 0, -3), 0, men)
	tick(r, Vector3(5, 0, -2), -1, men)
	r.note_touch(1, Vector3(5, 0, 8))
	tick(r, Vector3(5, 0, r.end_dot_z + 0.3), -1, men)
	check(tick(r, Vector3(5, 0, r.goal_line + 0.3), -1, men).call == Rules.NONE, "Deflected by an opponent: no icing")
	# Goalkeeper plays it.
	r = Rules.new()
	tick(r, Vector3(5, 0, -3), 0, men)
	tick(r, Vector3(5, 0, -2), -1, men)
	r.goalie_touch()
	tick(r, Vector3(5, 0, r.end_dot_z + 0.3), -1, men)
	check(tick(r, Vector3(5, 0, r.goal_line + 0.3), -1, men).call == Rules.NONE, "Goalkeeper touched it: no icing")
	r = Rules.new()
	r.enabled = false
	check(ice(r, -3, 5, men).call == Rules.NONE, "Rules off: no icing")

func park(team: int, z_along_attack: float) -> Array:
	var out := []
	var a: float = scene.attack_direction(team)
	var i := 0
	for s in scene.skaters:
		if scene.body_team(s) != team or not bool(s.get_meta("eligible")): continue
		s.position = Vector3(-6.0 + 3.0 * i, 0, a * z_along_attack)
		s.velocity = Vector3.ZERO
		out.append(s)
		i += 1
	return out

func check_match() -> void:
	var Match = load("res://scripts/match.gd")
	Match.play_spectate = true
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	check(scene.rules.enabled, "Match plays with offside and icing by default")
	var a0: float = scene.attack_direction(0)
	# --- offside: team 0 carries in past a team-mate ---
	scene.match_state.phase = MatchState.Phase.PLAY
	scene.rules.reset()
	var mine := park(0, 2.0)
	park(1, 14.0)
	var carrier: CharacterBody3D = mine[0]
	var ahead: CharacterBody3D = mine[1]
	ahead.position.z = a0 * (Arena.BLUE_LINE + 2.0)
	carrier.position = Vector3(3, 0, a0 * (Arena.BLUE_LINE - 0.4))
	scene.carrier = carrier
	scene.puck.position = Vector3(3, 0.02, a0 * (Arena.BLUE_LINE - 0.3))
	scene.step_rules()
	check(scene.match_state.phase == MatchState.Phase.PLAY, "Before the line: play on")
	scene.puck.position = Vector3(3, 0.02, a0 * (Arena.BLUE_LINE + 0.4))
	scene.step_rules()
	check(scene.match_state.phase == MatchState.Phase.STOPPAGE, "Offside: whistle stops play")
	check(scene.hud_node.banner_title.text == "OFFSIDE" and scene.hud_node.banner.visible, "OFFSIDE banner shown")
	check(str(scene.match_state.event).to_lower().contains("offside"), "Event names the offside")
	check(is_equal_approx(scene.next_faceoff.z, a0 * Arena.NEUTRAL_DOT_Z) and is_equal_approx(scene.next_faceoff.x, Arena.DOT_X), "Offside faceoff at the neutral dot outside the line")
	check(scene.carrier == null, "Nobody carries a dead puck")
	# --- icing: team 0 fires it down from its own half ---
	scene.match_state.phase = MatchState.Phase.PLAY
	scene.rules.reset()
	mine = park(0, -3.0)
	var theirs := park(1, 0.0)
	# One defender back, nearer the puck than any attacker but not on it.
	(theirs[0] as CharacterBody3D).position = Vector3(1, 0, a0 * 23.0)
	carrier = mine[0]
	carrier.position = Vector3(-4, 0, a0 * -3.0)
	scene.carrier = carrier
	scene.puck.position = Vector3(-4, 0.02, a0 * -2.8)
	scene.step_rules()
	scene.carrier = null
	for z in [0.0, 10.0, Arena.END_DOT_Z + 0.3]:
		scene.puck.position = Vector3(-5, 0.02, a0 * z)
		scene.step_rules()
	check(scene.match_state.phase == MatchState.Phase.PLAY, "Still live until it crosses the goal line")
	scene.puck.position = Vector3(-5, 0.02, a0 * (Arena.GOAL_LINE + 0.3))
	scene.step_rules()
	check(scene.match_state.phase == MatchState.Phase.STOPPAGE, "Icing: whistle stops play")
	check(scene.hud_node.banner_title.text == "ICING", "ICING banner shown")
	check(is_equal_approx(scene.next_faceoff.z, -a0 * Arena.END_DOT_Z) and is_equal_approx(scene.next_faceoff.x, -Arena.DOT_X), "Icing faceoff in the offender's end, side it was shot from")
	# --- CPU tag-up target during a delayed offside ---
	scene.match_state.phase = MatchState.Phase.PLAY
	scene.rules.reset()
	scene.rules.delayed[0] = true
	var deep := Vector3(2, 0, a0 * (Arena.BLUE_LINE + 6.0))
	(mine[1] as CharacterBody3D).position = deep
	var t: Vector3 = scene.onside_target(mine[1], 0, a0, deep + Vector3(0, 0, a0 * 2.0))
	check(t.z * a0 < Arena.BLUE_LINE, "CPU attacker heads back out to tag up")
	# --- off switch ---
	scene.rules.reset()
	scene.rules.enabled = false
	mine = park(0, 2.0)
	(mine[1] as CharacterBody3D).position.z = a0 * (Arena.BLUE_LINE + 2.0)
	scene.carrier = mine[0]
	scene.puck.position = Vector3(3, 0.02, a0 * (Arena.BLUE_LINE - 0.3))
	scene.step_rules()
	scene.puck.position = Vector3(3, 0.02, a0 * (Arena.BLUE_LINE + 0.4))
	scene.step_rules()
	check(scene.match_state.phase == MatchState.Phase.PLAY, "Rules off: no whistle")
	# Practice/lab never has the rules object at all.
	var lab = load("res://practice.tscn").instantiate()
	check(not ("rules" in lab), "Practice scene has no offside/icing rules")
	lab.free()
