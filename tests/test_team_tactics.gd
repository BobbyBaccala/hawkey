extends SceneTree
## Basic hockey AI roles: defencemen stay home, forwards don't go too deep.
const T = preload("res://scripts/team_tactics.gd")
const Arena = preload("res://scripts/arena.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var goal := Arena.GOAL_LINE
	var blue := Arena.BLUE_LINE
	# Sweep the puck over the whole rink, both attack directions, with and without possession.
	var d_deep := -INF
	var d_past_centre_defending := -INF
	var f_low := INF
	for attack in [-1.0, 1.0]:
		for possession in [true, false]:
			for zi in range(-12, 13):
				for xi in range(-5, 6):
					var puck := Vector3(xi * 2.0, 0, zi * 2.2)
					for slot in range(5):
						var t: Vector3 = T.support_target(slot, attack, puck, possession)
						var a: float = t.z * attack
						check(absf(t.x) < Arena.HALF_WIDTH and absf(t.z) < Arena.GOAL_LINE, "Target inside the rink")
						if T.is_defence(slot):
							d_deep = maxf(d_deep, a)
							if not possession and puck.z * attack <= blue: d_past_centre_defending = maxf(d_past_centre_defending, a)
						else:
							f_low = minf(f_low, a)
	check(d_deep <= blue + 1.5, "D never go deeper than just inside the offensive blue line (%.1f m)" % d_deep)
	check(d_past_centre_defending <= 0.01, "Defending D never push past centre unless holding the offensive blue line (%.1f m)" % d_past_centre_defending)
	check(f_low >= -(goal - 6.0) - 0.01, "Forwards never drop below the slot defensively (%.1f m)" % f_low)
	# Own zone: a defenceman covers the net front; wingers are up at the points.
	var own := Vector3(6, 0, -(goal - 4.0))   # attack +1: own zone is -z, puck on the +x side
	# Sides are the player's own (side_for): attacking +z, the right-side
	# players (slots 2, 4) are on -x, so with the puck on +x they are weak-side.
	var weak_d: Vector3 = T.support_target(4, 1.0, own, false)
	check(absf(weak_d.x) < 2.5 and weak_d.z < -(goal - 6.0), "Weak-side D covers the net front")
	var wing: Vector3 = T.support_target(2, 1.0, own, false)
	check(wing.z > -(blue + 3.0) and wing.z < -blue + 0.1, "Winger covers the point in his own zone")
	# Offensive zone: D at the points, a forward at the net front.
	var oz := Vector3(5, 0, goal - 6.0)
	var d1: Vector3 = T.support_target(4, 1.0, oz, true)
	check(d1.z > blue - 1.0 and d1.z <= blue + 1.5, "D holds the offensive blue line")
	var near_w: Vector3 = T.support_target(1, 1.0, oz, true)
	check(near_w.z > goal - 5.0 and absf(near_w.x) < 2.5, "Strong-side winger drives the net front")
	# Own sides: a left winger is on his own left, so the two teams' LWs are on
	# opposite rink sides (LW lines up against the other team's RW).
	check(T.side_for(1, -1.0) < 0.0 and T.side_for(1, 1.0) > 0.0, "LW plays his own left for both attack directions")
	check(T.side_for(1, 1.0) == T.side_for(2, -1.0), "One team's LW is on the same rink side as the other's RW")
	# Offensive zone points: strong-side D out by the boards, weak-side D in the middle.
	var oz_l := Vector3(T.side_for(1, 1.0) * 6.0, 0, goal - 5.0)        # puck on the left side, attacking +z
	var strong_d: Vector3 = T.support_target(3, 1.0, oz_l, true)
	var weak_d2: Vector3 = T.support_target(4, 1.0, oz_l, true)
	check(absf(strong_d.x) >= 6.4 and signf(strong_d.x) == signf(oz_l.x), "Strong-side D holds the point by the boards (%.1f)" % strong_d.x)
	check(absf(weak_d2.x) <= 3.0, "Weak-side D slides to the middle of the line (%.1f)" % weak_d2.x)
	# Net front is always filled: with the strong-side winger carrying, the weak-side one goes there.
	var weak_w: Vector3 = T.support_target(2, 1.0, oz_l, true, 1)
	check(weak_w.z > goal - 4.5 and absf(weak_w.x) < 2.0, "Weak-side winger takes the net front when the strong-side winger has it (%s)" % weak_w)
	# Own zone: strong-side winger out on the half-wall lane, weak-side sagging inside.
	var own_l := Vector3(T.side_for(1, 1.0) * 6.0, 0, -(goal - 4.0))
	var sw: Vector3 = T.support_target(1, 1.0, own_l, false)
	var ww: Vector3 = T.support_target(2, 1.0, own_l, false)
	check(absf(sw.x) > absf(ww.x) + 2.0, "Own zone: strong-side winger wider than the weak-side one (%.1f vs %.1f)" % [sw.x, ww.x])
	check(not T.may_chase(3, 1.0, Vector3(0, 0, goal - 5.0)), "D don't chase loose pucks deep in the offensive zone")
	check(T.may_chase(3, 1.0, Vector3(0, 0, -10.0)), "D chase loose pucks in their own half")
	# Live match: AI defencemen spend almost no time deep in the offensive zone.
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	await physics_frame
	scene.match_state.phase_timer = 0
	var samples := 0
	var deep := 0
	for f in range(120 * 25):
		await physics_frame
		if f % 6 != 0: continue
		for actor in scene.skaters:
			if actor == scene.player or actor == scene.carrier or not bool(actor.get_meta("eligible")): continue
			if not T.is_defence(int(actor.get_meta("slot"))): continue
			samples += 1
			if actor.position.z * scene.attack_direction(scene.body_team(actor)) > blue + 4.0: deep += 1
	check(samples > 0 and float(deep) / samples < 0.08, "AI D rarely deep in the offensive zone (%d/%d samples)" % [deep, samples])
	print("Team tactics failures: %d" % failures)
	quit(failures)
