extends SceneTree
## Goalie save selection and poses: the right save for where the shot crosses,
## gear actually moves to the puck's line (so the physical colliders do too),
## pads lie on the ice for an extension, the stick never stretches, and a new
## save interrupts the recovery from the last one.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func settle(v, kind: String, target: Vector2, frames := 60) -> void:
	for k in range(frames):
		v.butterfly = move_toward(v.butterfly, 1.0 if kind in ["butterfly", "pad_left", "pad_right"] else 0.0, 6.0 / 60)
		v.set_save(kind, target, 1.0 / 60)
		v.animate(0, 1.0 / 60, 0, false)

func run() -> void:
	var Visual = load("res://scripts/skater_visual.gd")
	# Selection by crossing point (x + = glove side, height).
	check(Visual.choose_save(0.1, 0.15) == "butterfly", "Low shot in front -> butterfly")
	check(Visual.choose_save(0.9, 0.1) == "pad_left", "Low shot wide glove side -> pad extension left")
	check(Visual.choose_save(-0.9, 0.1) == "pad_right", "Low shot wide blocker side -> pad extension right")
	check(Visual.choose_save(0.6, 1.2) == "glove", "High glove side -> glove")
	check(Visual.choose_save(-0.6, 0.9) == "blocker", "Blocker side -> blocker")
	check(Visual.choose_save(0.0, 0.7) == "body", "Chest-height centre -> body block")
	check(Visual.choose_save(1.15, 0.1) == "splits_left", "Low shot past the pad reach, glove side -> splits")
	check(Visual.choose_save(-1.15, 0.1) == "splits_right", "Low shot past the pad reach, blocker side -> splits")
	check(Visual.choose_save(0.9, 0.1, 2.2) == "stack_left", "Sliding toward a low wide shot, glove side -> pad stack")
	check(Visual.choose_save(-0.9, 0.1, -2.2) == "stack_right", "Sliding toward a low wide shot, blocker side -> pad stack")
	check(Visual.choose_save(0.9, 0.1, -2.2) == "pad_left", "Sliding away from the shot -> no stack")
	check(Visual.choose_save(0.9, 0.1, 0.4) == "pad_left", "Not sliding -> pad extension, not a stack")
	check(Visual.choose_save(0.9, 0.1, 0.0, "stack_left") == "stack_left", "A started pad stack is kept")
	check(Visual.choose_save(0.9, 1.2, 2.2) == "glove", "High shot while sliding -> glove, not a stack")
	var v = Visual.new()
	v.goalie = true
	root.add_child(v)
	await process_frame
	settle(v, "", Vector2(0, 0.8))
	# Save motion: the weight fires fast (half-way by ~0.07 s, as the old
	# linear ramp), then eases into the pose instead of stopping dead, and the
	# recovery starts from rest; weights stay within 0..1.
	var trace: Array[float] = []
	for f in range(40):
		v.set_save("glove" if f < 25 else "", Vector2(0.8, 1.35), 1.0 / 60)
		trace.append(float(v.save_weights.glove))
	var half_frame := trace.find(trace.filter(func(w): return w >= 0.5)[0])
	check(half_frame >= 3 and half_frame <= 4, "Save reaches half-way on frame %d (timing kept)" % half_frame)
	var near_full := trace.find(trace.filter(func(w): return w >= 0.95)[0])
	check(trace[near_full] - trace[near_full - 1] < 0.03, "Save eases into the pose (last step %.3f)" % (trace[near_full] - trace[near_full - 1]))
	check(trace[24] - trace[25] < 0.02, "Recovery starts from rest (first step %.3f)" % (trace[24] - trace[25]))
	check(trace.all(func(w): return w >= 0.0 and w <= 1.0), "Save weight stays within 0..1")
	settle(v, "", Vector2(0, 0.8))
	var ready_catcher: Vector3 = v.goalie_gloves[0].position
	var ready_blocker: Vector3 = v.goalie_gloves[1].position
	# Eyes on the puck: straight ahead when ready, toward the crossing point
	# in a save (within the neck's range).
	var ready_look: Vector3 = (v.helmet.basis as Basis).z
	check(ready_look.distance_to(Vector3.BACK) < 0.01, "Ready: goalie looks straight ahead (%s)" % ready_look)
	for probe in [["glove", Vector2(0.8, 1.35), 1.0, -1.0], ["pad_right", Vector2(-0.95, 0.1), -1.0, 1.0]]:
		settle(v, probe[0], probe[1], 60)
		var fwd: Vector3 = (v.helmet.basis as Basis).z
		check(signf(fwd.x) == probe[2] and absf(fwd.x) > 0.25, "%s: head turns toward the puck (%s)" % [probe[0], fwd])
		check(signf(-fwd.y) == probe[3] and absf(fwd.y) > 0.15, "%s: head tips toward the puck's height (%s)" % [probe[0], fwd])
		check(acos(clampf(fwd.dot(Vector3.BACK), -1, 1)) < v.LOOK_YAW + v.LOOK_DOWN + 0.01, "%s: turn within the neck's range" % probe[0])
		settle(v, "", Vector2(0, 0.8), 90)
	# Glove: catcher reaches toward a high glove-side shot.
	settle(v, "glove", Vector2(0.8, 1.35))
	var catcher: Vector3 = v.goalie_gloves[0].position
	check(catcher.y > ready_catcher.y + 0.35 and catcher.x > ready_catcher.x + 0.1, "Glove rises and reaches out (%s -> %s)" % [ready_catcher, catcher])
	check(v.posed_wrists[0].distance_to(v.shoulder_of(0)) <= v.ARM_REACH + 0.01, "Glove reach stays within arm length")
	var gear: Dictionary = v.get_goalie_gear()
	check(gear.Catcher.transform.origin.y > 1.0, "Catcher collider follows the glove")
	# Interrupt the glove with a blocker read: blocker ramps in while glove recovers.
	for k in range(6):
		v.set_save("blocker", Vector2(-0.7, 0.95), 1.0 / 60)
		v.animate(0, 1.0 / 60, 0, false)
	check(v.save_weights.blocker > 0.5 and v.save_weights.glove > 0.5 and v.save_weights.glove < 1.0, "New save interrupts mid-recovery (blocker %.2f, glove %.2f)" % [v.save_weights.blocker, v.save_weights.glove])
	settle(v, "blocker", Vector2(-0.7, 0.95))
	var blocker: Vector3 = v.goalie_gloves[1].position
	check(blocker.x < ready_blocker.x - 0.15 and blocker.y > ready_blocker.y + 0.15, "Blocker punches out and up (%s -> %s)" % [ready_blocker, blocker])
	check(v.stick_shaft.scale.y < v.GOALIE_STICK_REACH + 0.5, "Goalie stick never stretches (%.2f)" % v.stick_shaft.scale.y)
	# Pad extensions: one leg out along the ice on the shot side, pad low.
	for kind in ["pad_left", "pad_right"]:
		settle(v, kind, Vector2(0.95 if kind == "pad_left" else -0.95, 0.1), 90)
		var out_i: int = 0 if kind == "pad_left" else 1
		var side := 1.0 if out_i == 0 else -1.0
		check(side * v.feet[out_i].x > 0.9, "%s: skate reaches out to the post (%.2f m)" % [kind, v.feet[out_i].x])
		var pad: Dictionary = v.get_goalie_gear()["PadLeft" if out_i == 0 else "PadRight"]
		var centre: Vector3 = pad.transform.origin
		check(centre.y < 0.30, "%s: extended pad lies low on the ice (centre %.2f m)" % [kind, centre.y])
		# Gear transforms are actor-space; the rig faces the other way, so the
		# goalie's left (rig +x) is actor -x.
		check(-side * centre.x > 0.45, "%s: extended pad covers the wide side (%.2f m)" % [kind, centre.x])
	# Splits: hips low, both legs straight out along the ice to either side,
	# pads face-on to the shooter and down on the ice, wider than a pad save.
	for kind in ["splits_left", "splits_right"]:
		settle(v, "", Vector2(0, 0.8), 90)
		var lead := 1.0 if kind == "splits_left" else -1.0
		settle(v, kind, Vector2(1.15 * lead, 0.1), 90)
		var hip_y: float = (v.rest["upperleg01.L"] as Transform3D).origin.y + v.posed_drop.y
		check(hip_y < 0.40, "%s: hips drop low (%.2f m)" % [kind, hip_y])
		check(lead * v.posed_drop.x > 0.15, "%s: hips slide toward the puck (%.2f m)" % [kind, v.posed_drop.x])
		check(lead * v.feet[0 if lead > 0 else 1].x > 1.0, "%s: lead skate reaches past the pad-save reach (%.2f m)" % [kind, v.feet[0 if lead > 0 else 1].x])
		check(v.feet[0].x - v.feet[1].x > 1.55, "%s: legs spread to both sides (%.2f m)" % [kind, v.feet[0].x - v.feet[1].x])
		for i in range(2):
			var leg: Vector3 = v.feet[i] - v.knees[i]
			var thigh: Vector3 = v.knees[i] - ((v.rest["upperleg01.L" if i == 0 else "upperleg01.R"] as Transform3D).origin + v.posed_drop)
			check(leg.normalized().dot(thigh.normalized()) > 0.95, "%s: leg %d nearly straight (%.3f)" % [kind, i, leg.normalized().dot(thigh.normalized())])
			var face: Vector3 = (v.pads[i].basis as Basis).z
			check(face.z > 0.9, "%s: pad %d faces the shooter (%s)" % [kind, i, face])
			check(v.feet[i].y < 0.16, "%s: skate %d on the ice (%.3f)" % [kind, i, v.feet[i].y])
		var split_gear: Dictionary = v.get_goalie_gear()
		# Covered width: outermost pad-collider ends along the ice (the goal is 1.83 m).
		var lo := INF
		var hi := -INF
		for pad_name in ["PadLeft", "PadRight"]:
			var xf: Transform3D = split_gear[pad_name].transform
			var half: float = (split_gear[pad_name].size as Vector3).y * 0.5
			for end_ in [-1.0, 1.0]:
				var x: float = (xf * Vector3(0, end_ * half, 0)).x
				lo = minf(lo, x)
				hi = maxf(hi, x)
		check(hi - lo > 1.6, "%s: pad colliders cover the goal mouth (%.2f m of 1.83)" % [kind, hi - lo])
		check(v.stick_shaft.scale.y < v.GOALIE_STICK_REACH + 0.5, "%s: stick never stretches" % kind)
		# The stick lies flat across the five-hole (paddle on the ice), not
		# standing up in front of the chest.
		var shaft_up: Vector3 = (v.stick_shaft.basis as Basis).y.normalized()
		check(absf(shaft_up.y) < 0.45, "%s: stick lies low across the ice (%s)" % [kind, shaft_up])
		check(absf(shaft_up.x) > 0.6, "%s: stick runs across the five-hole (%s)" % [kind, shaft_up])
	# Pad stack: on the side, both pads stacked into a wall from the ice,
	# facing the shooter, feet toward the post, colliders following.
	for kind in ["stack_left", "stack_right"]:
		settle(v, "", Vector2(0, 0.8), 90)
		var lead := 1.0 if kind == "stack_left" else -1.0
		settle(v, kind, Vector2(0.9 * lead, 0.1), 90)
		var upright: Basis = Basis(Vector3.UP, v.rig.rotation.y)
		var stack_gear: Dictionary = v.get_goalie_gear()
		var low := INF
		var high := -INF
		var far := -INF
		for pad_name in ["PadLeft", "PadRight"]:
			var xf: Transform3D = stack_gear[pad_name].transform
			var size: Vector3 = stack_gear[pad_name].size
			for c in range(8):
				var p: Vector3 = xf * ((Vector3(c & 1, (c >> 1) & 1, (c >> 2) & 1) - Vector3.ONE * 0.5) * size)
				low = minf(low, p.y)
				high = maxf(high, p.y)
				# Rig +x (glove side) is actor -x: the rig faces the other way.
				far = maxf(far, -lead * p.x)
			var face: Vector3 = upright.inverse() * (v.rig.basis * (v.pads[0 if pad_name == "PadLeft" else 1].basis as Basis).z)
			check(face.z > 0.85, "%s: %s faces the shooter (%s)" % [kind, pad_name, face])
		check(low < 0.06, "%s: bottom pad on the ice (%.3f m)" % [kind, low])
		check(high > 0.55, "%s: stacked pads stand as a wall (%.2f m high)" % [kind, high])
		check(far > 0.8, "%s: pads reach toward the post (%.2f m)" % [kind, far])
		var p_low: Vector3 = v.rig.transform * v.pads[1 if lead > 0 else 0].position
		var p_top: Vector3 = v.rig.transform * v.pads[0 if lead > 0 else 1].position
		check(p_top.y - p_low.y > 0.22, "%s: lead-side leg on top (%.2f m)" % [kind, p_top.y - p_low.y])
		var torso_low: float = (v.rig.transform * v.torso_pose.origin).y
		check(torso_low < 0.45, "%s: body down on the ice (chest %.2f m)" % [kind, torso_low])
		check(v.stick_shaft.scale.y < v.GOALIE_STICK_REACH + 0.5, "%s: stick never stretches" % kind)
	# Recovering from a stack stands the goalie back up (no leftover roll).
	settle(v, "", Vector2(0, 0.8), 120)
	check(absf(v.stack_roll) < 0.001 and absf(v.rig.rotation.z) < 0.14, "Stack recovers upright (roll %.3f)" % v.rig.rotation.z)
	v.queue_free()
	await process_frame
	print("Goalie save failures: ", failures)
	quit(failures)
