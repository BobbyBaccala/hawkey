extends SceneTree
## Shooting gallery for goalie tuning: in a live (spectated) match, CPU
## skaters are held at the far end and the goalie at the +z end faces a
## series of shots aimed as the CPU aims them (SkaterAI.shot_aim, --noise=
## PRO 0.38 by default) at CPU speeds, from a ring of spots. Each trial the
## puck sits at a spot ("settle"), optionally slides across to a second spot
## like a pass (one-timer case), then is shot. Prints save / goal / miss per
## case, where goals crossed the line, and the totals.
## godot --headless --script tools/goalie_gallery.gd -- [--noise=0.38] [--speed=29] [--reps=3]
const SkaterAI = preload("res://scripts/skater_ai.gd")
const PuckPhysics = preload("res://scripts/puck.gd")
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var noise := 0.38
	var speed := 29.0
	var reps := 3
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.substr(7)
		if arg.begins_with("--noise="): noise = float(arg.substr(8))
		if arg.begins_with("--speed="): speed = float(arg.substr(8))
		if arg.begins_with("--reps="): reps = int(arg.substr(7))
	var Match = load("res://scripts/match.gd")
	Match.play_spectate = true
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.match_state.phase_timer = 0
	for f in range(10): await physics_frame
	var keeper = scene.goalkeeper_at_end(1.0)
	var end_ := signf(keeper.position.z)
	var gl := 26.65 * end_
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# [name, settle spot, pass-to spot (or null)], spots as (x, distance out from the goal line)
	var cases := [
		["slot 10m", Vector2(0, 10), null], ["left 12m", Vector2(-5, 11), null], ["right 12m", Vector2(5, 11), null],
		["high slot 15m", Vector2(1, 15), null], ["left circle", Vector2(-6.7, 6.1), null], ["right circle", Vector2(6.7, 6.1), null],
		["close 5m", Vector2(1, 5), null],
		["1T L->R", Vector2(-6, 9), Vector2(5, 11)], ["1T R->L", Vector2(6, 9), Vector2(-5, 11)],
		["1T behind->slot", Vector2(2, -1.5), Vector2(-1, 7)],
		["5-hole 12m", Vector2(0.5, 12), null, Vector2(0.0, 0.08)], ["5-hole 8m", Vector2(-0.5, 8), null, Vector2(0.05, 0.12)],
		["low middle 1T", Vector2(-6, 9), Vector2(1.5, 11), Vector2(0.1, 0.10)],
		["dribble 4m/s", Vector2(0.2, 5), null, Vector2(0.0, 0.0), 4.0], ["dribble 7m/s", Vector2(-0.3, 7), null, Vector2(0.1, 0.0), 7.0],
		["high right 8m", Vector2(-1, 8), null, Vector2(0.75, 0.62)], ["high left 8m", Vector2(1, 8), null, Vector2(-0.75, 0.62)],
		["high right 1T", Vector2(-6, 8), Vector2(1.5, 8), Vector2(0.75, 0.6)], ["high left 1T", Vector2(6, 8), Vector2(-1.5, 8), Vector2(-0.75, 0.6)],
		["low post 6m", Vector2(2, 6), null, Vector2(-0.8, 0.05)],
	]
	var totals := {"save":0,"goal":0,"miss":0}
	var goal_spots := []
	for c in cases:
		if only != "" and not String(c[0]).begins_with(only): continue
		var res := {"save":0,"goal":0,"miss":0}
		for r in range(reps):
			var fixed: Vector2 = c[3] if c.size() > 3 else Vector2(INF, 0)
			var sp_: float = c[4] if c.size() > 4 else speed
			var out: String = await trial(scene, keeper, end_, gl, c[1], c[2], noise, sp_, rng, goal_spots, fixed)
			res[out] += 1
			totals[out] += 1
		print("%-18s save %d goal %d miss %d" % [c[0], res.save, res.goal, res.miss])
	var on: int = totals.save + totals.goal
	print("TOTAL save %d goal %d miss %d  save%% %.0f" % [totals.save, totals.goal, totals.miss, 100.0 * totals.save / maxf(on, 1)])
	for g in goal_spots: print("  goal ", g)
	Match.play_spectate = false
	quit()

func spot(end_: float, gl: float, s: Vector2) -> Vector3:
	return Vector3(s.x, 0.02, gl - end_ * s.y)

func hold_skaters(scene, end_: float) -> void:
	var i := 0
	for a in scene.skaters:
		a.position = Vector3(-10 + i * 1.8, 0, -end_ * 22)
		a.velocity = Vector3.ZERO
		i += 1
	scene.carrier = null

func trial(scene, keeper, end_: float, gl: float, a: Vector2, b, noise: float, speed: float, rng: RandomNumberGenerator, goal_spots: Array, fixed := Vector2(INF, 0)) -> String:
	if scene.replay.playing(): scene.replay.skip()
	scene.match_state.phase = 1
	scene.match_state.event = "Play"
	scene.puck.freeze = false
	var p := spot(end_, gl, a)
	for f in range(60):
		hold_skaters(scene, end_)
		scene.puck.position = p
		scene.puck.linear_velocity = Vector3.ZERO
		await physics_frame
	if b != null:
		var q := spot(end_, gl, b)
		var frames := int(p.distance_to(q) / 16.0 * 60.0)
		for f in range(frames):
			hold_skaters(scene, end_)
			scene.puck.position = p.lerp(q, float(f + 1) / frames)
			scene.puck.linear_velocity = (q - p).normalized() * 16.0
			await physics_frame
		p = q
	var aim: Vector3 = SkaterAI.shot_aim(p, end_, keeper.position, noise, rng.randf(), rng.randf())
	# Fixed aim (x across, height) for the five-hole / dribble cases.
	if fixed.x != INF: aim = Vector3(fixed.x + (rng.randf() - 0.5) * 0.1, fixed.y, end_ * 26.65)
	var d: Vector3 = aim - p
	var dist := Vector2(d.x, d.z).length()
	var sp := speed + (rng.randf() * 3.0 - 1.5 if speed > 10.0 else 0.0)
	var elev: float = PuckPhysics.solve_elevation(dist, sp, aim.y, p.y)
	scene.puck.position = p
	scene.puck.linear_velocity = PuckPhysics.launch(Vector3(d.x, 0, d.z).normalized(), sp, elev)
	scene.released_by = null
	var score_before: int = scene.match_state.score[0] + scene.match_state.score[1]
	var saves_before: int = scene.saves
	for f in range(150 if speed < 10.0 else 70):
		hold_skaters(scene, end_)
		var prev: Vector3 = scene.puck.position
		await physics_frame
		if scene.match_state.score[0] + scene.match_state.score[1] > score_before:
			goal_spots.append("x %.2f y %.2f  (aim x %.2f y %.2f, goalie x %.2f, from %s)" % [scene.puck.position.x, scene.puck.position.y, aim.x, aim.y, keeper.position.x, str(a if b == null else b)])
			return "goal"
		if scene.saves > saves_before:
			# A touch is only a save if the puck stays out: watch it for 1 s.
			for g in range(120):
				hold_skaters(scene, end_)
				await physics_frame
				if scene.match_state.score[0] + scene.match_state.score[1] > score_before:
					goal_spots.append("THROUGH x %.2f y %.2f after a touch (aim x %.2f y %.2f, from %s)" % [scene.puck.position.x, scene.puck.position.y, aim.x, aim.y, str(a if b == null else b)])
					return "goal"
				if int(scene.match_state.phase) != 1: break
			return "save"
	return "miss"
