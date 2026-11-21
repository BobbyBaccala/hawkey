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
	# Angle per goal: long shots get the shooter cam, close-range goals ice level,
	# cross-slot plays overhead, otherwise the reverse angle; never twice running.
	var net := Vector3(0, 0, 26.65)
	check(GoalReplay.pick_angle(Vector3(2, 0, 12), net, 0.5, "") == "follow", "Long shot -> shooter cam")
	check(GoalReplay.pick_angle(Vector3(1, 0, 23.5), net, 0.5, "") == "ice", "Close-range goal -> ice level")
	check(GoalReplay.pick_angle(Vector3(1, 0, 20), net, 4.0, "") == "overhead", "Cross-slot play -> overhead")
	check(GoalReplay.pick_angle(Vector3(1, 0, 20), net, 0.5, "") == "reverse", "Slot shot -> reverse angle")
	for last in GoalReplay.ANGLES:
		for from in [Vector3(2, 0, 12), Vector3(1, 0, 23.5), Vector3(1, 0, 20)]:
			check(GoalReplay.pick_angle(from, net, 0.5, last) != last, "Never the same angle twice in a row (%s)" % last)
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	await physics_frame
	var r = scene.get_node_or_null("GoalReplay")
	check(r != null, "GoalReplay node under the match")
	if r == null:
		finish(scene)
		return
	r.force_angle = "reverse"
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
	check(r.skip_prompt.visible, "Skip prompt shown during playback")
	check(r.angle == "reverse" and r.angle_label.text == "REVERSE ANGLE", "Forced angle used and named on the tag")
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
	# The other angles frame the play from where they should.
	var p: Vector3 = scene.puck.global_position
	r.angle = "ice"
	r.aim_camera(0.0, true)
	check(cam.global_position.y < 1.0 and absf(cam.global_position.z) > Arena.GOAL_LINE and absf(cam.global_position.z) < Arena.HALF_LENGTH, "Ice-level camera low inside the end boards (%s)" % cam.global_position)
	check(-cam.global_basis.z.z * end_sign < 0.0, "Ice-level camera looks out from the end")
	r.angle = "overhead"
	r.aim_camera(0.0, true)
	check(cam.global_position.y > 10.0 and -cam.global_basis.z.y < -0.9, "Overhead camera high and looking down (%s)" % cam.global_position)
	check(cam.cull_mask == preload("res://scripts/arena_lighting.gd").camera_cull_mask(cam.global_position), "Overhead camera hides the rigging")
	r.angle = "follow"
	r._shot_dir = Vector3(0, 0, -end_sign)
	r._release_t = r.play_t + 1.0
	r.aim_camera(0.0, true)
	var rel: Vector3 = cam.global_position - p
	check(rel.z * end_sign < -3.0 and rel.y > 1.5, "Shooter cam rides behind the puck (%s)" % rel)
	check(absf(cam.global_position.z) < Arena.HALF_LENGTH and absf(cam.global_position.x) < Arena.HALF_WIDTH, "Shooter cam stays inside the rink")
	var before: Vector3 = cam.global_position
	r.aim_camera(1.0 / 120.0, false)
	check(cam.global_position.distance_to(before) < 0.2, "Shooter cam moves smoothly")
	# After the release it holds behind the shooter instead of chasing the puck.
	r._release_pos = p - Vector3(0, 0, end_sign * 6.0)
	r._release_t = r.play_t - 0.1
	r.aim_camera(0.0, true)
	check(cam.global_position.distance_to(r._release_pos + r._shot_dir * 4.5 + Vector3(0, 2.3, 0)) < 0.7, "Shooter cam holds over the shooter's shoulder after the release")
	check(r.release_time() <= r.goal_time and r.release_time() >= r.goal_time - 1.5, "Release found in the 1.5 s before the goal")
	r.angle = "reverse"
	# Skip: wipe out, then the live picture comes back exactly.
	r.skip()
	check(not r.skip_prompt.visible, "Skip prompt goes once skipped")
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
	await check_save_replay(scene, r)
	finish(scene)

## Big saves: replayed at the next whistle (never during live play), with a
## crisp puck trail in the slow motion.
func check_save_replay(scene, r) -> void:
	var GoalReplay = preload("res://scripts/goal_replay.gd")
	var d: float = GoalReplay.clip_duration("save")
	check(d >= 4.0 and d <= 6.0, "Save replay runs 4-6 s on screen (%.2f)" % d)
	for i in range(int(4.0 * Engine.physics_ticks_per_second)):
		await physics_frame
		if scene.match_state.phase == scene.MatchState.Phase.PLAY: break
	check(scene.match_state.phase == scene.MatchState.Phase.PLAY, "Back in play for the save checks")
	var Phase = scene.MatchState.Phase
	# A soft save is not replayed.
	r.big_save(1.0, 0.1)
	scene.match_state.phase = Phase.STOPPAGE
	scene.match_state.phase_timer = 0.3
	await physics_frame
	await physics_frame
	check(not r.pending(), "Soft save not replayed")
	await back_to_play(scene)
	# A big save long before the whistle is not replayed either.
	r.big_save(1.0, 0.4)
	for i in range(int((GoalReplay.SAVE_WINDOW + 0.5) * Engine.physics_ticks_per_second)): await physics_frame
	scene.match_state.phase = Phase.STOPPAGE
	scene.match_state.phase_timer = 0.3
	await physics_frame
	await physics_frame
	check(not r.pending(), "Save long before the whistle not replayed")
	await back_to_play(scene)
	# A hard shot is stopped: play goes on, no replay yet.
	var end_sign := 1.0
	scene.puck.position = Vector3(1.0, 0.05, end_sign * 14.0)
	scene.puck.linear_velocity = Vector3(-0.1, 0.0, end_sign * 22.0)
	for i in range(int(0.3 * Engine.physics_ticks_per_second)): await physics_frame
	r.big_save(end_sign, 0.4)
	var save_t: float = r.clock
	for i in range(int(0.5 * Engine.physics_ticks_per_second)): await physics_frame
	check(not r.pending() and not r.playing(), "A save never interrupts live play")
	# Whistle (goalie covers): the save replay is queued and plays.
	scene.match_state.phase = Phase.STOPPAGE
	scene.match_state.phase_timer = 2.0
	await physics_frame
	await physics_frame
	check(r.pending() and r.kind == "save", "Whistle after a big save queues a save replay")
	check(is_equal_approx(r.goal_time, save_t), "Save replay centred on the save")
	for i in range(int((GoalReplay.SAVE_DELAY + 0.6) * Engine.physics_ticks_per_second)):
		await physics_frame
		if r.playing(): break
	check(r.playing(), "Save replay plays during the stoppage")
	check(r.tag.visible and r.angle_label.text.begins_with("GREAT SAVE"), "Tag names the save (%s)" % r.angle_label.text)
	check(r.play_t < r.goal_time - 2.0, "Save clip starts seconds before the save")
	check(not r.trail.visible, "No puck trail at full speed")
	# Slow motion as the shot arrives: a trail follows the puck back up its path.
	r.play_t = r.goal_time - 0.1
	await physics_frame
	check(r.slow_motion(), "Slow motion as the shot arrives")
	check(r.trail.visible, "Puck trail shown in slow motion")
	var pts: PackedVector3Array = r.trail_points()
	check(pts.size() >= 6, "Trail has a path (%d points)" % pts.size())
	if pts.size() >= 2:
		check(pts[0].distance_to(scene.puck.global_position) < 0.05, "Trail starts at the puck")
		var length := 0.0
		for i in range(1, pts.size()): length += pts[i].distance_to(pts[i - 1])
		check(length > 3.0 and length < 15.0, "Trail covers the puck's recent path (%.1f m)" % length)
		check((pts[0].z - pts[-1].z) * end_sign > 2.0, "Trail runs back up the shot line")
		# The ribbon itself: a built strip in world space, on the camera's layers.
		var mesh: ImmediateMesh = r.trail.mesh
		check(mesh.get_surface_count() == 1 and (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == pts.size() * 2, "Trail ribbon mesh built")
		check(r.trail.global_transform.is_equal_approx(Transform3D.IDENTITY), "Trail mesh in world space")
		check((r.trail.layers & r.camera.cull_mask) != 0, "Replay camera renders the trail's layer")
	r.skip()
	check(not r.trail.visible, "Trail gone when the replay ends")
	var guard := 0
	while r.playing() and guard < 400:
		await physics_frame
		guard += 1
	check(not r.playing() and not r.trail.visible, "Save replay ends cleanly")

func back_to_play(scene) -> void:
	for i in range(int(6.0 * Engine.physics_ticks_per_second)):
		await physics_frame
		if scene.match_state.phase == scene.MatchState.Phase.PLAY: return

func finish(scene) -> void:
	scene.queue_free()
	await process_frame
	print("Goal replay failures: ", failures)
	quit(failures)
