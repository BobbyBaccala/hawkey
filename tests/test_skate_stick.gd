extends SceneTree
## Skate cuff and stick blade: the leg always goes down into the boot, and the
## blade runs on from the heel away from the hands, flat on the ice.
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var v = load("res://scripts/skater_visual.gd").new()
	root.add_child(v)
	await process_frame
	check(v.skate_cuffs.size() == 2, "Each player skate has an ankle cuff")
	var worst_sock := 0.0
	var worst_flex := 0.0
	var worst_toe := 1.0
	var worst_flat := 1.0
	for speed in [0.0, 3.0, 8.0]:
		for f in range(240):
			v.animate(speed, 1.0 / 120, 0, speed > 0.5)
			for i in range(2):
				var cuff: MeshInstance3D = v.skate_cuffs[i]
				var cuff_rig: Transform3D = v.skates[i].transform * cuff.transform
				# Sock bottom: where fit_limb ends the sock (local to the cuff).
				var sock: MeshInstance3D = v.socks[i]
				var sock_end: Vector3 = sock.transform * Vector3(0, -1, 0)
				var local := cuff_rig.affine_inverse() * sock_end
				var out := maxf(absf(local.x) - 0.05, 0.0) + maxf(absf(local.z) - 0.06, 0.0) + maxf(local.y - 0.13, 0.0) + maxf(-local.y, 0.0)
				worst_sock = maxf(worst_sock, out)
				var foot_up: Vector3 = Basis.from_euler(v.skates[i].rotation).y
				worst_flex = maxf(worst_flex, foot_up.angle_to(cuff_rig.basis.y.normalized()))
			# Stick: toe away from the hands, blade upright on the ice.
			var top: Vector3 = v.stick_grip()
			var heel: Vector3 = v.stick_blade.position - v.stick_blade.basis * Vector3(v.stick_blade_length * 0.48, 0, 0)
			var lean := heel - top
			lean.y = 0
			var toe: Vector3 = v.stick_blade.basis.x
			worst_toe = minf(worst_toe, toe.normalized().dot(lean.normalized()))
			worst_flat = minf(worst_flat, v.stick_blade.basis.y.normalized().dot(Vector3.UP))
	check(worst_sock < 0.005, "Sock ends inside the skate cuff (worst %.3f m outside)" % worst_sock)
	check(worst_flex <= v.CUFF_FLEX + 0.01, "Cuff flexes no more than a stiff boot allows (%.2f rad)" % worst_flex)
	check(worst_toe > 0.95, "Blade runs on from the heel away from the hands (dot %.2f)" % worst_toe)
	check(worst_flat > 0.99, "Blade sits flat, upright on the ice (dot %.3f)" % worst_flat)
	check(v.get_blade_world().distance_to(v.stick_blade.to_global(Vector3(0,-0.0163,-0.00575+v.shot_side()*0.050))) < 0.001, "Puck center sits outside blade face, not inside mesh")
	# Two-hand grip like a real player: both fists closed ON the shaft, two to
	# three hand-widths apart, top hand on the knob, shaft across the palm
	# (not held end-on), and a full-length stick out in front.
	var worst_off := 0.0
	var min_gap := 9.0
	var max_gap := 0.0
	var min_forearm := 180.0
	var min_len := 9.0
	for speed in [0.0, 4.0, 8.0]:
		for f in range(120):
			v.animate(speed, 1.0 / 120, 0, speed > 0.5)
		var top: Vector3 = v.stick_grip()
		var heel: Vector3 = v.stick_heel(top)
		var sd := (heel - top).normalized()
		min_len = minf(min_len, top.distance_to(heel))
		var along := []
		for i in range(2):
			var hole: Vector3 = v.skater_gloves[i].transform * v.GLOVE_HOLE
			worst_off = maxf(worst_off, (hole - top).cross(sd).length())
			along.append((hole - top).dot(sd))
			var forearm: Vector3 = (v.posed_elbows[i] - v.posed_wrists[i]).normalized()
			min_forearm = minf(min_forearm, rad_to_deg(forearm.angle_to(sd)))
		min_gap = minf(min_gap, along[1] - along[0])
		max_gap = maxf(max_gap, along[1] - along[0])
		check(absf(along[0]) < 0.03, "Top hand is on the knob (%.3f m from the end)" % along[0])
	check(worst_off < 0.02, "Both fists close on the shaft (worst %.3f m off)" % worst_off)
	check(min_gap > 0.22 and max_gap < 0.55, "Hands two to three hand-widths apart (%.2f-%.2f m)" % [min_gap, max_gap])
	check(min_forearm > 100.0, "Shaft crosses the palms, not held end-on (min %.0f deg)" % min_forearm)
	check(min_len > 0.95, "Full-length stick out in front (min %.2f m knob to heel)" % min_len)
	print("Skate/stick failures: %d" % failures)
	quit(failures)
