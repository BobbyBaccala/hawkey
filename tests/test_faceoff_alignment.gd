extends SceneTree
## End-zone faceoff alignment (owner 2026-11-18): the defending team stacks
## both wingers one behind the other on its own (goal) side of the middle
## hash marks with a D below them toward the net and the other D low behind
## the centre; nobody lines up along the boards beside another player. The
## attacking team has a winger on each hash and its D at the blue line.
const Arena = preload("res://scripts/arena.gd")
const T = preload("res://scripts/team_tactics.gd")
var failures := 0
func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		push_error(msg)
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	await physics_frame
	for dot in [Vector3(Arena.DOT_X, 0, -Arena.END_DOT_Z), Vector3(-Arena.DOT_X, 0, Arena.END_DOT_Z)]:
		scene.next_faceoff = dot
		scene.setup_faceoff()
		var end_: float = signf(dot.z)
		var boards: float = signf(dot.x)
		var defending := []
		var attacking := []
		for a in scene.skaters:
			if not bool(a.get_meta("eligible")): continue
			var team: int = scene.body_team(a)
			(attacking if scene.attack_direction(team) == end_ else defending).append(a)
		var wings := defending.filter(func(a): return int(a.get_meta("slot")) in [1, 2])
		var ds := defending.filter(func(a): return int(a.get_meta("slot")) >= 3)
		check(wings.size() == 2 and ds.size() == 2, "Defending team has two wingers and two D")
		var hash_x: float = dot.x - boards * scene.FACEOFF_HASH_X
		for w in wings:
			check(absf(w.position.x - hash_x) < 0.3, "Defending winger on the middle hash marks (x %.2f vs %.2f)" % [w.position.x, hash_x])
			check((w.position.z - dot.z) * end_ > 0.3, "Defending winger on his own (goal) side of the hash marks")
		if wings.size() == 2:
			check(absf(wings[0].position.z - wings[1].position.z) > 0.8 and absf(wings[0].position.x - wings[1].position.x) < 0.3, "The two wingers are stacked one behind the other")
		var below := false
		for d in ds:
			if (d.position.z - dot.z) * end_ > 2.5 and signf(d.position.x - dot.x) == -boards: below = true
		check(below, "A D below the stacked wingers toward the net")
		# Nobody from the defending team on the boards-side hash.
		var boards_hash := Vector3(dot.x + boards * scene.FACEOFF_HASH_X, 0, dot.z)
		for a in defending:
			if int(a.get_meta("slot")) == 0: continue
			check(Vector2(a.position.x - boards_hash.x, a.position.z - boards_hash.z).length() > 2.0, "No defending player along the boards-side hash")
		# Inside the rink, never behind the goal line.
		for a in defending + attacking:
			check(absf(a.position.z) < Arena.GOAL_LINE - 0.5, "Lined up in front of the goal line")
		# Attacking D at the blue line.
		for a in attacking:
			if int(a.get_meta("slot")) >= 3:
				check(absf(absf(a.position.z) - (Arena.BLUE_LINE + 1.2)) < 0.5, "Attacking D at the blue line")
	print("Faceoff alignment failures: ", failures)
	quit(1 if failures > 0 else 0)
