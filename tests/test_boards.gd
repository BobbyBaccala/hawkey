extends SceneTree
## Boards, glass and end netting: sliding pucks at any angle and speed must
## bounce back into play; lifted pucks may only leave over the side glass
## (a real out-of-play stoppage), never through the boards or over the ends.
## Also checks that a sliding puck keeps its speed on open ice.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func shoot(m, start: Vector3, velocity: Vector3, frames: int) -> Vector3:
	m.puck.freeze = false
	m.puck.global_position = start
	m.puck.rotation = Vector3.ZERO
	m.puck.angular_velocity = Vector3.ZERO
	m.puck.linear_velocity = velocity
	m.puck.sleeping = false
	for i in range(frames):
		await physics_frame
		var p: Vector3 = m.puck.position
		if p.y < -0.5 or absf(p.x) > 16 or absf(p.z) > 31:
			return p
	return Vector3.INF

func run() -> void:
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	m.set_physics_process(false)
	for actor in m.skaters + m.goalkeepers + m.referee_nodes:
		actor.queue_free()
	await physics_frame
	# Open-ice glide: a 20 m/s pass loses well under 1 m/s over half a second.
	m.puck.freeze = false
	m.puck.global_position = Vector3(-6, 0.0128, -14)
	m.puck.linear_velocity = Vector3(20, 0, 0)
	for i in range(60):
		await physics_frame
	check(m.puck.linear_velocity.length() > 19.0, "Sliding puck keeps its speed on open ice (%.1f m/s)" % m.puck.linear_velocity.length())
	check(absf(m.puck.position.y - 0.0127) < 0.003, "Sliding puck rests on the ice surface")
	var starts := [Vector3(0, 0.0128, 0), Vector3(8, 0.0128, 20), Vector3(-8, 0.0128, -20), Vector3(12, 0.0128, -26)]
	for speed in [8.0, 25.0, 45.0]:
		for deg in range(0, 360, 30):
			var dir := Vector3(cos(deg_to_rad(deg)), 0, sin(deg_to_rad(deg)))
			for start in starts:
				var out: Vector3 = await shoot(m, start, dir * speed, 90)
				check(out == Vector3.INF, "Sliding %d m/s shot at %d deg from %s left the rink at %s" % [speed, deg, start, out])
	# Lifted shots: ends and corners have netting; only the sides may be cleared.
	for deg in range(0, 360, 30):
		var dir := Vector3(cos(deg_to_rad(deg)), 0, sin(deg_to_rad(deg)))
		var out: Vector3 = await shoot(m, Vector3(0, 0.0128, 0), dir * 45 * cos(0.3) + Vector3.UP * 45 * sin(0.3), 120)
		if out != Vector3.INF:
			check(out.y > 2.66 and absf(out.x) > 15 and absf(out.z) < 22, "Lifted shot at %d deg left only over the side glass (%s)" % [deg, out])
	m.queue_free()
	await process_frame
	print("Board failures: ", failures)
	quit(failures)
