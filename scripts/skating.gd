extends RefCounted
static func step(velocity: Vector3, intent: Vector3, rating: float, effort: bool, delta: float) -> Vector3:
	var attribute := clampf(rating / 100,0,1)
	# Weighty, EA-style skating: elite skaters reach ~9.4 m/s in about two
	# seconds, glide a long way, and carve wider turns the faster they go.
	var top_speed := lerpf(5.8,9.4,attribute)
	var acceleration := lerpf(4.6,7.4,attribute)
	if effort: top_speed *= 1.12
	top_speed *= minf(1,intent.length())
	if intent.length_squared() < 0.01:
		return velocity.move_toward(Vector3.ZERO,0.9 * delta)
	var direction := intent.normalized()
	var speed := velocity.length()
	if speed < 0.1:
		# First push from a standstill: build on the current speed so slow
		# accelerations still get past this threshold.
		return direction * (speed + acceleration * 1.6 * delta)
	# Edges redirect momentum at a capped rate; hard reversals scrub speed.
	var angle := velocity.normalized().angle_to(direction)
	if angle > 1.8:
		return velocity.move_toward(direction * top_speed,acceleration * 1.8 * delta)
	var turned := velocity.normalized().slerp(direction,minf(1,delta * lerpf(6.5,2.0,clampf(speed / 9.5,0,1))))
	speed = move_toward(speed,top_speed,acceleration * delta)
	return turned.normalized() * speed

static func goal_crossing(previous: Vector3, current: Vector3) -> bool:
	return goal_crossing_end(previous,current,-1)

static func goal_crossing_end(previous: Vector3, current: Vector3, end_sign: float) -> bool:
	var before := previous.z * end_sign
	var after := current.z * end_sign
	var whole_puck_plane:=25.0381
	if before >= whole_puck_plane or after < whole_puck_plane: return false
	var t := (whole_puck_plane - before) / (after - before)
	var crossing := previous.lerp(current,t)
	return absf(crossing.x) < 0.8869 and crossing.y >= 0 and crossing.y < 1.15
