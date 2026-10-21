extends SceneTree
## Board hop (line change): the visual leaves the body at the bench door,
## vaults the dasher with the knees tucked so no part of either skate passes
## through the boards, lands on the bench floor, and the hop back out ends
## exactly on the body. The path and pose change smoothly (no pops), and the
## stick is lifted blade-up so it never passes through the boards.
const Arena = preload("res://scripts/arena.gd")
const BoardHop = preload("res://scripts/board_hop.gd")
const DT := 1.0 / 120
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

## World-space AABB of every mesh under a node.
func world_box(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null or not mi.visible: continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## Lowest skate point inside the board's footprint (x band), or INF if none.
func lowest_over_boards(v) -> float:
	var low := INF
	for skate in v.skates:
		var b := world_box(skate)
		if b.end.x > -(Arena.HALF_WIDTH + 0.30) and b.position.x < -Arena.HALF_WIDTH + 0.02:
			low = minf(low, b.position.y)
	return low

## Deepest any point of the stick (shaft and blade) sits inside the dasher
## boards' volume (west boards, up to the cap), 0 if clear.
func stick_in_boards(v) -> float:
	var pts: Array[Vector3] = []
	for k in range(25):
		pts.append(v.stick_shaft.global_transform * Vector3(0, k / 24.0 - 0.5, 0))
	for k in range(9):
		pts.append(v.stick_blade.global_transform * Vector3(v.stick_blade_length * k / 8.0, 0, 0))
	var worst := 0.0
	var x_in := -Arena.HALF_WIDTH
	var x_out := x_in - BoardHop.BOARD_DEPTH
	for p in pts:
		if p.x < x_in and p.x > x_out and p.y < BoardHop.BOARD_TOP:
			worst = maxf(worst, minf(minf(x_in - p.x, p.x - x_out), BoardHop.BOARD_TOP - p.y))
	return worst

func check_stick(r: Dictionary, what: String) -> void:
	check(r.stick_in < 0.005, "Stick carried clear of the boards %s (%.3f m inside)" % [what, r.stick_in])
	check(r.max_stick_step < 0.16, "Stick lifts and lowers without popping %s (blade step %.3f m)" % [what, r.max_stick_step])
	# Turns into the hop from the heading it had (no snap to face the boards).
	check(r.max_yaw_step < 0.11, "Turns smoothly into the hop %s (largest yaw step %.3f rad)" % [what, r.max_yaw_step])

func check_plant(r: Dictionary, what: String) -> void:
	check(r.plant_peak > 0.99, "Top hand plants on the board cap %s (peak %.2f)" % [what, r.plant_peak])
	check(r.plant_frames >= 15, "Hand stays planted at least 0.125 s %s (%d frames)" % [what, r.plant_frames])
	check(r.hand_err < 0.03, "Planted glove sits on the cap %s (off by %.3f m)" % [what, r.hand_err])
	# The hand comes off quickly (~0.1 s) as the body rises into the vault; the
	# glove-step check below is what keeps that from reading as a pop.
	check(r.max_plant_step < 0.16, "Plant blends in and out smoothly %s (step %.3f)" % [what, r.max_plant_step])
	check(r.max_hand_step < 0.06, "Glove never jumps %s (largest step %.3f m)" % [what, r.max_hand_step])

func run_hop(v, body: Node3D, a: Vector3, b: Vector3, carried := false) -> Dictionary:
	v.start_hop(a, b, -Arena.HALF_WIDTH - body.position.x, carried)
	var result := {"clear": INF, "max_step": 0.0, "max_tuck_step": 0.0, "peak": 0.0, "frames": 0, "crossed": false,
		"plant_peak": 0.0, "plant_frames": 0, "max_plant_step": 0.0, "hand_err": 0.0, "max_hand_step": 0.0, "stick_in": 0.0, "max_stick_step": 0.0, "max_yaw_step": 0.0}
	var last_blade := Vector3.INF
	var last_yaw: float = v.rotation.y
	var last_plant := 0.0
	var last_hand := Vector3.INF
	var last: Vector3 = v.position
	var last_tuck := 0.0
	while v.hopping():
		v.animate(0, DT, 0, false)
		result.frames += 1
		result.clear = minf(result.clear, lowest_over_boards(v))
		result.stick_in = maxf(result.stick_in, stick_in_boards(v))
		result.max_yaw_step = maxf(result.max_yaw_step, absf(angle_difference(last_yaw, v.rotation.y)))
		last_yaw = v.rotation.y
		var blade: Vector3 = v.stick_blade.global_position
		if last_blade != Vector3.INF: result.max_stick_step = maxf(result.max_stick_step, blade.distance_to(last_blade))
		last_blade = blade
		result.max_step = maxf(result.max_step, (v.position - last).length())
		var tuck: float = v.hop_state.get("tuck", 0.0)
		result.max_tuck_step = maxf(result.max_tuck_step, absf(tuck - last_tuck))
		result.peak = maxf(result.peak, tuck)
		last = v.position
		last_tuck = tuck
		# Top hand on the board cap: planted firmly for part of the hop, right on
		# the cap (not floating, not sunk into it) while planted, blended in and
		# out without the glove jumping.
		var plant: float = v.hand_plant
		result.plant_peak = maxf(result.plant_peak, plant)
		result.max_plant_step = maxf(result.max_plant_step, absf(plant - last_plant))
		# Where the fist closes (the glove's hole), which rests on the cap.
		var hand: Vector3 = v.rig.global_transform * (v.skater_gloves[0].transform * v.GLOVE_HOLE)
		if plant > 0.95:
			result.plant_frames += 1
			var cap: Vector3 = body.global_transform * (v.hop_state.hand as Vector3)
			result.hand_err = maxf(result.hand_err, hand.distance_to(cap))
		if last_hand != Vector3.INF: result.max_hand_step = maxf(result.max_hand_step, hand.distance_to(last_hand))
		last_hand = hand
		last_plant = plant
		if result.frames > 1000: break
	return result

func run() -> void:
	var Visual = load("res://scripts/skater_visual.gd")
	var body := Node3D.new()
	body.position = Vector3(-(Arena.HALF_WIDTH - 0.75), 0, 4.0)
	root.add_child(body)
	var v = Visual.new()
	body.add_child(v)
	await process_frame
	for f in range(30): v.animate(0, DT, 0, false)

	# Over the boards onto the bench floor.
	var bench := Vector3(-(Arena.HALF_WIDTH + 0.85), 0, 4.0) - body.position
	var out := run_hop(v, body, Vector3.ZERO, bench)
	check(out.frames >= int(BoardHop.DURATION / DT) - 2 and out.frames <= int(BoardHop.DURATION / DT) + 2, "Hop takes about %.2f s (%d frames)" % [BoardHop.DURATION, out.frames])
	check(v.hop_finished(), "Hop out reaches its end")
	check(out.clear > BoardHop.BOARD_TOP + 0.02, "Skates clear the board top going over (lowest %.3f m)" % out.clear)
	check(out.peak > 0.9, "Knees tuck over the boards (%.2f)" % out.peak)
	check(out.max_step < 0.05, "Hop path is continuous (largest step %.3f m)" % out.max_step)
	check(out.max_tuck_step < 0.08, "Tuck blends smoothly (largest step %.3f)" % out.max_tuck_step)
	check_plant(out, "going over")
	check_stick(out, "going over")
	check(v.global_position.distance_to(body.position + bench) < 0.01, "Lands on the bench floor")
	check(absf(v.global_position.y) < 0.001, "Stands on the bench floor after landing")
	# Facing the bench while going out: game forward (-Z of the visual) points -x.
	var forward: Vector3 = -v.global_basis.z
	check(forward.x < -0.9, "Faces the bench going out")

	# Fresh player back over onto the ice, ending on the body.
	# He is a different player (match.gd swaps identity on the bench) and gets
	# up off the bench facing the ice.
	v.rotation.y = -PI * 0.5
	var back := run_hop(v, body, v.position + Vector3(0, 0, -0.7), Vector3.ZERO, true)
	check(back.clear > BoardHop.BOARD_TOP + 0.02, "Skates clear the boards coming back (lowest %.3f m)" % back.clear)
	check(back.max_step < 0.05, "Return path is continuous (largest step %.3f m)" % back.max_step)
	check_plant(back, "coming back")
	check_stick(back, "coming back")
	check(v.position.length() < 0.001, "Return hop ends on the body")
	forward = -v.global_basis.z
	check(forward.x > 0.9, "Faces the ice coming back")
	v.cancel_hop()
	check(not v.hopping() and v.hop_state.is_empty() and v.position == Vector3.ZERO, "cancel_hop() resets the visual")
	v.animate(0, DT, 0, false)
	check(v.hand_plant == 0.0, "Both hands back on the stick after the hop")
	check(v.stick_carry == 0.0 and v.blade_position.y < 0.05, "Stick back down on the ice after the hop")

	# Whatever heading the skater has when he starts the hop (skating along the
	# boards either way, facing them, back to them) he turns smoothly into it
	# and the stick never reaches into the boards.
	for yaw in [PI, PI * 0.5, -PI * 0.5, PI * 0.25]:
		v.rotation.y = yaw
		for f in range(30): v.animate(0, DT, 0, false)
		var r := run_hop(v, body, Vector3.ZERO, bench)
		var what := "starting at yaw %.2f" % yaw
		# Facing the boards from 0.75 m the blade is in them before the hop
		# starts; it must come out at once and stay out.
		check(r.stick_in < 0.005, "Stick clear of the boards %s (%.3f m inside)" % [what, r.stick_in])
		check(r.max_yaw_step < 0.11, "Turns smoothly into the hop %s (largest yaw step %.3f rad)" % [what, r.max_yaw_step])
		if yaw != PI * 0.5: check(r.max_stick_step < 0.16, "Stick lifts without popping %s (blade step %.3f m)" % [what, r.max_stick_step])
		check(r.clear > BoardHop.BOARD_TOP + 0.02, "Skates clear the boards %s" % what)
		v.cancel_hop()

	# Pure path: offsets stay on the near side before take-off and the far side after landing.
	for k in range(101):
		var u := k / 100.0
		var s: Dictionary = BoardHop.sample(u, Vector3(1.2, 0, 0), Vector3(-0.9, 0, 0.3), 0.0)
		if u < BoardHop.VAULT_START: check(s.offset.x >= BoardHop.TAKEOFF - 0.001, "Near side before take-off (u=%.2f)" % u)
		if u > BoardHop.VAULT_END: check(s.offset.x <= -BoardHop.BOARD_DEPTH - BoardHop.TAKEOFF + 0.001, "Far side after landing (u=%.2f)" % u)
		if u < BoardHop.VAULT_START - 0.06 or u > BoardHop.VAULT_END + 0.04: check(s.tuck == 0.0, "No tuck while skating (u=%.2f)" % u)
		if u >= BoardHop.CARRY_IN and u <= 1.0 - BoardHop.CARRY_OUT: check(s.carry > 0.999, "Stick fully carried over the vault (u=%.2f)" % u)
		if u <= BoardHop.PLANT_START or u >= BoardHop.PLANT_END: check(s.plant == 0.0, "Hand off the boards outside the plant (u=%.2f)" % u)
		check(absf(s.hand.x + BoardHop.BOARD_DEPTH * 0.5) < 0.001 and absf(s.hand.y - BoardHop.BOARD_TOP - BoardHop.HAND_ABOVE_CAP) < 0.001, "Hand point is on the middle of the cap (u=%.2f)" % u)
	body.queue_free()
	await process_frame
	print("Board hop failures: ", failures)
	quit(failures)
