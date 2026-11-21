extends SceneTree
## Headless CPU-vs-CPU period: counts offside / icing whistles for tuning.
## godot --headless --script tools/sim_rules.gd [-- --frames=18000 --no-rules]
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var frames := 18000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="): frames = int(a.substr(9))
	var Match = load("res://scripts/match.gd")
	Match.play_spectate = true
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.match_state.phase_timer = 0
	var play_frames := 0
	var events := {}
	var last_event := ""
	for frame in range(frames):
		await physics_frame
		if scene.match_state.phase == 1: play_frames += 1
		var e: String = scene.match_state.event
		if e != last_event:
			last_event = e
			events[e] = int(events.get(e, 0)) + 1
		if scene.match_state.period > 1: break
	print("RULES SIM play seconds ", play_frames / 60.0, " game clock used ", 1200.0 - scene.match_state.clock if scene.match_state.period == 1 else 1200.0)
	print("calls ", scene.rules.calls, " waved icings ", scene.rules.waved_icings, " delayed offsides cleared ", scene.rules.delayed_cleared)
	print("shots ", scene.team_shots, " score ", scene.match_state.score, " passes ", scene.passes_by_team, " ai ", scene.ai_log)
	print("events ", events)
	quit(0)
