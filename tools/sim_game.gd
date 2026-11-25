extends SceneTree
## Full CPU-vs-CPU game simulator for stat tuning: plays a spectated PLAY NOW
## match headless from the opening faceoff to the final horn (or --periods=N)
## and prints an NHL-style box score: shots on goal and attempts per team,
## goals, each goalie's save percentage, and every skater's G/A/P and shots.
## Replays are skipped to save time. --out=<json> writes the numbers;
## tools/sim_report.py summarises several games.
## godot --headless --script tools/sim_game.gd -- --seed=1 [--periods=3] [--out=/tmp/game.json]
##   [--tune=<match var>=<number>]...  e.g. --tune=goalie_read_time=0.17 (no code edits
##   mid-batch). The JSON is rewritten at every period end ("partial": true until
##   the final horn), so a container restart loses at most one period;
##   sim_report.py scales partial games to three periods. tools/sim_batch.sh runs
##   several seeds in parallel.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var seed_ := -1
	var periods := 3
	var out := ""
	var tunes := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tune="):
			var kv := arg.substr(7).split("=")
			tunes[kv[0]] = float(kv[1])
		if arg.begins_with("--seed="): seed_ = int(arg.substr(7))
		if arg.begins_with("--periods="): periods = int(arg.substr(10))
		if arg.begins_with("--out="): out = arg.substr(6)
	var Match = load("res://scripts/match.gd")
	Match.play_spectate = true
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	if seed_ >= 0: scene.ai_rng.seed = seed_
	for k in tunes:
		if not (k in scene):
			push_error("--tune: match has no variable '%s'" % k)
			quit(2)
			return
		scene.set(k, tunes[k])
		print("tune %s = %s" % [k, scene.get(k)])
	var started := Time.get_ticks_msec()
	var hz := float(Engine.physics_ticks_per_second)
	var live := 0
	var frames := 0
	var goal_log := []
	var last_score := 0
	var release_frame := 0
	var touches_at_release := 0
	var period_seen := 1
	while true:
		await physics_frame
		frames += 1
		if scene.replay.playing(): scene.replay.skip()
		if int(scene.match_state.phase) == 1: live += 1
		if scene.released_by != null and absf(scene.released_wait - 0.42) < 0.0001:
			release_frame = frames
			touches_at_release = scene.saves
		var sc: int = scene.match_state.score[0] + scene.match_state.score[1]
		if sc > last_score:
			last_score = sc
			var gk = scene.goalkeepers[0] if absf(scene.goalkeepers[0].position.z - scene.puck.position.z) < 5.0 else scene.goalkeepers[1]
			goal_log.append({"kind": scene.released_kind, "after_s": snappedf((frames - release_frame) / hz, 0.01), "goalie_touches": scene.saves - touches_at_release,
				"deflected": scene.deflected, "x": snappedf(scene.puck.position.x, 0.01), "y": snappedf(scene.puck.position.y, 0.01),
				"save_kind": gk.get_child(1).save_kind, "rebound_shot": int(scene.ai_log.get("rebound_shot", 0))})
		if int(scene.match_state.period) != period_seen:
			period_seen = int(scene.match_state.period)
			if out != "" and period_seen > 1: save(out, result_of(scene, seed_, periods, live, hz, goal_log, started, tunes, true))
		if int(scene.match_state.phase) == 4: break
		if scene.match_state.period > periods: break
		if frames > hz * 60 * 40: break
	var result := result_of(scene, seed_, periods, live, hz, goal_log, started, tunes, false)
	var ms = scene.match_state
	var sog: Array = result.sog
	var attempts: Array = result.attempts
	var players: Array = result.players.duplicate()
	print("GAME seed %d  score %d-%d  SOG %d-%d  attempts %d-%d  SV%% TOR %.3f MTL %.3f  live %.1f min" % [seed_, ms.score[0], ms.score[1], sog[0], sog[1], attempts[0], attempts[1], result.sv[0], result.sv[1], result.live_minutes])
	for g in goal_log: print("   goal: ", g)
	players.sort_custom(func(a, b): return a.g + a.a > b.g + b.a)
	for p in players.slice(0, 8):
		if p.g + p.a == 0: break
		print("   %s %-11s %s%d  %dG %dA %dP  %d S" % ["TOR" if p.team == 0 else "MTL", p.name, p.pos, p.line, p.g, p.a, p.g + p.a, p.s])
	if out != "": save(out, result)
	Match.play_spectate = false
	quit()

func save(path: String, result: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(result))
	f.close()

## Box score so far. partial = the game is still going (saved at a period end).
func result_of(scene, seed_: int, periods: int, live: int, hz: float, goal_log: Array, started: int, tunes: Dictionary, partial: bool) -> Dictionary:
	var ms = scene.match_state
	var attempts := [0, 0]
	var players := []
	for team in range(2):
		for i in range(18):
			var r: Dictionary = scene.rosters[team][i]
			attempts[team] += int(r.shots)
			players.append({"team": team, "id": i, "name": r.name, "pos": "F" if i < 12 else "D", "line": (i / 3 + 1) if i < 12 else (i - 12) / 2 + 1,
				"shooting": r.get("shooting", 0.0), "g": int(r.goals), "a": int(r.get("assists", 0)), "s": int(r.shots)})
	var sog: Array = scene.team_shots
	# A partial game counts the periods completed so far.
	var played := mini(int(ms.period) - (1 if partial else 0), periods)
	return {"seed": seed_, "periods": maxi(played, 1), "partial": partial, "tunes": tunes, "score": [ms.score[0], ms.score[1]], "sog": [sog[0], sog[1]], "attempts": attempts,
		"sv": [1.0 - float(ms.score[1]) / maxf(sog[1], 1.0), 1.0 - float(ms.score[0]) / maxf(sog[0], 1.0)],
		"live_minutes": live / hz / 60.0, "goal_log": goal_log, "wall_minutes": (Time.get_ticks_msec() - started) / 60000.0, "players": players, "ai_log": scene.ai_log}
