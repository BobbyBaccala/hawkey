extends SceneTree
## Skater bodies tethered to the opposing net (face it whatever way they skate,
## shots go on goal), and goalies square to the puck from the middle of their net.
const Arena = preload("res://scripts/arena.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func _initialize() -> void: call_deferred("run")

func facing_of(visual: Node3D) -> Vector3:
	# The rig faces local -Z of the visual.
	var f: Vector3 = -visual.global_basis.z
	f.y = 0
	return f.normalized()

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	await physics_frame
	scene.match_state.phase_timer = 0
	for i in range(4): await physics_frame
	var player: CharacterBody3D = scene.player
	var net := Vector3(0, 0, scene.attack_direction(scene.body_team(player)) * Arena.GOAL_LINE)
	# With the puck: whatever direction the carrier skates, he faces the net.
	scene.puck.freeze = true
	for key in [KEY_W, KEY_S, KEY_A, KEY_D]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.pressed = true
		Input.parse_input_event(ev)
		for f in range(90):
			scene.carrier = player
			scene.puck.position = player.get_child(1).get_blade_world()
			await physics_frame
		ev.pressed = false
		Input.parse_input_event(ev)
		var want := net - player.position
		want.y = 0
		var got := facing_of(player.get_child(1))
		check(got.dot(want.normalized()) > 0.95, "Carrying, holding %s the player faces the opposing net (dot %.2f)" % [OS.get_keycode_string(key), got.dot(want.normalized())])
	# Without the puck: every skater (both teams, including the user's) faces the puck.
	scene.carrier = null
	scene.puck.position = Vector3(3, 0.05, 2)
	for f in range(90):
		scene.carrier = null
		await physics_frame
	var worst := 1.0
	for actor in scene.skaters:
		if not bool(actor.get_meta("eligible")) or bool(actor.get_meta("changing")): continue
		var want: Vector3 = scene.puck.position - actor.position
		want.y = 0
		if want.length() < 0.5: continue
		worst = minf(worst, facing_of(actor.get_child(1)).dot(want.normalized()))
	check(worst > 0.9, "Skaters without the puck face the puck (worst dot %.2f)" % worst)
	scene.puck.freeze = false
	# A shot from the side boards with the aim pointed away from the net goes on goal.
	scene.aim = Vector3(1, 0, 0)
	scene.puck.position = Vector3(8, 0.05, net.z * 0.6)
	var d: Vector3 = scene.shot_direction()
	var hit_x: float = scene.puck.position.x + d.x * ((net.z - scene.puck.position.z) / d.z)
	check(absf(hit_x) < 0.92, "Shot aimed off to the side still travels at the goal mouth (x %.2f)" % hit_x)
	# Goalies: on the line from the net centre to the puck, chest square to it.
	scene.puck.freeze = true
	# Puck at the left point, right half-wall and the slot of the first goalie's zone.
	var zone := signf(scene.goalkeepers[0].position.z)
	var checked := 0
	for spot in [Vector2(-6, 9), Vector2(5, 7), Vector2(0, 6)]:
		scene.puck.position = Vector3(spot.x, 0.05, zone * (Arena.GOAL_LINE - spot.y))
		for f in range(120): await physics_frame
		for keeper in scene.goalkeepers:
			var end_ := signf(keeper.position.z)
			var base := Vector3(0, 0, end_ * Arena.GOAL_LINE)
			var to_puck: Vector3 = scene.puck.position - base
			to_puck.y = 0
			# Only the goalie whose zone the puck is in matters.
			if signf(scene.puck.position.z) != end_: continue
			checked += 1
			var face := facing_of(keeper.get_child(1))
			check(face.dot(to_puck.normalized()) > 0.95, "Goalie square to the puck (dot %.2f)" % face.dot(to_puck.normalized()))
			var off: Vector3 = keeper.position - base
			off.y = 0
			check(off.normalized().dot(to_puck.normalized()) > 0.9, "Goalie on the net-centre-to-puck line (dot %.2f)" % off.normalized().dot(to_puck.normalized()))
	check(checked == 3, "Goalie checked at all three puck spots (%d)" % checked)
	print("Net tether failures: %d" % failures)
	quit(failures)
