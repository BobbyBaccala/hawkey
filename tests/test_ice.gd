extends SceneTree
## Rink markings to NHL proportions and skate cuts carved behind skaters.
const Arena = preload("res://scripts/arena.gd")
const Skating = preload("res://scripts/skating.gd")
const Puck = preload("res://scripts/puck.gd")
const IceMarks = preload("res://scripts/ice_marks.gd")
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
	check(near(Arena.corner_half_width(10.0), Arena.HALF_WIDTH) and Arena.corner_half_width(Arena.GOAL_LINE) < Arena.HALF_WIDTH, "Corner half-width narrows in the corners")
	# NHL sheet: 85 ft wide, 28 ft corner radii, continuous where the arc starts.
	check(near(Arena.HALF_WIDTH * 2.0, 85 * 0.3048), "Rink is 85 ft wide")
	check(near(Arena.CORNER_RADIUS, 28 * 0.3048), "Corners have a 28 ft radius")
	check(near(Arena.corner_half_width(Arena.CORNER_START + 0.001), Arena.HALF_WIDTH), "Corner arc meets the side boards smoothly")
	check(near(Arena.corner_half_width(Arena.HALF_LENGTH), Arena.HALF_WIDTH - Arena.CORNER_RADIUS), "Corner arc meets the end boards")
	check(near(Puck.RINK_HALF.x, Arena.HALF_WIDTH + 0.2) and near(IceMarks.RINK_SIZE.x, Arena.HALF_WIDTH * 2.0), "Puck ice plane and cut map follow the rink width")
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
	# Slice 2: fresh flood gloss that dries off, and board reflections.
	check(marks_node.freshness() > 0.99, "Resurfaced sheet starts glossy")
	check(marks_node.material == m.arena.ice_surface_material, "Flood sheen drives the ice shader")
	marks_node.since_flood = marks_node.DRY_TIME + 1.0
	await process_frame
	await process_frame
	check(marks_node.freshness() == 0.0, "Flood gloss dries off")
	check(m.arena.ice_surface_material.get_shader_parameter("fresh") is float and m.arena.ice_surface_material.get_shader_parameter("fresh") == 0.0, "Dry sheet reaches the shader")
	marks_node.clear()
	await process_frame
	await process_frame
	check(m.arena.ice_surface_material.get_shader_parameter("fresh") > 0.99, "New period's flood reaches the shader")
	check("board_distance" in m.arena.ice_surface_material.shader.code, "Ice shader mirrors the boards near the edge")
	var a := Vector3(-3, 0.06, 5)
	var b := Vector3(3, 0.06, 5)
	marks_node.score(a, b, 1.0)
	check(marks_node.cut_texels >= 6 * marks_node.PX_PER_M, "A 6 m stride scores a continuous line (%d texels)" % marks_node.cut_texels)
	# The stroke is anti-aliased across neighbouring rows: sum a column through it.
	var column := func(x_m: float) -> float:
		var c: Vector2 = marks_node.to_texel(Vector3(x_m, 0, 5))
		var total := 0.0
		for dy in range(-2, 3):
			total += marks_node.image.get_pixel(int(c.x), int(c.y) + dy).r
		return total
	check(column.call(0.0) > 0.2, "Cut visible at the stride midpoint (%.2f)" % column.call(0.0))
	# Smooth, continuous stroke: no beads (bright joints) or gaps along it.
	var lo := INF
	var hi := 0.0
	for i in range(-80, 81):
		var v: float = column.call(i * 0.03)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	check(lo > 0.0 and hi / lo < 1.35, "Stroke intensity is even along its length (min %.3f max %.3f)" % [lo, hi])
	# Wear haze builds where skaters pass.
	marks_node.haze(Vector3(0, 0, -10), 1.0)
	var hz: Vector2 = marks_node.to_texel(Vector3(0, 0, -10))
	check(marks_node.image.get_pixel(int(hz.x), int(hz.y)).g > 0.02, "Haze splat lands in the wear channel")
	check(marks_node.image.get_pixel(int(hz.x), int(hz.y)).r == 0.0, "Haze leaves the scratch channel alone")
	var untouched: Vector2 = marks_node.to_texel(Vector3(0, 0, -20))
	check(marks_node.image.get_pixel(int(untouched.x), int(untouched.y)).r == 0.0, "Ice elsewhere stays clean")
	# Cuts run over the paint: every flat marking samples the same cut map
	# (and flood gloss) by world position, and the emblem has a wear layer.
	var arena = m.arena
	check(arena.paint_materials.size() >= 4, "Paint materials exist for red, blue, crease and emblem wear (%d)" % arena.paint_materials.size())
	for pm in arena.paint_materials:
		check(pm.get_shader_parameter("cut_tex") == marks_node.texture, "Painted marking samples the cut map")
		check("MODEL_MATRIX" in pm.shader.code, "Paint maps cuts by world position")
	check(marks_node.paint_materials == arena.paint_materials, "Flood gloss reaches the paint")
	var unpainted := 0
	var painted := 0
	for n in arena.get_children():
		if n is MeshInstance3D and n.position.y > 0.005 and n.position.y < 0.03 and absf(n.position.x) < 15.0 and absf(n.position.z) < 30.0:
			if n.mesh is BoxMesh or n.mesh is ImmediateMesh or n.mesh is CylinderMesh:
				var mo = n.material_override
				if n.mesh is ImmediateMesh: mo = n.mesh.surface_get_material(0)
				if mo is ShaderMaterial and mo in arena.paint_materials: painted += 1
				elif not (n.mesh is CylinderMesh and n.position.length() < 0.1): unpainted += 1
	check(unpainted == 0 and painted > 60, "Every line, circle, spot and crease is painted (%d painted, %d not)" % [painted, unpainted])
	check(arena.emblem_wear != null and arena.emblem_wear.material_override in arena.paint_materials, "Centre emblem carries a wear layer")
	check(arena.emblem_wear.material_override.render_priority > 0, "Emblem wear draws over the logo text")
	await process_frame
	await process_frame
	check(absf(arena.paint_materials[0].get_shader_parameter("fresh") - marks_node.freshness()) < 0.05, "Paint gloss follows the flood")
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
