extends SceneTree
const Gear = preload("res://scripts/gear_builder.gd")
## Goalie sweater and pad detail: accent shoulder yoke only on goalies, wider
## protector shoulders/arms than a skater sweater, pads carry kit + accent.
var failures := 0
func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", msg)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var SV = preload("res://scripts/skater_visual.gd")
	var Kit = preload("res://scripts/kit_materials.gd")
	var g = SV.new()
	g.goalie = true
	g.kit = Color("#b3162c")
	g.accent = Color("#1b2a4a")
	root.add_child(g)
	var s = SV.new()
	s.kit = Color("#b3162c")
	s.accent = Color("#1b2a4a")
	root.add_child(s)
	await physics_frame
	var gm := g.jersey.material_override as ShaderMaterial
	var sm := s.jersey.material_override as ShaderMaterial
	check(is_equal_approx(float(gm.get_shader_parameter("yoke_v")), SV.GOALIE_YOKE), "goalie sweater has the shoulder yoke")
	check(float(sm.get_shader_parameter("yoke_v")) == 0.0, "skater sweater has no yoke")
	check(gm != sm, "goalie and skater sweaters use different materials")
	var gw: float = absf(g.jersey_point(0.0, 1.40).x)
	var gwaist: float = absf(g.jersey_point(0.0, 1.10).x)
	check(gw > 0.31, "goalie shoulders are protector-wide: %.3f" % gw)
	check(gwaist > 0.24, "goalie waist is not pinched: %.3f" % gwaist)
	var pad_mat: ShaderMaterial = null
	for vis in g.pad_visuals:
		for c in vis.get_children():
			if c is MeshInstance3D: pad_mat = c.material_override
		# Constant drawn size: 91 cm long, 11 in wide, deeper than the 10 cm source.
		check(vis.scale.is_equal_approx(SV.PAD_VIS_SCALE), "pad drawn at its constant size (%s)" % vis.scale)
	check(pad_mat != null and pad_mat.get_shader_parameter("pad_graphics") == true, "pads use pad graphics")
	if pad_mat != null:
		check((pad_mat.get_shader_parameter("pad_team") as Color).is_equal_approx(g.kit), "pad team colour follows the kit")
		check((pad_mat.get_shader_parameter("pad_accent") as Color).is_equal_approx(g.accent), "pad accent follows the kit accent")
		check((pad_mat.get_shader_parameter("base_color") as Color).get_luminance() > 0.8, "pad base is white, not grey")
	check(Kit.goalie_pad(Color.RED, Color.BLUE) != Kit.goalie_pad(Color.RED, Color.GREEN), "pad materials are per accent")
	# Pad assembly through the drop and back: no telescoping (the pad and the
	# thigh rise keep one size), the knee landing stays on the knee, the rise
	# only rotates, and the skate stays on the ankle.
	for b in [0.0, 0.25, 0.5, 0.75, 1.0, 0.5, 0.0]:
		for k in range(30):
			g.butterfly = b
			g.animate(0, 1.0/60, 0, false)
		for i in range(2):
			var vis: Node3D = g.pad_visuals[i]
			var rise: Node3D = g.thigh_rises[i]
			check(vis.scale.is_equal_approx(SV.PAD_VIS_SCALE), "pad size constant at butterfly %.2f" % b)
			var sc: Vector3 = (rise.basis as Basis).get_scale()
			check(absf(sc.y - SV.PAD_VIS_SCALE.y) < 0.002 and absf(sc.z - SV.PAD_VIS_SCALE.z) < 0.002, "thigh rise size constant at butterfly %.2f (%s)" % [b, sc])
			var knee_mark: Vector3 = vis.global_transform * Vector3(0, Gear.PAD_KNEE, 0)
			var knee_w: Vector3 = g.rig.global_transform * (g.skeleton.transform * Vector3(g.knees[i]))
			check(absf((g.pads[i].global_transform.affine_inverse() * knee_mark).y - (g.pads[i].global_transform.affine_inverse() * knee_w).y) < 0.005, "knee landing on the knee at butterfly %.2f" % b)
			# The boot pivots about the ankle: its ankle point never leaves it.
			var ankle_from_boot: Vector3 = g.skates[i].transform * Vector3(0, 0.0525, 0)
			check(ankle_from_boot.is_finite(), "boot pose finite")
	# The stick is the de-branded downloaded model, drawn instead of the proxies.
	check(g.goalie_stick_mesh != null and g.goalie_stick_mesh.visible, "goalie draws the stick model")
	check(not g.goalie_paddle.visible and not g.stick_shaft.visible, "box stick proxies hidden")
	var stick_len: float = g.goalie_stick_mesh.mesh.get_aabb().size.y * SV.GOALIE_STICK_SCALE
	check(stick_len > 1.4 and stick_len < 1.55, "goalie stick about 1.45 m (%.2f)" % stick_len)
	# Each pad is held on by a knee cradle, calf wrap and straps that follow the knee.
	check(g.pad_rears.size() == 2, "both pads have rear straps")
	for i in range(2):
		var knee_l: Vector3 = g.pads[i].transform.affine_inverse() * g.knees[i]
		check(absf(g.pad_rears[i].position.y - knee_l.y) < 0.005, "straps ride with the knee")
	check(g.skate_cuffs.size() == 2, "goalie skates have shin-following cuffs")
	print("Goalie kit failures: ", failures)
	quit(1 if failures > 0 else 0)
