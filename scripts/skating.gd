extends RefCounted
static func step(velocity: Vector3, intent: Vector3, rating: float, effort: bool, delta: float) -> Vector3:
	var attribute := clampf(rating / 100,0,1)
	var top_speed := lerpf(5.8,9.4,attribute)
	var acceleration := lerpf(7,13,attribute)
	if effort: top_speed *= 1.12
	if intent.length_squared() < 0.01:
		return velocity.move_toward(Vector3.ZERO,1.7 * delta)
	var direction := intent.normalized()
	var speed := velocity.length()
	if speed < 0.1:
		return direction * acceleration * delta
	# Edges redirect momentum at a capped rate; hard reversals scrub speed.
	var angle := velocity.normalized().angle_to(direction)
	if angle > 1.8:
		return velocity.move_toward(direction * top_speed,acceleration * 1.8 * delta)
	var turned := velocity.normalized().slerp(direction,minf(1,delta * lerpf(7,3,speed / 12)))
	speed = move_toward(speed,top_speed,acceleration * delta)
	return turned.normalized() * speed

static func goal_crossing(previous: Vector3, current: Vector3) -> bool:
	return goal_crossing_end(previous,current,-1)

static func goal_crossing_end(previous: Vector3, current: Vector3, end_sign: float) -> bool:
	var before := previous.z * end_sign
	var after := current.z * end_sign
	if before >= 25 or after < 25: return false
	var t := (25 - before) / (after - before)
	var crossing := previous.lerp(current,t)
	return absf(crossing.x) < 0.83 and crossing.y >= 0 and crossing.y < 1.15
