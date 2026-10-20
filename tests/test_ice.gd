extends SceneTree
## Rink markings to NHL proportions and skate cuts carved behind skaters.
const Arena = preload("res://scripts/arena.gd")
const Skating = preload("res://scripts/skating.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func near(a: float, b: float, tol := 0.02) -> bool:
	return absf(a - b) <= tol

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Markings (metres; rink end boards at z = +/-30).
	check(near(30.0 - Arena.GOAL_LINE, 11 * 0.3048), "Goal line 11 ft from the end boards")
	check(near(Arena.BLUE_LINE, 25 * 0.3048), "Blue lines 25 ft from centre")
	check(near(Arena.GOAL_LINE - Arena.END_DOT_Z, 20 * 0.3048), "End-zone spots 20 ft out from the goal line")
	check(near(Arena.DOT_X * 2.0, 44 * 0.3048), "Faceoff spots 44 ft apart")
	check(near(Arena.BLUE_LINE - Arena.NEUTRAL_DOT_Z, 5 * 0.3048), "Neutral spots 5 ft inside the blue line")
	check(near(Arena.CIRCLE_RADIUS, 15 * 0.3048), "Faceoff circles 15 ft radius")
	var circle_gap := Arena.GOAL_LINE - (Arena.END_DOT_Z + Arena.CIRCLE_RADIUS)
	check(circle_gap > 1.4 and circle_gap < 1.6, "Circle stops ~5 ft short of the goal line (%.2f m)" % circle_gap)
	check(Arena.CIRCLE_RADIUS + Arena.DOT_X + 0.61 < Arena.corner_half_width(Arena.END_DOT_Z), "Hash marks fit inside the boards")
	check(near(Arena.corner_half_width(10.0), 15.0) and Arena.corner_half_width(Arena.GOAL_LINE) < 15.0, "Corner half-width narrows in the corners")
	# Goal plane follows the goal line.
	var gl := Arena.GOAL_LINE
	check(Skating.goal_crossing(Vector3(0, 0.1, -gl + 0.5), Vector3(0, 0.1, -gl - 0.5)), "Goal registers on the moved goal line")
	check(not Skating.goal_crossing(Vector3(0, 0.1, -gl + 1.5), Vector3(0, 0.1, -gl + 0.5)), "No goal short of the line")
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	for g in m.arena.goals:
		check(near(absf(g.position.z), gl), "%s sits on the goal line" % g.name)
	# Count the hash/L marks: thin red boxes near each end-zone spot.
	var marks := 0
	for mesh in m.arena.get_children():
		if mesh is MeshInstance3D and mesh.mesh is BoxMesh and absf(mesh.position.y - 0.014) < 0.001:
			if absf(absf(mesh.position.z) - Arena.END_DOT_Z) < 1.6 and absf(absf(mesh.position.x) - Arena.DOT_X) < 6.0:
				marks += 1
	check(marks == 4 * (4 + 8), "Each end-zone circle has 4 hash marks and 8 L legs (found %d total)" % marks)
	# Skate cuts: a skater moving across the ice leaves marks behind it.
	var marks_node = m.ice_marks
	check(marks_node != null, "IceMarks exists")
	check(m.arena.ice_surface_material.get_shader_parameter("cut_tex") == marks_node.texture, "Ice shader samples the cut map")
	marks_node.clear()
	check(marks_node.cut_texels == 0, "Clear resurfaces the sheet")
	var a := Vector3(-3, 0.06, 5)
	var b := Vector3(3, 0.06, 5)
	marks_node.score(a, b, 1.0)
	check(marks_node.cut_texels >= 6 * marks_node.PX_PER_M, "A 6 m stride scores a continuous line (%d texels)" % marks_node.cut_texels)
	var mid: Vector2 = marks_node.to_texel(Vector3(0, 0, 5))
	check(marks_node.image.get_pixel(int(mid.x), int(mid.y)).r > 0.2, "Cut visible at the stride midpoint")
	var untouched: Vector2 = marks_node.to_texel(Vector3(0, 0, -20))
	check(marks_node.image.get_pixel(int(untouched.x), int(untouched.y)).r == 0.0, "Ice elsewhere stays clean")
	marks_node.clear()
	# Live play: let the match run and require cuts to build up from real skating.
	for i in range(360):
		await process_frame
		await physics_frame
	check(marks_node.cut_texels > 200, "Two-plus seconds of live skating leaves cuts (%d texels)" % marks_node.cut_texels)
	m.queue_free()
	await process_frame
	print("Ice failures: ", failures)
	quit(failures)
