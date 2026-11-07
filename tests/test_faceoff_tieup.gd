extends SceneTree
## Faceoff slice 4: after the puck lands the losing centre drives his body into
## the winner (tie-up lean) and the linesman backs out of the circle facing the
## dot with a backward glide before turning for his line.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	await physics_frame
	scene.match_state.phase_timer = 50.0
	scene.camera_mode = 0
	for i in range(10): await physics_frame
	var dot: Vector3 = scene.next_faceoff
	var linesman = scene.linesman
	check(linesman != null, "A linesman takes the faceoff")
	scene.match_state.phase_timer = 0.0
	var frames := 0
	while not scene.draw_landed and frames < 200:
		await physics_frame
		frames += 1
	check(scene.draw_landed, "Puck landed")
	check(scene.backing_official == linesman, "The linesman starts backing out on the landing")
	var start_yaw: float = linesman.rotation.y
	var start_off := Vector2(linesman.position.x - dot.x, linesman.position.z - dot.z).length()
	var winner = scene.faceoff_winner
	var loser = null
	for c in scene.draw_centres:
		if c != winner: loser = c
	check(loser != null, "There is a losing centre")
	# ~0.25 s after landing: the tie-up is at full weight.
	for i in range(30): await physics_frame
	var lv = loser.get_child(1)
	var wv = winner.get_child(1)
	check(lv.tie_up_weight() > 0.9, "Loser leaning into the winner (weight %.2f)" % lv.tie_up_weight())
	var lz: float = (lv.rig.basis.inverse()*lv.rig.position).z
	check(lz > 0.12, "Loser's body driven forward into the winner (%.2f m)" % lz)
	var wz: float = (wv.rig.basis.inverse()*wv.rig.position).z
	check(wz < -0.03, "Winner gives a little ground (%.2f m)" % wz)
	# Loser's body closes on the winner in world space.
	var gap_rest: float = loser.global_position.distance_to(winner.global_position)
	var gap_body: float = lv.rig.global_position.distance_to(wv.rig.global_position)
	check(gap_body < gap_rest - 0.12, "Bodies come together in the tie-up (%.2f -> %.2f m)" % [gap_rest, gap_body])
	# Linesman: moving away from the dot, still facing it (backward glide).
	var mid_off := Vector2(linesman.position.x - dot.x, linesman.position.z - dot.z).length()
	check(mid_off > start_off + 0.15, "Linesman backs away from the dot (%.2f -> %.2f m)" % [start_off, mid_off])
	check(absf(wrapf(linesman.rotation.y - start_yaw, -PI, PI)) < 0.01, "Linesman keeps facing the dot while backing out")
	for i in range(60): await physics_frame
	var late_off := Vector2(linesman.position.x - dot.x, linesman.position.z - dot.z).length()
	check(late_off > 1.9, "Linesman well clear of the circle centre after ~0.75 s (%.2f m)" % late_off)
	check(lv.tie_up_weight() == 0.0 and lv.rig.position.length() < 0.001, "Tie-up released (no rig offset left)")
	# After the backing glide he turns and skates to his line as before.
	for i in range(120): await physics_frame
	check(scene.backing_official == null, "Backing glide ends")
	print("test_faceoff_tieup: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)
