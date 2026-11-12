extends SceneTree
## Goalie gloves are worn on the arms in every save. The ready stance keeps its
## glove rotations; the catcher pocket and blocker board face the shooter; the
## catcher stays upright (wrist cocked) unless it reaches for a puck - then its
## fingers follow the forearm out; the blocker turns with the stick so the
## shaft stays through the fist in every pose, including splits and stacks.
var failures := 0
func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", msg)
func _initialize() -> void: call_deferred("run")

func settle(v, kind: String, target: Vector2) -> void:
	for f in range(90):
		v.butterfly = move_toward(v.butterfly, 1.0 if kind in ["butterfly", "pad_left", "pad_right"] else 0.0, 0.1)
		v.set_save(kind, target, 1.0 / 60)
		v.animate(0, 1.0 / 60, 0, false)

## Angle (degrees) between the blocker's fist axis and the drawn stick shaft.
func fist_to_shaft(v) -> float:
	var fist: Vector3 = ((v.goalie_gloves[1].basis as Basis) * v.BLOCKER_SHAFT_LOCAL).normalized()
	var shaft: Vector3 = (v.stick_shaft.basis as Basis).y.normalized()
	return rad_to_deg(acos(clampf(absf(fist.dot(shaft)), 0.0, 1.0)))

func run() -> void:
	var v = load("res://scripts/skater_visual.gd").new()
	v.goalie = true
	root.add_child(v)
	await process_frame
	settle(v, "", Vector2(0, 0.8))
	# Ready stance: the rotations the gloves were tuned to.
	check((v.goalie_gloves[0].rotation as Vector3).distance_to(Vector3(-0.12, 0.32, -0.12)) < 0.01, "catcher ready rotation kept (%s)" % v.goalie_gloves[0].rotation)
	check((v.goalie_gloves[1].rotation as Vector3).distance_to(Vector3(-0.10, -0.28, 0.06)) < 0.01, "blocker ready rotation kept (%s)" % v.goalie_gloves[1].rotation)
	var poses := [["", Vector2(0, 0.8)], ["butterfly", Vector2(0.1, 0.15)], ["glove", Vector2(0.75, 1.35)], ["blocker", Vector2(-0.7, 0.95)],
		["pad_left", Vector2(0.95, 0.1)], ["pad_right", Vector2(-0.95, 0.1)], ["splits_left", Vector2(1.15, 0.1)], ["splits_right", Vector2(-1.15, 0.1)],
		["stack_left", Vector2(0.9, 0.1)], ["stack_right", Vector2(-0.9, 0.1)]]
	for pose in poses:
		settle(v, "", Vector2(0, 0.8))
		settle(v, pose[0], pose[1])
		var label: String = pose[0] if pose[0] != "" else "ready"
		var c: Basis = v.goalie_gloves[0].basis
		var b: Basis = v.goalie_gloves[1].basis
		check(c.z.normalized().z > 0.85, "%s: catcher pocket faces the shooter (%s)" % [label, c.z])
		check(b.z.normalized().z > 0.85, "%s: blocker board faces the shooter (%s)" % [label, b.z])
		var off := fist_to_shaft(v)
		check(off < 2.0, "%s: stick runs through the blocker fist (%.1f deg off)" % [label, off])
		if pose[0] == "glove" or pose[0] == "stack_left":
			# Reaching: fingers out along the forearm (tipped up by the wrist).
			var fore: Vector3 = (v.posed_wrists[0] - v.posed_elbows[0]).normalized()
			var want: Vector3 = fore + Vector3(0, v.CATCHER_WRIST_COCK, 0)
			want = (want - c.z.normalized() * c.z.normalized().dot(want)).normalized()
			var fingers: Vector3 = (c * v.CATCHER_FINGERS_LOCAL).normalized()
			check(fingers.dot(want) > 0.95, "%s: catcher fingers follow the reaching arm (%.3f)" % [label, fingers.dot(want)])
		elif not pose[0].begins_with("stack"):
			# Not reaching: the catcher stays upright, ready to close.
			var fingers2: Vector3 = (c * v.CATCHER_FINGERS_LOCAL).normalized()
			check(fingers2.y > 0.95, "%s: catcher stays upright (%s)" % [label, fingers2])
	print("Glove fit failures: ", failures)
	quit(1 if failures > 0 else 0)
