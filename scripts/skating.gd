extends RefCounted
## Ratings modify physical acceleration and speed, never success rolls.
static func step(velocity: Vector3, intent: Vector3, rating: float, effort: bool, delta: float) -> Vector3:
	var top_speed: float = lerpf(5.5, 10.0, clampf(rating / 100.0, 0.0, 1.0))
	var acceleration: float = lerpf(6.0, 15.0, clampf(rating / 100.0, 0.0, 1.0))
	if effort:
		top_speed *= 1.15
	if intent.length_squared() > 0.01:
		return velocity.move_toward(intent.normalized() * top_speed, acceleration * delta)
	return velocity.move_toward(Vector3.ZERO, 3.0 * delta)

static func goal_crossing(previous: Vector3, current: Vector3) -> bool:
	# Only crossing the front mouth toward the net scores.
	if previous.z <= -25.0 or current.z > -25.0:
		return false
	var t: float = (-25.0 - previous.z) / (current.z - previous.z)
	var crossing: Vector3 = previous.lerp(current, t)
	return absf(crossing.x) < 0.94 and crossing.y < 1.15
