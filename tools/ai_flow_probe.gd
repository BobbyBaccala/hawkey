extends SceneTree
## CPU-vs-CPU flow recorder: runs a spectated PLAY NOW match headless and
## writes a JSON log of every skater (team, slot, position, velocity), the
## puck, the carrier and the game phase every SAMPLE physics frames, plus the
## match counters at the end. tools/ai_flow_report.py turns it into
## positioning and flow numbers and top-down position maps.
## godot --headless --script tools/ai_flow_probe.gd -- --seconds=240 --out=/tmp/flow.json
const SAMPLE := 6
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var seconds := 240.0
	var out := "/tmp/hawkey-flow.json"
	var seed_ := 1
	var period_ := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="): seconds = float(arg.substr(10))
		if arg.begins_with("--out="): out = arg.substr(6)
		if arg.begins_with("--seed="): seed_ = int(arg.substr(7))
		if arg.begins_with("--period="): period_ = int(arg.substr(9))
	var Match = load("res://scripts/match.gd")
	Match.play_spectate = true
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	if "ai_rng" in scene and seed_ >= 0: scene.ai_rng.seed = seed_
	if period_ != 1:
		scene.match_state.period = period_
		scene.setup_faceoff()
	scene.match_state.phase_timer = 0
	var frames: Array = []
	# Physics runs at physics_ticks_per_second (120 in this project), not 60.
	var hz := Engine.physics_ticks_per_second
	var total := int(seconds * hz)
	for f in range(total):
		await physics_frame
		if f % SAMPLE != 0: continue
		var sk: Array = []
		for a in scene.skaters:
			if not bool(a.get_meta("eligible")): continue
			var team: int = scene.body_team(a)
			sk.append([team, int(a.get_meta("slot")), snappedf(a.position.x, 0.01), snappedf(a.position.z, 0.01),
				snappedf(a.velocity.x, 0.01), snappedf(a.velocity.z, 0.01), int(bool(a.get_meta("changing")) or scene.is_hopping(a))])
		var c = scene.carrier
		frames.append({"t": snappedf(f / float(hz), 0.01), "phase": int(scene.match_state.phase),
			"puck": [snappedf(scene.puck.position.x, 0.01), snappedf(scene.puck.position.z, 0.01), snappedf(scene.puck.linear_velocity.length(), 0.01)],
			"carrier": [-1, -1] if c == null else [scene.body_team(c), int(c.get_meta("slot"))],
			"attack": [scene.attack_direction(0), scene.attack_direction(1)], "sk": sk})
	var shots_att := [0, 0]
	for team in range(2):
		for r in scene.rosters[team]: shots_att[team] += int(r.shots)
	var summary := {"seconds": seconds, "shots_on_goal": scene.team_shots, "shot_attempts": shots_att,
		"passes": scene.passes_by_team, "score": scene.match_state.score, "ai_log": scene.ai_log,
		"blue_line": scene.Arena.BLUE_LINE if "Arena" in scene else 0.0}
	var fa := FileAccess.open(out, FileAccess.WRITE)
	fa.store_string(JSON.stringify({"summary": summary, "frames": frames}))
	fa.close()
	print("FLOW written ", out, " frames ", frames.size(), " ", JSON.stringify(summary))
	Match.play_spectate = false
	quit()
