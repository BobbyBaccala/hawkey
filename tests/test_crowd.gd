extends SceneTree
## Crowd reactions: the crowd cards use the animated crowd shader; a goal in
## the match brings the whole bowl up (cheer toward 1 at the scored-on end),
## it holds and then settles back to seated fidgeting; a hard save gets a
## smaller, shorter reaction that never cuts a goal roar short; soft or
## outgoing pucks get none.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	await physics_frame
	var d = scene.arena.get_node_or_null("Dressing")
	check(d != null, "Arena dressing exists")
	if d == null:
		finish(scene)
		return
	check(d.crowd_cards > 300, "Bowl is full of crowd cards (%d)" % d.crowd_cards)
	check(d.crowd_materials.size() == 6, "Six shared crowd materials")
	var shader_cards := 0
	for c in d.get_children():
		if c is MeshInstance3D and c.material_override is ShaderMaterial and c.material_override.shader == d.CROWD_SHADER:
			shader_cards += 1
	check(shader_cards == d.crowd_cards, "Every crowd card uses the crowd shader (%d of %d)" % [shader_cards, d.crowd_cards])
	check(d.cheer == 0.0, "Crowd seated at puck drop")
	# Fidget clock runs and reaches the materials.
	d.set_process(false)
	var clock0: float = d.crowd_clock
	d.advance_crowd(0.5)
	check(is_equal_approx(d.crowd_clock, clock0 + 0.5), "Crowd clock advances")
	var m: ShaderMaterial = d.crowd_materials[0]
	check(is_equal_approx(m.get_shader_parameter("clock"), d.crowd_clock), "Clock pushed to the shader")
	check(m.get_shader_parameter("shimmer") > 0.5, "Seat shimmer on during play")
	d.set_process(true)

	# Real goal in the match.
	scene.match_state.phase_timer = 0.05
	for i in range(240):
		await physics_frame
		if scene.match_state.phase == scene.MatchState.Phase.PLAY: break
	check(scene.match_state.phase == scene.MatchState.Phase.PLAY, "Match reached play")
	var Arena = preload("res://scripts/arena.gd")
	var end_sign := 1.0
	scene.previous_puck = Vector3(0.1, 0.02, end_sign * (Arena.GOAL_LINE - 0.25))
	scene.puck.position = Vector3(0.1, 0.02, end_sign * (Arena.GOAL_LINE + 0.4))
	await physics_frame
	await physics_frame
	check(d.cheer_target == 1.0 and d.cheer_end == end_sign, "Goal: crowd roars at the scored-on end (target %.2f end %.1f)" % [d.cheer_target, d.cheer_end])
	d.set_process(false)
	var prev: float = d.cheer
	var max_step := 0.0
	for i in range(30):
		d.advance_crowd(1.0 / 60.0)
		max_step = maxf(max_step, d.cheer - prev)
		prev = d.cheer
	check(d.cheer > 0.95, "Crowd on its feet within half a second (%.2f)" % d.cheer)
	check(max_step < 0.1, "Crowd rises smoothly (max step %.3f)" % max_step)
	check(is_equal_approx(m.get_shader_parameter("cheer"), d.cheer), "Cheer pushed to the shader")
	# A save during the roar does not cut it short.
	d.crowd_react(0.4, -1.0, 0.5)
	check(d.cheer_target == 1.0 and d.cheer_end == end_sign, "A smaller reaction never cuts the goal roar")
	d.advance_crowd(2.0)
	check(d.cheer > 0.95, "Roar held for the hold time")
	# Settles back down, smoothly.
	var t := 0.0
	var max_drop := 0.0
	prev = d.cheer
	while d.cheer > 0.0 and t < 10.0:
		d.advance_crowd(1.0 / 60.0)
		t += 1.0 / 60.0
		max_drop = maxf(max_drop, prev - d.cheer)
		prev = d.cheer
	check(d.cheer == 0.0 and t > 3.0 and t < 7.0, "Crowd sits back down a few seconds later (%.1f s)" % t)
	check(max_drop < 0.02, "Settles gradually (max drop %.3f/frame)" % max_drop)

	# Saves: only hard shots at the net get a reaction, scaled by speed.
	var S = scene.get_script()
	check(S.save_reaction(Vector3(0, 0, 32), 25.0) > 0.5, "32 m/s save gets a big reaction")
	check(S.save_reaction(Vector3(0, 0, 20), 25.0) > 0.1 and S.save_reaction(Vector3(0, 0, 20), 25.0) < S.save_reaction(Vector3(0, 0, 30), 25.0), "Reaction grows with shot speed")
	check(S.save_reaction(Vector3(0, 0, 12), 25.0) == 0.0, "Soft shot: no reaction")
	check(S.save_reaction(Vector3(0, 0, -30), 25.0) == 0.0, "Puck heading away from that net: no reaction")
	check(S.save_reaction(Vector3(3, 0, -30), -25.0) > 0.4, "Works at either net")
	d.crowd_react(S.save_reaction(Vector3(0, 0, 30), 25.0), 1.0, 0.5)
	for i in range(30): d.advance_crowd(1.0 / 60.0)
	check(d.cheer > 0.3 and d.cheer < 0.6, "Big save: crowd half up (%.2f)" % d.cheer)
	t = 0.0
	while d.cheer > 0.0 and t < 10.0:
		d.advance_crowd(1.0 / 60.0)
		t += 1.0 / 60.0
	check(t < 2.5, "Save reaction is short (%.1f s)" % t)
	finish(scene)

func finish(scene) -> void:
	scene.queue_free()
	if failures == 0: print("test_crowd: PASS")
	else: print("test_crowd: %d failures" % failures)
	quit(failures)
