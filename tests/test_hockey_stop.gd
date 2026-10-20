extends SceneTree
## Hockey stops: a hard deceleration from speed (brake button or an AI-style
## reversal) turns the body across the line of travel into a low skid with the
## blades spraying snow; gentle slowing and slow braking don't; the pose blends
## in and out without pops and recovers to the normal stance.
var failures := 0
const DT := 1.0 / 120

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

## Advances one frame moving the skater along -Z at `speed`.
func step(v, speed: float, braking := false, pushing := true) -> void:
	v.position += Vector3(0, 0, -speed * DT)
	v.animate(speed, DT, 0, pushing, braking)

## Angle (degrees) between the hips' facing and the direction of travel (-Z).
func hip_angle(v) -> float:
	var forward: Vector3 = v.rig.global_basis * Vector3(0, 0, 1)
	forward.y = 0
	return rad_to_deg(forward.normalized().angle_to(Vector3(0, 0, -1)))

func spraying(v) -> bool:
	for s in v.sprays:
		if s.is_spraying(): return true
	return false

func cruise(v, speed: float) -> void:
	for f in range(240): step(v, speed)

func run() -> void:
	var Visual = load("res://scripts/skater_visual.gd")
	var v = Visual.new()
	root.add_child(v)
	await process_frame
	check(v.sprays.size() == 2, "Skater has a snow spray on each blade")

	# 1. Hard brake from 8 m/s (Ctrl: 22 m/s^2).
	cruise(v, 8.0)
	check(not v.stopping and v.stop_weight == 0.0, "Cruising is not a stop")
	var speed := 8.0
	var max_weight := 0.0
	var max_angle := 0.0
	var lowest_drop := 0.0
	var sprayed := false
	var feet := [[], []]
	var yaws := []
	var max_jerk := 0.0
	var max_yaw_jerk := 0.0
	var mid_checked := false
	for f in range(60):
		speed = maxf(0.0, speed - 22.0 * DT)
		step(v, speed, true)
		max_weight = maxf(max_weight, v.stop_weight)
		if v.stop_weight > 0.95:
			max_angle = maxf(max_angle, hip_angle(v))
			lowest_drop = minf(lowest_drop, v.posed_drop.y)
		sprayed = sprayed or spraying(v)
		if v.stop_weight > 0.95 and not mid_checked:
			mid_checked = true
			for i in range(2):
				var hip: Vector3 = v.rest["upperleg01" + (".L" if i == 0 else ".R")].origin + v.posed_drop
				check(v.knees[i].distance_to(hip) < 0.445 and v.knees[i].distance_to(v.feet[i]) < 0.455, "Leg %d keeps its length in the stop" % i)
				check(hip.distance_to(v.feet[i]) < 0.80, "Knee %d is bent in the stop (hip-ankle %.2f m)" % [i, hip.distance_to(v.feet[i])])
				check(v.feet[i].y >= 0.11, "Blade %d stays on the ice in the stop" % i)
			check(absf(v.feet[0].x - v.feet[1].x) > 0.35, "Skates are spread for the skid (%.2f m)" % absf(v.feet[0].x - v.feet[1].x))
			# Both shins lean back away from the travel: blades on edge.
			check(absf(v.skates[0].rotation.z) > 0.15 or absf(v.skates[1].rotation.z) > 0.15, "Blades dig in on their edges")
			check(v.blade_position.z > 0.9, "Stick reaches out front (%.2f)" % v.blade_position.z)
	check(max_weight > 0.99, "Hard brake from speed plays the stop pose (weight %.2f)" % max_weight)
	check(max_angle > 65.0 and max_angle < 95.0, "Hips turn ~70-90 degrees across the travel (%.1f)" % max_angle)
	check(lowest_drop < -0.25, "Hips drop low in the stop (%.2f m)" % lowest_drop)
	check(sprayed, "Snow sprays from the blades while stopping")
	# 2. Recovery: stood still, then skating again.
	var recovered := false
	for f in range(240):
		step(v, 0.0, false, false)
		if v.stop_weight == 0.0: recovered = true
	check(recovered and not v.stopping, "Stop ends once the skater has stopped")
	check(absf(hip_angle(v)) < 1.0, "Hips turn back to face forward (%.1f deg)" % hip_angle(v))
	check(not spraying(v), "Spray stops after the stop")
	check(v.posed_drop.y > -0.25, "Hips come back up to the normal stance (%.2f m)" % v.posed_drop.y)

	# 3. Smoothness through a whole stop and recovery (AI-style reversal:
	# 14 m/s^2 without the brake button, then skating off again).
	cruise(v, 7.0)
	speed = 7.0
	for f in range(300):
		var pushing := true
		if f < 60: speed = maxf(0.0, speed - 14.0 * DT)
		else: speed = minf(5.0, speed + 4.0 * DT)
		step(v, speed, false, pushing)
		max_weight = maxf(max_weight, v.stop_weight)
		for i in range(2):
			feet[i].append(v.feet[i])
			var n: int = feet[i].size()
			if n >= 3:
				max_jerk = maxf(max_jerk, (feet[i][n - 1] - 2.0 * feet[i][n - 2] + feet[i][n - 3]).length())
		yaws.append(v.rig.rotation.y)
		var m := yaws.size()
		if m >= 3:
			max_yaw_jerk = maxf(max_yaw_jerk, absf(yaws[m - 1] - 2.0 * yaws[m - 2] + yaws[m - 3]))
	check(v.stop_weight < 0.01, "Reversal stop recovers once skating again (weight %.2f)" % v.stop_weight)
	check(max_jerk < 0.0065, "Feet blend into and out of the skid without pops - a linear blend read 0.016 (max second difference %.4f m)" % max_jerk)
	check(max_yaw_jerk < 0.012, "Hip turn blends in and out without pops (max second difference %.4f rad)" % max_yaw_jerk)

	# 4. Gentle slowing (coasting, 0.9 m/s^2) from speed: no stop, no spray.
	cruise(v, 8.0)
	speed = 8.0
	var gentle_weight := 0.0
	var gentle_spray := false
	for f in range(240):
		speed = maxf(0.0, speed - 0.9 * DT)
		step(v, speed, false, false)
		gentle_weight = maxf(gentle_weight, v.stop_weight)
		gentle_spray = gentle_spray or spraying(v)
	check(gentle_weight == 0.0, "Gentle slowing is not a hockey stop (weight %.2f)" % gentle_weight)
	check(not gentle_spray, "Gentle slowing throws no snow")
	# Moderate slowing (4 m/s^2) is not a hard stop either.
	cruise(v, 8.0)
	speed = 8.0
	gentle_weight = 0.0
	for f in range(120):
		speed = maxf(0.0, speed - 4.0 * DT)
		step(v, speed, false, false)
		gentle_weight = maxf(gentle_weight, v.stop_weight)
	check(gentle_weight == 0.0, "Moderate slowing is not a hockey stop (weight %.2f)" % gentle_weight)
	# 5. Braking at low speed: no stop.
	for f in range(240): step(v, 0.0, false, false)
	cruise(v, 3.0)
	speed = 3.0
	var slow_weight := 0.0
	for f in range(60):
		speed = maxf(0.0, speed - 22.0 * DT)
		step(v, speed, true)
		slow_weight = maxf(slow_weight, v.stop_weight)
	check(slow_weight == 0.0, "Braking from a slow glide is not a hockey stop (weight %.2f)" % slow_weight)
	# 6. One-frame speed loss (a hit or the boards) is not a stop.
	for f in range(240): step(v, 0.0, false, false)
	cruise(v, 8.0)
	step(v, 5.0, false, false)
	var bump_weight := 0.0
	for f in range(60):
		step(v, 5.0, false, false)
		bump_weight = maxf(bump_weight, v.stop_weight)
	check(bump_weight == 0.0, "A sudden one-frame speed loss is not a stop (weight %.2f)" % bump_weight)

	# 7. Goalies never hockey stop.
	var keeper = Visual.new()
	keeper.goalie = true
	root.add_child(keeper)
	await process_frame
	for f in range(60):
		keeper.position.z -= 6.0 * DT
		keeper.animate(6.0, DT)
	for f in range(30):
		keeper.animate(0.0, DT, 0, false, true)
	check(keeper.stop_weight == 0.0 and keeper.sprays.is_empty(), "Goalies don't hockey stop")
	keeper.queue_free()
	v.queue_free()
	await process_frame
	print("Hockey stop failures: ", failures)
	quit(failures)
