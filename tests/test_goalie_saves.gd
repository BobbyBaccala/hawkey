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
	var v = Visual.new()
	v.goalie = true
	root.add_child(v)
	await process_frame
	settle(v, "", Vector2(0, 0.8))
	var ready_catcher: Vector3 = v.goalie_gloves[0].position
	var ready_blocker: Vector3 = v.goalie_gloves[1].position
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
	v.queue_free()
	await process_frame
	print("Goalie save failures: ", failures)
	quit(failures)
