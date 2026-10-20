extends SceneTree
## Skater body mechanics: arms and gloves stay outside the torso in every stick
## position and through the stride, and the stride is one leg at a time - the
## feet alternate pushes out to the side, one lifts while the other glides, and
## a coasting skater keeps a staggered stance rather than feet side by side.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func arm_report(v) -> Array:
	var worst := 0.0
	var hand := INF
	for i in range(2):
		var suffix := ".L" if i == 0 else ".R"
		var shoulder: Vector3 = v.shoulder_of(i)
		# Deepest point of the sleeve tube inside the jersey, past the shoulder cap
		# (the first ~12 cm of sleeve is where it joins the jersey).
		var elbow: Vector3 = v.posed_elbows[i]
		var wrist: Vector3 = v.posed_wrists[i]
		var control := elbow * 2 - (shoulder + wrist) * 0.5
		for k in range(4, 11):
			var t := k / 10.0
			var c: Vector3 = (1 - t) * (1 - t) * shoulder + 2 * (1 - t) * t * control + t * t * wrist
			var radius := lerpf(0.105, 0.078, t * 2) if t <= 0.5 else lerpf(0.078, 0.060, (t - 0.5) * 2)
			worst = maxf(worst, radius - v.torso_clearance(c))
		hand = minf(hand, v.torso_clearance(v.posed_wrists[i]))
	return [worst, hand]

func run() -> void:
	var Visual = load("res://scripts/skater_visual.gd")
	var v = Visual.new()
	root.add_child(v)
	await process_frame
	# Arms: every stick position, standing and striding.
	for speed in [0.0, 8.0]:
		for stick in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(0.7, 0.7)]:
			v.desired_stick = stick
			for f in range(60):
				v.animate(speed, 1.0 / 60)
				if f % 6 == 5:
					var r := arm_report(v)
					check(r[0] < 0.015, "speed %d stick %s frame %d: sleeve sinks %.3f m into the torso" % [speed, stick, f, r[0]])
					check(r[1] > 0.04, "speed %d stick %s frame %d: glove only %.3f m outside the jersey" % [speed, stick, f, r[1]])
	v.desired_stick = Vector2.ZERO
	# Stride: sample two full cycles at speed.
	var lifted_count := [0, 0]
	var both_lifted := 0
	var max_spread := [0.0, 0.0]
	var pushing_side_changes := 0
	var last_pusher := -1
	for f in range(240):
		v.animate(8.0, 1.0 / 120)
		var hip_l: Vector3 = v.rest["upperleg01.L"].origin
		var lifted := [false, false]
		for i in range(2):
			var ankle: Vector3 = v.feet[i]
			lifted[i] = ankle.y > 0.14
			if lifted[i]: lifted_count[i] += 1
			max_spread[i] = maxf(max_spread[i], absf(ankle.x))
			check(ankle.y >= 0.11, "Foot %d never sinks into the ice" % i)
			var hip: Vector3 = v.rest["upperleg01" + (".L" if i == 0 else ".R")].origin
			check(v.knees[i].distance_to(hip + v.posed_drop) < 0.445 and v.knees[i].distance_to(ankle) < 0.455, "Leg %d keeps its length (no stretched shin)" % i)
		if lifted[0] and lifted[1]: both_lifted += 1
		var pusher: int = 0 if v.stride[0].ext > v.stride[1].ext else 1
		if absf(v.stride[0].ext - v.stride[1].ext) > 0.3 and pusher != last_pusher:
			if last_pusher != -1: pushing_side_changes += 1
			last_pusher = pusher
	check(lifted_count[0] > 20 and lifted_count[1] > 20, "Each foot lifts in recovery (%s frames)" % [lifted_count])
	check(both_lifted == 0, "Never both feet off the ice (%d frames)" % both_lifted)
	check(max_spread[0] > 0.40 and max_spread[1] > 0.40, "Each push drives the foot out to the side (%.2f / %.2f m)" % max_spread)
	check(pushing_side_changes >= 2, "Pushes alternate leg to leg (%d changes)" % pushing_side_changes)
	# Coasting: no push, feet staggered rather than side by side.
	for f in range(240):
		v.animate(6.0, 1.0 / 120, 0, false)
	var stagger := absf(v.feet[0].z - v.feet[1].z)
	check(stagger > 0.15, "Coasting stance is staggered (%.2f m between toes)" % stagger)
	v.queue_free()
	await process_frame
	print("Stride failures: ", failures)
	quit(failures)
