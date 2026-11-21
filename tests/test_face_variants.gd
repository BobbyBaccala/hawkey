extends SceneTree
## Skater faces: several skin tones across jersey numbers, stable per number,
## and an explicit face_variant overrides the pick.
var failures := 0
func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", msg)
func _initialize() -> void: call_deferred("run")
func tone_of(v: Node3D) -> Color:
	for n in v.head_nodes:
		if n.name == "MeshHead":
			return (n.material_override as ShaderMaterial).get_shader_parameter("tone")
	return Color.BLACK
func run() -> void:
	var SV = preload("res://scripts/skater_visual.gd")
	var tones := {}
	for num in ["4","9","17","23","31","44","58","71","88","91"]:
		var v = SV.new()
		v.number = num
		root.add_child(v)
		await physics_frame
		tones[tone_of(v).to_html()] = true
		var v2 = SV.new()
		v2.number = num
		root.add_child(v2)
		await physics_frame
		check(tone_of(v) == tone_of(v2), "stable face for number " + num)
	check(tones.size() >= 3, "ten numbers give >= 3 distinct skin tones: %d" % tones.size())
	var a = SV.new()
	a.face_variant = 0
	root.add_child(a)
	var b = SV.new()
	b.face_variant = 5
	root.add_child(b)
	await physics_frame
	check(tone_of(a).get_luminance() > tone_of(b).get_luminance() + 0.2, "variant 0 lighter than 5")
	# Face shapes: the numbers spread over several shapes; each shape changes
	# the lower/mid face but never the skull above the brow (helmet fit), and
	# the eyes move with the face.
	var shapes := {}
	for num in ["4","9","17","23","31","44","58","71","88","91"]:
		var vs = SV.new()
		vs.number = num
		shapes[vs.face_shape_index()] = true
		vs.free()
	check(shapes.size() >= 3, "ten numbers give >= 3 face shapes: %d" % shapes.size())
	var base: PackedVector3Array = (SV.head_shape_parts(0)["Head"][0] as Mesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for sh in range(1, SV.FACE_SHAPES.size()):
		var verts: PackedVector3Array = (SV.head_shape_parts(sh)["Head"][0] as Mesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var skull_moved := 0.0
		var face_moved := 0.0
		var jaw_lo := INF
		var jaw_hi := -INF
		var jaw_lo0 := INF
		var jaw_hi0 := -INF
		for i in range(base.size()):
			var d := verts[i].distance_to(base[i])
			if base[i].y > 1.74: skull_moved = maxf(skull_moved, d)
			else: face_moved = maxf(face_moved, d)
			if base[i].y > 1.60 and base[i].y < 1.62 and base[i].z > 0.06:
				jaw_lo = minf(jaw_lo, verts[i].x); jaw_hi = maxf(jaw_hi, verts[i].x)
				jaw_lo0 = minf(jaw_lo0, base[i].x); jaw_hi0 = maxf(jaw_hi0, base[i].x)
		check(skull_moved < 0.0005, "shape %d leaves the skull above the brow alone (%.4f m)" % [sh, skull_moved])
		check(face_moved > 0.004 and face_moved < 0.03, "shape %d reshapes the face by a few mm to cm (%.4f m)" % [sh, face_moved])
		var ew: PackedVector3Array = (SV.head_shape_parts(sh)["Eyes"][0] as Mesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var ew0: PackedVector3Array = (SV.head_shape_parts(0)["Eyes"][0] as Mesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var eye_y := 0.0
		var eye_y0 := 0.0
		for i in range(ew.size()): eye_y += ew[i].y; eye_y0 += ew0[i].y
		check(absf(eye_y - eye_y0) / ew.size() < 0.003, "shape %d keeps the eyes in their sockets" % sh)
	var wide: PackedVector3Array = (SV.head_shape_parts(5)["Head"][0] as Mesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var narrow: PackedVector3Array = (SV.head_shape_parts(2)["Head"][0] as Mesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var ww := 0.0
	var nw := 0.0
	for i in range(base.size()):
		if base[i].y > 1.60 and base[i].y < 1.63 and base[i].z > 0.06 and absf(base[i].x) < 0.07:
			ww = maxf(ww, absf(wide[i].x)); nw = maxf(nw, absf(narrow[i].x))
	check(ww > nw + 0.004, "shape 5 has a wider jaw than shape 2 (%.3f vs %.3f)" % [ww, nw])
	print("Face variant failures: ", failures)
	quit(1 if failures > 0 else 0)
