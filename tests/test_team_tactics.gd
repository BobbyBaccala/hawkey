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
	var weak_d: Vector3 = T.support_target(3, 1.0, own, false)
	check(absf(weak_d.x) < 2.5 and weak_d.z < -(goal - 6.0), "Weak-side D covers the net front")
	var wing: Vector3 = T.support_target(1, 1.0, own, false)
	check(wing.z > -(blue + 3.0) and wing.z < -blue + 0.1, "Winger covers the point in his own zone")
	# Offensive zone: D at the points, a forward at the net front.
	var oz := Vector3(5, 0, goal - 6.0)
	var d1: Vector3 = T.support_target(4, 1.0, oz, true)
	check(d1.z > blue - 1.0 and d1.z <= blue + 1.5, "D holds the offensive blue line")
	var near_w: Vector3 = T.support_target(2, 1.0, oz, true)
	check(near_w.z > goal - 5.0 and absf(near_w.x) < 2.5, "Strong-side winger drives the net front")
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
