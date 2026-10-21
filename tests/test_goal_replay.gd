extends SceneTree
## Goal replay: after a goal the match records-and-replays the last seconds
## from a reverse-angle camera behind a REPLAY wipe, then hands back the live
## picture exactly as it was and goes on to the faceoff.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var GoalReplay = preload("res://scripts/goal_replay.gd")
	var d: float = GoalReplay.clip_duration()
	check(d >= 4.0 and d <= 6.0, "Replay runs 4-6 s on screen (%.2f)" % d)
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	await physics_frame
	var r = scene.get_node_or_null("GoalReplay")
	check(r != null, "GoalReplay node under the match")
	if r == null:
		finish(scene)
		return
	check(r.actors.size() == 14, "Tracks 10 skaters, 2 goalies, 2 officials (%d)" % r.actors.size())
	scene.match_state.phase_timer = 0.05
	for i in range(240):
		await physics_frame
		if scene.match_state.phase == scene.MatchState.Phase.PLAY: break
	check(scene.match_state.phase == scene.MatchState.Phase.PLAY, "Match reached play")
	# Let some live play be recorded.
	for i in range(int(3.5 * Engine.physics_ticks_per_second)): await physics_frame
	check(r.frames.size() > 90 and r.frames.size() < 260, "Ring buffer holds ~30 fps of recent play (%d frames)" % r.frames.size())
	var span: float = float(r.frames[-1].t) - float(r.frames[0].t)
	check(span > 3.0 and span <= GoalReplay.KEEP + 0.1, "Buffer spans the recent seconds (%.2f s)" % span)
	var Arena = preload("res://scripts/arena.gd")
	var end_sign := 1.0
	scene.previous_puck = Vector3(0.1, 0.02, end_sign * (Arena.GOAL_LINE - 0.25))
	scene.puck.position = Vector3(0.1, 0.02, end_sign * (Arena.GOAL_LINE + 0.4))
	await physics_frame
	await physics_frame
	check(r.pending(), "Goal queues a replay")
	check(not r.playing(), "Replay waits while the goal is celebrated live")
	# Wait for the wipe and the cut.
	var saw_wipe := false
	for i in range(int((GoalReplay.START_DELAY + 0.5) * Engine.physics_ticks_per_second)):
		await physics_frame
		if r.wipe_progress() >= 0.0: saw_wipe = true
		if r.playing(): break
	check(saw_wipe, "REPLAY wipe starts before the cut")
	check(r.playing(), "Replay is playing")
	check(r.wipe.visible, "Wipe band on screen at the cut")
	check(r.wipe_label.text == "REPLAY", "Wipe reads REPLAY")
	check(r.tag.visible, "REPLAY tag shown during playback")
	var live: Dictionary = r._live
	var live_skater: Transform3D = live.actors[0].xf[0]
	# Camera: above the end boards of the scored-on net, looking back up ice.
	var cam: Camera3D = scene.camera
	check(signf(cam.global_position.z) == end_sign and absf(cam.global_position.z) > Arena.GOAL_LINE, "Replay camera behind the scored-on net (z %.1f)" % cam.global_position.z)
	check(-cam.global_basis.z.z * end_sign < 0.0, "Replay camera looks back up the ice")
	check(not cam.global_position.is_equal_approx(r._cam_saved.xf.origin), "Camera moved off the gameplay angle")
	# The clip starts before the goal, and the figures are at their recorded spots.
	check(r.play_t < r.goal_time - 2.0, "Clip starts seconds before the goal")
	var first: Dictionary = r.sample(r.play_t)
	var visual: Node3D = r.actors[0]
	check(visual.global_position.distance_to((first.actors[0].xf[0] as Transform3D).origin) < 0.05, "Skater posed from the recording")
	check(scene.puck.global_position.distance_to((first.puck as Transform3D).origin) < 0.05, "Puck placed from the recording")
	# The match is frozen while it plays: stoppage timer and clock don't move.
	var timer: float = scene.match_state.phase_timer
	var start_t: float = r.play_t
	for i in range(int(1.0 * Engine.physics_ticks_per_second)): await physics_frame
	check(is_equal_approx(scene.match_state.phase_timer, timer), "Live match frozen during replay")
	check(r.play_t > start_t + 0.8, "Clip advances at full speed before the slow motion (%.2f)" % (r.play_t - start_t))
	# Slow motion near the goal.
	r.play_t = r.goal_time - 0.5
	var t0: float = r.play_t
	for i in range(int(0.5 * Engine.physics_ticks_per_second)): await physics_frame
	check(absf((r.play_t - t0) - 0.5 * GoalReplay.SLOW) < 0.05, "Slow motion at the net (%.2f s clip in 0.5 s)" % (r.play_t - t0))
	# Skip: wipe out, then the live picture comes back exactly.
	r.skip()
	var guard := 0
	while r.playing() and guard < 400:
		await physics_frame
		guard += 1
	check(not r.playing(), "Replay ends after skip")
	check(not r.tag.visible, "REPLAY tag hidden after")
	check(cam.global_transform.origin.distance_to(r._cam_saved.xf.origin) < 0.5, "Gameplay camera restored")
	check(visual.global_position.distance_to(live_skater.origin) < 0.3, "Skater back at his live spot")
	# The faceoff follows.
	for i in range(int(4.0 * Engine.physics_ticks_per_second)):
		await physics_frame
		if scene.match_state.phase == scene.MatchState.Phase.PLAY: break
	check(scene.match_state.phase != scene.MatchState.Phase.STOPPAGE, "Match moves on to the faceoff after the replay")
	finish(scene)

func finish(scene) -> void:
	scene.queue_free()
	await process_frame
	print("Goal replay failures: ", failures)
	quit(failures)
