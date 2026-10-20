extends SceneTree
## Goal nets: NHL-style frame shape, padding, netting clear of the goal mouth,
## puck held by the net, and a ripple when the puck hits it.
const GoalNet = preload("res://scripts/goal_net.gd")
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Frame geometry.
	check(GoalNet.base_point(0.0).distance_to(Vector3(-GoalNet.POST_X, GoalNet.base_point(0.0).y, 0)) < 0.01, "Base frame starts at the left post")
	check(GoalNet.base_point(1.0).distance_to(Vector3(GoalNet.POST_X, GoalNet.base_point(1.0).y, 0)) < 0.01, "Base frame ends at the right post")
	check(absf(GoalNet.base_point(0.5).z + GoalNet.BASE_DEPTH) < 0.01 and absf(GoalNet.base_point(0.5).x) < 0.01, "Base frame is %.2f m deep at the back" % GoalNet.BASE_DEPTH)
	check(absf(GoalNet.top_point(0.5).z + GoalNet.TOP_DEPTH) < 0.01, "Upper back bar sits behind the crossbar")
	check(GoalNet.TOP_DEPTH < GoalNet.BASE_DEPTH, "Back of the net slopes out from the top bar to the base")
	# Netting stays behind the goal line and outside the scoring mouth.
	var intrudes := 0
	for i in range(41):
		for j in range(11):
			var p := GoalNet.net_point(float(i) / 40, float(j) / 10)
			if p.z > 0.001: intrudes += 1
			# Inside the frame (|x| < 0.887 for a whole puck) and just behind the line.
			if p.z > -0.05 and absf(p.x) < 0.89 and p.y < 1.15: intrudes += 1
			var q := GoalNet.shelf_point(float(i) / 40, float(j) / 10)
			if q.z > 0.001 or q.y < 1.15: intrudes += 1
	check(intrudes == 0, "Netting never crosses into the goal mouth (%d points)" % intrudes)

	var scene = load("res://practice.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	for g in scene.arena.goals:
		check(g is GoalNet, "%s is a GoalNet" % g.name)
		check(g.get_node_or_null("Netting") != null, "%s has netting mesh" % g.name)
		check(g.get_node_or_null("BasePadding") != null, "%s has white base padding" % g.name)
		check(g.get_node_or_null("UpperBackBar") != null and g.get_node_or_null("BaseFrame") != null, "%s has base frame and back bar" % g.name)
		check(g.collision_slabs >= 16, "%s netting has collision" % g.name)
		check(g.net_material.shader.code.contains("ripple_age"), "Net shader ripples")
	# Shot into the north net: scores once, stays in, and ripples the net.
	for goalie in scene.goalkeepers:
		goalie.collision_layer = 0
		scene.set_puck_contacts_enabled(goalie, false)
	var net = scene.arena.goals[0]
	var before: int = net.impacts
	scene.cooldown = 0
	scene.player.position = Vector3(0, 0, -25.45)
	scene.puck.position = Vector3(0, 0.15, -26.25)
	scene.previous_puck = scene.puck.position
	# Explicit centre placement: this test isolates back-net containment/ripple,
	# independent of the current pointer position under the new net-aim controls.
	scene.practice_input.active = true
	scene.practice_input.left_stick = Vector2.ZERO
	check(scene.strike(Vector3.FORWARD, 34), "Centre net shot is accepted")
	for i in range(60):
		await physics_frame
	check(scene.goals == 1, "Front shot scores exactly once")
	var local: Vector3 = net.to_local(scene.puck.global_position)
	check(local.z < 0 and local.z > -GoalNet.BASE_DEPTH - 0.05 and absf(local.x) < GoalNet.POST_X + 0.05, "Puck held inside the net (local %s)" % local)
	check(net.impacts > before, "Puck hitting the netting starts a ripple")
	check(net.ripple_age < 1.0 and net.ripple_strength > 0.0, "Ripple is live after the hit")
	# Ripple decays and stops updating.
	await create_timer(3.3).timeout
	check(net.ripple_age >= 3.0, "Ripple settles")
	# A puck sliding past behind the boards-side of the net with no hit: no ripple.
	var quiet: int = scene.arena.goals[1].impacts
	for i in range(20): await physics_frame
	check(scene.arena.goals[1].impacts == quiet, "Untouched net stays still")
	print("Goal net failures: %d" % failures)
	quit(failures)
